import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import type { ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import express from 'express';
import { db } from '../db.js';
import { generateToken } from '../auth.js';
import router from '../routes.js';
import { formatDateOnly } from './salarySchedule.js';

const enabled = process.env.RUN_DB_TESTS === 'true';
const prefix = `salary_atomic_${randomUUID().slice(0, 8)}`;
const users: number[] = [];
const servers: Server[] = [];
const bases: string[] = [];
if (enabled) {
  assert.equal(process.env.NODE_ENV, 'test');
  assert.equal(process.env.MYSQL_URL, undefined);
  assert.equal(process.env.MYSQL_HOST, '127.0.0.1');
  assert.match(process.env.MYSQL_DATABASE ?? '', /_test$/);
}
const rows = async (sql: string, values: unknown[] = []) => (await db.query<RowDataPacket[]>(sql, values))[0];
const insert = async (sql: string, values: unknown[]) => (await db.query<ResultSetHeader>(sql, values))[0].insertId;
const today = () => formatDateOnly(new Date())!;
async function fixture(name: string, balance = 0) {
  const username = `${prefix}_${name}`;
  const user = await insert("INSERT INTO users(username,email,password,credential_kind) VALUES (?,?,'unusable','local')", [username, `${username}@example.invalid`]);
  users.push(user);
  await db.query("INSERT INTO billing_grants(user_id,source,expires_at) VALUES (?,'test_salary',DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY))", [user]);
  const account = await insert("INSERT INTO accounts(user_id,name,type,balance) VALUES (?,'Salary test','Checking',?)", [user, balance]);
  const token = generateToken({ id: user, username });
  const request = async (path: string, method = 'GET', body?: unknown, instance = 0) => {
    const response = await fetch(`${bases[instance]}${path}`, {
      method, headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const payload = await response.json();
    return { status: response.status, payload };
  };
  const rule = (amount = 30, date = today(), description = 'Salary same description') => insert(
    "INSERT INTO salary_rules(user_id,name,amount,schedule,weekday,account_id,next_date) VALUES (?,?,?,'Weekly',?,?,?)",
    [user, description, amount, new Date().getDay(), account, date],
  );
  return { user, account, request, rule };
}
before(async () => {
  if (!enabled) return;
  process.env.LEGACY_SCHEMA_BOOTSTRAP = 'false';
  // Separate HTTP listeners; no process-local salary mutex exists. Concurrent
  // request scopes use independent pool connections and the database row lock.
  for (let instance = 0; instance < 2; instance++) {
    const app = express(); app.use(express.json()); app.use(router);
    const server = await new Promise<Server>(resolve => { const value = app.listen(0, '127.0.0.1', () => resolve(value)); });
    servers.push(server);
    bases.push(`http://127.0.0.1:${(server.address() as { port: number }).port}`);
  }
});
after(async () => {
  for (const server of servers) await new Promise<void>(resolve => server.close(() => resolve()));
  if (enabled) for (const user of users) {
    await db.query('DELETE FROM salary_rules WHERE user_id = ?', [user]);
    await db.query('DELETE FROM users WHERE id = ?', [user]);
  }
  await db.end();
});

test('parallel account, transaction and salary GETs consume one occurrence and one income', { skip: !enabled }, async () => {
  const f = await fixture('parallel');
  const id = await f.rule(123.45);
  const trigger = `test_salary_delay_${f.user}`;
  try {
    await db.query(`CREATE TRIGGER ${trigger} BEFORE INSERT ON transactions FOR EACH ROW BEGIN
      IF NEW.user_id = ${f.user} THEN DO SLEEP(0.12); END IF; END`);
    const results = await Promise.all(Array.from({ length: 9 }, (_, index) => f.request(
      ['/api/accounts', '/api/transactions', '/api/salaries'][index % 3], 'GET', undefined, index % 2,
    )));
    assert.deepEqual(results.map(result => result.status), Array(9).fill(200));
  } finally { await db.query(`DROP TRIGGER IF EXISTS ${trigger}`); }
  assert.equal((await rows('SELECT id FROM transactions WHERE user_id = ?', [f.user])).length, 1);
  assert.equal(Number((await rows('SELECT balance FROM accounts WHERE id = ?', [f.account]))[0].balance), 123.45);
  assert.equal(Number((await rows('SELECT balance FROM balance_history WHERE user_id = ?', [f.user]))[0].balance), 123.45);
  const due = new Date(); due.setDate(due.getDate() + 7);
  assert.equal((await rows("SELECT DATE_FORMAT(next_date,'%Y-%m-%d') AS date FROM salary_rules WHERE id = ?", [id]))[0].date, formatDateOnly(due));
  assert.equal((await rows("SELECT id FROM expense_categories WHERE user_id = ? AND name = 'Salary'", [f.user])).length, 1);
});

test('two distinct rules and a manual income with identical descriptions remain distinct', { skip: !enabled }, async () => {
  const f = await fixture('distinct', 30);
  const category = await insert("INSERT INTO expense_categories(user_id,name,icon) VALUES (?,'Salary','work')", [f.user]);
  const manual = await insert("INSERT INTO transactions(user_id,account_id,date,description,amount,type,category,category_id) VALUES (?,?,?,'Salary same description',30,'Income','Salary',?)", [f.user, f.account, today(), category]);
  await f.rule(); await f.rule();
  const result = await f.request('/api/salaries'); assert.equal(result.status, 200);
  const incomes = await rows('SELECT id,amount FROM transactions WHERE user_id = ? ORDER BY id', [f.user]);
  assert.equal(incomes.length, 3); assert.equal(incomes[0].id, manual);
  assert.equal(Number((await rows('SELECT balance FROM accounts WHERE id = ?', [f.account]))[0].balance), 90);
  await f.request('/api/accounts');
  assert.deepEqual(await rows('SELECT id,amount FROM transactions WHERE user_id = ? ORDER BY id', [f.user]), incomes);
});

test('failed cursor write rolls back income, account, history, investment and outbox; retry pays once', { skip: !enabled }, async () => {
  const f = await fixture('rollback', 100);
  const rule = await f.rule(25);
  const investment = await insert("INSERT INTO investments(user_id,name,principal,annual_rate,start_date,account_id) VALUES (?,'Salary rollback',100,0,?,?)", [f.user, today(), f.account]);
  const original = (await rows('SELECT * FROM salary_rules WHERE id = ?', [rule]))[0];
  const snapshot = async () => ({
    account: await rows('SELECT * FROM accounts WHERE id = ?', [f.account]),
    incomes: await rows('SELECT * FROM transactions WHERE user_id = ?', [f.user]),
    history: await rows('SELECT * FROM balance_history WHERE user_id = ?', [f.user]),
    contributions: await rows('SELECT * FROM investment_contributions WHERE investment_id = ?', [investment]),
    outbox: await rows('SELECT * FROM engagement_events WHERE user_id = ? ORDER BY id', [f.user]),
    categories: await rows('SELECT * FROM expense_categories WHERE user_id = ?', [f.user]),
  });
  const before = await snapshot();
  const trigger = `test_salary_rollback_${f.user}`;
  try {
    await db.query(`CREATE TRIGGER ${trigger} BEFORE UPDATE ON salary_rules FOR EACH ROW BEGIN
      IF OLD.id = ${rule} THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SALARY_TEST_ROLLBACK'; END IF; END`);
    assert.equal((await f.request('/api/salaries')).status, 500);
    assert.deepEqual(await snapshot(), before);
    assert.deepEqual((await rows('SELECT * FROM salary_rules WHERE id = ?', [rule]))[0], original);
  } finally { await db.query(`DROP TRIGGER IF EXISTS ${trigger}`); }
  assert.equal((await f.request('/api/salaries')).status, 200);
  assert.equal((await f.request('/api/salaries')).status, 200);
  assert.equal((await rows('SELECT id FROM transactions WHERE user_id = ?', [f.user])).length, 1);
  assert.equal(Number((await rows('SELECT balance FROM accounts WHERE id = ?', [f.account]))[0].balance), 125);
  assert.equal(Number((await rows('SELECT balance FROM balance_history WHERE user_id = ?', [f.user]))[0].balance), 125);
  const contributions = await rows('SELECT c.amount,c.transaction_id FROM investment_contributions c WHERE c.investment_id = ?', [investment]);
  assert.equal(contributions.length, 1); assert.equal(Number(contributions[0].amount), 25);
  assert.ok(contributions[0].transaction_id);
});

test('a balance-history error propagates and cannot consume a salary occurrence', { skip: !enabled }, async () => {
  const f = await fixture('history_failure');
  const rule = await f.rule();
  const trigger = `test_salary_history_${f.user}`;
  try {
    await db.query(`CREATE TRIGGER ${trigger} BEFORE INSERT ON balance_history FOR EACH ROW BEGIN
      IF NEW.user_id = ${f.user} THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SALARY_HISTORY_ROLLBACK'; END IF; END`);
    assert.equal((await f.request('/api/salaries')).status, 500);
    assert.equal((await rows('SELECT id FROM transactions WHERE user_id = ?', [f.user])).length, 0);
    assert.equal(Number((await rows('SELECT balance FROM accounts WHERE id = ?', [f.account]))[0].balance), 0);
    assert.equal((await rows("SELECT DATE_FORMAT(next_date,'%Y-%m-%d') AS date FROM salary_rules WHERE id = ?", [rule]))[0].date, today());
  } finally { await db.query(`DROP TRIGGER IF EXISTS ${trigger}`); }
});

test('creating a due rule and its initial income commit together or both roll back', { skip: !enabled }, async () => {
  const f = await fixture('creation_failure');
  const body = { name: 'Created salary', amount: 30, schedule: 'Weekly', weekday: new Date().getDay(), account_id: f.account };
  const trigger = `test_salary_creation_${f.user}`;
  try {
    await db.query(`CREATE TRIGGER ${trigger} BEFORE INSERT ON balance_history FOR EACH ROW BEGIN
      IF NEW.user_id = ${f.user} THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SALARY_CREATE_ROLLBACK'; END IF; END`);
    assert.equal((await f.request('/api/salaries', 'POST', body)).status, 500);
    assert.equal((await rows('SELECT id FROM salary_rules WHERE user_id = ?', [f.user])).length, 0);
    assert.equal((await rows('SELECT id FROM transactions WHERE user_id = ?', [f.user])).length, 0);
    assert.equal(Number((await rows('SELECT balance FROM accounts WHERE id = ?', [f.account]))[0].balance), 0);
  } finally { await db.query(`DROP TRIGGER IF EXISTS ${trigger}`); }
  const created = await f.request('/api/salaries', 'POST', body);
  assert.equal(created.status, 200);
  const next = new Date(); next.setDate(next.getDate() + 7);
  assert.equal(String(created.payload.next_date).slice(0, 10), formatDateOnly(next));
  assert.equal((await f.request('/api/salaries')).status, 200);
  assert.equal((await rows('SELECT id FROM salary_rules WHERE user_id = ?', [f.user])).length, 1);
  assert.equal((await rows('SELECT id FROM transactions WHERE user_id = ?', [f.user])).length, 1);
  assert.equal(Number((await rows('SELECT balance FROM accounts WHERE id = ?', [f.account]))[0].balance), 30);
});

test('48 occurrence cap preserves overdue cursor and later reads finish every remaining period', { skip: !enabled }, async () => {
  const f = await fixture('backlog');
  const first = new Date(); first.setDate(first.getDate() - 49 * 7);
  const rule = await f.rule(10, formatDateOnly(first)!);
  assert.equal((await f.request('/api/salaries')).status, 200);
  const middle = new Date(first); middle.setDate(middle.getDate() + 48 * 7);
  assert.equal((await rows('SELECT id FROM transactions WHERE user_id = ?', [f.user])).length, 48);
  assert.equal((await rows("SELECT DATE_FORMAT(next_date,'%Y-%m-%d') AS date FROM salary_rules WHERE id = ?", [rule]))[0].date, formatDateOnly(middle));
  assert.equal((await f.request('/api/salaries')).status, 200);
  assert.equal((await f.request('/api/salaries')).status, 200);
  const counts = (await rows('SELECT COUNT(*) AS total,COUNT(DISTINCT date) AS dates,SUM(amount) AS amount FROM transactions WHERE user_id = ?', [f.user]))[0];
  assert.equal(Number(counts.total), 50); assert.equal(Number(counts.dates), 50); assert.equal(Number(counts.amount), 500);
  assert.equal(Number((await rows('SELECT balance FROM accounts WHERE id = ?', [f.account]))[0].balance), 500);
});

test('month-end salary is included in its month history east of UTC', { skip: !enabled }, async () => {
  const previous = process.env.TZ;
  try {
    process.env.TZ = 'Asia/Jerusalem';
    const f = await fixture('month_end');
    const lastDay = new Date(new Date().getFullYear(), new Date().getMonth(), 0);
    const rule = await f.rule(30, formatDateOnly(lastDay)!);
    await db.query("UPDATE salary_rules SET schedule = 'Monthly', day = 31 WHERE id = ?", [rule]);
    assert.equal((await f.request('/api/salaries')).status, 200);
    const history = await rows('SELECT balance FROM balance_history WHERE user_id = ? AND year = ? AND month = ?', [f.user, lastDay.getFullYear(), lastDay.getMonth() + 1]);
    assert.equal(history.length, 1); assert.equal(Number(history[0].balance), 30);
    assert.equal((await rows('SELECT id FROM transactions WHERE user_id = ? AND date = ?', [f.user, formatDateOnly(lastDay)])).length, 1);
  } finally {
    if (previous === undefined) delete process.env.TZ; else process.env.TZ = previous;
  }
});

test('parallel rule edits and pause/reactivation retain the already-consumed cursor', { skip: !enabled }, async () => {
  const f = await fixture('edits');
  const rule = await f.rule();
  const results = await Promise.all([
    f.request('/api/accounts'), f.request(`/api/salaries/${rule}`, 'PUT', { name: 'Renamed salary' }, 1),
    f.request('/api/transactions'), f.request('/api/salaries', 'GET', undefined, 1),
  ]);
  assert.deepEqual(results.map(result => result.status), Array(4).fill(200));
  const original = (await rows("SELECT DATE_FORMAT(next_date,'%Y-%m-%d') AS date FROM salary_rules WHERE id = ?", [rule]))[0].date;
  assert.equal((await f.request(`/api/salaries/${rule}`, 'PUT', { is_active: false })).status, 200);
  assert.equal((await rows("SELECT DATE_FORMAT(next_date,'%Y-%m-%d') AS date FROM salary_rules WHERE id = ?", [rule]))[0].date, original);
  assert.equal((await f.request(`/api/salaries/${rule}`, 'PUT', { is_active: true })).status, 200);
  assert.equal((await f.request(`/api/salaries/${rule}`, 'PUT', { account_id: null })).status, 200);
  assert.equal((await f.request(`/api/salaries/${rule}`, 'PUT', { account_id: f.account })).status, 200);
  assert.equal((await rows('SELECT id FROM transactions WHERE user_id = ?', [f.user])).length, 1);
  assert.equal(Number((await rows('SELECT balance FROM accounts WHERE id = ?', [f.account]))[0].balance), 30);
});

test('salary mutations reject another owner account and legacy invalid ownership never pays', { skip: !enabled }, async () => {
  const owner = await fixture('owner'), other = await fixture('other');
  assert.equal((await owner.request('/api/salaries', 'POST', { name: 'Invalid account', amount: 30, schedule: 'Weekly', account_id: other.account })).status, 400);
  const rule = await owner.rule();
  assert.equal((await owner.request(`/api/salaries/${rule}`, 'PUT', { account_id: other.account })).status, 400);
  await db.query('UPDATE salary_rules SET account_id = ? WHERE id = ?', [other.account, rule]);
  assert.equal((await owner.request('/api/salaries')).status, 200);
  assert.equal((await rows('SELECT id FROM transactions WHERE user_id = ?', [owner.user])).length, 0);
  assert.equal(Number((await rows('SELECT balance FROM accounts WHERE id = ?', [other.account]))[0].balance), 0);
});
