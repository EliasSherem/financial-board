import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { db } from '../db.js';
import { readEntitlement, refreshEntitlement } from './repository.js';
import { effectiveAccess } from './types.js';

const enabled = process.env.RUN_DB_TESTS === 'true';
if (enabled) {
  assert.equal(process.env.NODE_ENV, 'test');
  assert.equal(process.env.MYSQL_URL, undefined);
  assert.equal(process.env.MYSQL_HOST, '127.0.0.1');
  assert.match(process.env.MYSQL_DATABASE ?? '', /_test$/);
}
after(() => db.end());

test('SQL: read-only access matches verified contracts, expiry, replacement, grants and the bounded legacy bridge', { skip: !enabled }, async () => {
  const prefix = `access_perf_${randomUUID().slice(0, 8)}`;
  const [user]: any = await db.query('INSERT INTO users(username,email,password) VALUES (?,?,?)', [prefix, `${prefix}@example.invalid`, 'not-a-login-hash']);
  const id = Number(user.insertId);
  try {
    const [insert]: any = await db.query(`INSERT INTO billing_contracts
      (user_id,provider,contract_key,product_id,raw_state,status,verified,environment)
      VALUES (?,'stripe',?,'fixture','fixture','expired',1,'test')`, [id, prefix]);
    const contractId = Number(insert.insertId);
    const future = new Date(Date.now() + 86400000), past = new Date(Date.now() - 86400000);
    for (const status of ['pending','trial','active','cancel_at_period_end','grace','hold','paused','expired','revoked','refunded','unknown','legacy']) {
      for (const verified of [0, 1]) for (const accessUntil of [past, future, null]) {
        await db.query('UPDATE users SET is_pro=0 WHERE id=?', [id]);
        await db.query('UPDATE billing_contracts SET status=?,verified=?,access_until=?,replaced_by_id=NULL WHERE id=?', [status, verified, accessUntil, contractId]);
        const expected = effectiveAccess({ status, verified, accessUntil });
        assert.equal(await readEntitlement(id), expected, `${status}, verified=${verified}, expiry=${accessUntil}`);
        const [unchanged]: any = await db.query('SELECT is_pro FROM users WHERE id=?', [id]);
        assert.equal(Number(unchanged[0].is_pro), 0, 'authorization reads must not materialize access');
        assert.equal(await refreshEntitlement(id), expected);
      }
    }
    await db.query("UPDATE billing_contracts SET status='active',verified=1,access_until=?,replaced_by_id=id WHERE id=?", [future, contractId]);
    assert.equal(await readEntitlement(id), false, 'replaced contracts do not grant access');
    await db.query("INSERT INTO billing_grants(user_id,source,expires_at) VALUES (?,'performance_fixture',?)", [id, future]);
    assert.equal(await readEntitlement(id), true, 'a separate current grant still grants access');
    await db.query('UPDATE billing_grants SET expires_at=? WHERE user_id=?', [past, id]);
    assert.equal(await readEntitlement(id), false, 'expired grants do not grant access');
    await db.query('UPDATE billing_grants SET expires_at=NULL WHERE user_id=?', [id]);
    assert.equal(await readEntitlement(id), true, 'unbounded explicit grants remain valid');
    await db.query('DELETE FROM billing_grants WHERE user_id=?', [id]);
    for (const age of [10, 40]) for (const wasPro of [0, 1]) {
      await db.query('UPDATE users SET is_pro=? WHERE id=?', [wasPro, id]);
      await db.query("UPDATE billing_contracts SET status='legacy',verified=0,replaced_by_id=NULL,created_at=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL ? DAY) WHERE id=?", [age, contractId]);
      const expected = wasPro === 1 && age < 30;
      assert.equal(await readEntitlement(id), expected);
      assert.equal(await refreshEntitlement(id), expected);
    }
    assert.equal(await readEntitlement(-1), false);

    // A financial read must not queue behind Momentum's exclusive user lock.
    const connection = await db.getConnection();
    let timeout: ReturnType<typeof setTimeout> | undefined;
    try {
      await connection.beginTransaction();
      await connection.query('SELECT id FROM users WHERE id=? FOR UPDATE', [id]);
      const value = await Promise.race([
        readEntitlement(id),
        new Promise<never>((_, reject) => { timeout = setTimeout(() => reject(new Error('Authorization read waited for the user lock')), 2000); }),
      ]);
      assert.equal(value, false);
    } finally {
      clearTimeout(timeout);
      await connection.rollback();
      connection.release();
    }
  } finally {
    await db.query('DELETE FROM users WHERE id=?', [id]);
  }
});
