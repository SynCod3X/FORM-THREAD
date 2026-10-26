import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const reply = (body: string, status = 200) => new Response(body, { status });

function serviceKey(): string {
  try {
    const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}');
    if (typeof keys.default === 'string' && keys.default) return keys.default;
  } catch (_) { /* Fall back to a legacy key. */ }
  return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
}

function adminClient(url: string, key: string) {
  return createClient(url, key, {
    auth: { persistSession: false },
    global: {
      fetch: (input, init) => {
        if (!key.startsWith('sb_secret_')) return fetch(input, init);
        // New Supabase secret keys belong in apikey, never Authorization.
        const headers = new Headers(init?.headers);
        headers.set('apikey', key);
        headers.delete('Authorization');
        return fetch(input, { ...init, headers });
      },
    },
  });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return reply('Method not allowed', 405);
  const expected = Deno.env.get('XENDIT_WEBHOOK_TOKEN') ?? '';
  const received = request.headers.get('x-callback-token') ?? '';
  if (!expected || expected.length !== received.length) return reply('Unauthorized', 401);
  // Compare without short-circuiting individual characters.
  let difference = 0;
  for (let i = 0; i < expected.length; i++) difference |= expected.charCodeAt(i) ^ received.charCodeAt(i);
  if (difference !== 0) return reply('Unauthorized', 401);

  let payload: Record<string, unknown>;
  try { payload = await request.json(); } catch (_) { return reply('Bad JSON', 400); }
  const event = String(payload.event ?? '');
  if (!['payment.capture', 'payment.failure', 'payment_request.expiry'].includes(event)) return reply('Ignored');
  const data = payload.data as Record<string, unknown> | undefined;
  const orderId = String(data?.reference_id ?? '');
  const requestId = String(data?.payment_request_id ?? data?.id ?? '');
  const amount = Number(data?.request_amount);
  const currency = String(data?.currency ?? '');
  const status = String(data?.status ?? '');
  // This shop accepts PHP only. Xendit's authenticated Test & Save sample
  // uses IDR; acknowledge it without applying any change to an order.
  if (currency && currency !== 'PHP') return reply('Ignored unsupported currency');
  if (!/^[0-9a-f-]{36}$/i.test(orderId) || !requestId.startsWith('pr-') ||
      !Number.isFinite(amount) || amount <= 0 || currency !== 'PHP' ||
      (event === 'payment.capture' && status !== 'SUCCEEDED')) return reply('Invalid event', 400);

  const url = Deno.env.get('SUPABASE_URL') ?? '';
  const key = serviceKey();
  if (!url || !key) return reply('Server not configured', 503);
  const admin = adminClient(url, key);
  const { error } = await admin.rpc('apply_xendit_event', {
    p_order_id: orderId,
    p_request_id: requestId,
    p_event: event,
    p_amount: amount,
    p_currency: currency,
    p_payment_id: typeof data?.payment_id === 'string' ? data.payment_id : null,
  });
  // A 5xx prompts Xendit to retry if the create function has not attached yet.
  if (error) {
    console.error('Payment webhook database update failed:', error.code, error.message);
    return reply('Could not apply payment event', 503);
  }
  return reply('OK');
});
