import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createPlatformRequest, PlatformError } from './request';

function setup() {
    let token: string | null = 'session-one';
    let unauthorized = 0;
    let respond!: (response: Response) => void;
    let captured: RequestInit | undefined;
    const request = createPlatformRequest({
        token: () => token, base: () => 'https://api.invalid/api', unauthorized: () => { unauthorized++; },
        fetch: async (_url, init) => { captured = init; return new Promise<Response>(resolve => { respond = resolve; }); },
    });
    return { request, respond: (status: number, body: unknown = {}) => respond(new Response(JSON.stringify(body), { status })), setToken: (value: string | null) => { token = value; }, unauthorized: () => unauthorized, captured: () => captured };
}
test('late 401 cannot clear a newer session', async () => {
    const h = setup(); const pending = h.request('/engagement/me');
    assert.equal((h.captured()?.headers as Record<string, string>).Authorization, 'Bearer session-one');
    h.setToken('session-two'); h.respond(401, { code: 'UNAUTHORIZED' });
    await assert.rejects(pending, error => error instanceof PlatformError && error.message === 'SESSION_CHANGED');
    assert.equal(h.unauthorized(), 0);
});
test('late successful response is rejected after logout or token rotation', async () => {
    for (const token of [null, 'session-two']) {
        const h = setup(); const pending = h.request('/engagement/me'); h.setToken(token); h.respond(200, { user_id: 11 });
        await assert.rejects(pending, error => error instanceof PlatformError && error.message === 'SESSION_CHANGED'); assert.equal(h.unauthorized(), 0);
    }
});
test('current 401 invalidates exactly that session; 503 keeps it', async () => {
    const h = setup(); const unauthorized = h.request('/engagement/me'); h.respond(401, { code: 'UNAUTHORIZED' });
    await assert.rejects(unauthorized, error => error instanceof PlatformError && error.status === 401); assert.equal(h.unauthorized(), 1);
    const unavailable = h.request('/engagement/me'); h.respond(503, { code: 'UNAVAILABLE' });
    await assert.rejects(unavailable, error => error instanceof PlatformError && error.status === 503); assert.equal(h.unauthorized(), 1);
});
test('caller cancellation is forwarded and an aborted success is never accepted', async () => {
    const h = setup(); const controller = new AbortController(); const pending = h.request('/engagement/review/weekly', undefined, controller.signal);
    controller.abort(); assert.equal(h.captured()?.signal?.aborted, true); h.respond(200, {});
    await assert.rejects(pending, error => error instanceof Error && error.name === 'AbortError'); assert.equal(h.unauthorized(), 0);
});
test('bounded timeout aborts a stalled network request without invalidating credentials', async () => {
    let unauthorized = 0;
    const request = createPlatformRequest({ token: () => 'session', base: () => 'https://api.invalid/api', unauthorized: () => { unauthorized++; }, timeoutMs: 5,
        fetch: async (_url, init) => new Promise<Response>((_resolve, reject) => { init?.signal?.addEventListener('abort', () => reject(init.signal?.reason), { once: true }); }),
    });
    await assert.rejects(request('/engagement/me'), /REQUEST_TIMEOUT/); assert.equal(unauthorized, 0);
});
test('POST keeps the established payload and privacy policy', async () => {
    const h = setup(); const pending = h.request('/engagement/client-events', { event_id: 'synthetic', type: 'week_presented' });
    assert.equal(h.captured()?.method, 'POST'); assert.equal(h.captured()?.cache, 'no-store'); assert.equal(h.captured()?.referrerPolicy, 'no-referrer');
    assert.deepEqual(JSON.parse(String(h.captured()?.body)), { event_id: 'synthetic', type: 'week_presented' }); h.respond(200, { ok: true });
    assert.deepEqual(await pending, { ok: true });
});
