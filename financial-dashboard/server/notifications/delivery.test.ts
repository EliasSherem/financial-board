import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createPushDelivery, retryOutcome, type Delivery, type DeliveryRepository, type Outcome, type PushEvent } from './delivery.js';
import type { FcmOutcome } from '../fcm.js';

const now = Date.parse('2026-09-25T12:00:00Z');
const event: PushEvent = { userId: 9, type: 'payment_due_soon', entityId: '7', eventKey: '2026-09-26', expiresAt: new Date(now + 86400000) };
function repository(tokens: string[]) {
  let time = now;
  const items = tokens.map((token, index) => ({ delivery: { id: index + 1, userId: event.userId, eventId: 10, token, lease: 'synthetic', attempts: 0, expiresAt: event.expiresAt }, status: 'pending', due: now }));
  const removed: string[] = [];
  const finishes: Outcome[] = [];
  const repo: DeliveryRepository = {
    prepare: async () => 10,
    claim: async () => { const item = items.find(item => ['pending', 'retryable'].includes(item.status) && item.due <= time); if (!item) return null; item.status = 'leased'; item.delivery.attempts++; return { ...item.delivery }; },
    finish: async (delivery, outcome) => { finishes.push(outcome); const item = items.find(item => item.delivery.id === delivery.id)!; item.status = outcome.status; item.due = outcome.nextAttemptAt?.getTime() ?? Infinity; },
    removeInvalidToken: async (userId, token) => { assert.equal(userId, 9); removed.push(token); },
  };
  return { repo, items, removed, finishes, now: () => time, advance: (ms: number) => { time += ms; } };
}

test('partial success retries only rejected devices; accepted devices are never sent twice', async () => {
  const h = repository(['one', 'two']); const sent: string[] = [];
  const deliver = createPushDelivery({ repository: h.repo, now: h.now, random: () => 0, send: async tokens => { const token = tokens[0]; sent.push(token); return [{ token, status: token === 'two' && sent.length === 2 ? 'retryable' : 'accepted', code: 'SYNTHETIC', retryAfterMs: 120000 }]; } });
  assert.equal((await deliver(event, { title: 'Synthetic', body: 'Test' })).accepted, 1);
  await deliver(event, { title: 'Synthetic', body: 'Test' }); assert.deepEqual(sent, ['one', 'two']);
  h.advance(120000); await deliver(event, { title: 'Synthetic', body: 'Test' });
  assert.deepEqual(sent, ['one', 'two', 'two']); assert.deepEqual(h.items.map(item => item.status), ['accepted', 'accepted']);
});

test('competing workers cannot send the same device twice', async () => {
  const h = repository(['one', 'two']); const sent: string[] = [];
  const deliver = createPushDelivery({ repository: h.repo, send: async tokens => { sent.push(tokens[0]); await new Promise(resolve => setImmediate(resolve)); return [{ token: tokens[0], status: 'accepted', code: 'ACCEPTED' }]; } });
  await Promise.all([deliver(event, { title: 'Synthetic', body: 'Test' }), deliver(event, { title: 'Synthetic', body: 'Test' })]);
  assert.deepEqual(sent.sort(), ['one', 'two']);
});

test('only UNREGISTERED deletes an owner-scoped token; ambiguous and rejected devices are retained without auto retry', async () => {
  const h = repository(['invalid', 'rejected', 'unknown']); const sent: string[] = [];
  const deliver = createPushDelivery({ repository: h.repo, send: async tokens => { const token = tokens[0]; sent.push(token); return [{ token, status: token as FcmOutcome['status'], code: token === 'invalid' ? 'UNREGISTERED' : 'SYNTHETIC' }]; } });
  await deliver(event, { title: 'Synthetic', body: 'Test' }); h.advance(86400000); await deliver(event, { title: 'Synthetic', body: 'Test' });
  assert.deepEqual(sent, ['invalid', 'rejected', 'unknown']); assert.deepEqual(h.removed, ['invalid']);
});

test('backoff grows, respects retry-after and stops at event expiry or max attempts', () => {
  const delivery: Delivery = { id: 1, userId: event.userId, eventId: 10, token: 'synthetic', lease: 'lease', attempts: 3, expiresAt: event.expiresAt };
  const result: FcmOutcome = { token: 'synthetic', status: 'retryable', code: 'HTTP_503', retryAfterMs: 60000 };
  assert.equal(retryOutcome(result, delivery, now, () => 0).nextAttemptAt?.getTime(), now + 240000);
  assert.equal(retryOutcome({ ...result, retryAfterMs: 500000 }, delivery, now, () => 0).nextAttemptAt?.getTime(), now + 500000);
  assert.equal(retryOutcome(result, { ...delivery, attempts: 8 }, now).status, 'expired');
  assert.equal(retryOutcome(result, { ...delivery, expiresAt: new Date(now + 1000) }, now).status, 'expired');
  assert.equal(retryOutcome({ ...result, status: 'validated' }, delivery, now).status, 'unknown');
});

test('historical event without delivery evidence is never replayed', async () => {
  const h = repository(['synthetic']); h.repo.prepare = async () => null; let sent = false;
  const deliver = createPushDelivery({ repository: h.repo, send: async () => { sent = true; return []; } });
  assert.equal((await deliver(event, { title: 'Synthetic', body: 'Test' })).accepted, 0); assert.equal(sent, false);
});
