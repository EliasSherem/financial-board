import { useId, useRef, useState, type KeyboardEvent, type ReactNode } from 'react';
import { motion, useInView, useReducedMotion } from 'framer-motion';
import {
  ArrowDownLeft,
  ArrowUpRight,
  CalendarDays,
  Check,
  CreditCard,
  ListChecks,
  Repeat,
  Target,
  WalletCards,
} from 'lucide-react';
import { useI18n } from '../contexts/I18nContext';

type Lang = 'en' | 'es';
type View = 'accounts' | 'transactions' | 'budgets' | 'review';
type Localized = Record<Lang, string>;
type DemoMotion = { active: boolean; reduceMotion: boolean };

// Reset only after the outgoing panel has faded; interrupted tab changes
// continue from their current visual position rather than flashing back.
function revealTransition(playing: boolean, reduceMotion: boolean, duration = 0.64, delay = 0) {
  if (reduceMotion) return { duration: 0, delay: 0 };
  return playing ? { duration, delay, ease } : { duration: 0, delay: 0.32 };
}

const ease = [0.22, 1, 0.36, 1] as const;
const tabs: { key: View; title: Localized; subtitle: Localized; icon: ReactNode }[] = [
  { key: 'accounts', title: { en: 'Accounts', es: 'Cuentas' }, subtitle: { en: 'Your overview', es: 'Tu panorama' }, icon: <WalletCards size={17} /> },
  { key: 'transactions', title: { en: 'Transactions', es: 'Movimientos' }, subtitle: { en: 'Everyday clarity', es: 'Claridad diaria' }, icon: <CreditCard size={17} /> },
  { key: 'budgets', title: { en: 'Budgets', es: 'Presupuestos' }, subtitle: { en: 'Room for your goals', es: 'Espacio para tus metas' }, icon: <Target size={17} /> },
  { key: 'review', title: { en: 'Review', es: 'Revisión' }, subtitle: { en: 'Your next steps', es: 'Tus próximos pasos' }, icon: <ListChecks size={17} /> },
];

function t(language: Lang, en: string, es: string) { return language === 'es' ? es : en; }
function money(value: number) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'MXN', currencyDisplay: 'narrowSymbol', maximumFractionDigits: 0 }).format(value);
}
function cx(...classes: Array<string | false | undefined>) { return classes.filter(Boolean).join(' '); }

function Card({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cx('min-w-0 rounded-2xl border border-slate-200/80 bg-white p-4 shadow-[0_2px_8px_-5px_rgba(15,23,42,0.12)] sm:p-5', className)}>{children}</div>;
}
function Heading({ children, detail }: { children: ReactNode; detail?: ReactNode }) {
  return <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
    <h4 className="text-sm font-semibold tracking-tight text-slate-900">{children}</h4>{detail && <span className="text-[11px] text-slate-500">{detail}</span>}</div>;
}
function Metric({ label, value, tone = 'text-slate-950' }: { label: string; value: string; tone?: string }) {
  return <div className="min-w-0">
    <div className="text-xs text-slate-500">{label}</div>
    <div className={cx('mt-2 break-words text-xl font-semibold tracking-tight tabular-nums sm:text-2xl', tone)}>{value}</div>
  </div>;
}
function Progress({ value, color = 'bg-blue-600', label, active, reduceMotion, delay = 0 }: { value: number; color?: string; label: string; delay?: number } & DemoMotion) {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { amount: 0.5 });
  const playing = reduceMotion || (active && inView);
  const clamped = Math.max(0, Math.min(value, 100));
  return <div ref={ref} role="progressbar" aria-label={label} aria-valuenow={clamped} aria-valuemin={0} aria-valuemax={100} className="h-1.5 overflow-hidden rounded-full bg-slate-100">
    <motion.div className={cx('h-full rounded-full', color)} style={{ width: `${clamped}%`, transformOrigin: 'left' }} initial={false} animate={{ scaleX: playing ? 1 : 0 }} transition={revealTransition(playing, reduceMotion, 0.76, delay)} />
  </div>;
}

