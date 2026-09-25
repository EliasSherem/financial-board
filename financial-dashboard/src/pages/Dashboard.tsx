import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { CreditCard, TrendingUp, DollarSign, Activity, Plus, ChevronRight, Calendar, Briefcase, Clock, AlertCircle } from 'lucide-react';
import { api } from '../utils/api';
import { useI18n } from '../contexts/I18nContext';
import { formatDate } from '../utils/date';
import { MomentumCard } from '../momentum/ui';
import {
  ActionButton,
  AppCard,
  EmptyState,
  LoadingState,
  PageHeader,
  StatCard as MetricCard,
  StatusBadge,
  cn,
} from '../components/ui';

interface Account {
  id: number;
  name: string;
  type: 'Checking' | 'Savings' | 'Business' | 'Investment' | 'Credit';
  balance: number;
  account_number: string;
  bank_name: string;
  is_active: boolean;
}

interface Transaction {
  id: number;
  date: string;
  description: string;
  amount: number;
  type: 'Income' | 'Expense' | 'Transfer';
  category: string;
  account_id: number;
  account_name?: string;
  project_id?: number;
  project_name?: string;
}

interface Project {
  id: number;
  name: string;
  description: string;
  budget: number;
  spent: number;
  status: 'Active' | 'On Hold' | 'Completed';
  start_date: string;
  end_date: string;
}

interface Payment {
  id: number;
  name: string;
  description: string;
  amount: number;
  frequency: 'Weekly' | 'Monthly' | 'Quarterly' | 'Yearly';
  next_date: string;
  account_id: number;
  account_name?: string;
  is_active: boolean;
  category: string;
}

const isTransferTransaction = (
  transaction: Pick<Transaction, 'type' | 'category'>
) => {
  const labels = [transaction.type, transaction.category]
    .map((value) => (value ?? '').trim().toLowerCase());
  return labels.includes('transfer') || labels.includes('fund transfer');
};

const isInvestmentAccount = (account: Pick<Account, 'type'>) =>
  (account?.type ?? '').toLowerCase() === 'investment';

