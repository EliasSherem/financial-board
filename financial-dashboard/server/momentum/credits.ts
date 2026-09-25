import { randomUUID } from 'node:crypto';
import type { PoolConnection } from 'mysql2/promise';
import { enabled, HttpError, limit, uuid } from '../platform/http.js';
import { refreshEntitlement } from '../billing/repository.js';
import { fact, json, locked, rows } from './repository.js';

export const creditsEnabled = () => (enabled('MOMENTUM_AI_REWARDS_ENABLED') || enabled('MOMENTUM_AI_CREDITS_ENABLED')) && !!process.env.OPENAI_API_KEY;
export async function creditState(conn: PoolConnection, userId: number) {
  const grants = await rows(conn, "SELECT COALESCE(SUM(credits),0) AS balance,MAX(expires_at) AS expires_at FROM ai_credit_ledger WHERE user_id=? AND (expires_at IS NULL OR expires_at>UTC_TIMESTAMP(3))", [userId]);
  const holds = await rows(conn, "SELECT COUNT(*) AS n FROM ai_credit_reservations WHERE user_id=? AND uses_credit=1 AND status='pending' AND expires_at>UTC_TIMESTAMP(3)", [userId]);
  return { available: creditsEnabled(), balance: Math.max(0, Number(grants[0].balance) - Number(holds[0].n)), expires_at: grants[0].expires_at ?? null };
}
export async function grantOrganizerCredits(conn: PoolConnection, userId: number, xp: number) {
  if (creditsEnabled() && xp >= 250) await conn.query("INSERT IGNORE INTO ai_credit_ledger(user_id,credits,kind,idempotency_key,expires_at) VALUES (?,3,'grant','organizer:v1',DATE_ADD(UTC_TIMESTAMP(3),INTERVAL 30 DAY))", [userId]);
}
export type Reservation = { requestId: string; cached?: { reply: string } };
export async function reserveAi(userId: number, suppliedId: unknown): Promise<Reservation> {
  const pro = await refreshEntitlement(userId);
  if (!pro && !creditsEnabled()) throw new HttpError(403, 'PRO_REQUIRED');
  const requestId = suppliedId == null && pro ? randomUUID() : uuid(suppliedId);
  return locked(userId, async conn => {
    const previous = (await rows(conn, 'SELECT * FROM ai_credit_reservations WHERE request_id=? FOR UPDATE', [requestId]))[0];
    if (previous) {
      if (Number(previous.user_id) !== userId) throw new HttpError(409, 'REQUEST_ID_UNAVAILABLE');
      if (previous.status === 'completed') {
        if (!previous.response_json) throw new HttpError(409, 'AI_RETRY_CACHE_EXPIRED');
        return { requestId, cached: json(previous.response_json, { reply: '' }) };
      }
      // Never resend the same provider call after an ambiguous timeout.
      throw new HttpError(409, previous.status === 'pending' ? 'AI_REQUEST_IN_PROGRESS' : 'AI_REQUEST_FINISHED');
    }
    const currentPro = await refreshEntitlement(userId,conn);
    if (!currentPro && !creditsEnabled()) throw new HttpError(403, 'PRO_REQUIRED');
    if (!currentPro && suppliedId == null) throw new HttpError(403, 'AI_REQUEST_ID_REQUIRED');
    // Failed calls also count: changing UUID cannot create unbounded provider retries.
    await limit(`ai:${userId}`, currentPro ? 100 : 6, 86400);
    await conn.query("UPDATE ai_credit_reservations SET status='failed',completed_at=UTC_TIMESTAMP(3) WHERE user_id=? AND status='pending' AND expires_at<=UTC_TIMESTAMP(3)", [userId]);
    if (!currentPro && (await creditState(conn, userId)).balance < 1) throw new HttpError(403, 'AI_CREDITS_EXHAUSTED');
    await conn.query("INSERT INTO ai_credit_reservations(request_id,user_id,status,uses_credit,expires_at) VALUES (?,?,'pending',?,DATE_ADD(UTC_TIMESTAMP(3),INTERVAL 2 MINUTE))", [requestId,userId,!currentPro]);
    return { requestId };
  });
}
export async function finishAi(userId: number, requestId: string, reply?: string) {
  return locked(userId, async conn => {
    const hold = (await rows(conn, 'SELECT * FROM ai_credit_reservations WHERE request_id=? AND user_id=? FOR UPDATE', [requestId,userId]))[0];
    if (!hold || hold.status !== 'pending') return;
    const success = !!reply && new Date(hold.expires_at as string) > new Date();
    if (success && hold.uses_credit) {
      await conn.query("INSERT IGNORE INTO ai_credit_ledger(user_id,credits,kind,idempotency_key,expires_at) SELECT ?,-1,'consume',?,MAX(expires_at) FROM ai_credit_ledger WHERE user_id=? AND kind='grant'", [userId,`request:${requestId}`,userId]);
    }
    await conn.query("UPDATE ai_credit_reservations SET status=?,response_json=?,completed_at=UTC_TIMESTAMP(3) WHERE request_id=?", [success ? 'completed' : 'failed',success ? JSON.stringify({reply}) : null,requestId]);
    if (success) {
      await fact(conn,userId,'ai_responses',requestId,'verified_provider');
      // No question, reply, balances or model context in the event/outbox.
      await conn.query("INSERT IGNORE INTO engagement_events(event_id,user_id,event_type,source,idempotency_key,payload_json,occurred_at) VALUES (?,?,'ai.response','server',?,JSON_OBJECT(),UTC_TIMESTAMP(3))", [requestId,userId,`ai:${requestId}`]);
    }
  });
}
