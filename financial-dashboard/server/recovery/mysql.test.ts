import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { Pool, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { db } from '../db.js';
import { hashPassword, verifyPassword, generateToken, authenticateToken } from '../auth.js';
import { MysqlRecoveryRepository } from './repository.js';
import { RecoveryService, hashToken, rateKey, type RecoveryMail } from './core.js';
import type { Request, Response } from 'express';
const enabled = process.env.RUN_DB_TESTS === 'true' || process.env.RUN_PLATFORM_SQL_TESTS === 'true';
test('MySQL recovery: captured email, neutral identities, atomic double-use, expiry, reauth, revoke and intact entitlement', { skip: !enabled }, async () => {
    assert.equal(process.env.NODE_ENV, 'test');
    assert.ok(['localhost', '127.0.0.1'].includes(process.env.MYSQL_HOST ?? ''));
    assert.match(process.env.MYSQL_DATABASE ?? '', /test/);
    assert.ok(!process.env.MYSQL_URL);
    const fixture = 'recovery_' + randomUUID().slice(0, 8), ids: number[] = [], rates: string[] = [], mail: RecoveryMail[] = [];
    const secret = 'sql-test-recovery-rate-secret-at-least-32-characters', config = { origin: 'https://example.test', allowedOrigins: ['https://example.test'], ttlMinutes: 30, rateSecret: secret };
    const repo = new MysqlRecoveryRepository(db), service = new RecoveryService({ repository: repo, config, hashPassword, send: async (item) => { mail.push(item); return true; } });
    const add = async (kind: string) => { const email = `${fixture}_${kind}@example.test`; const [r] = await db.query<ResultSetHeader>('INSERT INTO users (username,email,password,credential_kind,is_pro) VALUES (?,?,?,?,TRUE)', [`${fixture}_${kind}`, email, await hashPassword('old-password'), kind]); ids.push(r.insertId); return { id: r.insertId, email }; };
    const forgot = async (email: string, ip: string) => { rates.push(rateKey(secret, 'forgot-ip', ip), rateKey(secret, 'forgot-account', email)); await service.forgot(email, ip, 'es'); };
    const authenticate = (token: string) => new Promise<number>(resolve => { const req = { headers: { authorization: `Bearer ${token}` } } as Request; const res = { status(code: number) { resolve(code); return this; }, json() { return this; } } as unknown as Response; void authenticateToken(req, res, () => resolve(200)); });
    try {
        const local = await add('local'), google = await add('google'), legacy = await add('unknown');
        const oldToken = generateToken({ id: local.id, username: fixture, token_version: 0 });
        for (const [i, email] of [google.email, legacy.email, `${fixture}_missing@example.test`].entries())
            await forgot(email, `${fixture}_${i}`);
        assert.equal(mail.length, 0);
        await forgot(local.email, `${fixture}_local`);
        assert.equal(mail.length, 1);
        const token = mail[0].text.match(/#token=([A-Za-z0-9_-]+)/)![1];
        assert.equal(token.length, 43);
        const [stored] = await db.query<RowDataPacket[]>('SELECT token_hash FROM password_reset_tokens WHERE user_id=?', [local.id]);
        assert.equal(stored[0].token_hash, hashToken(token));
        assert.ok(!JSON.stringify(stored).includes(token));
        assert.equal(await authenticate(oldToken), 200);
        const now = new Date();
        const hash = await hashPassword('new-password');
        const results = await Promise.all([repo.consume(hashToken(token), hash, now), repo.consume(hashToken(token), hash, now)]);
        assert.equal(results.filter(r => r.ok).length, 1);
        assert.deepEqual(results.find(r => !r.ok), { ok: false, reason: 'used' });
        assert.equal(await authenticate(oldToken), 401);
        const [users] = await db.query<RowDataPacket[]>('SELECT password,token_version,is_pro FROM users WHERE id=?', [local.id]);
        assert.equal(users[0].token_version, 1);
        assert.equal(users[0].is_pro, 1);
        assert.equal(await verifyPassword('new-password', users[0].password), true);
        const expired = hashToken(randomUUID());
        await db.query('INSERT INTO password_reset_tokens(token_hash,user_id,expires_at,created_at) VALUES (?,?,UTC_TIMESTAMP()-INTERVAL 1 SECOND,UTC_TIMESTAMP())', [expired, local.id]);
        assert.deepEqual(await repo.consume(expired, hash, now), { ok: false, reason: 'expired' });
        assert.equal(await repo.changePassword(local.id, 'wrong', hash, now), null);
        assert.equal(await repo.changePassword(google.id, 'old-password', hash, now), null);
        assert.equal((await repo.changePassword(legacy.id, 'old-password', hash, now))?.kind, 'local');
        // Replacement request invalidates the prior link, without changing the password.
        const future = new Date(Date.now() + 61000), oldHash = hashToken(randomUUID()), newHash = hashToken(randomUUID());
        const base = { email: local.email, ipKey: hashToken(fixture + '_i'), accountKey: hashToken(fixture + '_a'), now: future, expiresAt: new Date(Date.now() + 600000) };
        rates.push(base.ipKey, base.accountKey);
        assert.ok(await repo.issue({ ...base, tokenHash: oldHash }));
        assert.ok(await repo.issue({ ...base, tokenHash: newHash, now: new Date(future.getTime() + 61000) }));
        assert.deepEqual(await repo.consume(oldHash, hash, now), { ok: false, reason: 'invalid' });
        assert.equal(await repo.issue({ ...base, tokenHash: hashToken(randomUUID()), now: new Date(future.getTime() + 61001) }), null);
        const failingPool = {
            query: db.query.bind(db),
            async getConnection() {
                const conn = await db.getConnection();
                return new Proxy(conn, { get(target, key) {
                    if (key === 'query') return async (sql: string, values: unknown[]) => {
                        if (sql.startsWith('UPDATE password_reset_tokens SET consumed_at')) throw new Error('TEST_FAILURE_AFTER_PASSWORD_WRITE');
                        return target.query(sql, values);
                    };
                    const value = Reflect.get(target, key);
                    return typeof value === 'function' ? value.bind(target) : value;
                } });
            },
        } as unknown as Pick<Pool, 'getConnection' | 'query'>;
        await assert.rejects(new MysqlRecoveryRepository(failingPool).consume(newHash, await hashPassword('must-roll-back'), now), /TEST_FAILURE/);
        const [rolledBack] = await db.query<RowDataPacket[]>('SELECT u.password,u.token_version,t.consumed_at FROM users u JOIN password_reset_tokens t ON t.user_id=u.id WHERE t.token_hash=?', [newHash]);
        assert.equal(rolledBack[0].token_version, 1);
        assert.equal(rolledBack[0].consumed_at, null);
        assert.equal(await verifyPassword('new-password', rolledBack[0].password), true);
        assert.equal((await repo.consume(newHash, hash, now)).ok, true);
        const [duplicate] = await db.query<ResultSetHeader>("INSERT INTO users(username,email,password,credential_kind) VALUES (?,?,?,'local')", [fixture + '_ambiguous', ' ' + local.email, hash]);
        ids.push(duplicate.insertId);
        const ambiguousKeys = { ipKey: hashToken(fixture + '_dup_ip'), accountKey: hashToken(fixture + '_dup_account') };
        rates.push(ambiguousKeys.ipKey, ambiguousKeys.accountKey);
        assert.equal(await repo.issue({ ...base, ...ambiguousKeys, tokenHash: hashToken(randomUUID()), now }), null);
        const [plan] = await db.query<RowDataPacket[]>('EXPLAIN FORMAT=TRADITIONAL SELECT id,email,credential_kind FROM users WHERE email_normalized=? FOR UPDATE', [local.email]);
        assert.match(String(plan[0].possible_keys), /idx_users_recovery_email/);
    }
    finally {
        if (ids.length)
            await db.query('DELETE FROM users WHERE id IN (?)', [ids]);
        if (rates.length)
            await db.query('DELETE FROM auth_rate_limits WHERE subject_hash IN (?)', [rates]);
        await db.end();
    }
});
