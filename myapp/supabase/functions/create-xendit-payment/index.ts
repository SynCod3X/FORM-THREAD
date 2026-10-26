import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' },
});

function projectKey(modernName: string, legacyName: string): string {
  try {
    const keys = JSON.parse(Deno.env.get(modernName) ?? '{}');
    if (typeof keys.default === 'string' && keys.default) return keys.default;
  } catch (_) { /* Fall back to a legacy key. */ }
  return Deno.env.get(legacyName) ?? '';
}

function adminClient(url: string, key: string) {
  return createClient(url, key, {
    auth: { persistSession: false },
    global: {
      fetch: (input, init) => {
        if (!key.startsWith('sb_secret_')) return fetch(input, init);
        // New Supabase secret keys are API keys, not JWT bearer tokens.
        const headers = new Headers(init?.headers);
        headers.set('apikey', key);
        headers.delete('Authorization');
        return fetch(input, { ...init, headers });
      },
    },
  });
}

const orderColumns = 'id,customer_id,customer_name,total,currency,status,payment_method,payment_status,xendit_request_id,payment_action';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return json({}, 200);
  if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);
  const key = Deno.env.get('XENDIT_TEST_SECRET_KEY') ?? '';
  if (!key.startsWith('xnd_development_')) {
    return json({ error: 'A Xendit test-mode secret key is required.' }, 503);
  }
  const url = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = projectKey('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY');
  const serviceKey = projectKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY');
  const token = request.headers.get('Authorization')?.replace(/^Bearer /i, '') ?? '';
  if (!token || !url || !anonKey || !serviceKey) return json({ error: 'Not configured or signed in.' }, 401);

  const authClient = createClient(url, anonKey);
  const { data: userData, error: userError } = await authClient.auth.getUser(token);
  if (userError || !userData.user) return json({ error: 'Please sign in again.' }, 401);
  const admin = adminClient(url, serviceKey);
  let orderId: string;
  try {
    const body = await request.json();
    if (typeof body.project_url === 'string' &&
        new URL(body.project_url).host !== new URL(url).host) {
      return json({ error: 'The app and Xendit payment function use different Supabase projects.' }, 409);
    }
    if (body.health_check === true) {
      const { error } = await admin.from('orders').select(orderColumns).limit(1);
      if (error) {
        console.error('Payment database readiness failed:', error.code, error.message);
        return json({ error: `The payment function cannot read orders (${error.code ?? 'unknown'}). Check its Supabase secret key and function logs.` }, 503);
      }
      return json({ ready: true });
    }
    orderId = body.order_id;
    if (typeof orderId !== 'string' || !/^[0-9a-f-]{36}$/i.test(orderId)) throw Error();
  } catch (_) { return json({ error: 'Invalid order ID.' }, 400); }

  const { data: order, error: orderError } = await admin.from('orders')
    .select(orderColumns)
    .eq('id', orderId).maybeSingle();
  if (orderError) {
    console.error('Payment order lookup failed:', orderError.code, orderError.message);
    return json({ error: `The payment function could not read orders (${orderError.code ?? 'unknown'}). Check its function logs.` }, 503);
  }
  if (!order) {
    const userDb = createClient(url, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false },
    });
    const { data: visibleOrder } = await userDb.from('orders').select('id')
      .eq('id', orderId).eq('customer_id', userData.user.id).maybeSingle();
    if (visibleOrder) {
      return json({ error: 'The order exists, but the payment function’s Supabase secret key cannot read it. Check Edge Function secrets.' }, 503);
    }
    return json({ error: 'This order is not in the payment function’s Supabase project. Check that the app and function use the same project.' }, 404);
  }
  if (order.customer_id !== userData.user.id) {
    return json({ error: 'This order belongs to a different signed-in account.' }, 403);
  }
  if (!['gcash', 'bank_transfer'].includes(order.payment_method) || order.currency !== 'PHP' || order.status !== 'pending') {
    return json({ error: 'This order cannot start a Xendit payment.' }, 409);
  }
  if (order.payment_status !== 'awaiting_payment') return json({ error: 'This payment is no longer pending.' }, 409);
  if (order.xendit_request_id && order.payment_action) {
    return json({ order_id: order.id, action: order.payment_action, payment_status: order.payment_status });
  }

  const returnUrl = `${url}/functions/v1/xendit-return?order_id=${encodeURIComponent(order.id)}`;
  const body: Record<string, unknown> = {
    reference_id: order.id,
    type: 'PAY',
    country: 'PH',
    currency: 'PHP',
    request_amount: Number(order.total),
    capture_method: 'AUTOMATIC',
    channel_code: order.payment_method === 'gcash' ? 'GCASH' : 'BANK_TRANSFER',
    description: `Order ${order.id}`,
    channel_properties: order.payment_method === 'gcash'
      ? { success_return_url: returnUrl, failure_return_url: returnUrl }
      : { display_name: String(order.customer_name ?? 'Customer').slice(0, 100) },
  };
  // Never send the secret to Flutter or include it in error logs.
  let payment: Record<string, unknown>;
  try {
    const response = await fetch('https://api.xendit.co/v3/payment_requests', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${btoa(`${key}:`)}`,
        'Content-Type': 'application/json',
        'api-version': '2024-11-11',
      },
      body: JSON.stringify(body),
    });
    payment = await response.json();
    if (!response.ok) {
      return json({ error: `Xendit test payment could not be created: ${String(payment.message ?? payment.error_code ?? response.status)}` }, 502);
    }
  } catch (_) { return json({ error: 'Xendit test service is unavailable. Retry from your order.' }, 502); }

  const actions = Array.isArray(payment.actions) ? payment.actions as Record<string, unknown>[] : [];
  const wanted = order.payment_method === 'gcash' ? 'REDIRECT_CUSTOMER' : 'PRESENT_TO_CUSTOMER';
  const action = actions.find((entry) => entry.type === wanted &&
    (order.payment_method === 'gcash' ? entry.descriptor === 'WEB_URL' : entry.descriptor === 'VIRTUAL_ACCOUNT_NUMBER'));
  const value = String(action?.value ?? '');
  if (!action || !value || (order.payment_method === 'gcash' && !value.startsWith('https://'))) {
    return json({ error: 'Xendit did not return usable payment instructions. Contact staff with your order ID.' }, 502);
  }
  const safeAction = { type: wanted, descriptor: action.descriptor, value };
  const requestId = String(payment.payment_request_id ?? '');
  if (!requestId.startsWith('pr-')) return json({ error: 'Xendit returned an invalid payment request.' }, 502);
  const { error: attachError } = await admin.rpc('attach_xendit_payment', {
    p_order_id: order.id, p_request_id: requestId, p_action: safeAction,
    p_expires_at: typeof payment.expires_at === 'string' ? payment.expires_at : null,
  });
  if (attachError) {
    console.error('Payment attachment failed:', attachError.code, attachError.message);
    return json({ error: `Payment was created but could not be saved (${attachError.code ?? 'unknown'}). Contact staff with your order ID.` }, 502);
  }
  return json({ order_id: order.id, action: safeAction, payment_status: 'awaiting_payment' });
});
