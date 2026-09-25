import { db } from '../db.js';

export const requiredMigrations = [
  '000_legacy_baseline.sql', '001_platform.sql', '002_billing.sql',
  '003_recovery.sql', '004_domain_outbox.sql', '005_financial_identity.sql',
  '006_analytics.sql', '007_momentum_preferences.sql', '008_recovery_email_index.sql',
  '009_billing_identity_collation.sql',
  '010_notification_delivery.sql',
] as const;

export const requiredPlatformTables = [
  'users', 'platform_rate_limits', 'platform_settings', 'admin_roles', 'admin_audit',
  'analytics_events', 'analytics_sessions', 'analytics_user_settings', 'engagement_events',
  'user_momentum', 'momentum_periods', 'user_missions', 'mission_replacements',
  'user_achievement_progress', 'reward_ledger', 'momentum_entities', 'momentum_facts',
  'momentum_review_snapshots', 'weekly_reviews', 'monthly_reviews',
  'ai_credit_ledger', 'ai_credit_reservations', 'billing_contracts', 'billing_grants',
  'billing_purchase_tokens', 'billing_inbox', 'billing_jobs', 'billing_charges',
  'billing_state_events', 'password_reset_tokens', 'auth_rate_limits', 'auth_security_audit',
  'notification_deliveries',
] as const;

type ReadinessCode = 'JWT_SECRET_NOT_CONFIGURED' | 'PLATFORM_MIGRATION_TRACKER_MISSING'
  | 'PLATFORM_MIGRATIONS_REQUIRED' | 'PLATFORM_SCHEMA_INCOMPLETE' | 'TRANSACTIONAL_STORAGE_REQUIRED';

export class StartupReadinessError extends Error {
  constructor(readonly code: ReadinessCode, readonly pendingMigrations: string[] = []) {
    super(code);
    this.name = 'StartupReadinessError';
  }
}

type ReadOnlyDatabase = { query(sql: string): Promise<unknown> };
function databaseCode(error: unknown): string {
  return error && typeof error === 'object' && 'code' in error ? String(error.code) : '';
}

/** SELECT-only readiness. Never bootstrap, seed or mark a migration complete here. */
export async function assertPlatformSchema(database: ReadOnlyDatabase = db, environment = process.env) {
  if (environment.NODE_ENV === 'production' &&
      (!environment.JWT_SECRET || environment.JWT_SECRET === 'secret' || environment.JWT_SECRET.length < 32)) {
    throw new StartupReadinessError('JWT_SECRET_NOT_CONFIGURED');
  }
  let migrations: { name: string; completed_at: unknown }[];
  try {
    [migrations] = await database.query('SELECT name, completed_at FROM platform_migrations') as [typeof migrations];
  } catch (error) {
    if (databaseCode(error) === 'ER_NO_SUCH_TABLE') {
      throw new StartupReadinessError('PLATFORM_MIGRATION_TRACKER_MISSING', [...requiredMigrations]);
    }
    throw error;
  }
  const installed = new Set(migrations.filter(row => row.completed_at != null).map(row => row.name));
  const pending = requiredMigrations.filter(name => !installed.has(name));
  if (pending.length) throw new StartupReadinessError('PLATFORM_MIGRATIONS_REQUIRED', pending);

  const [tables] = await database.query(
    "SELECT TABLE_NAME AS name, ENGINE AS engine FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE'"
  ) as [{ name: string; engine: string }[]];
  const names = new Set(tables.map(row => row.name));
  if (requiredPlatformTables.some(name => !names.has(name))) {
    throw new StartupReadinessError('PLATFORM_SCHEMA_INCOMPLETE');
  }
  if (tables.some(row => row.engine !== 'InnoDB')) {
    throw new StartupReadinessError('TRANSACTIONAL_STORAGE_REQUIRED');
  }
}

