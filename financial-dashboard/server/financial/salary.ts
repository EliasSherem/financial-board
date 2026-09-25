import type { PoolConnection, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { db, withTransaction } from '../db.js';
import { computeFirstSalaryDate, computeNextSalaryDate, formatDateOnly, parseSalaryDate, startOfDay } from './salarySchedule.js';

type SalaryEffects = {
  updateBalanceHistory: (userId: number, accountId: number, year: number, month: number) => Promise<void>;
  syncInvestmentContribution: (userId: number, accountId: number, transactionId: number, amount: number, date: string) => Promise<void>;
};

export const SALARY_PROCESS_LIMIT = 48;
const TRANSACTION_LIMIT = 8;

/** All salary writers take the same cross-instance lock, before rules and accounts. */
export async function withSalaryLock<T>(userId: number, work: (connection: PoolConnection) => Promise<T>): Promise<T> {
  return withTransaction(async connection => {
    const [users] = await connection.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ? FOR UPDATE', [userId]);
    if (!users.length) throw new Error('Salary owner unavailable');
    return work(connection);
  });
}

async function ensureSalaryCategory(connection: PoolConnection, userId: number) {
  const [existing] = await connection.query<RowDataPacket[]>(
    "SELECT id FROM expense_categories WHERE user_id = ? AND name = 'Salary' ORDER BY id LIMIT 1", [userId],
  );
  if (existing.length) return Number(existing[0].id);
  const [insert] = await connection.query<ResultSetHeader>(
    "INSERT INTO expense_categories (user_id, name, icon) VALUES (?, 'Salary', 'work')", [userId],
  );
  return insert.insertId;
}

/**
 * next_date is the first unconsumed occurrence. Read it under the database lock,
 * then commit its advance together with the income and every derived balance.
 * A description/amount match is never evidence that a rule was already paid.
 */
export async function processSalaryRules(userId: number, referenceDate: Date, effects: SalaryEffects, ruleId?: number): Promise<void> {
  if (!userId) return;
  const today = startOfDay(referenceDate);
  const todayString = formatDateOnly(today)!;
  // The unlocked scan is only a work hint: every candidate is rechecked under lock.
  // Most financial reads have no due rule and need no transaction or writes.
  const [candidates] = await db.query<RowDataPacket[]>(
    `SELECT id FROM salary_rules WHERE user_id = ? AND is_active = TRUE
       AND account_id IS NOT NULL AND (next_date IS NULL OR next_date <= ?)${ruleId === undefined ? '' : ' AND id = ?'} ORDER BY id`,
    ruleId === undefined ? [userId, todayString] : [userId, todayString, ruleId],
  );
  for (const candidate of candidates) {
    let consumed = 0;
    while (consumed < SALARY_PROCESS_LIMIT) {
      const result = await withSalaryLock(userId, async connection => {
        const [rules] = await connection.query<RowDataPacket[]>(
          `SELECT *, DATE_FORMAT(next_date, '%Y-%m-%d') AS cursor_date FROM salary_rules
           WHERE id = ? AND user_id = ? AND is_active = TRUE
             AND account_id IS NOT NULL AND (next_date IS NULL OR next_date <= ?) FOR UPDATE`,
          [candidate.id, userId, todayString],
        );
        const rule = rules[0];
        if (!rule || !Number.isFinite(Number(rule.amount))) return { consumed: 0, remaining: false };
        const [accounts] = await connection.query<RowDataPacket[]>(
          'SELECT id FROM accounts WHERE id = ? AND user_id = ? FOR UPDATE', [rule.account_id, userId],
        );
        // Legacy schemas have no owner FK on salary_rules. Never credit a foreign
        // or deleted account, and never consume its cursor without an income.
        if (!accounts.length) return { consumed: 0, remaining: false };
        let dueDate = parseSalaryDate(rule.cursor_date) ?? computeFirstSalaryDate(rule, today);
        const amount = Math.abs(Number(rule.amount));
        const batchSize = Math.min(TRANSACTION_LIMIT, SALARY_PROCESS_LIMIT - consumed);
        const months = new Map<string, { year: number; month: number }>();
        let categoryId: number | undefined;
        let processed = 0;
        while (dueDate <= today && processed < batchSize) {
          categoryId ??= await ensureSalaryCategory(connection, userId);
          const date = formatDateOnly(dueDate)!;
          const [insert] = await connection.query<ResultSetHeader>(
            `INSERT INTO transactions (user_id, account_id, date, description, amount, type, category, project_id, category_id)
             VALUES (?, ?, ?, ?, ?, 'Income', 'Salary', NULL, ?)`,
            [userId, rule.account_id, date, rule.name || 'Salary', amount, categoryId],
          );
          await connection.query('UPDATE accounts SET balance = balance + ? WHERE id = ? AND user_id = ?', [amount, rule.account_id, userId]);
          await effects.syncInvestmentContribution(userId, Number(rule.account_id), insert.insertId, amount, date);
          const year = dueDate.getFullYear(), month = dueDate.getMonth() + 1;
          months.set(`${year}-${month}`, { year, month });
          dueDate = computeNextSalaryDate(rule, dueDate);
          processed++;
        }
        // Helpers use the same AsyncLocalStorage connection established above.
        // Their errors must propagate, including balance-history failures.
        for (const { year, month } of months.values()) await effects.updateBalanceHistory(userId, Number(rule.account_id), year, month);
        if (rule.cursor_date !== formatDateOnly(dueDate)) {
          await connection.query('UPDATE salary_rules SET next_date = ? WHERE id = ? AND user_id = ?', [formatDateOnly(dueDate), rule.id, userId]);
        }
        return { consumed: processed, remaining: dueDate <= today };
      });
      consumed += result.consumed;
      if (!result.remaining || !result.consumed) break;
    }
  }
}
