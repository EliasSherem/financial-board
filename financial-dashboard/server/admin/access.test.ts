import test from 'node:test';
import assert from 'node:assert/strict';
import type { Request, Response } from 'express';
import { db } from '../db.js';
import { ownerMiddleware } from './access.js';
test('owner API guard rejects anonymous and normal user; no ID exemption or client role', async () => {
    const original = db.query;
    let role: string | undefined;
    db.query = (async () => [role ? [{ role }] : [], []]) as unknown as typeof db.query;
    const call = (user?: Record<string, unknown>) => new Promise<number>(resolve => { const req = { user, body: { role: 'owner' } } as unknown as Request; const res = { status(code: number) { resolve(code); return this; }, json() { return this; } } as unknown as Response; ownerMiddleware(req, res, () => resolve(200)); });
    try {
        assert.equal(await call(), 401);
        assert.equal(await call({ id: 1 }), 403);
        assert.equal(await call({ id: 3 }), 403);
        role = 'owner';
        assert.equal(await call({ id: 789 }), 200);
        role = 'viewer';
        assert.equal(await call({ id: 789 }), 403);
    }
    finally {
        db.query = original;
    }
});
