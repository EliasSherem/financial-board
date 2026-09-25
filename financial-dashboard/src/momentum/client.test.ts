import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { test } from 'node:test';
import { MOMENTUM_CACHE_KEY, MOMENTUM_CACHE_MS, MOMENTUM_FRESH_MS, MomentumClient, type MomentumSession } from './client';
import type { Momentum, MomentumResponse } from './types';

const start = Date.parse('2026-09-25T12:00:00Z');
const digest = async (token: string) => createHash('sha256').update(token).digest('hex');
const turn = () => new Promise<void>(resolve => setImmediate(resolve));
function deferred<T>() {
    let resolve!: (value: T) => void;
    let reject!: (reason?: unknown) => void;
    const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
    return { promise, resolve, reject };
}
function fixture(user_id = 11, lifetime_xp = 50, generated_at = new Date(start).toISOString()): Momentum {
    return {
        enabled: true, user_id, generated_at, lifetime_xp, rhythm: 1,
        level: { key: 'seed', title: { en: 'Seed', es: 'Semilla' }, minimum_xp: 0, next_xp: 100 },
        week: { key: '2026-W39', timezone: 'UTC', starts_at: '2026-09-21T00:00:00Z', ends_at: '2026-09-28T00:00:00Z', assigned: true, completed: 0, total: 3, bonus_xp: 0, repeatable_xp: 0, cap: 100, new_week: false, unavailable: false, grace_applied: false },
        month: { key: '2026-09', repeatable_xp: 0, cap: 50 }, missions: [], xp_history: [],
        achievements: [{ key: 'first_account', title: { en: 'First account', es: 'Primera cuenta' }, requirement: { en: 'Add an account', es: 'Añade una cuenta' }, progress: 1, target: 1, xp: 50, available: true, reason: null, completed_at: '2026-09-24T12:00:00Z', seen_at: null }],
        ai_credits: { available: false, balance: 0, expires_at: null }, backfill: { completed: true, unseen: false }, coachmark_seen: true,
        preferences: { notifications_enabled: true, quiet_start: 22, quiet_end: 8, locale: 'en' },
    };
}
function harness() {
    let session: MomentumSession | null = { userId: 11, token: 'private-session-one', expiresAt: start + 24 * 60 * 60_000 };
    let now = start;
    let visible = true;
    const values = new Map<string, string>();
    const requests: (ReturnType<typeof deferred<MomentumResponse>> & { signal: AbortSignal })[] = [];
    const seen: (ReturnType<typeof deferred<unknown>> & { key: string })[] = [];
    const storage = { getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => { values.set(key, value); }, removeItem: (key: string) => { values.delete(key); } };
    const options = { session: () => session, now: () => now, visible: () => visible, storage, fingerprint: digest,
        request: (signal: AbortSignal) => { const request = { ...deferred<MomentumResponse>(), signal }; requests.push(request); return request.promise; },
        seen: (key: string) => { const request = { ...deferred<unknown>(), key }; seen.push(request); return request.promise; },
    };
    return { client: new MomentumClient(options), options, requests, seen, values, setNow: (value: number) => { now = value; }, setSession: (value: MomentumSession | null) => { session = value; }, setVisible: (value: boolean) => { visible = value; } };
}
async function populate(h: ReturnType<typeof harness>, state = fixture()) {
    const pending = h.client.refresh(true); await turn(); h.requests.at(-1)!.resolve(state); await pending;
}

test('one GET serves concurrent consumers; foreground freshness is 30 seconds, explicit retry refreshes', async () => {
    const h = harness();
    const first = h.client.refresh(true), second = h.client.refresh(true);
    await turn(); assert.equal(h.requests.length, 1);
    h.requests[0].resolve(fixture()); await Promise.all([first, second]);
    h.setNow(start + MOMENTUM_FRESH_MS - 1); await h.client.refresh(); assert.equal(h.requests.length, 1);
    h.setNow(start + MOMENTUM_FRESH_MS); const next = h.client.refresh(); await turn(); assert.equal(h.requests.length, 2);
    h.requests[1].resolve(fixture()); await next;
    const retry = h.client.refresh(true); await turn(); assert.equal(h.requests.length, 3);
    h.requests[2].resolve(fixture()); await retry;
});

test('same-session cache appears while the entry refresh is pending and never stores the token', async () => {
    const h = harness(); await populate(h);
    const raw = h.values.get(MOMENTUM_CACHE_KEY)!;
    assert.ok(raw); assert.equal(raw.includes('private-session-one'), false);
    const reopened = new MomentumClient(h.options);
    const pending = reopened.refresh(true); await turn();
    assert.equal(reopened.snapshot().state?.lifetime_xp, 50);
    assert.equal(reopened.snapshot().loading, false); assert.equal(h.requests.length, 2);
    h.requests[1].resolve(fixture(11, 75, new Date(start + 1).toISOString())); await pending;
    assert.equal(reopened.snapshot().state?.lifetime_xp, 75);
});