export default function Dashboard() {
  const navigate = useNavigate();
  const { t, locale } = useI18n();
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(true);
  const [investmentsTotal, setInvestmentsTotal] = useState<number>(0);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      // Fetch all data from API in parallel
      const projectsPromise = api.getProjects().catch((error: any) => {
        if (typeof error?.message === 'string' && error.message.toLowerCase().includes('pro plan')) {
          return [];
        }
        console.warn('Projects unavailable:', error);
        return [];
      });
      const paymentsPromise = api.getPayments().catch((error: any) => {
        console.warn('Payments unavailable:', error);
        return [];
      });
      const investmentsPromise = api.getInvestments().catch((error: any) => {
        console.warn('Investments unavailable:', error);
        return [];
      });
      const [accountsData, transactionsData, projectsData, paymentsData, investmentsData] = await Promise.all([
        api.getAccounts(),
        api.getTransactions(),
        projectsPromise,
        paymentsPromise,
        // Investments list returns estimated_value including contributions (server-side)
        investmentsPromise
      ]);
      
      setAccounts(Array.isArray(accountsData) ? accountsData : []);
      setTransactions(Array.isArray(transactionsData) ? transactionsData : []);
      setProjects(Array.isArray(projectsData) ? projectsData : []);
      setPayments(Array.isArray(paymentsData) ? paymentsData : []);
      // Sum estimated value if provided; fallback 0
      const investmentList = Array.isArray(investmentsData) ? investmentsData : [];
      const invTotal = investmentList.reduce((sum, it: any) => sum + Number(it?.estimated_value || 0), 0);
      setInvestmentsTotal(invTotal);
    } catch (error) {
      console.error('Failed to load dashboard data:', error);
      // If unauthorized, redirect to login
      if (error instanceof Error && error.message === 'Unauthorized') {
        navigate('/login');
      }
    } finally {
      setLoading(false);
    }
  };

  const nonInvestmentBalance = accounts.reduce(
    (sum, account) => sum + (isInvestmentAccount(account) ? 0 : Number(account.balance)),
    0,
  );
  const totalBalance = nonInvestmentBalance + Number(investmentsTotal || 0);
  const recentTransactions = transactions.slice(0, 5);
  const activeProjects = projects.filter(p => p.status === 'Active').length;
  
  // Calculate balance change from last month (simplified - using current balance vs estimated previous)
  // For a more accurate calculation, you'd need historical balance data
  const balanceChange = 0; // Set to 0 since we don't have historical balance data

  // Calculate monthly expenses from transactions
  const currentMonth = new Date().toISOString().slice(0, 7); // YYYY-MM format
  const lastMonth = new Date();
  lastMonth.setMonth(lastMonth.getMonth() - 1);
  const lastMonthStr = lastMonth.toISOString().slice(0, 7); // YYYY-MM format
  
  const monthlyExpenses = transactions
    .filter(
      (t) =>
        t.date.startsWith(currentMonth) &&
        t.amount < 0 &&
        !isTransferTransaction(t)
    )
    .reduce((sum, t) => sum + Math.abs(t.amount), 0);
    
  const lastMonthExpenses = transactions
    .filter(
      (t) =>
        t.date.startsWith(lastMonthStr) &&
        t.amount < 0 &&
        !isTransferTransaction(t)
    )
    .reduce((sum, t) => sum + Math.abs(t.amount), 0);
    
  // Calculate expense percentage change
  const expenseChange = lastMonthExpenses > 0 
    ? ((monthlyExpenses - lastMonthExpenses) / lastMonthExpenses) * 100 
    : 0;

  // Get upcoming payments (next 3)
  const upcomingPayments = payments
    .filter(p => p.is_active)
    .sort((a, b) => new Date(a.next_date).getTime() - new Date(b.next_date).getTime())
    .slice(0, 3);

  // Get project summaries
  const projectSummaries = projects.slice(0, 3);

  if (loading) {
    return (
      <LoadingState
        className="min-h-[60vh]"
        label={`${t('common.loading')} ${t('dashboard.title').toLowerCase()}...`}
      />
    );
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title={t('dashboard.title')}
        subtitle={t('dashboard.subtitle')}
      />

      <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          title={t('dashboard.totalBalance')}
          value={`$${totalBalance.toLocaleString(locale, { minimumFractionDigits: 2 })}`}
          icon={<DollarSign className="h-5 w-5" />}
          trend={t('dashboard.changeFromLastMonth', { pct: `${balanceChange > 0 ? '+' : ''}${balanceChange.toFixed(1)}` })}
          trendVariant={balanceChange > 0 ? 'positive' : balanceChange < 0 ? 'negative' : 'neutral'}
          accent="blue"
        />
        <MetricCard
          title={t('dashboard.totalAccounts')}
          value={accounts.length.toString()}
          icon={<CreditCard className="h-5 w-5" />}
          accent="neutral"
        />
        <MetricCard
          title={t('dashboard.thisMonthExpenses')}
          value={`$${monthlyExpenses.toLocaleString(locale, { minimumFractionDigits: 2 })}`}
          icon={<TrendingUp className="h-5 w-5" />}
          trend={t('dashboard.changeFromLastMonth', { pct: `${expenseChange > 0 ? '+' : ''}${expenseChange.toFixed(1)}` })}
          trendVariant={expenseChange > 0 ? 'positive' : expenseChange < 0 ? 'negative' : 'neutral'}
          accent="amber"
        />
        <MetricCard
          title={t('dashboard.activeProjects')}
          value={activeProjects.toString()}
          icon={<Activity className="h-5 w-5" />}
          accent="purple"
        />
      </div>

      <MomentumCard />
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        <AppCard variant="elevated" className="min-w-0">
          <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <h3 className="text-lg font-semibold text-slate-950 dark:text-white">{t('dashboard.accountSummary')}</h3>
            <div className="flex flex-wrap gap-2">
              <ActionButton
                onClick={() => navigate('/accounts')}
                size="sm"
                iconLeft={<Plus className="h-4 w-4" />}
              >
                {t('dashboard.addAccount')}
              </ActionButton>
              <ActionButton
                onClick={() => navigate('/accounts')}
                variant="outline"
                size="sm"
                iconRight={<ChevronRight className="h-4 w-4" />}
              >
                {t('dashboard.more')}
              </ActionButton>
            </div>
          </div>
          <div className="space-y-3">
            {accounts.slice(0, 5).map((account) => {
              const isCredit = account.type === 'Credit';
              return (
                <div
                  key={account.id}
                  className="group flex items-center justify-between gap-4 rounded-2xl border border-slate-200/70 bg-slate-50/70 p-4 transition hover:border-blue-200 hover:bg-white hover:shadow-sm dark:border-white/10 dark:bg-white/[0.04] dark:hover:border-blue-400/30 dark:hover:bg-white/[0.06]"
                >
                  <div className="flex min-w-0 items-center gap-3">
                    <div
                      className={cn(
                        'flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ring-1',
                        isCredit
                          ? 'bg-amber-50 text-amber-600 ring-amber-100 dark:bg-amber-500/10 dark:text-amber-300 dark:ring-amber-400/20'
                          : 'bg-blue-50 text-blue-600 ring-blue-100 dark:bg-blue-500/10 dark:text-blue-300 dark:ring-blue-400/20'
                      )}
                    >
                      <CreditCard className="h-5 w-5" aria-hidden="true" />
                    </div>
                    <div className="min-w-0">
                      <p className="truncate font-semibold text-slate-950 dark:text-white">{account.name}</p>
                      <div className="mt-1 flex flex-wrap items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
                        <span>{account.type}</span>
                        {account.bank_name && (
                          <>
                            <span className="h-1 w-1 rounded-full bg-slate-300 dark:bg-slate-600" aria-hidden="true" />
                            <span className="truncate">{account.bank_name}</span>
                          </>
                        )}
                      </div>
                    </div>
                  </div>
                  <p className="shrink-0 text-right text-lg font-bold text-slate-950 dark:text-white">
                    ${Number(account.balance).toLocaleString(locale, { minimumFractionDigits: 2 })}
                  </p>
                </div>
              );
            })}
          </div>
        </AppCard>

        <AppCard variant="elevated" className="min-w-0">
          <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <h3 className="text-lg font-semibold text-slate-950 dark:text-white">{t('dashboard.recentTransactions')}</h3>
            <ActionButton
              onClick={() => navigate('/transactions')}
              variant="outline"
              size="sm"
              iconRight={<ChevronRight className="h-4 w-4" />}
            >
              {t('dashboard.viewAllTransactions')}
            </ActionButton>
          </div>
          <div className="space-y-3">
            {recentTransactions.map((transaction) => (
              <div
                key={transaction.id}
                className="flex items-center justify-between gap-4 rounded-2xl border border-slate-200/70 bg-white p-4 transition hover:border-blue-200 hover:bg-blue-50/30 dark:border-white/10 dark:bg-white/[0.03] dark:hover:border-blue-400/30 dark:hover:bg-blue-500/10"
              >
                <div className="min-w-0">
                  <p className="truncate font-semibold text-slate-950 dark:text-white">{transaction.description}</p>
                  <div className="mt-1 flex flex-wrap items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
                    <span>{formatDate(transaction.date)}</span>
                    {transaction.account_name && (
                      <>
                        <span className="h-1 w-1 rounded-full bg-slate-300 dark:bg-slate-600" aria-hidden="true" />
                        <span className="truncate">{transaction.account_name}</span>
                      </>
                    )}
                    {transaction.category && (
                      <>
                        <span className="h-1 w-1 rounded-full bg-slate-300 dark:bg-slate-600" aria-hidden="true" />
                        <span className="truncate">{transaction.category}</span>
                      </>
                    )}
                  </div>
                </div>
                <p className={`shrink-0 text-right text-lg font-bold ${
                  transaction.amount > 0 ? 'text-emerald-600 dark:text-emerald-300' : 'text-red-600 dark:text-red-300'
                }`}>
                  {transaction.amount > 0 ? '+' : ''}${Math.abs(transaction.amount).toLocaleString(locale, { minimumFractionDigits: 2 })}
                </p>
              </div>
            ))}
          </div>
        </AppCard>
      </div>

      {/* Upcoming Payments Section */}
      <AppCard variant="elevated">
        <div className="mb-5 flex items-center gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-50 text-blue-600 ring-1 ring-blue-100 dark:bg-blue-500/10 dark:text-blue-300 dark:ring-blue-400/20">
            <Calendar className="h-5 w-5" aria-hidden="true" />
          </span>
          <h3 className="text-lg font-semibold text-slate-950 dark:text-white">{t('dashboard.upcomingEvents')}</h3>
        </div>
        {upcomingPayments.length > 0 ? (
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            {upcomingPayments.map((payment) => {
              const daysUntil = Math.ceil((new Date(payment.next_date).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24));
              const badgeVariant = daysUntil <= 3 ? 'danger' : daysUntil <= 7 ? 'warning' : 'success';
              return (
                <div
                  key={payment.id}
                  className="rounded-2xl border border-slate-200/80 bg-slate-50/70 p-4 transition hover:-translate-y-0.5 hover:border-blue-200 hover:bg-white hover:shadow-md dark:border-white/10 dark:bg-white/[0.04] dark:hover:border-blue-400/30 dark:hover:bg-white/[0.06]"
                >
                  <div className="mb-3 flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate font-semibold text-slate-950 dark:text-white">{payment.name}</p>
                      <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">{payment.category}</p>
                    </div>
                    <StatusBadge variant={badgeVariant}>
                      {daysUntil === 0 ? t('common.today') : 
                       daysUntil === 1 ? t('common.tomorrow') : 
                       t('common.inDays', { days: daysUntil })}
                    </StatusBadge>
                  </div>
                  <p className="mb-2 text-2xl font-bold text-slate-950 dark:text-white">
                    ${payment.amount.toLocaleString(locale, { minimumFractionDigits: 2 })}
                  </p>
                  <div className="flex flex-wrap items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
                    <Clock className="h-3.5 w-3.5" aria-hidden="true" />
                    <span>{payment.frequency}</span>
                    <span className="h-1 w-1 rounded-full bg-slate-300 dark:bg-slate-600" aria-hidden="true" />
                    <span>{formatDate(payment.next_date)}</span>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <EmptyState
            icon={<AlertCircle className="h-6 w-6" />}
            title={t('dashboard.noUpcoming')}
          />
        )}
      </AppCard>

      {/* Project Summaries Section */}
      <AppCard variant="elevated">
        <div className="mb-5 flex items-center gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-violet-50 text-violet-600 ring-1 ring-violet-100 dark:bg-violet-500/10 dark:text-violet-300 dark:ring-violet-400/20">
            <Briefcase className="h-5 w-5" aria-hidden="true" />
          </span>
          <h3 className="text-lg font-semibold text-slate-950 dark:text-white">{t('dashboard.projectSummaries')}</h3>
        </div>
        {projectSummaries.length > 0 ? (
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            {projectSummaries.map((project) => {
              const progress = (project.spent / project.budget) * 100;
              const statusVariants = {
                'Active': 'active',
                'Completed': 'completed',
                'On Hold': 'warning'
              };
              return (
                <div key={project.id} className="rounded-2xl border border-slate-200/80 bg-slate-50/70 p-4 dark:border-white/10 dark:bg-white/[0.04]">
                  <div className="mb-4 flex items-start justify-between gap-3">
                    <h4 className="min-w-0 truncate font-semibold text-slate-950 dark:text-white">{project.name}</h4>
                    <StatusBadge variant={statusVariants[project.status] as 'active' | 'completed' | 'warning'}>
                      {project.status}
                    </StatusBadge>
                  </div>
                  <div className="space-y-3">
                    <div className="flex justify-between text-sm">
                      <span className="text-slate-500 dark:text-slate-400">{t('dashboard.budget')}</span>
                      <span className="font-semibold text-slate-950 dark:text-white">${project.budget.toLocaleString(locale)}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-slate-500 dark:text-slate-400">{t('dashboard.spent')}</span>
                      <span className={`font-semibold ${progress > 100 ? 'text-red-600 dark:text-red-300' : 'text-slate-950 dark:text-white'}`}>
                        ${project.spent.toLocaleString(locale)}
                      </span>
                    </div>
                    <div className="h-2 w-full rounded-full bg-slate-200 dark:bg-slate-800">
                      <div 
                        className={`h-2 rounded-full ${progress > 100 ? 'bg-red-500' : progress > 75 ? 'bg-yellow-500' : 'bg-green-500'}`}
                        style={{ width: `${Math.min(progress, 100)}%` }}
                      />
                    </div>
                    <p className="text-right text-xs text-slate-500 dark:text-slate-400">{progress.toFixed(0)}% {t('dashboard.ofBudget')}</p>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <EmptyState
            icon={<Briefcase className="h-6 w-6" />}
            title={t('dashboard.noProjects')}
          />
        )}
      </AppCard>
    </div>
  );
}
