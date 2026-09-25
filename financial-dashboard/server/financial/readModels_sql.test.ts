import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import type { ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import express from 'express';
import { db } from '../db.js';
import { generateToken } from '../auth.js';
import router from '../routes.js';
import { ACCOUNTS_READ_SQL, INVESTMENTS_READ_SQL, ensureMissingBalanceHistory } from './readModels.js';

const enabled = process.env.RUN_DB_TESTS === 'true';
const prefix = `financial_read_${randomUUID().slice(0, 8)}`;
const users: number[] = [];
let user = 0, other = 0;
let server: Server | undefined;
let base = '', token = '';
if (enabled) {
  assert.equal(process.env.NODE_ENV, 'test');
  assert.equal(process.env.MYSQL_URL, undefined);
  assert.equal(process.env.MYSQL_HOST, '127.0.0.1');
  assert.match(process.env.MYSQL_DATABASE ?? '', /_test$/);
}
const rows = async (sql: string, values: unknown[] = []) => (await db.query<RowDataPacket[]>(sql, values))[0];
const insert = async (sql: string, values: unknown[]) => (await db.query<ResultSetHeader>(sql, values))[0].insertId;
const account = (owner: number, name: string, balance: number) => insert(
  "INSERT INTO accounts (user_id,name,type,balance) VALUES (?,?,'Checking',?)", [owner, name, balance],
);
before(async () => {
  if (!enabled) return;
  process.env.LEGACY_SCHEMA_BOOTSTRAP = 'false';
  for (const suffix of ['owner', 'other']) {
    const username = `${prefix}_${suffix}`;
    const id = await insert("INSERT INTO users (username,email,password,credential_kind) VALUES (?,?,'unusable','local')", [username, `${username}@example.invalid`]);
    users.push(id);
    await db.query("INSERT INTO billing_grants(user_id,source,expires_at) VALUES (?,'test_manual',DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY))", [id]);
    if (suffix === 'owner') { user = id; token = generateToken({ id, username }); } else other = id;
  }
  const app = express();
  app.use(express.json()); app.use(router);
  server = await new Promise(resolve => { const listener = app.listen(0, '127.0.0.1', () => resolve(listener)); });
  base = `http://127.0.0.1:${(server!.address() as { port: number }).port}`;
});
after(async () => {
  if (server) await new Promise<void>(resolve => server!.close(() => resolve()));
  if (enabled) for (const id of users) {
    await db.query('DELETE FROM salary_rules WHERE user_id=?', [id]);
    await db.query('DELETE FROM users WHERE id=?', [id]);
  }
  await db.end();
});

test('batch history equals legacy decimal sums and preserves existing months and other owners', { skip: !enabled }, async () => {
  const existing = await account(user, 'History existing', 1000.55);
  const empty = await account(user, 'History empty', 25.12);
  const current = await account(user, 'History current', 300);
  const foreign = await account(other, 'Other history', 450);
  await db.query('INSERT INTO balance_history(user_id,account_id,year,month,balance) VALUES (?,?,2024,12,999),(?,?,2025,3,123),(?,?,2025,1,450)', [user, existing, user, current, other, foreign]);
  for (const [date, amount] of [['2024-12-01', 100.10], ['2025-01-15', -20.05], ['2025-01-31', -0.01], ['2025-02-15', 35], ['2025-03-31', -15.25], ['2027-01-01', 44.44]] as const) {
    await db.query("INSERT INTO transactions(user_id,account_id,date,description,amount,type,category) VALUES (?,?,?,'History fixture',?,'Income','Fixture')", [user, existing, date, amount]);
  }
  // Legacy schemas permit inconsistent owner references; another user's row must not affect this owner.
  await db.query("INSERT INTO transactions(user_id,account_id,date,description,amount,type,category) VALUES (?,?,'2027-01-01','Foreign fixture',99999,'Income','Fixture')", [other, existing]);
  const preserved = await rows('SELECT id,user_id,account_id,year,month,balance FROM balance_history WHERE user_id IN (?,?) ORDER BY id', [user, other]);
  await ensureMissingBalanceHistory(db, user, 2025, 3);
  const history = await rows('SELECT id,user_id,account_id,year,month,balance FROM balance_history WHERE user_id IN (?,?) ORDER BY id', [user, other]);
  for (const row of preserved) assert.deepEqual(history.find(candidate => candidate.id === row.id), row);
  const added = history.filter(row => !preserved.some(old => old.id === row.id));
  assert.equal(added.length, 4);
  assert.deepEqual(added.filter(row => row.account_id === empty).map(row => [row.year, row.month, Number(row.balance)]), [[2025, 3, 25.12]]);
  for (const month of [1, 2, 3]) {
    const cutoff = new Date(2025, month, 0).toISOString().slice(0, 10);
    const expected = (await rows(`SELECT a.balance
      - COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.account_id=a.id AND t.user_id=a.user_id),0)
      + COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.account_id=a.id AND t.user_id=a.user_id AND t.date<=?),0) AS balance
      FROM accounts a WHERE a.id=? AND a.user_id=?`, [cutoff, existing, user]))[0];
    assert.equal(Number(added.find(row => row.account_id === existing && row.month === month)!.balance), Number(expected.balance));
  }
  await ensureMissingBalanceHistory(db, user, 2025, 3);
  assert.deepEqual(await rows('SELECT id,user_id,account_id,year,month,balance FROM balance_history WHERE user_id IN (?,?) ORDER BY id', [user, other]), history);
});

test('one grouped contribution scan preserves account and investment totals, empty values and owner isolation', { skip: !enabled }, async () => {
  const linked = await account(user, 'Investment linked', 175);
  const noContributions = await account(user, 'Investment empty', 50);
  const foreignAccount = await account(other, 'Foreign investment', 9000);
  const invested = await insert("INSERT INTO investments(user_id,name,principal,annual_rate,start_date,account_id) VALUES (?,'Grouped investment',100,10,'2025-01-01',?)", [user, linked]);
  const emptyInvestment = await insert("INSERT INTO investments(user_id,name,principal,annual_rate,start_date,account_id) VALUES (?,'Empty investment',50,0,'2025-01-01',?)", [user, noContributions]);
  const foreignInvestment = await insert("INSERT INTO investments(user_id,name,principal,annual_rate,start_date,account_id) VALUES (?,'Foreign investment',9000,8,'2025-01-01',?)", [other, foreignAccount]);
  for (const [amount, date] of [[25, '2025-02-01'], [-3, '2025-03-01'], [40, '2099-01-01']] as const) {
    await db.query('INSERT INTO investment_contributions(user_id,investment_id,amount,date) VALUES (?,?,?,?)', [user, invested, amount, date]);
  }
  await db.query("INSERT INTO investment_contributions(user_id,investment_id,amount,date) VALUES (?,?,999999,'2025-01-01')", [other, invested]);
  const expected = (await rows(`SELECT
    COALESCE((SELECT SUM(c.amount) FROM investment_contributions c WHERE c.investment_id=i.id AND c.user_id=i.user_id),0) AS total,
    i.principal*POW(1+(i.annual_rate/100)/365,GREATEST(DATEDIFF(CURDATE(),i.start_date),0))
    + COALESCE((SELECT SUM(c.amount*POW(1+(i.annual_rate/100)/365,GREATEST(DATEDIFF(CURDATE(),c.date),0))) FROM investment_contributions c WHERE c.investment_id=i.id AND c.user_id=i.user_id),0) AS estimated
    FROM investments i WHERE i.id=? AND i.user_id=?`, [invested, user]))[0];
  const investments = await rows(INVESTMENTS_READ_SQL, [user, user]);
  const accounts = await rows(ACCOUNTS_READ_SQL, [user, user]);
  assert.equal(investments.some(row => row.id === foreignInvestment), false);
  assert.equal(accounts.some(row => row.id === foreignAccount), false);
  const result = investments.find(row => row.id === invested)!;
  const resultAccount = accounts.find(row => row.id === linked)!;
  assert.equal(Number(result.total_contributions), 62);
  assert.equal(Number(result.total_contributions), Number(expected.total));
  assert.ok(Math.abs(Number(result.estimated_value) - Number(expected.estimated)) < 1e-8);
  assert.equal(resultAccount.investment_estimated_value, result.estimated_value);
  assert.equal(resultAccount.balance, result.estimated_value);
  assert.equal(Number(resultAccount.raw_balance), 175);
  assert.equal(Number(resultAccount.investment_total_contributions), 62);
  assert.equal(Number(investments.find(row => row.id === emptyInvestment)!.estimated_value), 50);
  assert.equal(Number(investments.find(row => row.id === emptyInvestment)!.total_contributions), 0);
  const ordinary = accounts.find(row => row.investment_id === null)!;
  assert.equal(Number(ordinary.balance), Number(ordinary.raw_balance));
  assert.equal(ordinary.investment_estimated_value, null);
});

test('financial GET skips future salary writes but processes due rules once across subsequent reads', { skip: !enabled }, async () => {
  const salaryAccount = await account(user, 'Salary performance fixture', 0);
  const future = await insert("INSERT INTO salary_rules(user_id,name,amount,schedule,weekday,account_id,next_date,updated_at) VALUES (?,'Future salary',30,'Weekly',1,?,'2099-01-01','2020-01-01')", [user, salaryAccount]);
  const desiredDay = new Date().getDate() === 1 ? 2 : 1;
  const unscheduled = await insert("INSERT INTO salary_rules(user_id,name,amount,schedule,day,account_id,next_date) VALUES (?,'Unscheduled salary',20,'Monthly',?,?,NULL)", [user, desiredDay, salaryAccount]);
  const beforeRule = (await rows('SELECT * FROM salary_rules WHERE id=?', [future]))[0];
  const trigger = `test_future_salary_${user}`;
  try {
    await db.query(`CREATE TRIGGER ${trigger} BEFORE UPDATE ON salary_rules FOR EACH ROW
      BEGIN IF OLD.id=${future} THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='FUTURE_SALARY_UPDATE_FORBIDDEN'; END IF; END`);
    let initializedRule: RowDataPacket | undefined;
    for (const path of ['/api/accounts', '/api/transactions']) {
      const response = await fetch(`${base}${path}`, { headers: { Authorization: `Bearer ${token}` } });
      assert.equal(response.status, 200);
      await response.json();
      const state = (await rows('SELECT * FROM salary_rules WHERE id=?', [unscheduled]))[0];
      assert.ok(state.next_date);
      if (initializedRule) assert.deepEqual(state, initializedRule);
      initializedRule = state;
    }
  } finally {
    await db.query(`DROP TRIGGER IF EXISTS ${trigger}`);
  }
  assert.deepEqual((await rows('SELECT * FROM salary_rules WHERE id=?', [future]))[0], beforeRule);
  assert.equal((await rows("SELECT id FROM expense_categories WHERE user_id=? AND name='Salary'", [user])).length, 0);
  assert.equal((await rows('SELECT id FROM transactions WHERE user_id=? AND account_id=?', [user, salaryAccount])).length, 0);
  const now = new Date();
  const today = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
  await insert("INSERT INTO salary_rules(user_id,name,amount,schedule,weekday,account_id,next_date) VALUES (?,'Due salary',30,'Weekly',1,?,?)", [user, salaryAccount, today]);
  for (const path of ['/api/accounts', '/api/transactions', '/api/accounts']) {
    const response = await fetch(`${base}${path}`, { headers: { Authorization: `Bearer ${token}` } });
    assert.equal(response.status, 200); await response.json();
  }
  const txs = await rows('SELECT amount,type FROM transactions WHERE user_id=? AND account_id=?', [user, salaryAccount]);
  assert.equal(txs.length, 1);
  assert.equal(Number(txs[0].amount), 30);
  assert.equal(txs[0].type, 'Income');
  assert.equal(Number((await rows('SELECT balance FROM accounts WHERE id=?', [salaryAccount]))[0].balance), 30);
});
