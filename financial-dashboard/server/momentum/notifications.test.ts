import assert from 'node:assert/strict';
import { test } from 'node:test';
import { quiet, runMomentumNotifications, type MomentumNotificationPorts } from './notifications.js';

function fixture() {
  const user = { user_id: 11, id: 111, locale: 'es', quiet_start: 22, quiet_end: 8, timezone_name: 'UTC', offset_min: 0, assigned_at: '2026-09-25T08:00:00Z', starts_at: '2026-09-21T00:00:00Z', ends_at: '2026-09-28T00:00:00Z', presented_at: null, period_key: '2026-W39' };
  let hour = 12, recent = false, unavailable = false, optedOut = false, delivered = 0, prepared = 0;
  const queries: string[] = [];
  const query = async (sql: string) => {
    queries.push(sql);
    if (sql.includes('SELECT value_json')) return [[], []];
    if (sql.includes('FROM user_momentum m JOIN')) return [[user], []];
    if (sql.includes('FROM momentum_periods WHERE')) return [[user], []];
    if (sql.includes('FROM notification_events')) return [recent ? [{ n: 1 }] : [], []];
    if (sql.includes("status='unavailable'")) return [unavailable ? [{ n: 1 }] : [], []];
    if (sql.includes('FROM user_missions')) return [[], []];
    if (sql.startsWith('INSERT INTO platform_settings')) return [{ affectedRows: 1 }, []];
    throw new Error('Unexpected synthetic query');
  };
  const ports: MomentumNotificationPorts = {
    query: query as MomentumNotificationPorts['query'], enabled: () => true, configured: () => true,
    locked: (async (_id: number, callback: any) => callback({ query }, { notifications_enabled: !optedOut, quiet_start: 22, quiet_end: 8 })) as MomentumNotificationPorts['locked'],
    prepare: async () => { prepared++; return 77; },
    deliver: async (_event, _note, data, reserved) => { delivered++; assert.equal(reserved, 77); assert.equal(data?.route, '/momentum'); return { accepted: 1, retryable: 0, invalid: 0, rejected: 0, unknown: 0, expired: 0 }; },
    now: () => new Date(`2026-09-25T${String(hour).padStart(2, '0')}:00:00Z`), log: () => {},
  };
  return { ports, user, queries, sent: () => delivered, prepared: () => prepared, setHour: (value: number) => { hour = value; }, recent: () => { recent = true; }, unavailable: () => { unavailable = true; }, optOut: () => { optedOut = true; } };
}

test('Momentum sends through durable delivery after rechecking preferences, and keeps current-event retry outside caps', async () => {
  const h = fixture(); await runMomentumNotifications(h.ports);
  assert.equal(h.sent(), 1); assert.equal(h.prepared(), 1);
  assert.ok(h.queries.some(sql => sql.includes("AND NOT(type=? AND entity_id='momentum' AND event_key=?)")));
});

test('quiet hours, opted-out preferences, another recent event and unavailable activities suppress pushes', async () => {
  for (const block of ['quiet', 'optOut', 'recent', 'unavailable', 'presented'] as const) {
    const h = fixture();
    if (block === 'quiet') h.setHour(23);
    else if (block === 'presented') h.user.presented_at = '2026-09-25T10:00:00Z';
    else h[block]();
    await runMomentumNotifications(h.ports); assert.equal(h.sent(), 0, block); assert.equal(h.prepared(), 0, block);
  }
});

test('Momentum without provider configuration performs no DB or provider work', async () => {
  const h = fixture(); h.ports.configured = () => false; await runMomentumNotifications(h.ports);
  assert.equal(h.queries.length, 0); assert.equal(h.sent(), 0);
});

test('quiet hours retain midnight wrap and all-day semantics', () => {
  assert.equal(quiet(23, 22, 8), true); assert.equal(quiet(7, 22, 8), true); assert.equal(quiet(12, 22, 8), false); assert.equal(quiet(12, 12, 12), true);
});
