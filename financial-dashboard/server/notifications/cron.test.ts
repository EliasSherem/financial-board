import assert from 'node:assert/strict';
import { test } from 'node:test';
import { runNotificationCron, type NotificationPorts } from '../notification_cron.js';

function fixture() {
  const users = [{ id: 1, username: 'Synthetic', email: 'one@example.invalid', timezone_offset_min: 0 }, { id: 2, username: 'Synthetic', email: 'two@example.invalid', timezone_offset_min: 0 }];
  const claimed = new Set<string>(), sent: number[] = [], mails: string[] = [], logs: string[] = [];
  let emailFailure = false, pushFailure = false, evidenceFailure = false;
  const query = async (sql: string, values: any[] = []) => {
    if (sql.includes('FROM users')) return [users, []];
    if (sql.includes('FROM payments p')) return [[{ id: 10 + values[0], name: 'Synthetic bill', next_date: '2026-09-26', amount: '12.30', account_name: 'Synthetic' }], []];
    if (sql.startsWith('SELECT entity_id, event_key')) {
      if (evidenceFailure) throw new Error('synthetic email store failure');
      return [[...claimed].filter(key => key.startsWith(`${values[0]}|${values[1]}|`)).map(key => { const parts = key.split('|'); return { entity_id: parts[2], event_key: parts[3] }; }), []];
    }
    if (sql.includes('FROM projects') || sql.includes('FROM expense_subcategories') || sql.includes('SELECT entity_id')) return [[], []];
    if (sql.startsWith('UPDATE notification_events')) return [{ affectedRows: 0 }, []];
    if (sql.startsWith('INSERT IGNORE INTO notification_events')) { const key = values.join('|'); const affectedRows = claimed.has(key) ? 0 : 1; claimed.add(key); return [{ affectedRows }, []]; }
    if (sql.startsWith('DELETE FROM notification_events')) { claimed.delete(values.join('|')); return [{ affectedRows: 1 }, []]; }
    throw new Error(`Unexpected test query: ${sql}`);
  };
  const ports: NotificationPorts = {
    query: query as NotificationPorts['query'], pushConfigured: () => true, emailConfigured: () => true, now: () => new Date('2026-09-25T12:00:00Z'), log: code => logs.push(code),
    sendEmail: async mail => { if (emailFailure) throw new Error('synthetic'); mails.push(mail.to); return true; },
    deliverPush: async event => { sent.push(event.userId); if (pushFailure && event.userId === 1) throw new Error('synthetic'); return { accepted: 1, retryable: 0, invalid: 0, rejected: 0, unknown: 0, expired: 0 }; },
  };
  return { users, ports, claimed, sent, mails, logs, failEmail: () => { emailFailure = true; }, recoverEmail: () => { emailFailure = false; }, failPush: () => { pushFailure = true; }, failEmailEvidence: () => { evidenceFailure = true; } };
}

test('email failure releases its own claim and cannot block push or later users', async () => {
  const h = fixture(); h.failEmail(); await runNotificationCron(h.ports);
  assert.deepEqual(h.sent, [1, 2]); assert.equal(h.claimed.size, 0);
  h.recoverEmail(); await runNotificationCron(h.ports); assert.equal(h.mails.length, 2);
  await runNotificationCron(h.ports); assert.equal(h.mails.length, 2, 'accepted emails keep their existing dedupe');
});

test('push failure cannot block email or subsequent users', async () => {
  const h = fixture(); h.failPush(); await runNotificationCron(h.ports);
  assert.deepEqual(h.sent, [1, 2]); assert.equal(h.mails.length, 2); assert.ok(h.logs.includes('PUSH_EVENT_FAILED'));
});

test('placeholder email suppression skips only mail, and email evidence failures leave push independent', async () => {
  const h = fixture(); h.users[0].email = 'root@example.com'; await runNotificationCron(h.ports);
  assert.deepEqual(h.sent, [1, 2]); assert.deepEqual(h.mails, ['two@example.invalid']);
  const broken = fixture(); broken.failEmailEvidence(); await runNotificationCron(broken.ports);
  assert.deepEqual(broken.sent, [1, 2]); assert.equal(broken.mails.length, 0);
});

test('configured channels run independently', async () => {
  const email = fixture(); email.ports.pushConfigured = () => false; await runNotificationCron(email.ports);
  assert.equal(email.sent.length, 0); assert.equal(email.mails.length, 2);
  const push = fixture(); push.ports.emailConfigured = () => false; await runNotificationCron(push.ports);
  assert.equal(push.sent.length, 2); assert.equal(push.mails.length, 0);
});