function AccountsDemo({ language, gradientId, active, reduceMotion }: { language: Lang; gradientId: string } & DemoMotion) {
  const chartRef = useRef<SVGSVGElement>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const chartInView = useInView(chartRef, { amount: 0.25 });
  const listInView = useInView(listRef, { amount: 0.2 });
  const draw = reduceMotion || (active && chartInView);
  const assemble = reduceMotion || (active && listInView);
  const accounts = [
    { name: t(language, 'Everyday account', 'Cuenta diaria'), type: t(language, 'Daily spending', 'Gastos diarios'), amount: 18420, icon: <CreditCard size={17} />, color: 'bg-blue-50 text-blue-600' },
    { name: t(language, 'Savings', 'Ahorro'), type: t(language, 'Emergency fund', 'Fondo de emergencia'), amount: 32000, icon: <Target size={17} />, color: 'bg-violet-50 text-violet-600' },
    { name: t(language, 'Cash', 'Efectivo'), type: t(language, 'On hand', 'Disponible'), amount: 3900, icon: <WalletCards size={17} />, color: 'bg-slate-100 text-slate-600' },
  ];
  return <div className="space-y-4">
    <Card>
      <div className="grid grid-cols-2 gap-x-4 gap-y-6 sm:grid-cols-[1.2fr_1fr_1fr]">
        <div className="col-span-2 sm:col-span-1">
          <div className="text-xs text-slate-500">{t(language, 'Total balance', 'Saldo total')}</div>
          <div className="mt-2 text-3xl font-semibold tracking-tight text-slate-950 tabular-nums sm:text-4xl">{money(54320)}<span className="ml-2 text-xs font-medium tracking-normal text-slate-500">MXN</span>
          </div>
          <div className="mt-2 text-xs text-slate-500">{t(language, 'Across 3 accounts', 'En tus 3 cuentas')}</div>
        </div>
        <Metric label={t(language, 'Income this month', 'Ingresos del mes')} value={money(32000)} tone="text-emerald-700" />
        <Metric label={t(language, 'Expenses this month', 'Gastos del mes')} value={money(19680)} />
      </div>
    </Card>
    <div className="grid gap-4 lg:grid-cols-[0.95fr_1.05fr]">
      <Card>
        <Heading>{t(language, 'Your accounts', 'Tus cuentas')}</Heading>
        <div ref={listRef} className="divide-y divide-slate-100">
          {accounts.map((account, index) => <motion.div initial={false} animate={{ opacity: assemble ? 1 : 0, x: assemble ? 0 : 12 }} transition={revealTransition(assemble, reduceMotion, 0.56, index * 0.07)} key={account.name} className="flex items-center gap-3 py-4 first:pt-1 last:pb-1">
            <span className={cx('flex h-10 w-10 shrink-0 items-center justify-center rounded-xl', account.color)}>{account.icon}</span>
            <div className="min-w-0 flex-1">
              <div className="text-sm font-medium text-slate-800">{account.name}</div>
              <div className="mt-0.5 text-[11px] text-slate-500">{account.type}</div>
            </div>
            <span className="shrink-0 text-sm font-semibold text-slate-900 tabular-nums">{money(account.amount)}</span>
          </motion.div>)}
        </div>
      </Card>
      <Card>
        <Heading detail={t(language, 'September', 'Septiembre')}>{t(language, 'Balance over time', 'Evolución del saldo')}</Heading>
        <div className="flex flex-wrap items-baseline gap-2">
          <span className="text-2xl font-semibold tracking-tight text-slate-900 tabular-nums">+{money(12320)}</span>
          <span className="text-xs text-slate-500">{t(language, 'net this month', 'netos este mes')}</span>
        </div>
        <svg ref={chartRef} viewBox="0 0 520 190" className="mt-3 h-36 w-full overflow-visible" role="img" aria-label={t(language, 'Sample balance starts at $42,000 and ends at $54,320 on September 25.', 'El saldo de ejemplo empieza en $42,000 y termina en $54,320 el 25 de septiembre.')}>
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#2563eb" stopOpacity="0.12" />
              <stop offset="100%" stopColor="#2563eb" stopOpacity="0" />
            </linearGradient>
            <clipPath id={`${gradientId}-reveal`}>
              <motion.rect x="0" y="0" height="190" initial={false} animate={{ width: draw ? 520 : 0 }} transition={revealTransition(draw, reduceMotion, 0.78, 0.06)} />
            </clipPath>
          </defs>
          {[40, 100, 160].map(y => <line key={y} x1="0" x2="520" y1={y} y2={y} stroke="#eef2f7" strokeDasharray="3 5" />)}
          <path d="M4 94 L24 136 C90 143 150 157 235 162 L290 24 C365 28 435 40 516 40 L516 184 L4 184 Z" fill={`url(#${gradientId})`} clipPath={`url(#${gradientId}-reveal)`} />
          <motion.path d="M4 94 L24 136 C90 143 150 157 235 162 L290 24 C365 28 435 40 516 40" fill="none" stroke="#2563eb" strokeWidth="2.5" strokeLinecap="round" initial={false} animate={{ pathLength: draw ? 1 : 0, opacity: draw ? 1 : 0 }} transition={revealTransition(draw, reduceMotion, 0.84)} />
          <motion.circle cx="516" cy="40" r="4" fill="#2563eb" stroke="white" strokeWidth="3" initial={false} animate={{ opacity: draw ? 1 : 0 }} transition={revealTransition(draw, reduceMotion, 0.18, 0.7)} />
        </svg>
        <div className="mt-1 flex justify-between text-[10px] text-slate-500">
          <span>01 {t(language, 'Sep', 'sep')}</span>
          <span>12 {t(language, 'Sep', 'sep')}</span>
          <span>25 {t(language, 'Sep', 'sep')}</span>
        </div>
      </Card>
    </div>
  </div>;
}

