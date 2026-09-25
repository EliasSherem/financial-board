import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { Server } from 'node:http';
import type { ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import express from 'express';
import { db } from '../db.js';
import { generateToken } from '../auth.js';
import router from '../routes.js';

const enabled = process.env.RUN_DB_TESTS === 'true';
const prefix = `push_${randomUUID().slice(0, 8)}`;
const users: number[] = [], tokens: string[] = [];
let server: Server | undefined, base = '';
before(async () => {
  if (!enabled) return;
  assert.equal(process.env.NODE_ENV, 'test');
  assert.equal(process.env.MYSQL_URL, undefined);
  assert.equal(process.env.MYSQL_HOST, '127.0.0.1');
  assert.match(process.env.MYSQL_DATABASE ?? '', /_test$/);
  for (const suffix of ['first', 'second']) {
    const username = `${prefix}_${suffix}`;
    const [row] = await db.query<ResultSetHeader>("INSERT INTO users (username,email,password,credential_kind) VALUES (?,?,'unusable','local')", [username, `${username}@example.invalid`]);
    users.push(row.insertId); tokens.push(generateToken({ id: row.insertId, username }));
  }
  const app = express(); app.use(express.json()); app.use(router);
  server = await new Promise(resolve => { const listener = app.listen(0, '127.0.0.1', () => resolve(listener)); });
  base = `http://127.0.0.1:${(server!.address() as { port: number }).port}`;
});
after(async () => {
  if (server) await new Promise<void>(resolve => server!.close(() => resolve()));
  if (enabled) for (const id of users) await db.query('DELETE FROM users WHERE id=?', [id]);
  await db.end();
});
const request = (user: number, token: unknown, path = '/api/device-tokens', extra = {}) => fetch(`${base}${path}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokens[user]}` },
  body: JSON.stringify({ token, platform: 'android', ...extra }),
});
const stored = async (token: string) => (await db.query<RowDataPacket[]>('SELECT user_id,token FROM device_tokens WHERE token=?', [token]))[0];

test('device registration handles concurrent accounts and logout cannot detach a new owner', { skip: !enabled }, async () => {
  const device = `${prefix}:shared`;
  const replies = await Promise.all(Array.from({ length: 8 }, (_, i) => request(i % 2, device)));
  for (const reply of replies) { assert.equal(reply.status, 200); await reply.json(); }
  assert.equal((await stored(device)).length, 1);
  assert.equal((await request(1, device)).status, 200);
  assert.equal((await request(0, device, '/api/device-tokens/unregister')).status, 200);
  assert.deepEqual((await stored(device)).map(row => row.user_id), [users[1]]);
  assert.equal((await request(1, device, '/api/device-tokens/unregister')).status, 200);
  assert.equal((await stored(device)).length, 0);
  assert.equal((await request(1, device, '/api/device-tokens/unregister')).status, 200);
});

test('device registration preserves complete tokens and their case and rejects malformed input', { skip: !enabled }, async () => {
  const device = `${prefix}:${'A'.repeat(600)}`;
  assert.equal((await request(0, device)).status, 200);
  assert.equal((await stored(device))[0].token, device);
  const lower = device.toLowerCase();
  assert.equal((await request(1, lower)).status, 200);
  assert.equal((await stored(device))[0].user_id, users[0]);
  assert.equal((await stored(lower))[0].user_id, users[1]);
  for (const invalid of ['', 'has space', 'x'.repeat(1025), 123, {}]) {
    assert.equal((await request(0, invalid)).status, 400);
  }
  assert.equal((await request(0, 'valid-device', '/api/device-tokens', { timezone_offset_min: 841 })).status, 400);
  assert.equal((await request(0, 'valid-device', '/api/device-tokens', { timezone_offset_min: 1.2 })).status, 400);
});

test('device registration rolls back ownership when profile update fails and releases the lock', { skip: !enabled }, async () => {
  const device = `${prefix}:rollback`;
  await request(0, device);
  const trigger = `${prefix}_rollback`;
  try {
    await db.query(`CREATE TRIGGER ${trigger} BEFORE UPDATE ON users FOR EACH ROW BEGIN IF OLD.id=${users[1]} THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='fixture'; END IF; END`);
    assert.equal((await request(1, device, '/api/device-tokens', { timezone_offset_min: 120 })).status, 503);
    assert.deepEqual((await stored(device)).map(row => row.user_id), [users[0]]);
  } finally { await db.query(`DROP TRIGGER IF EXISTS ${trigger}`); }
  assert.equal((await request(1, device)).status, 200);
  assert.deepEqual((await stored(device)).map(row => row.user_id), [users[1]]);
});

test('different devices of one account can register timezones concurrently', { skip: !enabled }, async () => {
  const trigger = `${prefix}_concurrent`;
  try {
    await db.query(`CREATE TRIGGER ${trigger} AFTER INSERT ON device_tokens FOR EACH ROW BEGIN IF NEW.user_id=${users[0]} THEN DO SLEEP(0.1); END IF; END`);
    const devices = [`${prefix}:concurrentA`, `${prefix}:concurrentB`];
    const responses = await Promise.all(devices.map((device, i) => request(0, device, '/api/device-tokens', { timezone_offset_min: 60 + i * 60 })));
    for (const response of responses) { assert.equal(response.status, 200); await response.json(); }
    for (const device of devices) assert.deepEqual((await stored(device)).map(row => row.user_id), [users[0]]);
    const [rows] = await db.query<RowDataPacket[]>('SELECT timezone_offset_min FROM users WHERE id=?', [users[0]]);
    assert.ok([60, 120].includes(Number(rows[0].timezone_offset_min)));
  } finally { await db.query(`DROP TRIGGER IF EXISTS ${trigger}`); }
});
