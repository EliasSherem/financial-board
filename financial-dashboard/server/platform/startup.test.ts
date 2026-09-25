import test from 'node:test';
import assert from 'node:assert/strict';
import {
  assertPlatformSchema, describeDatabaseTarget, formatStartupFailure, reportStartupFailure,
  requiredMigrations, requiredPlatformTables, StartupReadinessError,
} from './startup.js';

function schema(options: { missing?: string; incomplete?: string; tableMissing?: string; engine?: string; error?: unknown } = {}) {
  const queries: string[] = [];
  return {
    queries,
    query: async (sql: string) => {
      queries.push(sql);
      assert.match(sql, /^SELECT /);
      if (options.error) throw options.error;
      if (sql.includes('FROM platform_migrations')) {
        return [requiredMigrations.filter(name => name !== options.missing).map(name => ({
          name, completed_at: name === options.incomplete ? null : new Date(),
        }))];
      }
      return [requiredPlatformTables.filter(name => name !== options.tableMissing).map(name => ({name, engine: options.engine ?? 'InnoDB'}))];
    },
  };
}
const development = { NODE_ENV: 'test' };

test('startup identifies an unmigrated database without echoing the driver message', async () => {
  const database = schema({error: {code: 'ER_NO_SUCH_TABLE', message: "Table 'private_database.platform_migrations' doesn't exist"}});
  await assert.rejects(assertPlatformSchema(database, development), error => {
    assert.ok(error instanceof StartupReadinessError);
    assert.equal(error.code, 'PLATFORM_MIGRATION_TRACKER_MISSING');
    assert.deepEqual(error.pendingMigrations, [...requiredMigrations]);
    assert.match(formatStartupFailure(error), /no platform_migrations table/);
    assert.doesNotMatch(formatStartupFailure(error), /private_database/);
    return true;
  });
  assert.equal(database.queries.length, 1);
});

test('startup rejects missing and incomplete migrations without checking or changing tables', async () => {
  const database = schema({missing: requiredMigrations[3], incomplete: requiredMigrations[7]});
  await assert.rejects(assertPlatformSchema(database, development), error => {
    assert.ok(error instanceof StartupReadinessError);
    assert.equal(error.code, 'PLATFORM_MIGRATIONS_REQUIRED');
    assert.deepEqual(error.pendingMigrations, [requiredMigrations[3], requiredMigrations[7]]);
    return true;
  });
  assert.equal(database.queries.length, 1);
});

test('completed migration records do not hide missing tables or non-transactional storage', async () => {
  await assert.rejects(assertPlatformSchema(schema({tableMissing: 'password_reset_tokens'}), development), /PLATFORM_SCHEMA_INCOMPLETE/);
  await assert.rejects(assertPlatformSchema(schema({engine: 'MyISAM'}), development), /TRANSACTIONAL_STORAGE_REQUIRED/);
  await assertPlatformSchema(schema(), development);
});

test('production secret validation precedes database reads; development remains compatible', async () => {
  const database = schema();
  await assert.rejects(assertPlatformSchema(database, {NODE_ENV: 'production', JWT_SECRET: 'secret'}), /JWT_SECRET_NOT_CONFIGURED/);
  assert.equal(database.queries.length, 0);
  await assertPlatformSchema(database, {NODE_ENV: 'production', JWT_SECRET: 'x'.repeat(32)});
});

test('database failures retain safe distinctions and never print arbitrary messages or codes', async () => {
  for (const code of ['ER_ACCESS_DENIED_ERROR', 'ER_TABLEACCESS_DENIED_ERROR', 'ECONNREFUSED', 'ENOTFOUND', 'ETIMEDOUT']) {
    const error = {code, message: 'sensitive-password/host/sql'};
    await assert.rejects(assertPlatformSchema(schema({error}), development), thrown => thrown === error);
    const text = formatStartupFailure(error);
    assert.ok(text.includes(`[${code}]`));
    assert.doesNotMatch(text, /sensitive-password/);
  }
  assert.doesNotMatch(formatStartupFailure({code: 'private-host', message: 'private-password'}), /private-/);
});

test('target summary follows URL precedence and explicit empty override without exposing connection values', () => {
  const env = {MYSQL_HOST: '127.0.0.1', MYSQL_URL: 'mysql://private-user:private-password@private-host/private-db'};
  const text = describeDatabaseTarget(env);
  assert.match(text, /remote; source: MYSQL_URL/);
  assert.doesNotMatch(text, /private-/);
  assert.match(describeDatabaseTarget({...env, MYSQL_URL: ''}), /local; source: MYSQL_\* variables/);
});

test('failed startup closes the pool so the process can exit, with sanitized cleanup errors', async () => {
  let ended = 0;
  const messages: string[] = [];
  await reportStartupFailure({code: 'ECONNREFUSED'}, {end: async () => {ended++;}}, message => messages.push(message));
  assert.equal(ended, 1);
  assert.match(messages[0], /ECONNREFUSED/);
  await reportStartupFailure(new Error('secret'), {end: async () => {throw new Error('secret');}}, message => messages.push(message));
  assert.doesNotMatch(messages.join('\n'), /secret/);
  assert.match(messages.at(-1)!, /cleanup failed/);
});