function TransactionsDemo({ language, active, reduceMotion }: { language: Lang } & DemoMotion) {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { amount: 0.2 });
  const assemble = reduceMotion || (active && inView);
  const rows = [
    { name: t(language, 'Groceries', 'Supermercado'), category: t(language, 'Food', 'Alimentación'), day: '24', amount: -480 },
    { name: t(language, 'Cloud tools', 'Herramientas de trabajo'), category: t(language, 'Subscriptions', 'Suscripciones'), day: '22', amount: -400 },
    { name: t(language, 'Salary', 'Salario'), category: t(language, 'Income', 'Ingresos'), day: '18', amount: 32000 },
    { name: t(language, 'Electricity', 'Electricidad'), category: t(language, 'Utilities', 'Servicios'), day: '15', amount: -1150 },
    { name: t(language, 'Rent', 'Renta'), category: t(language, 'Housing', 'Vivienda'), day: '01', amount: -10000 },
  ];
  return <div className="space-y-4">
    <Card>
      <div className="grid grid-cols-2 gap-6 sm:grid-cols-3">
        <Metric label={t(language, 'Monthly income', 'Ingresos del mes')} value={money(32000)} tone="text-emerald-700" />
        <Metric label={t(language, 'Monthly expenses', 'Gastos del mes')} value={money(19680)} />
        <div className="col-span-2 sm:col-span-1">
          <Metric label={t(language, 'Difference', 'Diferencia')} value={`+${money(12320)}`} tone="text-blue-700" />
        </div>
      </div>
    </Card>
    <Card>
      <Heading detail={t(language, 'September · Selected entries', 'Septiembre · Movimientos seleccionados')}>{t(language, 'Your daily record', 'Tu registro diario')}</Heading>
      <div ref={ref} className="divide-y divide-slate-100">
        {rows.map((row, index) => <motion.div initial={false} animate={{ opacity: assemble ? 1 : 0, x: assemble ? 0 : 16, y: assemble ? 0 : 6 }} transition={revealTransition(assemble, reduceMotion, 0.5, index * 0.075)} key={row.name} className="flex items-center gap-3 py-3.5 first:pt-0 last:pb-0">
          <div className={cx('hidden h-9 w-9 shrink-0 items-center justify-center rounded-xl sm:flex', row.amount > 0 ? 'bg-emerald-50 text-emerald-600' : 'bg-slate-100 text-slate-500')}>{row.amount > 0 ? <ArrowUpRight size={16} /> : <ArrowDownLeft size={16} />}</div>
          <div className="min-w-0 flex-1">
            <div className="text-sm font-medium text-slate-900">{row.name}</div>
            <div className="mt-1 flex flex-wrap gap-x-2 text-[11px] text-slate-500">
              <span>{row.day} {t(language, 'Sep', 'sep')}</span>
              <span aria-hidden="true">·</span>
              <span>{row.category}</span>
            </div>
          </div>
          <div className={cx('shrink-0 text-sm font-semibold tabular-nums', row.amount > 0 ? 'text-emerald-700' : 'text-slate-800')}>{row.amount > 0 ? '+' : '−'}{money(Math.abs(row.amount))}</div>
        </motion.div>)}
      </div>
    </Card>
  </div>;
}

