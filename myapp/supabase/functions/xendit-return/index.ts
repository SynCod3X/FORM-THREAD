// Xendit's browser return is navigation only. The app reads the order from
// Supabase and waits for the verified webhook before showing "paid".
Deno.serve((request) => {
  if (request.method !== 'GET') {
    return new Response('Method not allowed', { status: 405 });
  }

  const orderId = new URL(request.url).searchParams.get('order_id') ?? '';
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(orderId)) {
    return new Response('Invalid order link', { status: 400 });
  }

  const appUrl = `formandthread://payment-return?order_id=${encodeURIComponent(orderId)}`;
  return new Response('Returning to Form & Thread…', {
    status: 302,
    headers: {
      Location: appUrl,
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
});
