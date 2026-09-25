import type { Pool, PoolConnection, RowDataPacket } from 'mysql2/promise';
import { verifyPassword } from '../auth.js';
import type { CredentialKind, RecoveryAccount, RecoveryRepository, RecoveryResult } from './core.js';
const sqlDate = (date: Date) => date.toISOString().slice(0, 23).replace('T', ' ');
type UserRow = RowDataPacket & {
    id: number;
    email: string;
    password: string;
    credential_kind: CredentialKind;
};
export class MysqlRecoveryRepository implements RecoveryRepository {
    constructor(private readonly pool: Pick<Pool, 'getConnection' | 'query'>) { }
    private async transaction<T>(work: (conn: PoolConnection) => Promise<T>): Promise<T> {
        const conn = await this.pool.getConnection();
        try {
            await conn.beginTransaction();
            const result = await work(conn);
            await conn.commit();
            return result;
        }
        catch (error) {
            await conn.rollback();
            throw error;
        }
        finally {
            conn.release();
        }
    }
    private async limit(conn: PoolConnection, key: string, now: Date, maximum: number, cooldownSeconds: number): Promise<boolean> {
        await conn.query('INSERT IGNORE INTO auth_rate_limits (subject_hash, window_started_at, last_attempt_at, attempts) VALUES (?, ?, ?, 0)', [key, sqlDate(now), sqlDate(now)]);
        const [rows] = await conn.query<RowDataPacket[]>("SELECT attempts, DATE_FORMAT(window_started_at, '%Y-%m-%dT%H:%i:%s.%fZ') AS started, DATE_FORMAT(last_attempt_at, '%Y-%m-%dT%H:%i:%s.%fZ') AS last_attempt FROM auth_rate_limits WHERE subject_hash = ? FOR UPDATE", [key]);
        const row = rows[0];
        const freshWindow = now.getTime() - new Date(row.started).getTime() >= 3600000;
        const attempts = freshWindow ? 0 : Number(row.attempts);
        const allowed = attempts < maximum && (attempts === 0 || now.getTime() - new Date(row.last_attempt).getTime() >= cooldownSeconds * 1000);
        await conn.query('UPDATE auth_rate_limits SET attempts = ?, window_started_at = ?, last_attempt_at = ? WHERE subject_hash = ?', [Math.min(attempts + 1, 1000000), freshWindow ? sqlDate(now) : sqlDate(new Date(row.started)), sqlDate(now), key]);
        return allowed;
    }
    async issue(input: Parameters<RecoveryRepository['issue']>[0]): Promise<RecoveryAccount | null> {
        return this.transaction(async (conn) => {
            if (!await this.limit(conn, input.ipKey, input.now, 20, 0))
                return null;
            if (!await this.limit(conn, input.accountKey, input.now, 5, 60))
                return null;
            const [rows] = await conn.query<UserRow[]>('SELECT id, email, credential_kind FROM users WHERE email_normalized = ? FOR UPDATE', [input.email]);
            const user = rows.length === 1 ? rows[0] : undefined;
            await conn.query('INSERT INTO auth_security_audit (user_id, event_type, received_at) VALUES (?, ?, ?)', [user?.id ?? null, 'recovery_requested', sqlDate(input.now)]);
            if (!user || user.credential_kind !== 'local')
                return null;
            await conn.query('UPDATE password_reset_tokens SET invalidated_at = ? WHERE user_id = ? AND consumed_at IS NULL AND invalidated_at IS NULL', [sqlDate(input.now), user.id]);
            await conn.query('INSERT INTO password_reset_tokens (token_hash, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)', [input.tokenHash, user.id, sqlDate(input.expiresAt), sqlDate(input.now)]);
            return { id: user.id, email: user.email, kind: user.credential_kind };
        });
    }
    async allowReset(ipKey: string, now: Date): Promise<boolean> {
        return this.transaction(conn => this.limit(conn, ipKey, now, 20, 0));
    }
    async consume(tokenHash: string, passwordHash: string, now: Date): Promise<RecoveryResult> {
        return this.transaction(async (conn) => {
            // Look up identity without taking a token lock. All writers then lock user -> token.
            const [lookup] = await conn.query<RowDataPacket[]>('SELECT user_id FROM password_reset_tokens WHERE token_hash = ?', [tokenHash]);
            const userId = lookup[0]?.user_id;
            if (!userId) {
                await conn.query('INSERT INTO auth_security_audit (event_type, received_at) VALUES (?, ?)', ['recovery_invalid', sqlDate(now)]);
                return { ok: false, reason: 'invalid' };
            }
            const [users] = await conn.query<UserRow[]>('SELECT id, email, credential_kind FROM users WHERE id = ? FOR UPDATE', [userId]);
            const user = users[0];
            const [tokens] = await conn.query<RowDataPacket[]>("SELECT consumed_at, invalidated_at, expires_at <= UTC_TIMESTAMP(3) AS is_expired FROM password_reset_tokens WHERE token_hash = ? AND user_id = ? FOR UPDATE", [tokenHash, userId]);
            const token = tokens[0];
            const reason = !user || user.credential_kind !== 'local' || !token || token.invalidated_at ? 'invalid' : token.consumed_at ? 'used' : Boolean(token.is_expired) ? 'expired' : null;
            if (reason) {
                await conn.query('INSERT INTO auth_security_audit (user_id, event_type, received_at) VALUES (?, ?, ?)', [user?.id ?? null, 'recovery_invalid', sqlDate(now)]);
                return { ok: false, reason };
            }
            await conn.query('UPDATE users SET password = ?, token_version = token_version + 1 WHERE id = ?', [passwordHash, userId]);
            await conn.query('UPDATE password_reset_tokens SET consumed_at = ? WHERE token_hash = ?', [sqlDate(now), tokenHash]);
            await conn.query('UPDATE password_reset_tokens SET invalidated_at = ? WHERE user_id = ? AND token_hash <> ? AND consumed_at IS NULL', [sqlDate(now), userId, tokenHash]);
            await conn.query('INSERT INTO auth_security_audit (user_id, event_type, received_at) VALUES (?, ?, ?)', [userId, 'recovery_completed', sqlDate(now)]);
            return { ok: true, account: { id: userId, email: user.email, kind: user.credential_kind } };
        });
    }
    async changePassword(userId: number, currentPassword: string, passwordHash: string, now: Date): Promise<RecoveryAccount | null> {
        return this.transaction(async (conn) => {
            const [rows] = await conn.query<UserRow[]>('SELECT id, email, password, credential_kind FROM users WHERE id = ? FOR UPDATE', [userId]);
            const user = rows[0];
            if (!user || user.credential_kind === 'google' || !await verifyPassword(currentPassword, user.password)) {
                await conn.query('INSERT INTO auth_security_audit (user_id,event_type,received_at) VALUES (?,?,?)', [user?.id ?? null, 'password_change_rejected', sqlDate(now)]);
                return null;
            }
            await conn.query("UPDATE users SET password = ?, token_version = token_version + 1, credential_kind = 'local' WHERE id = ?", [passwordHash, userId]);
            await conn.query('UPDATE password_reset_tokens SET invalidated_at = ? WHERE user_id = ? AND consumed_at IS NULL', [sqlDate(now), userId]);
            await conn.query('INSERT INTO auth_security_audit (user_id, event_type, received_at) VALUES (?, ?, ?)', [userId, 'password_changed', sqlDate(now)]);
            return { id: userId, email: user.email, kind: 'local' };
        });
    }
    async audit(event: string, userId?: number): Promise<void> {
        await this.pool.query('INSERT INTO auth_security_audit (user_id, event_type, received_at) VALUES (?, ?, ?)', [userId ?? null, event, sqlDate(new Date())]);
    }
}
