import { createHash, randomUUID } from 'node:crypto';
import type { PoolConnection } from 'mysql2/promise';
import { db, withTransaction } from '../db.js';
import { sendFcmDetailed, type FcmOutcome, type NotificationPayload } from '../fcm.js';

export type PushEvent = { userId: number; type: string; entityId: string; eventKey: string; expiresAt: Date };
export type Delivery = { id: number; userId: number; eventId: number; token: string; lease: string; attempts: number; expiresAt: Date };
export type Outcome = { status: Exclude<FcmOutcome['status'], 'validated'> | 'expired'; code: string; nextAttemptAt?: Date };
export type DeliverySummary = { accepted: number; retryable: number; invalid: number; rejected: number; unknown: number; expired: number };
export interface DeliveryRepository {
  prepare(event: PushEvent): Promise<number | null>;
  claim(userId: number, eventId: number): Promise<Delivery | null>;
  finish(delivery: Delivery, outcome: Outcome): Promise<void>;
  removeInvalidToken(userId: number, token: string): Promise<void>;
}
export const tokenHash = (token: string) => createHash('sha256').update(token).digest('hex');

async function withDeliveryUser<T>(userId: number, work: (conn: PoolConnection) => Promise<T>, missing: T): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await withTransaction(async conn => {
        // Every preparation, claim and completion uses the same parent-first lock order.
        const [users] = await conn.query('SELECT id FROM users WHERE id=? FOR UPDATE', [userId]);
        return (users as unknown[]).length ? work(conn) : missing;
      });
    } catch (error) {
      if (attempt >= 2 || !['ER_LOCK_DEADLOCK', 'ER_LOCK_WAIT_TIMEOUT'].includes(String((error as { code?: string }).code))) throw error;
      // Retrying rolled-back database work cannot repeat an external provider call.
    }
  }
}

/** Enqueue in the caller's transaction when its preference/rate-limit checks hold a lock. */
export async function preparePushEvent(conn: PoolConnection, event: PushEvent): Promise<number | null> {
  const [tokens] = await conn.query('SELECT d.token FROM device_tokens d WHERE d.user_id=? AND NOT EXISTS(SELECT 1 FROM device_tokens other WHERE BINARY other.token=BINARY d.token AND other.user_id<>d.user_id)', [event.userId]);
  const hashes = [...new Set((tokens as { token: string }[]).map(row => row.token).filter(Boolean).map(tokenHash))];
  if (!hashes.length) return null;
  const [insert] = await conn.query('INSERT IGNORE INTO notification_events(user_id,type,entity_id,event_key) VALUES (?,?,?,?)', [event.userId, event.type, event.entityId, event.eventKey]);
  const [events] = await conn.query('SELECT id FROM notification_events WHERE user_id=? AND type=? AND entity_id=? AND event_key=? FOR UPDATE', [event.userId, event.type, event.entityId, event.eventKey]);
  const eventId = Number((events as { id: number }[])[0].id);
  if (Number((insert as { affectedRows: number }).affectedRows) > 0) {
    await conn.query(`INSERT INTO notification_deliveries(event_id,token_hash,expires_at) VALUES ${hashes.map(() => '(?,?,?)').join(',')}`, hashes.flatMap(hash => [eventId, hash, event.expiresAt]));
  }
  // Historical event rows predate delivery evidence. Never turn those into a replay of old alerts.
  const [deliveries] = await conn.query('SELECT 1 FROM notification_deliveries WHERE event_id=? LIMIT 1', [eventId]);
  return (deliveries as unknown[]).length ? eventId : null;
}