/** Deliberately excludes raw driver messages, SQL, hosts, usernames and credentials. */
export function formatStartupFailure(error: unknown): string {
  if (error instanceof StartupReadinessError) {
    const descriptions: Record<ReadinessCode, string> = {
      JWT_SECRET_NOT_CONFIGURED: 'Production requires JWT_SECRET with at least 32 characters.',
      PLATFORM_MIGRATION_TRACKER_MISSING: 'The configured database has no platform_migrations table. The platform migrations have not been installed on this database.',
      PLATFORM_MIGRATIONS_REQUIRED: 'Required migrations are missing or incomplete on the configured database.',
      PLATFORM_SCHEMA_INCOMPLETE: 'Migration records are complete but required tables are missing. Review the schema before restarting.',
      TRANSACTIONAL_STORAGE_REQUIRED: 'The configured database contains non-InnoDB tables. Transactional storage is required.',
    };
    const pending = requiredMigrations.filter(name => error.pendingMigrations.includes(name));
    return `Startup blocked [${error.code}]: ${descriptions[error.code]}` +
      (pending.length ? `\nPending: ${pending.join(', ')}` : '') +
      '\nRun npm run doctor:server for read-only checks. See docs/implementation/finsight-platform-upgrade.md; no migrations run automatically.';
  }
  const code = databaseCode(error);
  const known: Record<string, string> = {
    ER_ACCESS_DENIED_ERROR: 'MySQL rejected the configured credentials.',
    ER_DBACCESS_DENIED_ERROR: 'The configured identity cannot access this database.',
    ER_TABLEACCESS_DENIED_ERROR: 'The configured identity cannot read the required schema metadata.',
    ER_BAD_DB_ERROR: 'The configured database does not exist.',
    ER_NO_DB_ERROR: 'No database is selected. Check MYSQL_DATABASE or the path in MYSQL_URL.',
    ER_NO_SUCH_TABLE: 'A required schema table is missing.',
    ER_BAD_FIELD_ERROR: 'Required schema columns are missing or incompatible.',
    ECONNREFUSED: 'MySQL refused the connection. Check that the intended database is running.',
    ENOTFOUND: 'The configured database hostname could not be resolved.',
    EAI_AGAIN: 'Database DNS resolution is temporarily unavailable.',
    ETIMEDOUT: 'The database connection timed out.',
    PROTOCOL_CONNECTION_LOST: 'The database connection closed during readiness checks.',
    HANDSHAKE_SSL_ERROR: 'The database TLS handshake failed. Check the configured CA and TLS settings.',
    CERT_HAS_EXPIRED: 'The database TLS certificate has expired.',
    DEPTH_ZERO_SELF_SIGNED_CERT: 'The database TLS certificate is not trusted. Configure the correct CA.',
    UNABLE_TO_VERIFY_LEAF_SIGNATURE: 'The database TLS certificate chain could not be verified.',
  };
  return known[code]
    ? `Startup blocked [${code}]: ${known[code]}\nRun npm run doctor:server for read-only checks.`
    : 'Startup blocked [UNEXPECTED_STARTUP_ERROR]: Initialization failed. Raw error details were omitted to protect credentials. Run npm run doctor:server.';
}

export function describeDatabaseTarget(environment = process.env): string {
  let host = environment.MYSQL_HOST;
  if (environment.MYSQL_URL) {
    try { host = new URL(environment.MYSQL_URL).hostname || host; }
    catch { return 'Database configuration: invalid MYSQL_URL; runtime falls back to MYSQL_* variables.'; }
  }
  const kind = !host ? 'unspecified' : ['localhost', '127.0.0.1', '::1', '[::1]'].includes(host) ? 'local' : 'remote';
  return `Database target: ${kind}; source: ${environment.MYSQL_URL ? 'MYSQL_URL (overrides MYSQL_*)' : 'MYSQL_* variables'}. Connection values are hidden.`;
}

export async function reportStartupFailure(
  error: unknown,
  pool: { end(): Promise<unknown> },
  report: (message: string) => void = console.error,
) {
  report(formatStartupFailure(error));
  try { await pool.end(); }
  catch { report('Database pool cleanup failed; connection details omitted.'); }
}
