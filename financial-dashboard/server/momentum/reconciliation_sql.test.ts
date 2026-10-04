import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import express from 'express';
import { db, pooledDb } from '../db.js';
import { generateToken } from '../auth.js';
import router from './routes.js';
import type { getMomentum } from './service.js';

const run = process.env.RUN_DB_TESTS === 'true';
const originalConnection = pooledDb.getConnection.bind(pooledDb);
let server: Server;
let base: string;
const users: number[] = [];
const rows = async (sql: string, values: unknown[] = []) =>
  (await db.query(sql, values))[0] as Record<string, unknown>[];
const insert = async (sql: string, values: unknown[]) =>
  Number(((await db.query(sql, values))[0] as { insertId: number }).insertId);

before(async () => {
  if (!run) return;
  assert.equal(process.env.NODE_ENV, 'test');
  assert.equal(process.env.MYSQL_HOST, '127.0.0.1');
  assert.match(process.env.MYSQL_DATABASE ?? '', /_test$/);
  assert.equal(process.env.MYSQL_URL, undefined);
  process.env.MOMENTUM_ENABLED = 'true';
  process.env.MOMENTUM_AI_CREDITS_ENABLED = 'false';
  process.env.MOMENTUM_AI_REWARDS_ENABLED = 'false';

  const [column] = await rows(`SELECT COLLATION_NAME AS collation_name FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='momentum_entities' AND COLUMN_NAME='canonical_key'`);
  // Exercise the actual MySQL coercion rules regardless of the local DB default.
  // Production uses 0900_ai_ci, while mysql2 normally connects with unicode_ci.
  const connectionCollation = column.collation_name === 'utf8mb4_unicode_ci'
    ? 'utf8mb4_0900_ai_ci' : 'utf8mb4_unicode_ci';
  assert.notEqual(connectionCollation, column.collation_name);
  pooledDb.getConnection = async () => {
    const conn = await originalConnection();
    try {
      await conn.query(`SET NAMES utf8mb4 COLLATE ${connectionCollation}`);
      return conn;
    } catch (error) { conn.release(); throw error; }
  };
  const app = express();
  app.use(express.json());
  app.use(router);
  server = await new Promise<Server>(resolve => {
    const listening = app.listen(0, '127.0.0.1', () => resolve(listening));
  });
  base = `http://127.0.0.1:${(server.address() as { port: number }).port}`;
});

after(async () => {
  if (!run) return;
  pooledDb.getConnection = originalConnection;
  try {
    for (const userId of users) await db.query('DELETE FROM users WHERE id=?', [userId]);
  } finally {
    if (server) await new Promise<void>(resolve => server.close(() => resolve()));
    await db.end();
  }
});

async function createUser() {
  const username = `reconcile_${randomUUID().slice(0, 8)}`;
  const userId = await insert("INSERT INTO users(username,email,password,credential_kind,timezone_name) VALUES (?,?,'unusable','local','UTC')", [username, `${username}@example.invalid`]);
  users.push(userId);
  return { userId, token: generateToken({ id: userId, username }) };
}

async function read(token: string) {
  const response = await fetch(`${base}/api/engagement/me`, { headers: { Authorization: `Bearer ${token}` } });
  assert.equal(response.status, 200, 'A financial-data reconciliation must not fail the Momentum endpoint');
  const state = await response.json() as Awaited<ReturnType<typeof getMomentum>>;
  assert.ok('lifetime_xp' in state);
  return state;
}

for (const receipts of [false, true]) {
  test(`SQL: HTTP reconciliation with mismatched collations and receipts=${receipts} preserves facts and rewards`, { skip: !run }, async () => {
    const { userId, token } = await createUser();
    const control = await createUser();
    const controlBefore = await read(control.token);
    const account = await insert("INSERT INTO accounts(user_id,name,type) VALUES (?,'Fixture','Checking')", [userId]);
    const category = await insert("INSERT INTO expense_categories(user_id,name) VALUES (?,'Fixture')", [userId]);
    const subcategory = await insert("INSERT INTO expense_subcategories(user_id,category_id,name) VALUES (?,?,'Fixture')", [userId, category]);
    await db.query(`INSERT INTO transactions(user_id,account_id,date,description,amount,type,category_id,subcategory_id)
      VALUES (?,?,UTC_DATE(),'First',-1,'Expense',?,?),(?,?,UTC_DATE(),'Second',-2,'Expense',?,?)`,
    [userId, account, category, subcategory, userId, account, category, subcategory]);
    const receiptKey = 'a'.repeat(64);
    if (receipts) await db.query("INSERT INTO transaction_drafts(user_id,status,image_sha256) VALUES (?,'confirmed',?),(?,'confirmed',?)", [userId, receiptKey, userId, receiptKey]);

    const first = await read(token);
    const expectedKeys = (await rows('SELECT momentum_identity FROM transactions WHERE user_id=? ORDER BY momentum_identity', [userId])).map(row => row.momentum_identity);
    assert.deepEqual((await rows("SELECT fact_key FROM momentum_facts WHERE user_id=? AND metric='categorized' ORDER BY fact_key", [userId])).map(row => row.fact_key), expectedKeys);
    assert.deepEqual((await rows("SELECT fact_key FROM momentum_facts WHERE user_id=? AND metric='used_subcategories'", [userId])).map(row => row.fact_key), [String(subcategory)]);
    assert.deepEqual((await rows("SELECT fact_key FROM momentum_facts WHERE user_id=? AND metric='receipts'", [userId])).map(row => row.fact_key), receipts ? [receiptKey] : []);

    const snapshot = async () => ({
      facts: await rows('SELECT * FROM momentum_facts WHERE user_id=? ORDER BY metric,fact_key', [userId]),
      rewards: await rows('SELECT * FROM reward_ledger WHERE user_id=? ORDER BY id', [userId]),
    });
    const before = await snapshot();
    const repeated = await Promise.all([read(token), read(token)]);
    assert.ok(repeated.every(state => state.lifetime_xp === first.lifetime_xp));
    assert.deepEqual(await snapshot(), before, 'Retries preserve fact timestamps and cannot duplicate XP');

    // Existing users can hit the same UNION later, after their initial backfill.
    const addedSubcategory = await insert("INSERT INTO expense_subcategories(user_id,category_id,name) VALUES (?,?,'Added later')", [userId, category]);
    await db.query(`INSERT INTO transactions(user_id,account_id,date,description,amount,type,category_id,subcategory_id)
      VALUES (?,?,UTC_DATE(),'Later transaction',-3,'Expense',?,?)`, [userId, account, category, addedSubcategory]);
    const updated = await read(token);
    assert.ok(updated.lifetime_xp >= first.lifetime_xp);
    const reconciled = await snapshot();
    assert.equal(reconciled.facts.filter(row => row.metric === 'categorized').length, 3);
    assert.equal(reconciled.facts.filter(row => row.metric === 'used_subcategories').length, 2);
    assert.equal(reconciled.facts.filter(row => row.metric === 'categorized' && row.provenance === 'reconciliation').length, 1);
    for (const reward of before.rewards) assert.deepEqual(reconciled.rewards.find(row => row.id === reward.id), reward);
    await read(token);
    assert.deepEqual(await snapshot(), reconciled);
    const controlAfter = await read(control.token);
    assert.equal(controlAfter.lifetime_xp, controlBefore.lifetime_xp);
    assert.deepEqual(await rows('SELECT * FROM momentum_facts WHERE user_id=?', [control.userId]), []);
  });
}
