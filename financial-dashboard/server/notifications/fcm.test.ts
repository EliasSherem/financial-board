import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createFcmSender, fcmConfiguration } from '../fcm.js';

const note = { title: 'Synthetic reminder', body: 'No real delivery' };
const auth = async () => ({ token: 'synthetic-auth', projectId: 'target-project' });
const error = (status: number, code?: string, headers?: Record<string, string>) => new Response(JSON.stringify({ error: { details: code ? [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: code }] : [], message: 'private-provider-message' } }), { status, headers });

test('configuration supports explicit ADC and cross-project targeting, rejecting incomplete/malformed JSON', () => {
  assert.deepEqual(fcmConfiguration({ FCM_PROJECT_ID: ' target-project ' }), { mode: 'adc', projectId: 'target-project' });
  assert.equal(fcmConfiguration({}), null);
  for (const raw of ['bad', '{}', 'null', '[]']) assert.equal(fcmConfiguration({ FCM_SERVICE_ACCOUNT_JSON: raw, FCM_PROJECT_ID: 'target-project' }), null);
  const config = fcmConfiguration({ FCM_PROJECT_ID: 'target-project', FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({ project_id: 'sender-project', client_email: 'synthetic@example.invalid', private_key: '-----BEGIN PRIVATE KEY-----\\nsynthetic' }) });
  assert.equal(config?.projectId, 'target-project'); assert.equal(config?.mode, 'service_account'); assert.ok(config?.credentials?.private_key.includes('\n'));
});

test('per-device acceptance, transient rejection and UNREGISTERED remain distinct; payload has Android channel and APNs sound', async () => {
  const requests: { url: string; body: Record<string, any> }[] = [];
  const responses = [new Response(JSON.stringify({ name: 'projects/test/messages/one' })), error(503), error(404, 'UNREGISTERED')];
  const logs: unknown[] = [];
  const send = createFcmSender({ accessToken: auth, fetch: async (url, init) => { requests.push({ url: String(url), body: JSON.parse(String(init?.body)) }); return responses.shift()!; }, log: (...args) => logs.push(args) });
  const results = await send(['one', 'one', 'two', 'three'], note, { route: '/momentum' }, 'event:42');
  assert.deepEqual(results.map(result => result.status), ['accepted', 'retryable', 'invalid']);
  assert.equal(results[2].code, 'UNREGISTERED'); assert.equal(requests.length, 3);
  assert.equal(requests[0].body.message.android.notification.channel_id, 'finsight_default');
  assert.equal(requests[0].body.message.apns.payload.aps.sound, 'default');
  assert.equal(requests[0].body.message.apns.headers['apns-push-type'], 'alert');
  assert.equal(requests[0].body.message.data.route, '/momentum'); assert.equal(requests[0].body.validate_only, undefined);
  assert.equal(requests[0].body.message.apns.headers['apns-collapse-id'], requests[1].body.message.apns.headers['apns-collapse-id']);
  assert.ok(requests.every(request => request.url.includes('/projects/target-project/')));
  assert.equal(JSON.stringify(logs).includes('private-provider-message'), false);
});

test('generic bad request and sender mismatch never invalidate device tokens; retry-after is respected', async () => {
  const responses = [error(400), error(403, 'SENDER_ID_MISMATCH'), error(429, undefined, { 'retry-after': '300' }), error(503, undefined, { 'retry-after': 'Fri, 25 Sep 2026 12:03:00 GMT' })];
  const send = createFcmSender({ accessToken: auth, fetch: async () => responses.shift()!, now: () => Date.parse('2026-09-25T12:00:00Z') });
  const results = await send(['a', 'b', 'c', 'd'], note);
  assert.deepEqual(results.map(result => result.status), ['rejected', 'rejected', 'retryable', 'retryable']);
  assert.equal(results[2].retryAfterMs, 300_000); assert.equal(results[3].retryAfterMs, 180_000);
});

test('network ambiguity is isolated per device and never reported as successful', async () => {
  let calls = 0;
  const send = createFcmSender({ accessToken: auth, fetch: async () => { calls++; if (calls === 1) throw new Error('private-network-error'); return new Response(JSON.stringify({ name: 'projects/test/messages/next' })); } });
  assert.deepEqual((await send(['a', 'b'], note)).map(result => result.status), ['unknown', 'accepted']);
});

test('credential failures are retryable before sending and a later attempt can recover', async () => {
  let attempts = 0, sends = 0;
  const send = createFcmSender({ accessToken: async () => { if (++attempts === 1) throw new Error('synthetic'); return auth(); }, fetch: async () => { sends++; return new Response(JSON.stringify({ name: 'projects/test/messages/ok' })); } });
  assert.equal((await send(['a'], note))[0].status, 'retryable'); assert.equal(sends, 0);
  assert.equal((await send(['a'], note))[0].status, 'accepted'); assert.equal(sends, 1);
});

test('stalled credential lookup is bounded without contacting FCM', async () => {
  let sent = false;
  const send = createFcmSender({ accessToken: async () => new Promise(() => {}), authTimeoutMs: 5, fetch: async () => { sent = true; return new Response('{}'); } });
  assert.equal((await send(['a'], note))[0].status, 'retryable'); assert.equal(sent, false);
});

test('validate-only sends the documented flag and reports validation separately from acceptance', async () => {
  const send = createFcmSender({ accessToken: auth, fetch: async (_url, init) => { assert.equal(JSON.parse(String(init?.body)).validate_only, true); return new Response('{}'); } });
  assert.deepEqual((await send(['synthetic'], note, undefined, undefined, true)).map(result => ({ status: result.status, code: result.code })), [{ status: 'validated', code: 'VALIDATED' }]);
});
