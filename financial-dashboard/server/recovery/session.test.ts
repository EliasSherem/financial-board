import test from 'node:test';
import assert from 'node:assert/strict';
import jwt from 'jsonwebtoken';
import type { Request, Response } from 'express';
import { authenticateToken, generateToken, verifyToken } from '../auth.js';
import { db } from '../db.js';
test('legacy sessions, immediate version revocation, deleted users and DB failures fail safely', async () => {
    const original = db.query;
    const secret = process.env.JWT_SECRET || 'secret';
    let version: number | null = 0;
    let outage = false;
    db.query = (async () => {
        if (outage)
            throw new Error('simulated outage');
        return [version === null ? [] : [{ token_version: version }], []];
    }) as unknown as typeof db.query;
    const call = async (token: string) => {
        let status = 200;
        let next = false;
        const res = { status(code: number) { status = code; return this; }, json() { return this; } } as unknown as Response;
        await authenticateToken({ headers: { authorization: `Bearer ${token}` } } as Request, res, () => { next = true; });
        return { status, next };
    };
    try {
        const legacy = jwt.sign({ id: 42, username: 'test' }, secret, { expiresIn: '1h' });
        assert.deepEqual(await call(legacy), { status: 200, next: true });
        version = 1;
        assert.deepEqual(await call(legacy), { status: 401, next: false });
        const current = generateToken({ id: 42, username: 'test', token_version: 1 });
        assert.deepEqual(await call(current), { status: 200, next: true });
        assert.equal(verifyToken(current)?.token_version, 1);
        version = null;
        assert.deepEqual(await call(current), { status: 401, next: false });
        outage = true;
        assert.deepEqual(await call(current), { status: 503, next: false });
        assert.deepEqual(await call('invalid-token'), { status: 401, next: false });
    }
    finally {
        db.query = original;
    }
});
