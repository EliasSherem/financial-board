import { createHash } from 'node:crypto';
import type { Request, RequestHandler, Response } from 'express';
import { db } from '../db.js';

export class HttpError extends Error {
  constructor(public status: number, public code: string) { super(code); }
}
export function endpoint(work: (req: Request, res: Response) => Promise<unknown>): RequestHandler {
  return (req, res) => { void work(req, res).catch(error => {
    if (res.headersSent) return;
    if (error instanceof HttpError) res.status(error.status).json({ message: error.code, code: error.code });
    else { console.error('platform_request_failed', { code: 'INTERNAL_ERROR' }); res.status(500).json({ message: 'Request failed', code: 'INTERNAL_ERROR' }); }
  }); };
}
export function enabled(name: string): boolean { return process.env[name]?.toLowerCase() === 'true'; }
export function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new HttpError(400, 'INVALID_PAYLOAD');
  return value as Record<string, unknown>;
}
export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function uuid(value: unknown): string {
  if (typeof value !== 'string' || !UUID.test(value)) throw new HttpError(400, 'INVALID_EVENT_ID');
  return value.toLowerCase();
}
export function timestamp(value: unknown, maxAgeMs = 24 * 60 * 60 * 1000, now = new Date()): Date {
  if (typeof value !== 'string') throw new HttpError(400, 'INVALID_TIMESTAMP');
  const date = new Date(value);
  if (!Number.isFinite(date.getTime()) || date.getTime() > now.getTime() + 60_000 || date.getTime() < now.getTime() - maxAgeMs) throw new HttpError(400, 'INVALID_TIMESTAMP');
  return date;
}
/** Shared fixed-window limiter, works across API instances. Keys contain no raw PII. */
export async function limit(key: string, maximum: number, seconds = 60): Promise<void> {
  const start = new Date(Math.floor(Date.now() / (seconds * 1000)) * seconds * 1000);
  const digest = createHash('sha256').update(key).digest('hex');
  await db.query(`INSERT INTO platform_rate_limits (bucket_key, window_start, attempts) VALUES (?, ?, 1)
    ON DUPLICATE KEY UPDATE attempts = attempts + 1`, [digest, start]);
  const [rows] = await db.query('SELECT attempts FROM platform_rate_limits WHERE bucket_key = ? AND window_start = ?', [digest, start]);
  if (Number((rows as Array<{ attempts: number }>)[0]?.attempts) > maximum) throw new HttpError(429, 'RATE_LIMITED');
}
