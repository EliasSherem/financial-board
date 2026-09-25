import test from 'node:test';
import assert from 'node:assert/strict';
import { hashToken, normalizeEmail, rateKey, recoveryUrl, resetEmail, RecoveryService, validPassword, type RecoveryAccount, type RecoveryConfig, type RecoveryMail, type RecoveryRepository, type RecoveryResult } from './core.js';
const config: RecoveryConfig = { origin: 'https://example.test', allowedOrigins: ['https://example.test'], ttlMinutes: 30, rateSecret: 'test-only-secret-at-least-thirty-two-characters' };
const now = new Date('2026-09-24T10:00:00Z');
const token = 'A'.repeat(43);
const account: RecoveryAccount = { id: 42, email: 'person@example.test', kind: 'local' };
function fixture() {
    const deliveries: RecoveryMail[] = [];
    const audit: string[] = [];
    let stored: Parameters<RecoveryRepository['issue']>[0] | undefined;
    let consumed = false;
    let identity: RecoveryAccount | null = account;
    let allowed = true;
    const repository: RecoveryRepository = {
        async issue(input) { stored = input; return identity; },
        async allowReset() { return allowed; },
        async consume(hash, _password, current): Promise<RecoveryResult> {
            if (!stored || stored.tokenHash !== hash || !identity)
                return { ok: false, reason: 'invalid' };
            if (consumed)
                return { ok: false, reason: 'used' };
            if (current >= stored.expiresAt)
                return { ok: false, reason: 'expired' };
            consumed = true;
            return { ok: true, account: identity };
        },
        async changePassword(_userId, current) { return current === 'previous-secret' ? identity : null; },
        async audit(event) { audit.push(event); },
    };
    let clock = now;
    const service = new RecoveryService({ repository, config, now: () => clock, randomToken: () => token, hashPassword: async (p) => `hashed:${p}`, send: async (mail) => { deliveries.push(mail); return true; } });
    return { service, repository, deliveries, audit, stored: () => stored, identity: (value: RecoveryAccount | null) => { identity = value; }, advance: (date: Date) => { clock = date; }, limit: () => { allowed = false; } };
}
test('canonical HTTPS links allow only explicit origin and keep token out of HTTP URL', () => {
    const url = new URL(recoveryUrl(config, token));
    assert.equal(url.search, '');
    assert.equal(url.hash, `#token=${token}`);
    for (const origin of ['http://example.test', 'https://evil.test', 'https://example.test/path', 'https://example.test?next=bad', 'https://user:password@example.test']) {
        assert.throws(() => recoveryUrl({ ...config, origin }, token));
    }
});
test('email normalization and bcrypt password boundary are explicit', () => {
    assert.equal(normalizeEmail(' Person@Example.Test '), 'person@example.test');
    assert.equal(normalizeEmail('bad'), null);
    assert.equal(validPassword('123456', '123456'), true);
    assert.equal(validPassword('12345', '12345'), false);
    assert.equal(validPassword('secret', 'different'), false);
    assert.equal(validPassword('🙂'.repeat(19), '🙂'.repeat(19)), false);
    assert.equal(validPassword('a'.repeat(72), 'a'.repeat(72)), true);
    assert.equal(validPassword('a'.repeat(73), 'a'.repeat(73)), false);
});
test('issuance stores hash only, computes expiry and does not await provider latency', async () => {
    const f = fixture();
    await f.service.forgot(' Person@Example.Test ', '127.0.0.1', 'es');
    assert.equal(f.stored()?.tokenHash, hashToken(token));
    assert.equal(f.stored()?.expiresAt.toISOString(), '2026-09-24T10:30:00.000Z');
    assert.equal(f.stored()?.email, 'person@example.test');
    assert.equal(JSON.stringify(f.stored()).includes(token), false);
    assert.equal(f.deliveries.length, 1);
    assert.match(f.deliveries[0].text, /30 minutos/);
    assert.equal(f.stored()?.accountKey.includes('person'), false);
});
test('nonexistent, unknown and Google identities have same void response and no password mail', async () => {
    for (const identity of [null, { ...account, kind: 'unknown' as const }, { ...account, kind: 'google' as const }]) {
        const f = fixture();
        f.identity(identity);
        assert.equal(await f.service.forgot('person@example.test', '127.0.0.1', 'en'), undefined);
        assert.equal(f.deliveries.length, 0);
    }
});
test('reset validates confirmation/token, represents expired/used states, notifies only after success', async () => {
    const f = fixture();
    await f.service.forgot(account.email, '127.0.0.1', 'en');
    const input = { token, password: 'new-password', confirmation: 'new-password', ip: '127.0.0.1', language: 'en' };
    assert.deepEqual(await f.service.reset({ ...input, confirmation: 'different' }), { ok: false, reason: 'password' });
    assert.deepEqual(await f.service.reset({ ...input, token: 'malformed' }), { ok: false, reason: 'invalid' });
    assert.equal((await f.service.reset(input)).ok, true);
    assert.equal(f.deliveries.length, 2);
    assert.deepEqual(await f.service.reset(input), { ok: false, reason: 'used' });
    const expired = fixture();
    await expired.service.forgot(account.email, '127.0.0.1', 'en');
    expired.advance(new Date('2026-09-24T10:30:00Z'));
    assert.deepEqual(await expired.service.reset(input), { ok: false, reason: 'expired' });
});
test('rate limits precede hashing and authenticated change requires previous password', async () => {
    const f = fixture();
    f.limit();
    assert.deepEqual(await f.service.reset({ token, password: '123456', confirmation: '123456', ip: 'ip', language: 'en' }), { ok: false, reason: 'rate_limit' });
    const change = fixture();
    assert.equal(await change.service.change(42, { current: 'wrong', password: '123456', confirmation: '123456', language: 'en' }), false);
    assert.equal(await change.service.change(42, { current: 'previous-secret', password: '123456', confirmation: '123456', language: 'en' }), true);
    assert.equal(change.deliveries.length, 1);
});
test('email preview escapes href and rate hashes separate actions and identities', () => {
    assert.match(resetEmail(account.email, 'https://example.test/?a=1&b="', 30, 'en').html, /&amp;b=&quot;/);
    assert.notEqual(rateKey(config.rateSecret, 'ip', 'a'), rateKey(config.rateSecret, 'account', 'a'));
    assert.throws(() => rateKey('weak', 'ip', 'a'));
});
