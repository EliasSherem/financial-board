import { db, pooledDb } from '../server/db.js';
import { assertPlatformSchema, describeDatabaseTarget, formatStartupFailure } from '../server/platform/startup.js';

// Same environment resolution as the server, SELECT-only. Never import boot or initializeDatabase.
console.log(describeDatabaseTarget());
try {
  await db.query('SELECT 1');
  await assertPlatformSchema();
  console.log('Server readiness: OK. Required migrations and platform tables are present; storage is InnoDB.');
  console.log('No schema, data or provider configuration was changed. This does not verify provider credentials or a complete schema checksum.');
} catch (error) {
  console.error(formatStartupFailure(error));
  process.exitCode = 1;
} finally {
  await pooledDb.end();
}
