import { AsyncLocalStorage } from 'node:async_hooks';
import type { RequestHandler } from 'express';
import type { Pool, PoolConnection } from 'mysql2/promise';

type Scope = { connection?: PoolConnection; closed?: boolean; beginning?: boolean };

/** Keep legacy transaction statements AND their helper calls on one connection. */
export function createScopedDatabase(pool: Pool) {
  const contexts = new AsyncLocalStorage<Scope>();
  const release = async (scope: Scope, commit = false) => {
    const conn = scope.connection;
    if (!conn) return;
    scope.connection = undefined;
    try { if (commit) { try { await conn.commit(); } catch (error) { await conn.rollback().catch(() => {}); throw error; } } else await conn.rollback(); }
    finally { conn.release(); }
  };
  const database = new Proxy(pool, {
    get(target, key) {
      if (key !== 'query' && key !== 'execute') {
        const value = Reflect.get(target, key);
        return typeof value === 'function' ? value.bind(target) : value;
      }
      return async (...args: unknown[]) => {
        const scope = contexts.getStore();
        if (scope?.closed) throw new Error('Database request scope is closed');
        const sql = typeof args[0] === 'string' ? args[0].trim().replace(/;$/, '').toUpperCase() : '';
        if (sql === 'START TRANSACTION' || sql === 'BEGIN') {
          if (!scope) throw new Error('Transaction requires a database scope');
          if (scope.connection || scope.beginning) throw new Error('Nested transaction is not supported');
          scope.beginning = true;
          let conn: PoolConnection | undefined;
          try {
            conn = await pool.getConnection();
            if (scope.closed) throw new Error('Database request scope is closed');
            await conn.beginTransaction();
            if (scope.closed) { await conn.rollback(); throw new Error('Database request scope is closed'); }
            scope.connection = conn;
          } catch (error) { conn?.release(); throw error; }
          finally { scope.beginning = false; }
          return [[], []];
        }
        if (sql === 'COMMIT' || sql === 'ROLLBACK') {
          if (!scope) throw new Error('Transaction requires a database scope');
          await release(scope, sql === 'COMMIT');
          return [[], []];
        }
        const executor = scope?.connection ?? pool;
        return Reflect.apply(executor[key], executor, args);
      };
    },
  });
  const middleware: RequestHandler = (_req, res, next) => {
    const scope: Scope = {};
    const cleanup = () => { scope.closed = true; void release(scope).catch(() => console.error('database_scope_cleanup_failed')); };
    res.once('finish', cleanup);
    res.once('close', cleanup);
    contexts.run(scope, next);
  };
  async function transaction<T>(work: (conn: PoolConnection) => Promise<T>): Promise<T> {
    const active = contexts.getStore()?.connection;
    if (active) return work(active);
    const scope: Scope = {};
    return contexts.run(scope, async () => {
      const conn = await pool.getConnection();
      scope.connection = conn;
      try {
        await conn.beginTransaction();
        const value = await work(conn);
        await release(scope, true);
        return value;
      } catch (error) { await release(scope); throw error; }
    });
  }
  return { database, middleware, transaction };
}