function BudgetsDemo({ language, active, reduceMotion }: { language: Lang } & DemoMotion) {
  const budgets = [
    { title: t(language, 'Housing', 'Vivienda'), spent: 10000, limit: 10000, tone: 'bg-blue-600' },
    { title: t(language, 'Food', 'Alimentación'), spent: 2480, limit: 4000, tone: 'bg-blue-500' },
    { title: t(language, 'Transport', 'Transporte'), spent: 850, limit: 1600, tone: 'bg-sky-500' },
    { title: t(language, 'Subscriptions', 'Suscripciones'), spent: 400, limit: 600, tone: 'bg-violet-500' },
  ];
  return <div className="grid gap-4 lg:grid-cols-[1.1fr_0.9fr]">
    <Card>
      <Heading detail={t(language, 'September', 'Septiembre')}>{t(language, 'Spending by category', 'Gasto por categoría')}</Heading>
      <div className="space-y-6">
        {budgets.map((budget, index) => <div key={budget.title}>
          <div className="mb-2.5 flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
            <span className="text-sm font-medium text-slate-800">{budget.title}</span>
            <span className="text-xs text-slate-500 tabular-nums">
              <span className="font-semibold text-slate-800">{money(budget.spent)}</span> / {money(budget.limit)}</span>
          </div>
          <Progress label={budget.title} value={budget.spent / budget.limit * 100} color={budget.tone} active={active} reduceMotion={reduceMotion} delay={index * 0.04} />
        </div>)}
      </div>
      <div className="mt-6 border-t border-slate-100 pt-4 text-xs leading-relaxed text-slate-500">{t(language, 'Selected categories · Keep your monthly limits in view.', 'Categorías seleccionadas · Tus límites mensuales a la vista.')}</div>
    </Card>
    <Card className="flex flex-col">
      <Heading>{t(language, 'A goal with a plan', 'Una meta con un plan')}</Heading>
      <span className="mb-5 flex h-11 w-11 items-center justify-center rounded-2xl bg-violet-50 text-violet-600">
        <Target size={21} />
      </span>
      <div className="text-lg font-semibold tracking-tight text-slate-900">{t(language, 'Emergency fund', 'Fondo de emergencia')}</div>
      <p className="mt-1 text-xs text-slate-500">{t(language, 'Linked to your savings account', 'Vinculado a tu cuenta de ahorro')}</p>
      <div className="mb-4 mt-6 flex flex-wrap items-baseline gap-2">
        <span className="text-3xl font-semibold tracking-tight text-slate-950 tabular-nums">{money(32000)}</span>
        <span className="text-xs text-slate-500">/ {money(40000)}</span>
      </div>
      <Progress label={t(language, 'Emergency fund', 'Fondo de emergencia')} value={80} color="bg-violet-500" active={active} reduceMotion={reduceMotion} delay={0.1} />
      <div className="mt-3 flex justify-between text-xs">
        <span className="font-medium text-violet-700">80%</span>
        <span className="text-slate-500">{t(language, '$8,000 to go', 'Faltan $8,000')}</span>
      </div>
      <div className="mt-6 rounded-xl bg-slate-50 px-3 py-3 text-xs leading-relaxed text-slate-600">{t(language, 'Small, consistent contributions bring your goal closer.', 'Las aportaciones constantes te acercan a tu meta.')}</div>
    </Card>
  </div>;
}

