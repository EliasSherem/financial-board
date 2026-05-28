import { useState, type ReactNode } from 'react';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import {
  ArrowDownLeft,
  ArrowUpRight,
  BarChart3,
  CalendarDays,
  CreditCard,
  LayoutDashboard,
  Lightbulb,
  PieChart,
  Repeat,
  Sparkles,
  Target,
  WalletCards,
} from 'lucide-react';
import { useI18n } from '../contexts/I18nContext';

type ShowcaseKey = 'dashboard' | 'transactions' | 'budgets' | 'insights';
type Lang = 'en' | 'es';

type Tab = {
  key: ShowcaseKey;
  label: Record<Lang, string>;
  eyebrow: Record<Lang, string>;
  icon: ReactNode;
};

const tabs: Tab[] = [
  {
    key: 'dashboard',
    label: { en: 'Dashboard', es: 'Panel' },
    eyebrow: { en: 'Overview', es: 'Resumen' },
    icon: <LayoutDashboard className="h-4 w-4" />,
  },
  {
    key: 'transactions',
    label: { en: 'Transactions', es: 'Transacciones' },
    eyebrow: { en: 'Cash flow', es: 'Flujo' },
    icon: <CreditCard className="h-4 w-4" />,
  },
  {
    key: 'budgets',
    label: { en: 'Budgets', es: 'Presupuestos' },
    eyebrow: { en: 'Goals', es: 'Metas' },
    icon: <Target className="h-4 w-4" />,
  },
  {
    key: 'insights',
    label: { en: 'Insights', es: 'Insights' },
    eyebrow: { en: 'AI signals', es: 'Senales IA' },
    icon: <Sparkles className="h-4 w-4" />,
  },
];

const copy = {
  liveDemo: { en: 'Live product demo', es: 'Demo interactivo' },
  sidebarDashboard: { en: 'Dashboard', es: 'Panel' },
  sidebarTransactions: { en: 'Transactions', es: 'Transacciones' },
  sidebarBudgets: { en: 'Budgets', es: 'Presupuestos' },
  sidebarInsights: { en: 'Insights', es: 'Insights' },
  totalBalance: { en: 'Total Balance', es: 'Saldo total' },
  totalAccounts: { en: 'Total Accounts', es: 'Cuentas totales' },
  monthExpenses: { en: 'This Month Expenses', es: 'Gastos del mes' },
  activeProjects: { en: 'Active Projects', es: 'Proyectos activos' },
  accountSummary: { en: 'Account Summary', es: 'Resumen de cuentas' },
  recentTransactions: { en: 'Recent Transactions', es: 'Transacciones recientes' },
  upcomingEvents: { en: 'Upcoming Events', es: 'Proximos eventos' },
  cashFlow: { en: 'Cash Flow', es: 'Flujo de efectivo' },
  income: { en: 'Income', es: 'Ingresos' },
  expenses: { en: 'Expenses', es: 'Gastos' },
  netChange: { en: 'Net Change', es: 'Cambio neto' },
  transactionStream: { en: 'Transaction Stream', es: 'Movimientos' },
  budgetHealth: { en: 'Budget Health', es: 'Salud del presupuesto' },
  goalProgress: { en: 'Goal Progress', es: 'Avance de metas' },
  insightSummary: { en: 'Insight Summary', es: 'Resumen inteligente' },
  subscriptions: { en: 'Subscriptions', es: 'Suscripciones' },
  prioritySignals: { en: 'Priority Signals', es: 'Senales prioritarias' },
  onTrack: { en: 'On track', es: 'En curso' },
  underBudget: { en: 'Under budget', es: 'Bajo presupuesto' },
  recurring: { en: 'Recurring', es: 'Recurrente' },
} as const;

function L(language: Lang, key: keyof typeof copy) {
  return copy[key][language];
}

function cn(...classes: Array<string | false | undefined>) {
  return classes.filter(Boolean).join(' ');
}

