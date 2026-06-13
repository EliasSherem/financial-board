import { db } from './db.js';

export type CreateTransactionPayload = {
  account_id: number;
  project_id?: number | null;
  date: string | Date;
  description: string;
  amount: number;
  type: string;
  category: string | null;
  category_id: number | null;
  subcategory_id: number | null;
};

type CreateTransactionDependencies = {
  updateBalanceHistory: (userId: number, accountId: number, year: number, month: number) => Promise<void>;
  syncInvestmentContribution: (
    userId: number,
    accountId: number | null,
    transactionId: number,
    amount: number,
    date: string | Date
  ) => Promise<void>;
  fetchTransactionWithRelations: (userId: number, transactionId: number) => Promise<any>;
  afterCreate?: (transactionId: number) => Promise<void>;
};

export async function createTransactionForUser({
  userId,
  payload,
  updateBalanceHistory,
  syncInvestmentContribution,
  fetchTransactionWithRelations,
  afterCreate,
}: {
  userId: number;
  payload: CreateTransactionPayload;
} & CreateTransactionDependencies) {
  const {
    account_id,
    project_id,
    date,
    description,
    amount,
    type,
    category,
    category_id,
    subcategory_id,
  } = payload;

  await db.query('START TRANSACTION');

  try {
    const [result] = await db.query(
      `INSERT INTO transactions (user_id, account_id, project_id, date, description, amount, type, category, category_id, subcategory_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [userId, account_id, project_id || null, date, description, amount, type, category, category_id, subcategory_id]
    );

    await db.query(
      'UPDATE accounts SET balance = balance + ? WHERE id = ? AND user_id = ?',
      [amount, account_id, userId]
    );

    if (project_id) {
      const spentAmount =
        type === 'Expense'
          ? Math.abs(amount)
          : type === 'Income'
          ? -Math.abs(amount)
          : 0;
      if (spentAmount !== 0) {
        await db.query(
          'UPDATE projects SET spent = spent + ? WHERE id = ? AND user_id = ?',
          [spentAmount, project_id, userId]
        );
      }
    }

    const transactionDate = new Date(date);
    const year = transactionDate.getFullYear();
    const month = transactionDate.getMonth() + 1;
    await updateBalanceHistory(userId, account_id, year, month);

    const currentDate = new Date();
    const currentYear = currentDate.getFullYear();
    const currentMonth = currentDate.getMonth() + 1;
    for (let y = year; y <= currentYear; y++) {
      const startMonth = y === year ? month : 1;
      const endMonth = y === currentYear ? currentMonth : 12;
      for (let m = startMonth; m <= endMonth; m++) {
        await updateBalanceHistory(userId, account_id, y, m);
      }
    }

    const transactionId = (result as any).insertId;
    await syncInvestmentContribution(userId, account_id, transactionId, amount, date);
    if (afterCreate) {
      await afterCreate(transactionId);
    }
    await db.query('COMMIT');

    return fetchTransactionWithRelations(userId, transactionId);
  } catch (error) {
    await db.query('ROLLBACK');
    throw error;
  }
}