function ReviewDemo({ language, active, reduceMotion }: { language: Lang } & DemoMotion) {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { amount: 0.2 });
  const assemble = reduceMotion || (active && inView);
  const sections = [t(language, 'Transactions', 'Movimientos'), t(language, 'Categories', 'Categorías'), t(language, 'Upcoming payments', 'Próximos pagos')];
  return <div className="grid gap-4 lg:grid-cols-2">
    <Card>
      <Heading>{t(language, 'Upcoming payments', 'Próximos pagos')}</Heading>
      <div className="space-y-3">
        {[
          { title: t(language, 'Internet', 'Internet'), day: '28', amount: 650, detail: t(language, 'Recurring payment', 'Pago recurrente') },
          { title: t(language, 'Credit card', 'Tarjeta de crédito'), day: '30', amount: 1200, detail: t(language, 'Scheduled payment', 'Pago programado') },
        ].map(payment => <div key={payment.title} className="flex items-center gap-3 rounded-xl border border-slate-100 p-3">
          <div className="flex w-10 shrink-0 flex-col items-center rounded-lg bg-slate-50 py-1.5">
            <span className="text-[9px] font-medium uppercase text-slate-500">{t(language, 'Sep', 'sep')}</span>
            <span className="text-base font-semibold text-slate-800 tabular-nums">{payment.day}</span>
          </div>
          <div className="min-w-0 flex-1">
            <div className="text-sm font-medium text-slate-900">{payment.title}</div>
            <div className="mt-1 text-[11px] text-slate-500">{payment.detail}</div>
          </div>
          <span className="text-sm font-semibold text-slate-900 tabular-nums">{money(payment.amount)}</span>
        </div>)}
      </div>
      <div className="mt-5 flex items-start gap-2.5 rounded-xl bg-blue-50/70 p-3 text-xs leading-relaxed text-blue-800">
        <CalendarDays size={16} className="mt-0.5 shrink-0" />
        <span>{t(language, 'See what is coming before deciding what to spend.', 'Mira lo que viene antes de decidir cuánto gastar.')}</span>
      </div>
    </Card>
    <Card>
      <Heading detail="Momentum">{t(language, 'Your weekly review', 'Tu revisión semanal')}</Heading>
      <div className="mb-5">
        <span className="text-3xl font-semibold tracking-tight text-slate-950">2<span className="ml-1 text-lg font-normal text-slate-500">/ 3</span>
        </span>
        <span className="ml-2 text-xs text-slate-500">{t(language, 'sections reviewed', 'secciones revisadas')}</span>
      </div>
      <div ref={ref} className="space-y-4">{sections.map((section, index) => <motion.div initial={false} animate={{ opacity: assemble ? 1 : 0, x: assemble ? 0 : 12 }} transition={revealTransition(assemble, reduceMotion, 0.54, index * 0.08)} key={section} className="flex items-center gap-3">
        <span className={cx('flex h-6 w-6 shrink-0 items-center justify-center rounded-full', index < 2 ? 'bg-emerald-50 text-emerald-600' : 'border border-slate-200 text-slate-500')}>{index < 2 ? <Check size={13} strokeWidth={2.5} /> : <span className="h-1.5 w-1.5 rounded-full bg-slate-300" />}</span>
        <span className="flex-1 text-sm text-slate-700">{section}</span>
        <span className="text-[10px] text-slate-500">{index < 2 ? t(language, 'Reviewed', 'Revisado') : t(language, 'Next', 'Siguiente')}</span>
      </motion.div>)}</div>
      <div className="mt-6 border-t border-slate-100 pt-4">
        <div className="flex items-center gap-2 text-xs font-medium text-slate-700">
          <Repeat size={13} />{t(language, 'A little clarity, every week', 'Un poco de claridad cada semana')}</div>
        <p className="mt-2 text-xs leading-relaxed text-slate-500">{t(language, 'Review your activity and choose your next step.', 'Revisa tu actividad y elige tu siguiente paso.')}</p>
      </div>
    </Card>
  </div>;
}