function MotionPanel({ children, reduceMotion }: { children: ReactNode; reduceMotion: boolean }) {
  return (
    <motion.div
      className="h-full"
      initial={reduceMotion ? false : { opacity: 0, y: 14 }}
      animate={{ opacity: 1, y: 0 }}
      exit={reduceMotion ? undefined : { opacity: 0, y: -10 }}
      transition={{ duration: reduceMotion ? 0 : 0.38, ease: 'easeOut' }}
    >
      {children}
    </motion.div>
  );
}

function Stagger({ children, className, reduceMotion }: { children: ReactNode; className?: string; reduceMotion: boolean }) {
  return (
    <motion.div
      className={className}
      initial="hidden"
      animate="show"
      variants={{
        hidden: {},
        show: {
          transition: {
            staggerChildren: reduceMotion ? 0 : 0.055,
          },
        },
      }}
    >
      {children}
    </motion.div>
  );
}

function StaggerItem({ children, className, reduceMotion }: { children: ReactNode; className?: string; reduceMotion: boolean }) {
  return (
    <motion.div
      className={className}
      variants={{
        hidden: reduceMotion ? {} : { opacity: 0, y: 10 },
        show: { opacity: 1, y: 0 },
      }}
      transition={{ duration: reduceMotion ? 0 : 0.32, ease: 'easeOut' }}
    >
      {children}
    </motion.div>
  );
}

function MetricCard({
  label,
  value,
  detail,
  icon,
  reduceMotion,
}: {
  label: string;
  value: string;
  detail: string;
  icon: ReactNode;
  reduceMotion: boolean;
}) {
  return (
    <StaggerItem
      reduceMotion={reduceMotion}
      className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-xs font-medium text-slate-500">{label}</div>
          <div className="mt-2 text-2xl font-bold tracking-tight text-slate-950">{value}</div>
        </div>
        <div className="rounded-xl bg-blue-50 p-2 text-blue-600">{icon}</div>
      </div>
      <div className="mt-2 text-xs text-slate-500">{detail}</div>
    </StaggerItem>
  );
}

function ProgressBar({ value, color = 'bg-blue-600', reduceMotion }: { value: number; color?: string; reduceMotion: boolean }) {
  return (
    <div className="h-2 overflow-hidden rounded-full bg-slate-100">
      <motion.div
        className={cn('h-full rounded-full', color)}
        initial={reduceMotion ? false : { width: 0 }}
        animate={{ width: `${value}%` }}
        transition={{ duration: reduceMotion ? 0 : 0.75, ease: 'easeOut' }}
      />
    </div>
  );
}

