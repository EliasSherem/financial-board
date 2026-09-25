import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import type { ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import express from 'express';
import { db } from '../db.js';
import { generateToken } from '../auth.js';
import router from '../routes.js';

const enabled = process.env.RUN_DB_TESTS === 'true';
const prefix = `contribution_sql_${randomUUID().slice(0, 8)}`;
const users: number[] = [];
let user = 0;
let account = 0;
let investment = 0;
let ownerToken = '';
let otherToken = '';
let server: Server | undefined;
let base = '';
const date = '2025-06-15';

if (enabled) {
  assert.equal(process.env.NODE_ENV, 'test');
  assert.equal(process.env.MYSQL_URL, undefined);
  assert.equal(process.env.MYSQL_HOST, '127.0.0.1');
  assert.match(process.env.MYSQL_DATABASE ?? '', /_test$/);
}

async function rows(sql: string, values: unknown[] = []) {
  return (await db.query<RowDataPacket[]>(sql, values))[0];
}

before(async () => {
  if (!enabled) return;
  // Tests exercise reviewed migrations, never the legacy runtime DDL path.
  process.env.LEGACY_SCHEMA_BOOTSTRAP = 'false';
  for (const suffix of ['owner', 'other']) {
    const username = `${prefix}_${suffix}`;
    const [created] = await db.query<ResultSetHeader>(
      "INSERT INTO users (username,email,password,credential_kind) VALUES (?,?,'unusable','local')",
      [username, `${username}@example.invalid`],
    );
    users.push(created.insertId);
    await db.query(
      "INSERT INTO billing_grants (user_id,source,expires_at) VALUES (?,'test_manual',DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY))",
      [created.insertId],
    );
    const token = generateToken({ id: created.insertId, username });
    if (suffix === 'owner') {
      user = created.insertId;
      ownerToken = token;
    } else {
      otherToken = token;
    }
  }
  const [createdAccount] = await db.query<ResultSetHeader>(
    "INSERT INTO accounts (user_id,name,type,balance) VALUES (?,'Synthetic investment fixture','Investment',100)",
    [user],
  );
  account = createdAccount.insertId;
  const [createdInvestment] = await db.query<ResultSetHeader>(
    "INSERT INTO investments (user_id,name,principal,annual_rate,start_date,account_id) VALUES (?,'Synthetic contribution fixture',100,0,'2025-01-01',?)",
    [user, account],
  );
  investment = createdInvestment.insertId;
  await db.query(
    'INSERT INTO balance_history (user_id,account_id,year,month,balance) VALUES (?,?,2025,6,100)',
    [user, account],
  );
  const app = express();
  app.use(express.json());
  app.use(router);
  server = await new Promise<Server>((resolve) => {
    const listener = app.listen(0, '127.0.0.1', () => resolve(listener));
  });
  base = `http://127.0.0.1:${(server.address() as { port: number }).port}`;
});

after(async () => {
  if (server) await new Promise<void>((resolve) => server!.close(() => resolve()));
  if (enabled) {
    for (const id of users) await db.query('DELETE FROM users WHERE id=?', [id]);
  }
  await db.end();
});

async function contribute(body: unknown, bearer: string | null = ownerToken) {
  const response = await fetch(`${base}/api/investments/${investment}/contributions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}),
    },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() as Record<string, unknown> };
}

async function financialState() {
  return {
    contributions: await rows('SELECT id,amount,date FROM investment_contributions WHERE investment_id=? ORDER BY id', [investment]),
    account: await rows('SELECT id,balance FROM accounts WHERE id=?', [account]),
    history: await rows('SELECT id,year,month,balance FROM balance_history WHERE user_id=? AND account_id=? ORDER BY id', [user, account]),
    outbox: await rows('SELECT id,event_id,event_type,source,idempotency_key,payload_json FROM engagement_events WHERE user_id=? ORDER BY id', [user]),
  };
}

test('investment contribution HTTP rejects anonymous, other owner and invalid dates without financial writes', { skip: !enabled }, async () => {
  const beforeState = await financialState();
  assert.equal((await contribute({ amount: 25, date }, null)).status, 401);
  assert.equal((await contribute({ amount: 25, date }, otherToken)).status, 404);
  for (const invalid of ['not-a-date', '', null, undefined]) {
    const result = await contribute({ amount: 25, date: invalid });
    assert.equal(result.status, 400);
    assert.deepEqual(result.body, { message: 'Invalid payload' });
  }
  assert.deepEqual(await financialState(), beforeState);
});

test('investment contribution HTTP rolls back contribution, balance, history and actual outbox on either write failure', { skip: !enabled }, async (t) => {
  const beforeState = await financialState();
  const outboxFailure = `test_contribution_outbox_${user}`;
  const historyFailure = `test_contribution_history_${user}`;
  // Suppress expected injected SQL errors; assertions below verify the actual responses and database.
  t.mock.method(console, 'error', () => {});
  try {
    await db.query(`CREATE TRIGGER ${outboxFailure} BEFORE INSERT ON engagement_events FOR EACH ROW
      BEGIN IF NEW.user_id=${user} AND NEW.event_type='investment_contributions.insert'
      THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='TEST_CONTRIBUTION_OUTBOX_FAILURE'; END IF; END`);
    const failedOutbox = await contribute({ amount: 25, date });
    assert.equal(failedOutbox.status, 500);
    assert.deepEqual(failedOutbox.body, { message: 'Failed to add contribution' });
    assert.deepEqual(await financialState(), beforeState);
    await db.query(`DROP TRIGGER ${outboxFailure}`);

    await db.query(`CREATE TRIGGER ${historyFailure} BEFORE UPDATE ON balance_history FOR EACH ROW
      BEGIN IF NEW.user_id=${user} AND NEW.account_id=${account}
      THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='TEST_CONTRIBUTION_HISTORY_FAILURE'; END IF; END`);
    const failedHistory = await contribute({ amount: 25, date });
    assert.equal(failedHistory.status, 500);
    assert.deepEqual(failedHistory.body, { message: 'Failed to add contribution' });
    assert.deepEqual(await financialState(), beforeState);
    await db.query(`DROP TRIGGER ${historyFailure}`);

    const success = await contribute({ amount: 25, date });
    assert.equal(success.status, 200);
    assert.equal(typeof success.body.id, 'number');
    assert.deepEqual(success.body, { id: success.body.id, investment_id: investment, amount: 25, date });
    const afterState = await financialState();
    assert.equal(afterState.contributions.length, 1);
    assert.equal(afterState.contributions[0].amount, '25.00');
    assert.equal(afterState.account[0].balance, '125.00');
    assert.equal(afterState.history.length, 1);
    assert.equal(afterState.history[0].balance, '125.00');
    assert.equal(afterState.outbox.length, beforeState.outbox.length + 1);
    const event = afterState.outbox.find((row) => row.event_type === 'investment_contributions.insert');
    assert.ok(event);
    assert.equal(event.source, 'server');
    assert.equal(event.idempotency_key, `investment_contribution:${success.body.id}`);
    const payload = typeof event.payload_json === 'string' ? JSON.parse(event.payload_json) : event.payload_json;
    assert.deepEqual(payload, { entity_id: success.body.id, investment_id: investment });
  } finally {
    await db.query(`DROP TRIGGER IF EXISTS ${outboxFailure}`);
    await db.query(`DROP TRIGGER IF EXISTS ${historyFailure}`);
  }
});