export default function AppCarousel() {
  const { language } = useI18n();
  const reduceMotion = Boolean(useReducedMotion());
  const id = useId();
  const [active, setActive] = useState<View>('accounts');
  const tabRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const activeIndex = tabs.findIndex(tab => tab.key === active);
  const activeTab = tabs[activeIndex];
  function navigate(event: KeyboardEvent<HTMLButtonElement>, index: number) {
    const next = event.key === 'ArrowRight' ? (index + 1) % tabs.length : event.key === 'ArrowLeft' ? (index + tabs.length - 1) % tabs.length : event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : null;
    if (next === null) return;
    event.preventDefault();
    setActive(tabs[next].key);
    tabRefs.current[next]?.focus();
  }
  const panels: Record<View, ReactNode> = {
    accounts: <AccountsDemo language={language} gradientId={`${id}-balance`} active={active === 'accounts'} reduceMotion={reduceMotion} />,
    transactions: <TransactionsDemo language={language} active={active === 'transactions'} reduceMotion={reduceMotion} />,
    budgets: <BudgetsDemo language={language} active={active === 'budgets'} reduceMotion={reduceMotion} />,
    review: <ReviewDemo language={language} active={active === 'review'} reduceMotion={reduceMotion} />,
  };

  return <div className="relative mx-auto w-full max-w-6xl">
    <div role="tablist" aria-label={t(language, 'Explore FinSight', 'Explora FinSight')} className="relative mx-auto mb-6 grid max-w-2xl grid-cols-2 gap-1 rounded-[26px] bg-[#f5f5f7] p-1.5 sm:grid-cols-4 sm:rounded-full">
      {tabs.map((tab, index) => <button key={tab.key} ref={node => { tabRefs.current[index] = node; }} id={`${id}-tab-${tab.key}`} role="tab" aria-selected={active === tab.key} aria-controls={`${id}-panel-${tab.key}`} tabIndex={active === tab.key ? 0 : -1} type="button" onClick={() => setActive(tab.key)} onKeyDown={event => navigate(event, index)} className={cx('relative flex min-h-11 min-w-0 items-center justify-center gap-2 rounded-full px-3 py-2.5 text-center outline-none transition-colors duration-200 focus-visible:ring-2 focus-visible:ring-blue-500 motion-reduce:transition-none sm:gap-3', active === tab.key ? 'text-slate-950' : 'text-slate-500 hover:text-slate-800')}>
        {active === tab.key && <motion.span layoutId={`${id}-active-tab`} className="absolute inset-0 rounded-full border border-slate-200/60 bg-white shadow-[0_2px_6px_-3px_rgba(15,23,42,0.16)]" transition={{ duration: reduceMotion ? 0 : 0.3, ease }} />}
        <span className={cx('relative shrink-0 transition-colors duration-200 motion-reduce:transition-none', active === tab.key ? 'text-blue-600' : 'text-slate-500')}>{tab.icon}</span>
        <span className="relative min-w-0">
          <span className="block break-words text-xs font-semibold sm:text-sm">{tab.title[language]}</span>
        </span>
      </button>)}
    </div>

    <div className="relative overflow-hidden rounded-[28px] border border-slate-200/80 bg-[#f5f5f7] p-1.5 shadow-[0_24px_64px_-40px_rgba(15,23,42,0.2)] sm:p-2.5">
      <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-[#f5f5f7] sm:rounded-[20px]">
        <div className="flex min-h-12 items-center justify-between gap-3 border-b border-slate-200/70 bg-white/90 px-4 sm:px-5">
          <div className="flex items-center gap-3">
            <span className="text-xs font-semibold tracking-tight text-slate-700">FinSight</span>
          </div>
          <span className="rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1 text-[10px] font-medium text-slate-500">{t(language, 'Sample data · MXN', 'Datos de ejemplo · MXN')}</span>
        </div>
        <div>
          <div className="min-w-0 px-3 pb-4 pt-5 sm:px-5 sm:pb-5 lg:p-6">
            <div className="mb-5 flex items-center justify-between gap-3">
              <div>
                <h3 className="text-lg font-semibold tracking-tight text-slate-950 sm:text-xl">{activeTab.title[language]}</h3>
                <div className="mt-1 text-[11px] text-slate-500">{t(language, 'September · Your finances in view', 'Septiembre · Tus finanzas a la vista')}</div>
              </div>
            </div>
            {/* All four panels share a grid cell: the frame keeps its height on
                every viewport. Inactive examples are inert and hidden from AT. */}
            <div className="grid items-start">
              {tabs.map((tab, index) => {
                const selected = active === tab.key;
                return <motion.div key={tab.key} id={`${id}-panel-${tab.key}`} role="tabpanel" aria-labelledby={`${id}-tab-${tab.key}`} aria-hidden={!selected} inert={!selected} tabIndex={selected ? 0 : -1} className="col-start-1 row-start-1 min-w-0 rounded-xl outline-none focus-visible:ring-2 focus-visible:ring-blue-500" style={{ pointerEvents: selected ? 'auto' : 'none', zIndex: selected ? 1 : 0 }} initial={false} animate={selected ? 'visible' : 'hidden'} variants={{ visible: { visibility: 'visible', opacity: 1, x: 0 }, hidden: { opacity: 0, x: reduceMotion ? 0 : index < activeIndex ? -24 : 24, transitionEnd: { visibility: 'hidden' } } }} transition={{ duration: reduceMotion ? 0 : 0.3, ease }}>{panels[tab.key]}</motion.div>;
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
    <p className="mt-4 text-center text-[11px] leading-relaxed text-slate-500">{t(language, 'An illustrative view of FinSight. No personal financial information is shown.', 'Una vista ilustrativa de FinSight. No se muestran datos financieros personales.')}</p>
  </div>;
}
