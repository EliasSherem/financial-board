import { db } from '../db.js';
// Invoke from the maintenance worker, never from anonymous recovery requests.
export async function cleanupRecoveryRecords() {
    await db.query('DELETE FROM auth_rate_limits WHERE last_attempt_at < UTC_TIMESTAMP() - INTERVAL 2 DAY');
    await db.query('DELETE FROM password_reset_tokens WHERE expires_at < UTC_TIMESTAMP() - INTERVAL 30 DAY');
    await db.query('DELETE FROM auth_security_audit WHERE received_at < UTC_TIMESTAMP() - INTERVAL 30 DAY');
}
