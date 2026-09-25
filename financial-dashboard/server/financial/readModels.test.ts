import test from 'node:test';
import assert from 'node:assert/strict';
import type { Pool } from 'mysql2/promise';
import { ensureMissingBalanceHistory, missingHistoryPeriods } from './readModels.js';

test('history preserves current/future rows and fills only forward across year boundaries', () => {
  const periods = missingHistoryPeriods([
    { id: 1, last_period: 2024 * 12 + 10 },
    { id: 2, last_period: null },
    { id: 3, last_period: 2025 * 12 + 1 },
    { id: 4, last_period: 2026 * 12 },
  ], 2025, 2);
  assert.deepEqual(periods.map(({ accountId, year, month }) => [accountId, year, month]), [
    [1, 2024, 12], [1, 2025, 1], [1, 2025, 2], [2, 2025, 2],
  ]);
  assert.equal(missingHistoryPeriods([{ id: 5, last_period: null }], 2024, 2)[0].endDate,
    new Date(2024, 2, 0).toISOString().slice(0, 10));
});

test('history database round trips depend on bounded batches, not account count or months', async () => {
  const calls: Array<{ sql: string; values: unknown[] }> = [];
  const database = { query: async (sql: string, values: unknown[]) => {
    calls.push({ sql, values });
    return [calls.length === 1 ? Array.from({ length: 205 }, (_, index) => ({ id: index + 1, last_period: null })) : [], []];
  } } as unknown as Pick<Pool, 'query'>;
  await ensureMissingBalanceHistory(database, 42, 2025, 3);
  assert.equal(calls.length, 4); // One summary plus three batches; formerly 1 + 205 + 820.
  assert.deepEqual(calls[0].values, [42]);
  assert.deepEqual(calls.slice(1).map(call => (call.values.length - 2) / 4), [100, 100, 5]);
  for (const call of calls.slice(1)) {
    assert.equal(call.values[0], 42);
    assert.equal(call.values.at(-1), 42);
  }
});

test('history does not write when every account is already current', async () => {
  let queries = 0;
  const database = { query: async () => {
    queries++;
    return [[{ id: 1, last_period: 2025 * 12 + 2 }], []];
  } } as unknown as Pick<Pool, 'query'>;
  await ensureMissingBalanceHistory(database, 42, 2025, 3);
  assert.equal(queries, 1);
});
