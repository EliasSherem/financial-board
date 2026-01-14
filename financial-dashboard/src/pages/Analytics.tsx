import { useEffect, useMemo, useState } from "react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";
import { api } from "../utils/api";
import ProUpgradeBanner from "../components/ProUpgradeBanner";
import { useI18n } from "../contexts/I18nContext";

interface Transaction {
  id: number;
  account_id: number;
  project_id?: number;
  date: string;
  description: string;
  amount: number;
  type: "Income" | "Expense" | "Transfer";
  category?: string;
}

interface Account {
  id: number;
  name: string;
  type: string;
  balance: number;
}

interface BalanceHistoryRecord {
  account_id: number;
  year: number;
  month: number;
  balance: number;
  account_name?: string;
}

const monthLabel = (year: number, month: number) =>
  new Date(year, month - 1, 1).toLocaleDateString("en-US", { month: "short", year: "numeric" });

const slugify = (value: string) => value.toLowerCase().replace(/\s+/g, "");

const round = (value: number) => Math.round(value * 100) / 100;

const isInvestmentAccount = (account: Pick<Account, "type">) =>
  (account?.type ?? "").toLowerCase() === "investment";

export default function Analytics() {
  const { t, locale } = useI18n();
  const user = (() => {
    try {
      return JSON.parse(localStorage.getItem("user") || "{}");
    } catch {
      return {};
    }
  })();
  const isProOrExempt = Boolean((user as any)?.is_pro) || (user as any)?.id === 1 || (user as any)?.id === 3;
  if (!isProOrExempt) {
    return <ProUpgradeBanner featureLabel="Analytics" variant="page" />;
  }

  const [accounts, setAccounts] = useState<Account[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [totalBalanceData, setTotalBalanceData] = useState<Array<{ month: string; balance: number }>>([]);
  const [accountBalanceData, setAccountBalanceData] = useState<Array<Record<string, number | string>>>([]);
  const [loading, setLoading] = useState(true);
  const [investmentsTotal, setInvestmentsTotal] = useState(0);

  const formatAxisNumber = (value: any) => {
    const num = Number(value);
    if (Number.isNaN(num)) return String(value ?? "");
    return num.toLocaleString(locale);
  };

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const [accountsRes, transactionsRes, balanceHistoryRes, investmentsRes] = await Promise.all([
        api.getAccounts(),
        api.getTransactions(),
        api.getBalanceHistory(),
        api.getInvestments().catch(() => []),
      ]);

      setAccounts(accountsRes);
      setTransactions(transactionsRes);

      const investmentsTotalValue = (investmentsRes as any[]).reduce(
        (sum, item) => sum + Number(item?.estimated_value ?? 0),
        0,
      );
      setInvestmentsTotal(investmentsTotalValue);

      processAnalyticsData(accountsRes, balanceHistoryRes as BalanceHistoryRecord[], investmentsTotalValue);
    } catch (error) {
      console.error("Failed to load analytics data:", error);
    } finally {
      setLoading(false);
    }
  };

  const processAnalyticsData = (
    accountsList: Account[],
    balanceHistory: BalanceHistoryRecord[],
    investmentsSum: number,
  ) => {
    const investmentAccountIds = new Set(
      accountsList.filter(isInvestmentAccount).map((account) => account.id),
    );
    const nonInvestmentAccounts = accountsList.filter(
      (account) => !investmentAccountIds.has(account.id),
    );

    if (!balanceHistory.length) {
      const now = new Date();
      const currentMonth = monthLabel(now.getFullYear(), now.getMonth() + 1);
      const total =
        nonInvestmentAccounts.reduce((sum, acc) => sum + Number(acc.balance), 0) + investmentsSum;

      setTotalBalanceData([{ month: currentMonth, balance: round(total) }]);

      const accountRow: Record<string, number | string> = { month: currentMonth };
      accountsList.forEach((account) => {
        accountRow[slugify(account.name)] = round(Number(account.balance));
      });
      setAccountBalanceData([accountRow]);
      return;
    }

    const monthlyTotals = new Map<string, { total: number; perAccount: Map<number, number> }>();

    balanceHistory.forEach((record) => {
      const monthKey = `${record.year}-${String(record.month).padStart(2, "0")}`;
      if (!monthlyTotals.has(monthKey)) {
        monthlyTotals.set(monthKey, { total: 0, perAccount: new Map() });
      }
      const entry = monthlyTotals.get(monthKey)!;
      const accountId = record.account_id ?? (record as any).accountId;
      const balanceValue = Number(record.balance ?? 0);
      if (!investmentAccountIds.has(accountId)) {
        entry.total += balanceValue;
      }
      if (accountId != null) {
        entry.perAccount.set(accountId, balanceValue);
      }
    });

    const sortedKeys = Array.from(monthlyTotals.keys()).sort();

    if (!sortedKeys.length) {
      const now = new Date();
      const currentMonth = monthLabel(now.getFullYear(), now.getMonth() + 1);
      const total =
        nonInvestmentAccounts.reduce((sum, acc) => sum + Number(acc.balance), 0) + investmentsSum;
      setTotalBalanceData([{ month: currentMonth, balance: round(total) }]);
      const accountRow: Record<string, number | string> = { month: currentMonth };
      accountsList.forEach((account) => {
        accountRow[slugify(account.name)] = round(Number(account.balance));
      });
      setAccountBalanceData([accountRow]);
      return;
    }

    const lastKey = sortedKeys[sortedKeys.length - 1];
    const lastEntry = monthlyTotals.get(lastKey)!;
    lastEntry.total += investmentsSum;

    const totals = sortedKeys.map((key) => {
      const [year, month] = key.split("-").map(Number);
      const entry = monthlyTotals.get(key)!;
      return {
        month: monthLabel(year, month),
        balance: round(entry.total),
      };
    });

    const accountSeries = sortedKeys.map((key) => {
      const [year, month] = key.split("-").map(Number);
      const entry = monthlyTotals.get(key)!;
      const row: Record<string, number | string> = { month: monthLabel(year, month) };
      accountsList.forEach((account) => {
        const value = entry.perAccount.get(account.id) ?? 0;
        row[slugify(account.name)] = round(value);
      });
      return row;
    });

    setTotalBalanceData(totals);
    setAccountBalanceData(accountSeries);
  };

  const currentMonthKey = new Date().toISOString().slice(0, 7);
  const expenseByCategory = useMemo(() => {
    const map = new Map<string, number>();
    transactions
      .filter((tx) => typeof tx.date === "string" && tx.date.startsWith(currentMonthKey) && Number(tx.amount) < 0)
      .forEach((tx) => {
        const name = ((tx as any).category_name as string) ?? tx.category ?? "Other";
        const amount = Math.abs(Number(tx.amount) || 0);
        map.set(name, (map.get(name) || 0) + amount);
      });
    return Array.from(map.entries()).map(([name, value]) => ({ name, value }));
  }, [transactions, currentMonthKey]);

  const incomeByCategory = useMemo(() => {
    const map = new Map<string, number>();
    transactions
      .filter((tx) => typeof tx.date === "string" && tx.date.startsWith(currentMonthKey) && Number(tx.amount) > 0)
      .forEach((tx) => {
        const name = ((tx as any).category_name as string) ?? tx.category ?? "Other";
        const amount = Math.abs(Number(tx.amount) || 0);
        map.set(name, (map.get(name) || 0) + amount);
      });
    return Array.from(map.entries()).map(([name, value]) => ({ name, value }));
  }, [transactions, currentMonthKey]);

  const pieColors = ["#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#06B6D4", "#84CC16", "#F97316", "#EC4899", "#22C55E"];

  const nonInvestmentBalance = accounts.reduce(
    (sum, acc) => sum + (isInvestmentAccount(acc) ? 0 : Number(acc.balance)),
    0,
  );
  const totalBalance = nonInvestmentBalance + investmentsTotal;
  const highestAccount =
    accounts.length > 0
      ? accounts.reduce((prev, current) => (Number(prev.balance) >= Number(current.balance) ? prev : current))
      : null;

  const balanceGrowth =
    totalBalanceData.length > 1 && totalBalanceData[0].balance !== 0
      ? ((totalBalanceData[totalBalanceData.length - 1].balance - totalBalanceData[0].balance) /
          totalBalanceData[0].balance) *
        100
      : 0;

  if (loading) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600" />
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">{t("analytics.title")}</h1>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100">Current Total Balance</h3>
          <p className="text-3xl font-bold text-green-600 dark:text-green-400">
            ${totalBalance.toLocaleString(locale, { minimumFractionDigits: 2 })}
          </p>
        </div>

        <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100">Highest Balance Account</h3>
          <p className="text-xl font-semibold text-blue-600 dark:text-blue-400">{highestAccount?.name ?? "—"}</p>
          <p className="text-2xl font-bold text-gray-900 dark:text-gray-100">
            ${Number(highestAccount?.balance ?? 0).toLocaleString(locale, { minimumFractionDigits: 2 })}
          </p>
        </div>

        <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100">Balance Growth</h3>
          <p
            className={`text-2xl font-bold ${
              balanceGrowth >= 0 ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"
            }`}
          >
            {balanceGrowth >= 0 ? "+" : ""}{balanceGrowth.toFixed(1)}%
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">{t("analytics.totalBalanceOverTime")}</h3>
          {totalBalanceData.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={totalBalanceData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="month" />
                <YAxis tickFormatter={formatAxisNumber} width={90} tickMargin={8} />
                <Tooltip
                  formatter={(value: any) => [
                    `$${Number(value).toLocaleString(locale, { minimumFractionDigits: 2 })}`,
                    t("analytics.balance"),
                  ]}
                  labelFormatter={(label) => `${t("analytics.month")}: ${label}`}
                />
                <Legend />
                <Line type="monotone" dataKey="balance" stroke="#10B981" strokeWidth={2} name="Total Balance" />
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex items-center justify-center h-64 text-gray-500 dark:text-gray-400">
              {t("analytics.noBalanceData")}
            </div>
          )}
        </div>

        <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">{t("analytics.accountBalancesOverTime")}</h3>
          {accountBalanceData.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={accountBalanceData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="month" />
                <YAxis tickFormatter={formatAxisNumber} width={90} tickMargin={8} />
                <Tooltip
                  formatter={(value: any) => [
                    `$${Number(value).toLocaleString(locale, { minimumFractionDigits: 2 })}`,
                    t("analytics.balance"),
                  ]}
                  labelFormatter={(label) => `${t("analytics.month")}: ${label}`}
                />
                <Legend />
                {accounts.map((account, index) => {
                  const key = slugify(account.name);
                  const colors = ["#3B82F6", "#EF4444", "#10B981", "#F59E0B", "#8B5CF6"];
                  return (
                    <Line
                      key={account.id}
                      type="monotone"
                      dataKey={key}
                      stroke={colors[index % colors.length]}
                      strokeWidth={2}
                      name={account.name}
                    />
                  );
                })}
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex items-center justify-center h-64 text-gray-500 dark:text-gray-400">
              {t("analytics.noAccountBalanceData")}
            </div>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">{t("analytics.expensesByCategory")}</h3>
          {expenseByCategory.length > 0 ? (
            <ResponsiveContainer width="100%" height={320}>
              <PieChart>
                <Pie
                  data={expenseByCategory}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={110}
                  label={(entry) => `${entry.name}: $${Number(entry.value).toLocaleString(locale)}`}
                >
                  {expenseByCategory.map((entry, index) => (
                    <Cell key={`expense-${index}-${entry.name}`} fill={pieColors[index % pieColors.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(value: any) => `$${Number(value).toLocaleString(locale, { minimumFractionDigits: 2 })}`} />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex items-center justify-center h-64 text-gray-500 dark:text-gray-400">
              {t("analytics.noExpenseData")}
            </div>
          )}
        </div>

        <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">{t("analytics.incomeByCategory")}</h3>
          {incomeByCategory.length > 0 ? (
            <ResponsiveContainer width="100%" height={320}>
              <PieChart>
                <Pie
                  data={incomeByCategory}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={110}
                  label={(entry) => `${entry.name}: $${Number(entry.value).toLocaleString(locale)}`}
                >
                  {incomeByCategory.map((entry, index) => (
                    <Cell key={`income-${index}-${entry.name}`} fill={pieColors[index % pieColors.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(value: any) => `$${Number(value).toLocaleString(locale, { minimumFractionDigits: 2 })}`} />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex items-center justify-center h-64 text-gray-500 dark:text-gray-400">
              {t("analytics.noIncomeData")}
            </div>
          )}
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
        <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">{t("dashboard.accountSummary")}</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {accounts.map((account) => (
            <div key={account.id} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
              <h4 className="font-medium text-gray-900 dark:text-gray-100">{account.name}</h4>
              <p className="text-sm text-gray-500 dark:text-gray-400">{account.type}</p>
              <p className="text-xl font-bold text-gray-900 dark:text-gray-100">
                ${Number(account.balance).toLocaleString("en-US", { minimumFractionDigits: 2 })}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

