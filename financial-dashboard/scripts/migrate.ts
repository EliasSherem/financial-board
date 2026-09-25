import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import mysql from 'mysql2/promise';

// Does not load .env: operators must explicitly supply an isolated database.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../database/migrations');
const files = (await fs.readdir(root)).filter(f => /^\d+.*\.sql$/.test(f)).sort();
const migrations = await Promise.all(files.map(async name => {
  const sql = await fs.readFile(path.join(root, name), 'utf8');
  const statements = sql.replace(/^--.*$/gm, '').split(/;\s*(?:\n|$)/).map(s => s.trim()).filter(Boolean);
  return { name, statements, checksum: createHash('sha256').update(sql).digest('hex') };
}));
if (!process.argv.includes('--apply')) {
  for (const migration of migrations) console.log(`${migration.name}: ${migration.statements.length} statements, SHA256 ${migration.checksum}`);
  console.log('DRY RUN. No database connection. Set isolated MYSQL_* and add --apply.');
} else {
  const host = process.env.MYSQL_HOST;
  const database = process.env.MYSQL_DATABASE;
  if (!['localhost', '127.0.0.1', '::1'].includes(host ?? '') || !database || !/_(test|local|staging)$/.test(database) || process.env.MYSQL_URL) {
    throw new Error('This local runner requires MYSQL_HOST loopback and MYSQL_DATABASE ending _test/_local/_staging, with MYSQL_URL unset.');
  }
  const conn = await mysql.createConnection({ host, port: Number(process.env.MYSQL_PORT ?? 3306), user: process.env.MYSQL_USER, password: process.env.MYSQL_PASSWORD, database, timezone: 'Z', multipleStatements: false });
  try {
    await conn.query("SET time_zone = '+00:00'");
    await conn.query('CREATE TABLE IF NOT EXISTS platform_migrations (name VARCHAR(160) PRIMARY KEY, checksum CHAR(64) NOT NULL, next_statement INT NOT NULL DEFAULT 0, completed_at DATETIME NULL) ENGINE=InnoDB');
    const [lock] = await conn.query("SELECT GET_LOCK('finsight-platform-migrations', 1) AS acquired");
    if (Number((lock as Array<{ acquired: number }>)[0].acquired) !== 1) throw new Error('Another migration is running');
    for (const migration of migrations) {
      await conn.query('INSERT IGNORE INTO platform_migrations (name,checksum) VALUES (?,?)', [migration.name, migration.checksum]);
      const [records] = await conn.query('SELECT * FROM platform_migrations WHERE name=?', [migration.name]);
      const record = (records as Array<{ checksum: string; next_statement: number }>)[0];
      if (record.checksum !== migration.checksum) throw new Error(`Checksum changed: ${migration.name}`);
      for (let i = record.next_statement; i < migration.statements.length; i++) {
        // DDL auto-commits in MySQL. Persist every step; investigate crash-between-step-and-record,
        // never silently ignore an ALTER/constraint error.
        await conn.query(migration.statements[i]);
        await conn.query('UPDATE platform_migrations SET next_statement=? WHERE name=?', [i + 1, migration.name]);
      }
      await conn.query('UPDATE platform_migrations SET completed_at=COALESCE(completed_at,UTC_TIMESTAMP()) WHERE name=?', [migration.name]);
      console.log(`${migration.name}: complete`);
    }
  } finally { await conn.query("SELECT RELEASE_LOCK('finsight-platform-migrations')").catch(() => {}); await conn.end(); }
}