function DashboardDemo({ language, reduceMotion }: { language: Lang; reduceMotion: boolean }) {
  const accounts = [
    { name: 'Main Checking', value: '$29,633.33', pct: 68 },
    { name: 'Savings', value: '$13,770.00', pct: 42 },
    { name: 'Investment', value: '$501,915.01', pct: 86 },
  ];
  const transactions = [
    { name: 'Client Payment', meta: 'Income', value: '+$4,800.00', color: 'text-emerald-600' },
    { name: 'Software Suite', meta: 'Subscriptions', value: '-$400.00', color: 'text-slate-700' },
    { name: 'Office Supplies', meta: 'Operations', value: '-$166.67', color: 'text-slate-700' },
  ];

  return (
    <MotionPanel reduceMotion={reduceMotion}>
      <div className="space-y-4">
        <Stagger reduceMotion={reduceMotion} className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <MetricCard label={L(language, 'totalBalance')} value="$545,318.34" detail="0.0% from last month" icon={<WalletCards className="h-5 w-5" />} reduceMotion={reduceMotion} />
          <MetricCard label={L(language, 'totalAccounts')} value="3" detail={L(language, 'onTrack')} icon={<CreditCard className="h-5 w-5" />} reduceMotion={reduceMotion} />
          <MetricCard label={L(language, 'monthExpenses')} value="$3,197.67" detail={L(language, 'underBudget')} icon={<ArrowDownLeft className="h-5 w-5" />} reduceMotion={reduceMotion} />
          <MetricCard label={L(language, 'activeProjects')} value="2" detail="Q4 planning" icon={<BarChart3 className="h-5 w-5" />} reduceMotion={reduceMotion} />
        </Stagger>

        <div className="grid gap-4 lg:grid-cols-[1.1fr_0.9fr]">
          <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="mb-4 flex items-center justify-between">
              <h3 className="text-sm font-semibold text-slate-950">{L(language, 'accountSummary')}</h3>
              <span className="rounded-full bg-blue-50 px-2.5 py-1 text-xs font-medium text-blue-600">Live</span>
            </div>
            <div className="space-y-3">
              {accounts.map((account) => (
                <div key={account.name}>
                  <div className="mb-1.5 flex items-center justify-between text-xs">
                    <span className="font-medium text-slate-700">{account.name}</span>
                    <span className="text-slate-500">{account.value}</span>
                  </div>
                  <ProgressBar value={account.pct} reduceMotion={reduceMotion} />
                </div>
              ))}
            </div>
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <h3 className="mb-4 text-sm font-semibold text-slate-950">{L(language, 'recentTransactions')}</h3>
            <Stagger reduceMotion={reduceMotion} className="space-y-3">
              {transactions.map((transaction) => (
                <StaggerItem key={transaction.name} reduceMotion={reduceMotion} className="flex items-center justify-between rounded-xl bg-slate-50 px-3 py-2.5">
                  <div>
                    <div className="text-sm font-medium text-slate-900">{transaction.name}</div>
                    <div className="text-xs text-slate-500">{transaction.meta}</div>
                  </div>
                  <div className={cn('text-sm font-semibold', transaction.color)}>{transaction.value}</div>
                </StaggerItem>
              ))}
            </Stagger>
          </div>
        </div>

        <div className="hidden rounded-2xl border border-slate-200 bg-white p-4 shadow-sm md:block">
          <div className="mb-3 flex items-center gap-2 text-sm font-semibold text-slate-950">
            <CalendarDays className="h-4 w-4 text-blue-600" />
            {L(language, 'upcomingEvents')}
          </div>
          <div className="grid gap-3 lg:grid-cols-3">
            {['Netflix', 'Tenis', 'ChatGPT'].map((event, index) => (
              <div key={event} className="rounded-xl border border-slate-100 bg-slate-50 px-3 py-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-semibold text-slate-900">{event}</span>
                  <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-[11px] font-medium text-emerald-700">In {11 + index} days</span>
                </div>
                <div className="mt-2 text-xs text-slate-500">{L(language, 'recurring')}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </MotionPanel>
  );
}

function TransactionsDemo({ language, reduceMotion }: { language: Lang; reduceMotion: boolean }) {
  const rows = [
    { icon: <ArrowUpRight className="h-4 w-4" />, name: 'Client Retainer', type: L(language, 'income'), amount: '+$6,400.00', tone: 'text-emerald-600' },
    { icon: <ArrowDownLeft className="h-4 w-4" />, name: 'Rent Payment', type: L(language, 'expenses'), amount: '-$2,100.00', tone: 'text-slate-700' },
    { icon: <Repeat className="h-4 w-4" />, name: 'Cloud Tools', type: L(language, 'subscriptions'), amount: '-$400.00', tone: 'text-slate-700' },
    { icon: <ArrowDownLeft className="h-4 w-4" />, name: 'Travel', type: 'Operations', amount: '-$780.00', tone: 'text-slate-700' },
  ];

  return (
    <MotionPanel reduceMotion={reduceMotion}>
      <div className="grid h-full gap-4 lg:grid-cols-[1.05fr_0.95fr]">
        <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="mb-4 flex items-start justify-between">
            <div>
              <h3 className="text-sm font-semibold text-slate-950">{L(language, 'cashFlow')}</h3>
              <p className="mt-1 text-xs text-slate-500">Last 30 days</p>
            </div>
            <span className="rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-medium text-emerald-700">+$3,202</span>
          </div>

          <div className="grid grid-cols-3 gap-3">
            {[
              [L(language, 'income'), '$18,920', 'text-emerald-600'],
              [L(language, 'expenses'), '$9,475', 'text-blue-600'],
              [L(language, 'netChange'), '+14%', 'text-slate-950'],
            ].map(([label, value, color]) => (
              <div key={label} className="rounded-xl bg-slate-50 p-3">
                <div className="text-[11px] font-medium text-slate-500">{label}</div>
                <div className={cn('mt-1 text-lg font-bold', color)}>{value}</div>
              </div>
            ))}
          </div>

          <div className="mt-5 h-56 rounded-2xl bg-gradient-to-b from-blue-50 to-white p-4">
            <svg viewBox="0 0 560 220" className="h-full w-full" role="img" aria-label={L(language, 'cashFlow')}>
              <defs>
                <linearGradient id="cashFlowFill" x1="0" x2="0" y1="0" y2="1">
                  <stop offset="0%" stopColor="#3b82f6" stopOpacity="0.22" />
                  <stop offset="100%" stopColor="#3b82f6" stopOpacity="0" />
                </linearGradient>
              </defs>
              {[45, 90, 135, 180].map((y) => (
                <line key={y} x1="20" x2="540" y1={y} y2={y} stroke="#dbe5f2" strokeWidth="1" />
              ))}
              <motion.path
                d="M30 160 C100 128 130 72 210 98 C280 122 308 54 380 70 C440 82 474 38 535 50"
                fill="none"
                stroke="#2563eb"
                strokeWidth="6"
                strokeLinecap="round"
                initial={reduceMotion ? false : { pathLength: 0 }}
                animate={{ pathLength: 1 }}
                transition={{ duration: reduceMotion ? 0 : 1.1, ease: 'easeOut' }}
              />
              <path d="M30 160 C100 128 130 72 210 98 C280 122 308 54 380 70 C440 82 474 38 535 50 L535 200 L30 200 Z" fill="url(#cashFlowFill)" />
              {[76, 122, 92, 138, 64, 108, 52].map((height, index) => (
                <motion.rect
                  key={index}
                  x={52 + index * 67}
                  y={190 - height}
                  width="24"
                  height={height}
                  rx="6"
                  fill={index % 2 === 0 ? '#93c5fd' : '#bfdbfe'}
                  initial={reduceMotion ? false : { scaleY: 0 }}
                  animate={{ scaleY: 1 }}
                  style={{ transformOrigin: 'bottom' }}
                  transition={{ duration: reduceMotion ? 0 : 0.55, delay: index * 0.05, ease: 'easeOut' }}
                />
              ))}
            </svg>
          </div>
        </div>

        <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <h3 className="mb-4 text-sm font-semibold text-slate-950">{L(language, 'transactionStream')}</h3>
          <Stagger reduceMotion={reduceMotion} className="space-y-3">
            {rows.map((row) => (
              <StaggerItem key={row.name} reduceMotion={reduceMotion} className="flex items-center justify-between rounded-2xl border border-slate-100 bg-white px-3 py-3 shadow-sm">
                <div className="flex items-center gap-3">
                  <div className="rounded-xl bg-blue-50 p-2 text-blue-600">{row.icon}</div>
                  <div>
                    <div className="text-sm font-semibold text-slate-900">{row.name}</div>
                    <div className="text-xs text-slate-500">{row.type}</div>
                  </div>
                </div>
                <div className={cn('text-sm font-bold', row.tone)}>{row.amount}</div>
              </StaggerItem>
            ))}
          </Stagger>
        </div>
      </div>
    </MotionPanel>
  );
}

function BudgetsDemo({ language, reduceMotion }: { language: Lang; reduceMotion: boolean }) {
  const budgets = [
    { name: 'Operations', spent: '$2,850', pct: 72, color: 'bg-blue-600' },
    { name: 'Savings Goal', spent: '$7,400', pct: 54, color: 'bg-emerald-500' },
    { name: 'Marketing', spent: '$1,980', pct: 41, color: 'bg-violet-500' },
    { name: 'Subscriptions', spent: '$400', pct: 36, color: 'bg-amber-500' },
  ];

  return (
    <MotionPanel reduceMotion={reduceMotion}>
      <div className="grid gap-4 lg:grid-cols-[0.9fr_1.1fr]">
        <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="mb-5 flex items-center justify-between">
            <div>
              <h3 className="text-sm font-semibold text-slate-950">{L(language, 'budgetHealth')}</h3>
              <p className="mt-1 text-xs text-slate-500">September cycle</p>
            </div>
            <PieChart className="h-5 w-5 text-blue-600" />
          </div>
          <div className="relative mx-auto flex h-52 w-52 items-center justify-center rounded-full bg-[conic-gradient(#2563eb_0_44%,#22c55e_44%_68%,#a855f7_68%_84%,#e5e7eb_84%_100%)]">
            <div className="flex h-32 w-32 flex-col items-center justify-center rounded-full bg-white shadow-inner">
              <span className="text-3xl font-bold text-slate-950">68%</span>
              <span className="text-xs font-medium text-slate-500">{L(language, 'onTrack')}</span>
            </div>
          </div>
          <div className="mt-5 grid grid-cols-2 gap-2 text-xs text-slate-500">
            <div className="rounded-xl bg-blue-50 p-3 text-blue-700">Core budget</div>
            <div className="rounded-xl bg-emerald-50 p-3 text-emerald-700">Goals funded</div>
          </div>
        </div>

        <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <h3 className="mb-4 text-sm font-semibold text-slate-950">{L(language, 'goalProgress')}</h3>
          <Stagger reduceMotion={reduceMotion} className="grid gap-3 sm:grid-cols-2">
            {budgets.map((budget) => (
              <StaggerItem key={budget.name} reduceMotion={reduceMotion} className="rounded-2xl border border-slate-100 bg-slate-50 p-4">
                <div className="flex items-start justify-between">
                  <div>
                    <div className="text-sm font-semibold text-slate-900">{budget.name}</div>
                    <div className="mt-1 text-xs text-slate-500">{budget.spent} allocated</div>
                  </div>
                  <span className="text-sm font-bold text-slate-900">{budget.pct}%</span>
                </div>
                <div className="mt-4">
                  <ProgressBar value={budget.pct} color={budget.color} reduceMotion={reduceMotion} />
                </div>
              </StaggerItem>
            ))}
          </Stagger>
          <div className="mt-4 rounded-2xl border border-emerald-100 bg-emerald-50 p-4">
            <div className="flex items-center gap-3">
              <Target className="h-5 w-5 text-emerald-600" />
              <div>
                <div className="text-sm font-semibold text-emerald-950">Emergency fund</div>
                <div className="text-xs text-emerald-700">$12,400 of $18,000</div>
              </div>
            </div>
            <div className="mt-3">
              <ProgressBar value={69} color="bg-emerald-500" reduceMotion={reduceMotion} />
            </div>
          </div>
        </div>
      </div>
    </MotionPanel>
  );
}

function InsightsDemo({ language, reduceMotion }: { language: Lang; reduceMotion: boolean }) {
  const signals = [
    { title: 'Subscription drift', text: '-$92 projected next month', tone: 'bg-amber-50 text-amber-700' },
    { title: 'Savings pace', text: '+11% ahead of target', tone: 'bg-emerald-50 text-emerald-700' },
    { title: 'Cash reserve', text: '6.2 months runway', tone: 'bg-blue-50 text-blue-700' },
  ];
  const subscriptions = [
    ['Netflix', '$99.00', 'Monthly'],
    ['Tenis', '$166.67', 'Monthly'],
    ['ChatGPT', '$400.00', 'Monthly'],
  ];

  return (
    <MotionPanel reduceMotion={reduceMotion}>
      <div className="grid gap-4 lg:grid-cols-[1fr_0.95fr]">
        <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="rounded-2xl bg-gradient-to-br from-blue-600 to-sky-500 p-5 text-white shadow-lg shadow-blue-500/20">
            <div className="mb-4 flex items-center gap-2">
              <Sparkles className="h-5 w-5" />
              <span className="text-sm font-semibold">{L(language, 'insightSummary')}</span>
            </div>
            <p className="text-2xl font-bold leading-tight">Your spending trend is stable, with room to accelerate goals this month.</p>
            <div className="mt-5 grid grid-cols-3 gap-2 text-center text-xs">
              {['Stable', '+$3.2k', 'Low risk'].map((item) => (
                <div key={item} className="rounded-xl bg-white/15 px-2 py-2 font-medium">{item}</div>
              ))}
            </div>
          </div>

          <h3 className="mb-3 mt-5 text-sm font-semibold text-slate-950">{L(language, 'prioritySignals')}</h3>
          <Stagger reduceMotion={reduceMotion} className="grid gap-3 sm:grid-cols-3">
            {signals.map((signal) => (
              <StaggerItem key={signal.title} reduceMotion={reduceMotion} className={cn('rounded-2xl p-4', signal.tone)}>
                <Lightbulb className="mb-3 h-4 w-4" />
                <div className="text-sm font-semibold">{signal.title}</div>
                <div className="mt-1 text-xs opacity-80">{signal.text}</div>
              </StaggerItem>
            ))}
          </Stagger>
        </div>

        <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-sm font-semibold text-slate-950">{L(language, 'subscriptions')}</h3>
            <Repeat className="h-5 w-5 text-blue-600" />
          </div>
          <Stagger reduceMotion={reduceMotion} className="space-y-3">
            {subscriptions.map(([name, amount, cadence]) => (
              <StaggerItem key={name} reduceMotion={reduceMotion} className="flex items-center justify-between rounded-2xl border border-slate-100 bg-slate-50 px-4 py-3">
                <div>
                  <div className="text-sm font-semibold text-slate-900">{name}</div>
                  <div className="text-xs text-slate-500">{cadence}</div>
                </div>
                <div className="text-sm font-bold text-slate-900">{amount}</div>
              </StaggerItem>
            ))}
          </Stagger>
          <div className="mt-4 rounded-2xl bg-slate-950 p-4 text-white">
            <div className="text-xs font-medium text-slate-300">AI consultant</div>
            <div className="mt-2 text-sm leading-6 text-slate-100">Move $650 to savings after invoices clear to stay above your monthly target.</div>
          </div>
        </div>
      </div>
    </MotionPanel>
  );
}

function DemoContent({ active, language, reduceMotion }: { active: ShowcaseKey; language: Lang; reduceMotion: boolean }) {
  if (active === 'transactions') return <TransactionsDemo language={language} reduceMotion={reduceMotion} />;
  if (active === 'budgets') return <BudgetsDemo language={language} reduceMotion={reduceMotion} />;
  if (active === 'insights') return <InsightsDemo language={language} reduceMotion={reduceMotion} />;
  return <DashboardDemo language={language} reduceMotion={reduceMotion} />;
}

export default function AppCarousel() {
  const { language } = useI18n();
  const reduceMotion = Boolean(useReducedMotion());
  const [active, setActive] = useState<ShowcaseKey>('dashboard');
  const activeTab = tabs.find((tab) => tab.key === active) ?? tabs[0];

  return (
    <div className="relative mx-auto w-full max-w-6xl">
      <div className="pointer-events-none absolute inset-x-8 -top-8 h-40 rounded-full bg-blue-200/40 blur-3xl" />
      <div className="pointer-events-none absolute inset-x-20 bottom-10 h-24 rounded-full bg-emerald-100/50 blur-3xl" />

      <div className="relative mb-6 grid gap-2 rounded-2xl border border-white/70 bg-white/70 p-1.5 shadow-sm ring-1 ring-slate-900/5 backdrop-blur sm:grid-cols-4">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setActive(tab.key)}
            className={cn(
              'relative flex min-h-14 items-center gap-3 rounded-xl px-3 py-2 text-left transition focus:outline-none focus:ring-2 focus:ring-blue-500',
              active === tab.key ? 'text-slate-950' : 'text-slate-500 hover:text-slate-800',
            )}
            aria-pressed={active === tab.key}
          >
            {active === tab.key && (
              <motion.span
                layoutId="showcase-active-tab"
                className="absolute inset-0 rounded-xl bg-white shadow-sm"
                transition={{ duration: reduceMotion ? 0 : 0.28, ease: 'easeOut' }}
              />
            )}
            <span className={cn('relative rounded-lg p-2', active === tab.key ? 'bg-blue-50 text-blue-600' : 'bg-slate-100 text-slate-500')}>
              {tab.icon}
            </span>
            <span className="relative min-w-0">
              <span className="block text-sm font-semibold">{tab.label[language]}</span>
              <span className="block text-xs text-slate-500">{tab.eyebrow[language]}</span>
            </span>
          </button>
        ))}
      </div>

      <div className="relative overflow-hidden rounded-2xl border border-white/70 bg-white/85 p-2 shadow-2xl shadow-slate-900/10 ring-1 ring-slate-900/5 backdrop-blur sm:rounded-3xl sm:p-3">
        <div className="overflow-hidden rounded-xl border border-slate-200 bg-slate-50 shadow-sm sm:rounded-2xl">
          <div className="flex h-11 items-center justify-between border-b border-slate-200 bg-white px-4 sm:h-12 sm:px-5">
            <div className="flex items-center gap-2" aria-hidden="true">
              <span className="h-2.5 w-2.5 rounded-full bg-red-400" />
              <span className="h-2.5 w-2.5 rounded-full bg-amber-400" />
              <span className="h-2.5 w-2.5 rounded-full bg-emerald-400" />
            </div>
            <div className="min-w-0 px-3 text-center text-xs font-medium text-slate-500 sm:text-sm">
              <span className="hidden sm:inline">FinSight</span>
              <span className="sm:hidden">{activeTab.label[language]}</span>
              <span className="hidden sm:inline"> · {activeTab.label[language]}</span>
            </div>
            <div className="hidden h-2.5 w-16 rounded-full bg-slate-100 sm:block" aria-hidden="true" />
          </div>

          <div className="grid min-h-[610px] bg-slate-100 sm:min-h-[580px] lg:grid-cols-[88px_1fr]">
            <aside className="hidden flex-col items-center gap-3 border-r border-slate-200 bg-white/80 px-3 py-5 lg:flex" aria-label={L(language, 'liveDemo')}>
              {tabs.map((tab) => (
                <button
                  key={tab.key}
                  type="button"
                  onClick={() => setActive(tab.key)}
                  className={cn(
                    'flex h-11 w-11 items-center justify-center rounded-2xl transition focus:outline-none focus:ring-2 focus:ring-blue-500',
                    active === tab.key ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/20' : 'bg-slate-100 text-slate-500 hover:bg-slate-200',
                  )}
                  aria-label={tab.label[language]}
                >
                  {tab.icon}
                </button>
              ))}
            </aside>

            <main className="min-w-0 p-3 sm:p-5 lg:p-6">
              <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <div className="text-xs font-semibold uppercase tracking-[0.16em] text-blue-600">{L(language, 'liveDemo')}</div>
                  <h3 className="mt-1 text-xl font-bold tracking-tight text-slate-950 sm:text-2xl">{activeTab.label[language]}</h3>
                </div>
                <div className="flex w-full items-center rounded-full bg-white p-1 shadow-sm ring-1 ring-slate-200 sm:w-auto">
                  <span className="rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-700">{L(language, 'onTrack')}</span>
                </div>
              </div>

              <div className="min-h-[500px]">
                <AnimatePresence mode="wait">
                  <DemoContent key={active} active={active} language={language} reduceMotion={reduceMotion} />
                </AnimatePresence>
              </div>
            </main>
          </div>
        </div>
      </div>
    </div>
  );
}
