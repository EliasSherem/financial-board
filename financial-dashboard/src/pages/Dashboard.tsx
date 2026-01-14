import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { CreditCard, TrendingUp, DollarSign, Activity, Plus, ChevronRight, Calendar, Briefcase, Clock, AlertCircle } from 'lucide-react';
import { api } from '../utils/api';
import { useI18n } from '../contexts/I18nContext';
import { formatDate } from '../utils/date';

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

const isInvestmentAccount = (account: Pick<Account, 'type'>) =>
  (account?.type ?? '').toLowerCase() === 'investment';

const StatCard = ({ title, value, icon: Icon, change, t }: any) => (
  <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
    <div className="flex items-center justify-between">
      <div>
        <p className="text-sm font-medium text-gray-600 dark:text-gray-400">{title}</p>
        <p className="text-3xl font-bold text-gray-900 dark:text-gray-100">{value}</p>
        {change !== undefined && change !== null && (
          <p className={`text-sm ${change > 0 ? 'text-green-600 dark:text-green-400' : change < 0 ? 'text-red-600 dark:text-red-400' : 'text-gray-600 dark:text-gray-400'}`}>
            {t('dashboard.changeFromLastMonth', { pct: `${change > 0 ? '+' : ''}${change.toFixed(1)}` })}
          </p>
        )}
      </div>
      <Icon className="h-12 w-12 text-blue-500 dark:text-blue-400" />
    </div>
  </div>
);

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
    .filter(t => t.date.startsWith(currentMonth) && t.amount < 0)
    .reduce((sum, t) => sum + Math.abs(t.amount), 0);
    
  const lastMonthExpenses = transactions
    .filter(t => t.date.startsWith(lastMonthStr) && t.amount < 0)
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
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          <p className="mt-4 text-gray-600 dark:text-gray-400">{t('common.loading')} {t('dashboard.title').toLowerCase()}...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">{t('dashboard.title')}</h1>
        <p className="text-gray-600 dark:text-gray-400">{t('dashboard.subtitle')}</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title={t('dashboard.totalBalance')}
          value={`$${totalBalance.toLocaleString(locale, { minimumFractionDigits: 2 })}`}
          icon={DollarSign}
          change={balanceChange}
          t={t}
        />
        <StatCard
          title={t('dashboard.totalAccounts')}
          value={accounts.length.toString()}
          icon={CreditCard}
          t={t}
        />
        <StatCard
          title={t('dashboard.thisMonthExpenses')}
          value={`$${monthlyExpenses.toLocaleString(locale, { minimumFractionDigits: 2 })}`}
          icon={TrendingUp}
          change={expenseChange}
          t={t}
        />
        <StatCard
          title={t('dashboard.activeProjects')}
          value={activeProjects.toString()}
          icon={Activity}
          t={t}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">{t('dashboard.accountSummary')}</h3>
            <div className="flex gap-2">
              <button
                onClick={() => navigate('/accounts')}
                className="text-sm bg-blue-600 text-white px-3 py-1.5 rounded-md hover:bg-blue-700 flex items-center gap-1"
              >
                <Plus className="h-4 w-4" />
                {t('dashboard.addAccount')}
              </button>
              <button
                onClick={() => navigate('/accounts')}
                className="text-sm text-blue-600 hover:text-blue-800 px-3 py-1.5 rounded-md border border-blue-600 hover:bg-blue-50 flex items-center gap-1"
              >
                {t('dashboard.more')}
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>
          </div>
          <div className="space-y-4">
            {accounts.slice(0, 5).map((account) => (
              <div key={account.id} className="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
                <div>
                  <p className="font-medium text-gray-900 dark:text-gray-100">{account.name}</p>
                  <p className="text-sm text-gray-500 dark:text-gray-400">{account.type}</p>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                  ${Number(account.balance).toLocaleString(locale, { minimumFractionDigits: 2 })}
                </p>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">{t('dashboard.recentTransactions')}</h3>
            <button
              onClick={() => navigate('/transactions')}
              className="text-sm text-blue-600 hover:text-blue-800 px-3 py-1.5 rounded-md border border-blue-600 hover:bg-blue-50 flex items-center gap-1"
            >
              {t('dashboard.viewAllTransactions')}
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
          <div className="space-y-4">
            {recentTransactions.map((transaction) => (
              <div key={transaction.id} className="flex items-center justify-between p-3 border-b border-gray-100 dark:border-gray-700">
                <div>
                  <p className="font-medium text-gray-900 dark:text-gray-100">{transaction.description}</p>
                  <p className="text-sm text-gray-500 dark:text-gray-400">{formatDate(transaction.date)} â€¢ {transaction.account_name}</p>
                </div>
                <p className={`text-lg font-semibold ${
                  transaction.amount > 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'
                }`}>
                  {transaction.amount > 0 ? '+' : ''}${Math.abs(transaction.amount).toLocaleString(locale, { minimumFractionDigits: 2 })}
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Upcoming Payments Section */}
      <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
        <div className="flex items-center gap-2 mb-4">
          <Calendar className="h-5 w-5 text-blue-600 dark:text-blue-400" />
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">{t('dashboard.upcomingEvents')}</h3>
        </div>
        {upcomingPayments.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {upcomingPayments.map((payment) => {
              const daysUntil = Math.ceil((new Date(payment.next_date).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24));
              return (
                <div key={payment.id} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 hover:shadow-md dark:hover:shadow-gray-700 transition-shadow">
                  <div className="flex items-start justify-between mb-2">
                    <div>
                      <p className="font-medium text-gray-900 dark:text-gray-100">{payment.name}</p>
                      <p className="text-sm text-gray-500 dark:text-gray-400">{payment.category}</p>
                    </div>
                    <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
                      daysUntil <= 3 ? 'bg-red-100 text-red-800' : 
                      daysUntil <= 7 ? 'bg-yellow-100 text-yellow-800' : 
                      'bg-green-100 text-green-800'
                    }`}>
                      {daysUntil === 0 ? t('common.today') : 
                       daysUntil === 1 ? t('common.tomorrow') : 
                       t('common.inDays', { days: daysUntil })}
                    </span>
                  </div>
                  <p className="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-1">
                    ${payment.amount.toLocaleString(locale, { minimumFractionDigits: 2 })}
                  </p>
                  <div className="flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400">
                    <Clock className="h-3 w-3" />
                    <span>{payment.frequency}</span>
                    <span>â€¢</span>
                    <span>{formatDate(payment.next_date)}</span>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="text-center py-8 text-gray-500">
            <AlertCircle className="h-12 w-12 mx-auto mb-2 text-gray-300" />
            <p>{t('dashboard.noUpcoming')}</p>
          </div>
        )}
      </div>

      {/* Project Summaries Section */}
      <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
        <div className="flex items-center gap-2 mb-4">
          <Briefcase className="h-5 w-5 text-purple-600 dark:text-purple-400" />
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">{t('dashboard.projectSummaries')}</h3>
        </div>
        {projectSummaries.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {projectSummaries.map((project) => {
              const progress = (project.spent / project.budget) * 100;
              const statusColors = {
                'Active': 'bg-green-100 text-green-800',
                'Completed': 'bg-blue-100 text-blue-800',
                'On Hold': 'bg-yellow-100 text-yellow-800'
              };
              return (
                <div key={project.id} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
                  <div className="flex items-start justify-between mb-3">
                    <h4 className="font-medium text-gray-900 dark:text-gray-100">{project.name}</h4>
                    <span className={`inline-flex px-2 py-1 rounded-full text-xs font-medium ${statusColors[project.status]}`}>
                      {project.status}
                    </span>
                  </div>
                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-500 dark:text-gray-400">{t('dashboard.budget')}</span>
                      <span className="font-medium text-gray-900 dark:text-gray-100">${project.budget.toLocaleString(locale)}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-500 dark:text-gray-400">{t('dashboard.spent')}</span>
                      <span className={`font-medium ${progress > 100 ? 'text-red-600 dark:text-red-400' : 'text-gray-900 dark:text-gray-100'}`}>
                        ${project.spent.toLocaleString(locale)}
                      </span>
                    </div>
                    <div className="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-2 mt-2">
                      <div 
                        className={`h-2 rounded-full ${progress > 100 ? 'bg-red-500' : progress > 75 ? 'bg-yellow-500' : 'bg-green-500'}`}
                        style={{ width: `${Math.min(progress, 100)}%` }}
                      />
                    </div>
                    <p className="text-xs text-gray-500 dark:text-gray-400 text-right">{progress.toFixed(0)}% {t('dashboard.ofBudget')}</p>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="text-center py-8 text-gray-500">
            <Briefcase className="h-12 w-12 mx-auto mb-2 text-gray-300" />
            <p>{t('dashboard.noProjects')}</p>
          </div>
        )}
      </div>
    </div>
  );
}

