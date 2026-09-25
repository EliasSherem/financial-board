import type { Pool, RowDataPacket } from 'mysql2/promise';

type Reader = Pick<Pool, 'query'>;
type AccountPeriod = { id: number; last_period: number | null };
export type HistoryPeriod = { accountId: number; year: number; month: number; endDate: string };

/** Preserve the legacy rule: new accounts get the current month; existing history only grows forward. */
export function missingHistoryPeriods(accounts: AccountPeriod[], year: number, month: number): HistoryPeriod[] {
  const current = year * 12 + month - 1;
  const periods: HistoryPeriod[] = [];
  for (const account of accounts) {
    const first = account.last_period === null ? current : Number(account.last_period) + 1;
    for (let period = first; period <= current; period++) {
      const periodYear = Math.floor(period / 12);
      const periodMonth = period % 12 + 1;
      periods.push({
        accountId: Number(account.id), year: periodYear, month: periodMonth,
        // Same cutoff as the existing per-month writer, including the server's timezone.
        endDate: new Date(periodYear, periodMonth, 0).toISOString().slice(0, 10),
      });
    }
  }
  return periods;
}

/** Bounded batches remove account/month network fanout without changing existing history. */
export async function ensureMissingBalanceHistory(database: Reader, userId: number, year: number, month: number) {
  const [accounts] = await database.query<RowDataPacket[]>(
    `SELECT a.id, MAX(bh.year * 12 + bh.month - 1) AS last_period
       FROM accounts a
       LEFT JOIN balance_history bh ON bh.account_id = a.id AND bh.user_id = a.user_id
      WHERE a.user_id = ? GROUP BY a.id`, [userId],
  );
  const periods = missingHistoryPeriods(accounts as (RowDataPacket & AccountPeriod)[], year, month);
  for (let offset = 0; offset < periods.length; offset += 100) {
    const batch = periods.slice(offset, offset + 100);
    const values = batch.flatMap(period => [period.accountId, period.year, period.month, period.endDate]);
    const placeholders = batch.map(() => 'SELECT ? AS account_id, ? AS year, ? AS month, CAST(? AS DATE) AS end_date').join(' UNION ALL ');
    await database.query(
      `INSERT INTO balance_history (user_id, account_id, year, month, balance)
       SELECT ?, a.id, requested.year, requested.month, a.balance - COALESCE(SUM(t.amount), 0)
         FROM (${placeholders}) requested
         JOIN accounts a ON a.id = requested.account_id AND a.user_id = ?
         LEFT JOIN transactions t ON t.account_id = a.id AND t.user_id = a.user_id AND t.date > requested.end_date
        GROUP BY a.id, requested.year, requested.month, a.balance
       ON DUPLICATE KEY UPDATE balance = balance_history.balance`,
      [userId, ...values, userId],
    );
  }
}

// Both sums share one owner-scoped grouped scan instead of correlated scans per output column.
const CONTRIBUTION_TOTALS = `
  SELECT c.investment_id, SUM(c.amount) AS total_contributions,
         SUM(c.amount * POW(1 + (owned.annual_rate / 100) / 365,
             GREATEST(DATEDIFF(CURDATE(), c.date), 0))) AS contribution_value
    FROM investment_contributions c
    JOIN investments owned ON owned.id = c.investment_id AND owned.user_id = c.user_id
   WHERE owned.user_id = ?
   GROUP BY c.investment_id`;

const ESTIMATED_VALUE = `(i.principal * POW(1 + (i.annual_rate / 100) / 365,
  GREATEST(DATEDIFF(CURDATE(), i.start_date), 0))) + COALESCE(totals.contribution_value, 0)`;

export const ACCOUNTS_READ_SQL = `
  SELECT a.id, a.user_id, a.name, a.type, a.account_number, a.bank_name, a.is_active,
         a.balance AS raw_balance,
         CASE WHEN i.id IS NULL THEN a.balance ELSE ${ESTIMATED_VALUE} END AS balance,
         i.id AS investment_id, i.principal AS investment_principal,
         i.annual_rate AS investment_annual_rate,
         COALESCE(totals.total_contributions, 0) AS investment_total_contributions,
         CASE WHEN i.id IS NULL THEN NULL ELSE ${ESTIMATED_VALUE} END AS investment_estimated_value,
         i.start_date AS investment_start_date
    FROM accounts a
    LEFT JOIN investments i ON i.account_id = a.id AND i.user_id = a.user_id
    LEFT JOIN (${CONTRIBUTION_TOTALS}) totals ON totals.investment_id = i.id
   WHERE a.user_id = ? ORDER BY a.id DESC`;

export const INVESTMENTS_READ_SQL = `
  SELECT i.id, i.name, i.principal, i.annual_rate, i.start_date, i.account_id,
         COALESCE(totals.total_contributions, 0) AS total_contributions,
         ${ESTIMATED_VALUE} AS estimated_value
    FROM investments i
    LEFT JOIN (${CONTRIBUTION_TOTALS}) totals ON totals.investment_id = i.id
   WHERE i.user_id = ? ORDER BY i.created_at DESC`;
