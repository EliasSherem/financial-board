import { createHash } from 'node:crypto';
import type { RowDataPacket } from 'mysql2/promise';
import { db } from '../db.js';

export type DeviceRegistration = {
  token: string; platform: string | null; timezoneOffset: number | null; timezoneName: string | null;
};

export function validDeviceToken(value: unknown): value is string {
  return typeof value === 'string' && value.length > 0 && value.length <= 1024 && /^[A-Za-z0-9_:\-]+$/.test(value);
}

// Serialize this physical device across users and Cloud Run instances. The legacy
// index is per user, so a transaction alone cannot arbitrate two new owners.
export async function registerDeviceToken(userId: number, input: DeviceRegistration) {
  const conn = await db.getConnection();
  const lock = `push:${createHash('sha256').update(input.token).digest('hex').slice(0, 59)}`;
  let locked = false;
  try {
    const [rows] = await conn.query<RowDataPacket[]>('SELECT GET_LOCK(?, 10) AS acquired', [lock]);
    if (Number(rows[0]?.acquired) !== 1) throw new Error('DEVICE_REGISTRATION_BUSY');
    locked = true;
    await conn.beginTransaction();
    // Lock the parent before the token FK checks. Distinct devices registering
    // timezones together otherwise upgrade shared FK locks into a deadlock.
    const [users] = await conn.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ? FOR UPDATE', [userId]);
    if (!users.length) throw new Error('DEVICE_OWNER_UNAVAILABLE');
    await conn.query('DELETE FROM device_tokens WHERE token = ? AND user_id <> ?', [input.token, userId]);
    await conn.query(`INSERT INTO device_tokens (user_id, token, platform) VALUES (?, ?, ?)
      ON DUPLICATE KEY UPDATE platform = VALUES(platform)`, [userId, input.token, input.platform]);
    const fields: string[] = [], values: unknown[] = [];
    if (input.timezoneOffset != null) { fields.push('timezone_offset_min = ?'); values.push(input.timezoneOffset); }
    if (input.timezoneName != null) { fields.push('timezone_name = ?'); values.push(input.timezoneName); }
    if (fields.length) await conn.query(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, [...values, userId]);
    await conn.commit();
  } catch (error) {
    await conn.rollback().catch(() => {});
    throw error;
  } finally {
    if (locked) await conn.query('SELECT RELEASE_LOCK(?)', [lock]).catch(() => {});
    conn.release();
  }
}

export async function unregisterDeviceToken(userId: number, token: string) {
  // A late logout from the previous account cannot detach the new account.
  await db.query('DELETE FROM device_tokens WHERE user_id = ? AND token = ?', [userId, token]);
}