test('cache rejects another session, another identity, expiry, malformed data and stale data', async t => {
    const valid = { version: 1, fingerprint: await digest('private-session-one'), userId: 11, savedAt: start, state: fixture() };
    for (const [name, saved] of Object.entries({
        session: { ...valid, fingerprint: 'different-session' }, identity: { ...valid, userId: 12 },
        stale: { ...valid, savedAt: start - MOMENTUM_CACHE_MS - 1 }, future: { ...valid, savedAt: start + 1 },
        malformed: { ...valid, state: { ...fixture(), week: null } }, disabled: { ...valid, state: { enabled: false, user_id: 11 } },
    })) await t.test(name, async () => {
        const h = harness(); h.values.set(MOMENTUM_CACHE_KEY, JSON.stringify(saved));
        const pending = h.client.refresh(true); await turn();
        assert.equal(h.client.snapshot().state, null); assert.equal(h.values.has(MOMENTUM_CACHE_KEY), false);
        h.requests[0].resolve(fixture()); await pending;
    });
    const h = harness(); h.values.set(MOMENTUM_CACHE_KEY, JSON.stringify(valid));
    h.setSession({ userId: 11, token: 'private-session-one', expiresAt: start });
    const pending = h.client.refresh(true); await turn(); assert.equal(h.client.snapshot().state, null);
    h.requests[0].reject(new Error('expired')); await pending;
});

test('identity changes start a fresh request immediately and fence an older response', async () => {
    const h = harness(); const old = h.client.refresh(true); await turn();
    h.setSession({ userId: 22, token: 'private-session-two' }); const current = h.client.refresh(true); await turn();
    assert.equal(h.requests.length, 2); assert.equal(h.requests[0].signal.aborted, true);
    h.requests[1].resolve(fixture(22, 100)); await current;
    h.requests[0].resolve(fixture(11, 999)); await old;
    assert.equal(h.client.snapshot().state?.user_id, 22); assert.equal(h.client.snapshot().state?.lifetime_xp, 100); assert.equal(h.client.snapshot().error, false);
});

test('token rotation within the same account and logout clear the old display and cache', async () => {
    const h = harness(); await populate(h);
    h.setSession({ userId: 11, token: 'rotated-session' }); const pending = h.client.refresh(true); await turn();
    assert.equal(h.client.snapshot().state, null); assert.equal(h.values.has(MOMENTUM_CACHE_KEY), false);
    h.requests[1].resolve(fixture()); await pending;
    h.setSession(null); await h.client.refresh(true);
    assert.deepEqual(h.client.snapshot(), { state: null, loading: false, error: false }); assert.equal(h.values.has(MOMENTUM_CACHE_KEY), false);
});

test('a POST response supersedes an older GET without another GET', async () => {
    const h = harness(); const pending = h.client.refresh(true); await turn();
    h.client.replace(fixture(11, 100, new Date(start + 1).toISOString()));
    h.requests[0].resolve(fixture(11, 50)); await pending;
    assert.equal(h.client.snapshot().state?.lifetime_xp, 100); assert.equal(h.requests.length, 1);
});

test('a late POST and a late GET cannot replace a newer generated_at', async () => {
    const h = harness(); await populate(h, fixture(11, 100, new Date(start + 1000).toISOString()));
    h.client.replace(fixture(11, 50)); assert.equal(h.client.snapshot().state?.lifetime_xp, 100);
    const pending = h.client.refresh(true); await turn(); h.requests[1].resolve(fixture(11, 75)); await pending;
    assert.equal(h.client.snapshot().state?.lifetime_xp, 100);
});

test('financial changes during a POST are still refreshed once after the burst', async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const h = harness(); await populate(h);
    h.client.invalidate(); h.client.invalidate(); h.client.invalidate();
    h.client.replace(fixture(11, 60, new Date(start + 1).toISOString()));
    t.mock.timers.tick(450); await turn(); assert.equal(h.requests.length, 2);
    h.requests[1].resolve(fixture(11, 80, new Date(start + 2).toISOString())); await turn();
    t.mock.timers.tick(1000); await turn(); assert.equal(h.requests.length, 2); assert.equal(h.client.snapshot().state?.lifetime_xp, 80);
});

test('financial changes during GET discard that response and coalesce into one follow-up', async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const h = harness(); const pending = h.client.refresh(true); await turn();
    h.client.invalidate(); h.client.invalidate();
    h.requests[0].resolve(fixture(11, 25)); await turn();
    assert.equal(h.requests.length, 2); assert.equal(h.client.snapshot().state, null);
    h.requests[1].resolve(fixture(11, 75)); await pending;
    t.mock.timers.tick(1000); await turn(); assert.equal(h.requests.length, 2); assert.equal(h.client.snapshot().state?.lifetime_xp, 75);
});

test('a POST begun before a financial change cannot discard the newer invalidation GET', async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const h = harness(); await populate(h);
    h.client.invalidate(); t.mock.timers.tick(450); await turn();
    h.client.replace(fixture(11, 60, new Date(start + 1).toISOString()));
    h.requests[1].resolve(fixture(11, 80, new Date(start + 2).toISOString())); await turn();
    assert.equal(h.client.snapshot().state?.lifetime_xp, 80); assert.equal(h.requests.length, 2);
});

