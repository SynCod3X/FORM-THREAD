import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('./index.ts', import.meta.url), 'utf8');
const runnable = stripTypeScriptTypes(source.replace(
  "import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';", '',
));
const orderId = '6d936768-8042-48f0-a137-8dc4cc3f5c75';
const requestId = 'pr-cb6d73d8-f709-4cc4-a34d-f9cfa5f072eb';

function setup() {
  let handler;
  const rpcCalls = [];
  const env = {
    XENDIT_WEBHOOK_TOKEN: 'test-token',
    SUPABASE_URL: 'https://example.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'test-service-key',
  };
  vm.runInNewContext(runnable, {
    Deno: {
      env: { get: (name) => env[name] },
      serve: (callback) => { handler = callback; },
    },
    createClient: () => ({
      rpc: async (name, args) => {
        rpcCalls.push({ name, args });
        return { error: null };
      },
    }),
    Response, Headers, fetch, console,
  });
  return { handler, rpcCalls };
}

function webhookRequest(payload, token = 'test-token') {
  return new Request('https://example.supabase.co/functions/v1/xendit-webhook', {
    method: 'POST',
    headers: { 'x-callback-token': token, 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  });
}

test('Xendit IDR dashboard sample gets 200 without changing an order', async () => {
  const { handler, rpcCalls } = setup();
  const response = await handler(webhookRequest({
    event: 'payment.capture',
    data: {
      reference_id: 'dashboard-example', payment_request_id: requestId,
      country: 'ID', currency: 'IDR', request_amount: 10000,
      channel_code: 'CARDS', status: 'SUCCEEDED',
    },
  }));
  assert.equal(response.status, 200);
  assert.equal(await response.text(), 'Ignored unsupported currency');
  assert.equal(rpcCalls.length, 0);
});

test('wrong webhook token is rejected before IDR sample handling', async () => {
  const { handler, rpcCalls } = setup();
  const response = await handler(webhookRequest({
    event: 'payment.capture', data: { currency: 'IDR' },
  }, 'wrong-token'));
  assert.equal(response.status, 401);
  assert.equal(rpcCalls.length, 0);
});

test('valid PHP capture still reaches database verification', async () => {
  const { handler, rpcCalls } = setup();
  const response = await handler(webhookRequest({
    event: 'payment.capture',
    data: {
      reference_id: orderId, payment_request_id: requestId,
      currency: 'PHP', request_amount: 2500,
      status: 'SUCCEEDED', payment_id: 'py-test',
    },
  }));
  assert.equal(response.status, 200);
  assert.equal(rpcCalls.length, 1);
  assert.equal(rpcCalls[0].name, 'apply_xendit_event');
  assert.equal(rpcCalls[0].args.p_order_id, orderId);
  assert.equal(rpcCalls[0].args.p_currency, 'PHP');
});

test('malformed PHP capture remains rejected', async () => {
  const { handler, rpcCalls } = setup();
  const response = await handler(webhookRequest({
    event: 'payment.capture',
    data: {
      reference_id: 'not-an-order', payment_request_id: requestId,
      currency: 'PHP', request_amount: 2500, status: 'SUCCEEDED',
    },
  }));
  assert.equal(response.status, 400);
  assert.equal(rpcCalls.length, 0);
});