export class MysqlDeliveryRepository implements DeliveryRepository {
  async prepare(event: PushEvent) {
    return withDeliveryUser(event.userId, conn => preparePushEvent(conn, event), null);
  }
  async claim(userId: number, eventId: number): Promise<Delivery | null> {
    return withDeliveryUser(userId, async conn => {
      const [events] = await conn.query('SELECT resolved_at FROM notification_events WHERE user_id=? AND id=? FOR UPDATE', [userId, eventId]);
      const event = (events as { resolved_at: Date | null }[])[0];
      if (!event) return null;
      // A crashed sender might have reached FCM: preserve uncertainty instead of sending twice.
      await conn.query("UPDATE notification_deliveries SET status='unknown',last_code='LEASE_EXPIRED',lease_token=NULL,lease_until=NULL WHERE event_id=? AND status='leased' AND lease_until<=UTC_TIMESTAMP(3)", [eventId]);
      await conn.query("UPDATE notification_deliveries SET status='expired',last_code='EVENT_EXPIRED' WHERE event_id=? AND status IN ('pending','retryable') AND (expires_at<=UTC_TIMESTAMP(3) OR ? IS NOT NULL)", [eventId, event.resolved_at]);
      if (event.resolved_at) return null;
      const [found] = await conn.query(`SELECT id,token_hash,attempts,expires_at FROM notification_deliveries
        WHERE event_id=? AND status IN ('pending','retryable') AND next_attempt_at<=UTC_TIMESTAMP(3) AND expires_at>UTC_TIMESTAMP(3) ORDER BY id LIMIT 1 FOR UPDATE`, [eventId]);
      const row = (found as { id: number; token_hash: string; attempts: number; expires_at: Date }[])[0];
      if (!row) return null;
      const [tokens] = await conn.query('SELECT d.token FROM device_tokens d WHERE d.user_id=? AND SHA2(d.token,256)=? AND NOT EXISTS(SELECT 1 FROM device_tokens other WHERE BINARY other.token=BINARY d.token AND other.user_id<>d.user_id) LIMIT 1', [userId, row.token_hash]);
      const token = (tokens as { token: string }[])[0]?.token;
      if (!token) {
        await conn.query("UPDATE notification_deliveries SET status='invalid',last_code='DEVICE_REMOVED' WHERE id=?", [row.id]);
        return { id: Number(row.id), userId, eventId, token: '', lease: '', attempts: Number(row.attempts), expiresAt: new Date(row.expires_at) };
      }
      const lease = randomUUID();
      await conn.query("UPDATE notification_deliveries SET status='leased',attempts=attempts+1,lease_token=?,lease_until=DATE_ADD(UTC_TIMESTAMP(3),INTERVAL 2 MINUTE) WHERE id=?", [lease, row.id]);
      return { id: Number(row.id), userId, eventId, token, lease, attempts: Number(row.attempts) + 1, expiresAt: new Date(row.expires_at) };
    }, null);
  }
  async finish(delivery: Delivery, outcome: Outcome) {
    await withDeliveryUser(delivery.userId, async conn => {
      await conn.query(`UPDATE notification_deliveries SET status=?,last_code=?,next_attempt_at=COALESCE(?,next_attempt_at),accepted_at=IF(?='accepted',UTC_TIMESTAMP(3),accepted_at),lease_token=NULL,lease_until=NULL
        WHERE id=? AND status='leased' AND lease_token=?`, [outcome.status, outcome.code, outcome.nextAttemptAt ?? null, outcome.status, delivery.id, delivery.lease]);
    }, undefined);
  }
  async removeInvalidToken(userId: number, token: string) { await db.query('DELETE FROM device_tokens WHERE user_id=? AND BINARY token=BINARY ?', [userId, token]); }
}

export function retryOutcome(result: FcmOutcome, delivery: Delivery, now: number, random: () => number = Math.random): Outcome {
  if (result.status === 'validated') return { status: 'unknown', code: 'VALIDATION_ONLY' };
  if (result.status !== 'retryable') return { status: result.status, code: result.code };
  // Retry only explicit rejection or a failure before sending. Timeout/uncertain delivery is terminal.
  const delay = Math.max(result.retryAfterMs ?? 60_000, Math.min(6 * 60 * 60_000, 60_000 * 2 ** Math.min(delivery.attempts - 1, 8)) * (1 + random() * 0.25));
  if (delivery.attempts >= 8 || now + delay >= delivery.expiresAt.getTime()) return { status: 'expired', code: 'RETRY_WINDOW_ENDED' };
  return { status: 'retryable', code: result.code, nextAttemptAt: new Date(now + delay) };
}

export function createPushDelivery(options: { repository: DeliveryRepository; send: typeof sendFcmDetailed; now?: () => number; random?: () => number }) {
  return async (event: PushEvent, note: NotificationPayload, data?: Record<string, string>, reservedEventId?: number): Promise<DeliverySummary> => {
    const summary: DeliverySummary = { accepted: 0, retryable: 0, invalid: 0, rejected: 0, unknown: 0, expired: 0 };
    const eventId = reservedEventId ?? await options.repository.prepare(event);
    if (!eventId) return summary;
    for (;;) {
      const delivery = await options.repository.claim(event.userId, eventId);
      if (!delivery) return summary;
      if (!delivery.token) { summary.invalid++; continue; }
      let result: FcmOutcome;
      try {
        result = (await options.send([delivery.token], note, data, `notification:${eventId}`))[0] ?? { token: delivery.token, status: 'unknown', code: 'DELIVERY_UNCONFIRMED' };
      } catch { result = { token: delivery.token, status: 'unknown', code: 'DELIVERY_UNCONFIRMED' }; }
      const outcome = retryOutcome(result, delivery, options.now?.() ?? Date.now(), options.random);
      await options.repository.finish(delivery, outcome);
      summary[outcome.status]++;
      if (outcome.status === 'invalid' && outcome.code === 'UNREGISTERED') await options.repository.removeInvalidToken(event.userId, delivery.token);
    }
  };
}
export const deliverPushEvent = createPushDelivery({ repository: new MysqlDeliveryRepository(), send: sendFcmDetailed });
