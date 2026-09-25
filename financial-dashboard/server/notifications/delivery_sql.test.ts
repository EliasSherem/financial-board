import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { db } from '../db.js';
import { createPushDelivery, MysqlDeliveryRepository, type PushEvent } from './delivery.js';

const run = process.env.RUN_DB_TESTS === 'true';
const users: number[] = [];
const repository = new MysqlDeliveryRepository();
const prefix = `push_${randomUUID().slice(0, 8)}`;
const query = async (sql: string, values: unknown[] = []) => (await db.query(sql, values))[0] as Record<string, any>[];
before(async () => {
  if (!run) return;
  assert.equal(process.env.NODE_ENV, 'test'); assert.equal(process.env.MYSQL_HOST, '127.0.0.1'); assert.match(process.env.MYSQL_DATABASE ?? '', /_test$/); assert.equal(process.env.MYSQL_URL, undefined);
  for (let i = 0; i < 3; i++) { const [created] = await db.query('INSERT INTO users(username,password) VALUES (?,?)', [`${prefix}_${i}`, 'unusable']); users.push(Number((created as { insertId: number }).insertId)); }
  await db.query("INSERT INTO device_tokens(user_id,token,platform) VALUES (?,?,'android'),(?,?,'android'),(?,?,'android'),(?,?,'android'),(?,?,'ios')", [users[0], `${prefix}_one`, users[0], `${prefix}_two`, users[0], `${prefix}_shared`, users[1], `${prefix}_shared`, users[2], `${prefix}_long_${'x'.repeat(500)}`]);
});
after(async () => { if (!run) return; for (const id of users) await db.query('DELETE FROM users WHERE id=?', [id]); await db.end(); });
const event = (key: string, userId = users[0]): PushEvent => ({ userId, type: 'payment_due_soon', entityId: key, eventKey: '2026-09-26', expiresAt: new Date(Date.now() + 86400000) });

test('SQL: historical events do not enqueue delivery, and no-device/shared-only users do not claim events', { skip: !run }, async () => {
  const old = event('historical'); await db.query('INSERT INTO notification_events(user_id,type,entity_id,event_key) VALUES (?,?,?,?)', [old.userId, old.type, old.entityId, old.eventKey]);
  assert.equal(await repository.prepare(old), null); assert.equal(await repository.prepare(event('shared-only', users[1])), null);
  assert.equal(Number((await query('SELECT COUNT(*) AS n FROM notification_deliveries d JOIN notification_events e ON e.id=d.event_id WHERE e.user_id=?', [users[0]]))[0].n), 0);
});

test('SQL: concurrent workers send each unambiguously owned device once; accepted devices stay complete', { skip: !run }, async () => {
  const sent: string[] = [];
  const deliver = createPushDelivery({ repository, send: async tokens => { sent.push(tokens[0]); await new Promise(resolve => setTimeout(resolve, 5)); return [{ token: tokens[0], status: 'accepted', code: 'ACCEPTED' }]; } });
  await Promise.all(Array.from({ length: 3 }, () => deliver(event('concurrent'), { title: 'Synthetic', body: 'No external requests' })));
  await deliver(event('concurrent'), { title: 'Synthetic', body: 'No external requests' });
  assert.deepEqual(sent.sort(), [`${prefix}_one`, `${prefix}_two`]);
});

test('SQL: retry touches only rejected devices; stale lease cannot be replayed or acknowledged with an old fence', { skip: !run }, async () => {
  const target = event('retry', users[2]); const eventId = (await repository.prepare(target))!; const delivery = (await repository.claim(target.userId, eventId))!;
  assert.ok(delivery.token.length > 255);
  await repository.finish(delivery, { status: 'retryable', code: 'HTTP_503', nextAttemptAt: new Date(Date.now() + 60000) });
  assert.equal(await repository.claim(target.userId, eventId), null);
  await db.query('UPDATE notification_deliveries SET next_attempt_at=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 1 MINUTE) WHERE event_id=?', [eventId]);
  const retried = (await repository.claim(target.userId, eventId))!; assert.equal(retried.attempts, 2); assert.notEqual(retried.lease, delivery.lease);
  await repository.finish(delivery, { status: 'accepted', code: 'OLD_FENCE' });
  assert.equal((await query('SELECT status FROM notification_deliveries WHERE id=?', [delivery.id]))[0].status, 'leased');
  await db.query('UPDATE notification_deliveries SET lease_until=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 1 MINUTE) WHERE id=?', [retried.id]);
  assert.equal(await repository.claim(target.userId, eventId), null);
  assert.equal((await query('SELECT status FROM notification_deliveries WHERE id=?', [retried.id]))[0].status, 'unknown');
});

test('SQL: ownership is checked again at claim, and invalid-token removal is owner scoped', { skip: !run }, async () => {
  const target = event('owner-check', users[2]); const eventId = (await repository.prepare(target))!;
  const token = (await query('SELECT token FROM device_tokens WHERE user_id=?', [users[2]]))[0].token;
  await db.query("INSERT INTO device_tokens(user_id,token,platform) VALUES (?,?,'ios')", [users[1], token]);
  const delivery = (await repository.claim(target.userId, eventId))!; assert.equal(delivery.token, '');
  await repository.removeInvalidToken(users[2], token);
  assert.equal(Number((await query('SELECT COUNT(*) AS n FROM device_tokens WHERE user_id=? AND BINARY token=BINARY ?', [users[1], token]))[0].n), 1);
});