test('a GET with the same timestamp cannot undo a POST accepted while it was pending', async () => {
    const h = harness(); const pending = h.client.refresh(true); await turn();
    h.client.replace(fixture(11, 60)); h.requests[0].resolve(fixture(11, 50)); await pending;
    assert.equal(h.client.snapshot().state?.lifetime_xp, 60);
});

test('a failed older GET cannot report offline after a successful POST', async () => {
    const h = harness(); const pending = h.client.refresh(true); await turn();
    h.client.replace(fixture(11, 60)); h.requests[0].reject(new Error('old GET failed')); await pending;
    assert.equal(h.client.snapshot().state?.lifetime_xp, 60); assert.equal(h.client.snapshot().error, false);
});

test('hidden financial changes wait until visible and bypass the freshness window', async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const h = harness(); await populate(h); h.setVisible(false); h.client.invalidate();
    t.mock.timers.tick(450); await turn(); assert.equal(h.requests.length, 1);
    h.setVisible(true); const pending = h.client.refresh(); await turn(); assert.equal(h.requests.length, 2);
    h.requests[1].resolve(fixture()); await pending;
});

test('achievement ACK deduplicates and updates only seen_at without a full GET', async () => {
    const h = harness(); await populate(h); const before = structuredClone(h.client.snapshot().state!);
    const first = h.client.acknowledgeAchievement('first_account'), second = h.client.acknowledgeAchievement('first_account');
    assert.equal(first, second); assert.equal(h.seen.length, 1); assert.equal(h.client.snapshot().state?.achievements[0].seen_at, null);
    h.seen[0].resolve({ ok: true }); await first;
    const after = structuredClone(h.client.snapshot().state!); assert.equal(after.achievements[0].seen_at, new Date(start).toISOString());
    after.achievements[0].seen_at = null; assert.deepEqual(after, before); assert.equal(h.requests.length, 1);
    const pending = h.client.refresh(true); await turn(); h.requests[1].resolve(fixture()); await pending;
    assert.ok(h.client.snapshot().state?.achievements[0].seen_at, 'a concurrently generated response cannot resurrect the notice');
});

test('failed ACK and an ACK from a previous session cannot alter the current display', async () => {
    const h = harness(); await populate(h);
    const failure = h.client.acknowledgeAchievement('first_account'); h.seen[0].reject(new Error('offline'));
    await assert.rejects(failure); assert.equal(h.client.snapshot().state?.achievements[0].seen_at, null);
    const old = h.client.acknowledgeAchievement('first_account');
    h.setSession({ userId: 22, token: 'new-owner' }); const pending = h.client.refresh(true); await turn();
    h.requests[1].resolve(fixture(22)); await pending; h.seen[1].resolve({ ok: true }); await old;
    assert.equal(h.client.snapshot().state?.achievements[0].seen_at, null);
});

test('network failure keeps cached progress; no disabled state is persisted', async () => {
    const h = harness(); await populate(h);
    const pending = h.client.refresh(true); await turn(); h.requests[1].reject(new Error('offline')); await pending;
    assert.equal(h.client.snapshot().state?.lifetime_xp, 50); assert.equal(h.client.snapshot().error, true);
    const disabled = h.client.refresh(true); await turn(); h.requests[2].resolve({ enabled: false, user_id: 11 }); await disabled;
    assert.equal(h.values.has(MOMENTUM_CACHE_KEY), false); assert.equal(h.client.snapshot().state, null);
    h.setNow(start + 5_000); const enabled = h.client.refresh(); await turn(); assert.equal(h.requests.length, 4);
    h.requests[3].resolve(fixture()); await enabled; assert.ok(h.client.snapshot().state);
});

test('a true unmount cancels GET; StrictMode immediate resubscription keeps its one request', async () => {
    const h = harness(); let unsubscribe = h.client.subscribe(() => {});
    const pending = h.client.refresh(true); await turn(); unsubscribe(); h.client.stopWhenUnused(); unsubscribe = h.client.subscribe(() => {});
    await turn(); assert.equal(h.requests[0].signal.aborted, false);
    unsubscribe(); h.client.stopWhenUnused(); await turn(); assert.equal(h.requests[0].signal.aborted, true);
    h.requests[0].resolve(fixture()); await pending; assert.equal(h.client.snapshot().state, null);
});

test('storage and fingerprint failures never prevent a current server response', async () => {
    const h = harness(); const client = new MomentumClient({ ...h.options, fingerprint: async () => { throw new Error('unavailable'); }, storage: { getItem: () => { throw new Error('blocked'); }, setItem: () => { throw new Error('full'); }, removeItem: () => { throw new Error('blocked'); } } });
    const pending = client.refresh(true); await turn(); h.requests[0].resolve(fixture()); await pending;
    assert.equal(client.snapshot().state?.lifetime_xp, 50); assert.equal(client.snapshot().error, false);
});
