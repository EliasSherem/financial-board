import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { validateEvent } from './validation.js';
const now = new Date('2026-09-24T12:00:00Z');
const valid = () => ({ event_id: randomUUID(), schema_version: 1, event_type: 'screen_view', session_id: randomUUID(), client_platform: 'web', source_screen: 'dashboard', client_occurred_at: now.toISOString() });
test('telemetry accepts allowlisted web independent of OS/payment provider', () => assert.equal(validateEvent(valid(), now).client_platform, 'web'));
test('client cannot claim privileged events, identities, finance, prompts, links or impossible time', () => {
    for (const change of [{ event_type: 'purchase_verified' }, { event_type: 'transaction.created' }, { user_id: 1 }, { xp: 100 }, { metadata: { amount: 500 } }, { metadata: { prompt: 'question' } }, { source_screen: '/reset-password#secret' }, { client_occurred_at: '2026-09-20T00:00:00Z' }, { client_occurred_at: '2026-09-25T12:00:00Z' }, { metadata: { flow_id: 'bad' } }])
        assert.throws(() => validateEvent({ ...valid(), ...change }, now));
});
