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
import { BarChart3, CreditCard, DollarSign, TrendingUp } from "lucide-react";
import { AppCard, EmptyState, LoadingState, PageHeader, StatCard, cn } from "../components/ui";

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
      <LoadingState
        className="min-h-[60vh]"
        label={`${t("common.loading")} ${t("analytics.title").toLowerCase()}...`}
      />
    );
  }

  return (
    <div className="space-y-8">
      <PageHeader title={t("analytics.title")} />

      <div className="grid grid-cols-1 gap-5 md:grid-cols-3">
        <StatCard
          title="Current Total Balance"
          value={`$${totalBalance.toLocaleString(locale, { minimumFractionDigits: 2 })}`}
          icon={<DollarSign className="h-5 w-5" />}
          accent="green"
        />

        <StatCard
          title="Highest Balance Account"
          value={highestAccount?.name ?? "—"}
          subtitle={`$${Number(highestAccount?.balance ?? 0).toLocaleString(locale, { minimumFractionDigits: 2 })}`}
          icon={<CreditCard className="h-5 w-5" />}
          accent="blue"
        />

        <StatCard
          title="Balance Growth"
          value={`${balanceGrowth >= 0 ? "+" : ""}${balanceGrowth.toFixed(1)}%`}
          icon={<TrendingUp className="h-5 w-5" />}
          accent={balanceGrowth >= 0 ? "green" : "red"}
        />
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        <AppCard variant="elevated" className="min-w-0">
          <div className="mb-5 flex items-center gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600 ring-1 ring-emerald-100 dark:bg-emerald-500/10 dark:text-emerald-300 dark:ring-emerald-400/20">
              <TrendingUp className="h-5 w-5" aria-hidden="true" />
            </span>
            <h3 className="text-lg font-semibold text-slate-950 dark:text-white">{t("analytics.totalBalanceOverTime")}</h3>
          </div>
          {totalBalanceData.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={totalBalanceData} margin={{ top: 8, right: 12, left: 4, bottom: 8 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#CBD5E1" opacity={0.55} />
                <XAxis dataKey="month" tick={{ fill: "#64748B", fontSize: 12 }} tickLine={false} axisLine={false} />
                <YAxis tickFormatter={formatAxisNumber} width={90} tickMargin={8} tick={{ fill: "#64748B", fontSize: 12 }} tickLine={false} axisLine={false} />
                <Tooltip
                  formatter={(value: any) => [
                    `$${Number(value).toLocaleString(locale, { minimumFractionDigits: 2 })}`,
                    t("analytics.balance"),
                  ]}
                  labelFormatter={(label) => `${t("analytics.month")}: ${label}`}
                  contentStyle={{
                    borderRadius: "12px",
                    border: "1px solid rgba(148, 163, 184, 0.35)",
                    boxShadow: "0 18px 45px rgba(15, 23, 42, 0.14)",
                  }}
                />
                <Legend wrapperStyle={{ paddingTop: 12, color: "#64748B" }} />
                <Line type="monotone" dataKey="balance" stroke="#10B981" strokeWidth={3} dot={false} activeDot={{ r: 5 }} name="Total Balance" />
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <EmptyState title={t("analytics.noBalanceData")} />
          )}
        </AppCard>

        <AppCard variant="elevated" className="min-w-0">
          <div className="mb-5 flex items-center gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-50 text-blue-600 ring-1 ring-blue-100 dark:bg-blue-500/10 dark:text-blue-300 dark:ring-blue-400/20">
              <BarChart3 className="h-5 w-5" aria-hidden="true" />
            </span>
            <h3 className="text-lg font-semibold text-slate-950 dark:text-white">{t("analytics.accountBalancesOverTime")}</h3>
          </div>
          {accountBalanceData.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={accountBalanceData} margin={{ top: 8, right: 12, left: 4, bottom: 8 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#CBD5E1" opacity={0.55} />
                <XAxis dataKey="month" tick={{ fill: "#64748B", fontSize: 12 }} tickLine={false} axisLine={false} />
                <YAxis tickFormatter={formatAxisNumber} width={90} tickMargin={8} tick={{ fill: "#64748B", fontSize: 12 }} tickLine={false} axisLine={false} />
                <Tooltip
                  formatter={(value: any) => [
                    `$${Number(value).toLocaleString(locale, { minimumFractionDigits: 2 })}`,
                    t("analytics.balance"),
                  ]}
                  labelFormatter={(label) => `${t("analytics.month")}: ${label}`}
                  contentStyle={{
                    borderRadius: "12px",
                    border: "1px solid rgba(148, 163, 184, 0.35)",
                    boxShadow: "0 18px 45px rgba(15, 23, 42, 0.14)",
                  }}
                />
                <Legend wrapperStyle={{ paddingTop: 12, color: "#64748B" }} />
                {accounts.map((account, index) => {
                  const key = slugify(account.name);
                  const colors = ["#3B82F6", "#EF4444", "#10B981", "#F59E0B", "#8B5CF6"];
                  return (
                    <Line
                      key={account.id}
                      type="monotone"
                      dataKey={key}
                      stroke={colors[index % colors.length]}
                      strokeWidth={2.5}
                      dot={false}
                      activeDot={{ r: 5 }}
                      name={account.name}
                    />
                  );
                })}
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <EmptyState title={t("analytics.noAccountBalanceData")} />
          )}
        </AppCard>
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        <AppCard variant="elevated" className="min-w-0">
          <div className="mb-5 flex items-center gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-red-50 text-red-600 ring-1 ring-red-100 dark:bg-red-500/10 dark:text-red-300 dark:ring-red-400/20">
              <DollarSign className="h-5 w-5" aria-hidden="true" />
            </span>
            <h3 className="text-lg font-semibold text-slate-950 dark:text-white">{t("analytics.expensesByCategory")}</h3>
          </div>
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
                <Tooltip
                  formatter={(value: any) => `$${Number(value).toLocaleString(locale, { minimumFractionDigits: 2 })}`}
                  contentStyle={{
                    borderRadius: "12px",
                    border: "1px solid rgba(148, 163, 184, 0.35)",
                    boxShadow: "0 18px 45px rgba(15, 23, 42, 0.14)",
                  }}
                />
                <Legend wrapperStyle={{ paddingTop: 12, color: "#64748B" }} />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <EmptyState title={t("analytics.noExpenseData")} />
          )}
        </AppCard>

        <AppCard variant="elevated" className="min-w-0">
          <div className="mb-5 flex items-center gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600 ring-1 ring-emerald-100 dark:bg-emerald-500/10 dark:text-emerald-300 dark:ring-emerald-400/20">
              <DollarSign className="h-5 w-5" aria-hidden="true" />
            </span>
            <h3 className="text-lg font-semibold text-slate-950 dark:text-white">{t("analytics.incomeByCategory")}</h3>
          </div>
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
                <Tooltip
                  formatter={(value: any) => `$${Number(value).toLocaleString(locale, { minimumFractionDigits: 2 })}`}
                  contentStyle={{
                    borderRadius: "12px",
                    border: "1px solid rgba(148, 163, 184, 0.35)",
                    boxShadow: "0 18px 45px rgba(15, 23, 42, 0.14)",
                  }}
                />
                <Legend wrapperStyle={{ paddingTop: 12, color: "#64748B" }} />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <EmptyState title={t("analytics.noIncomeData")} />
          )}
        </AppCard>
      </div>

      <AppCard variant="elevated">
        <div className="mb-5 flex items-center gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-50 text-blue-600 ring-1 ring-blue-100 dark:bg-blue-500/10 dark:text-blue-300 dark:ring-blue-400/20">
            <CreditCard className="h-5 w-5" aria-hidden="true" />
          </span>
          <h3 className="text-lg font-semibold text-slate-950 dark:text-white">{t("dashboard.accountSummary")}</h3>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
          {accounts.map((account) => (
            <div
              key={account.id}
              className="rounded-2xl border border-slate-200/80 bg-slate-50/70 p-4 transition hover:border-blue-200 hover:bg-white hover:shadow-sm dark:border-white/10 dark:bg-white/[0.04] dark:hover:border-blue-400/30 dark:hover:bg-white/[0.06]"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <h4 className="truncate font-semibold text-slate-950 dark:text-white">{account.name}</h4>
                  <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">{account.type}</p>
                </div>
                <span
                  className={cn(
                    "flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ring-1",
                    isInvestmentAccount(account)
                      ? "bg-violet-50 text-violet-600 ring-violet-100 dark:bg-violet-500/10 dark:text-violet-300 dark:ring-violet-400/20"
                      : "bg-blue-50 text-blue-600 ring-blue-100 dark:bg-blue-500/10 dark:text-blue-300 dark:ring-blue-400/20",
                  )}
                  aria-hidden="true"
                >
                  <CreditCard className="h-4 w-4" />
                </span>
              </div>
              <p className="mt-4 overflow-hidden text-ellipsis whitespace-nowrap text-xl font-bold tracking-tight text-slate-950 dark:text-white">
                ${Number(account.balance).toLocaleString("en-US", { minimumFractionDigits: 2 })}
              </p>
            </div>
          ))}
        </div>
      </AppCard>
    </div>
  );
}
