import { useCallback, useEffect, useMemo, useState } from 'react';
import type { ChangeEvent, FormEvent } from 'react';
import { api } from '../utils/api';
import { useI18n } from '../contexts/I18nContext';
import { Banknote, Calendar, Percent, PlusCircle, Trash2, TrendingUp, Wallet, X } from 'lucide-react';
import ProUpgradeBanner from '../components/ProUpgradeBanner';
import { ActionButton, AppCard, EmptyState, LoadingState, PageHeader, StatCard } from '../components/ui';

type InvestmentRow = {
  id: number;
  name: string;
  principal: number;
  annual_rate: number; // percent, e.g. 8.5
  start_date: string;  // YYYY-MM-DD
};

type Contribution = {
  id: number;
  amount: number;
  date: string; // YYYY-MM-DD
};

type Detailed = InvestmentRow & {
  contributions: Contribution[];
};

function daysSince(dateStr: string): number {
  if (!dateStr) return 0;
  const normalized = dateStr.includes('T') ? dateStr : `${dateStr}T00:00:00`;
  const d = new Date(normalized);
  if (Number.isNaN(d.getTime())) return 0;
  const now = new Date();
  const diff = Math.floor((now.getTime() - d.getTime()) / (1000 * 60 * 60 * 24));
  return Math.max(diff, 0);
}

function safeNumber(value: unknown, fallback = 0): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function currency(n: number, locale: string) {
  return `$${safeNumber(n).toLocaleString(locale, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export default function Investments() {
  const { t, locale } = useI18n();
  const user = (() => { try { return JSON.parse(localStorage.getItem('user') || '{}'); } catch { return {}; } })() as { is_pro?: boolean; id?: number };
  const isProOrExempt = Boolean(user?.is_pro) || user?.id === 1 || user?.id === 3;
  if (!isProOrExempt) {
    return <ProUpgradeBanner featureLabel="Investments" variant="page" />;
  }

  const [loading, setLoading] = useState(true);
  const [list, setList] = useState<Detailed[]>([]);
  const createEmptyForm = () => ({
    name: '',
    principal: '',
    annual_rate: '',
    start_date: '',
  });

  const [formData, setFormData] = useState(createEmptyForm);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [formSuccess, setFormSuccess] = useState<string | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [deletingId, setDeletingId] = useState<number | null>(null);

  const loadInvestments = useCallback(async () => {
    setLoading(true);
    try {
      const rows: InvestmentRow[] = await api.getInvestments();
      const detailed = await Promise.all(
        rows.map(async (r) => {
          try {
            const detail = await api.getInvestment(r.id);
            const contributions: Contribution[] = Array.isArray(detail?.contributions) ? detail.contributions : [];
            return { ...r, contributions } as Detailed;
          } catch {
            return { ...r, contributions: [] } as Detailed;
          }
        })
      );
      setList(detailed);
    } catch (e) {
      console.error('Failed to load investments', e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadInvestments();
  }, [loadInvestments]);

  const handleFieldChange = (field: keyof typeof formData) => (event: ChangeEvent<HTMLInputElement>) => {
    setFormData((prev) => ({ ...prev, [field]: event.target.value }));
    if (formError) setFormError(null);
    if (formSuccess) setFormSuccess(null);
  };

  const handleCreate = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setFormError(null);
    setFormSuccess(null);

    const name = formData.name.trim();
    const principal = Number(formData.principal);
    const rate = Number(formData.annual_rate);
    const startDate = formData.start_date;

    if (!name) {
      setFormError(t('investments.form.errorName'));
      return;
    }
    if (!Number.isFinite(principal) || principal < 0) {
      setFormError(t('investments.form.errorAmount'));
      return;
    }
    if (!Number.isFinite(rate) || rate < 0 || rate > 100000) {
      setFormError(t('investments.form.errorRate'));
      return;
    }
    if (!startDate) {
      setFormError(t('investments.form.errorDate'));
      return;
    }

    try {
      setSaving(true);
      await api.createInvestment({
        name,
        principal,
        annual_rate: rate,
        start_date: startDate,
      });
      await loadInvestments();
      setFormSuccess(t('investments.form.success'));
      closeModal();
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : t('investments.form.errorGeneric');
      setFormError(message);
    } finally {
      setSaving(false);
    }
  };

  const openModal = () => {
    setFormData(createEmptyForm());
    setFormError(null);
    setFormSuccess(null);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setSaving(false);
    setFormError(null);
    setFormData(createEmptyForm());
  };
  const handleDelete = async (id: number) => {
    if (!confirm(t('common.confirmDelete'))) return;
    try {
      setDeletingId(id);
      await api.deleteInvestment(id);
      await loadInvestments();
    } catch (error) {
      console.error('Failed to delete investment', error);
    } finally {
      setDeletingId(null);
    }
  };

  // Compute KPI metrics and per-row values with daily compounding including contributions
  const computed = useMemo(() => {
    const rows = list.map((r) => {
      const principal = safeNumber(r.principal);
      const rate = safeNumber((r as any).annual_rate ?? (r as any).rate ?? 0);
      const daily = rate > 0 ? (rate / 100) / 365 : 0;
      const base = principal * Math.pow(1 + daily, daysSince(r.start_date));
      let contribTotal = 0;
      let contribValue = 0;
      for (const c of r.contributions) {
        const amount = safeNumber(c.amount);
        contribTotal += amount;
        contribValue += amount * Math.pow(1 + daily, daysSince(c.date));
      }
      const estimated = base + contribValue;
      const revenue = estimated - (principal + contribTotal);
      return { ...r, principal, contribTotal, estimated, revenue, rate } as any;
    });

    const totals = rows.reduce((acc, r) => {
      acc.invested += safeNumber(r.principal) + safeNumber(r.contribTotal);
      acc.contrib += safeNumber(r.contribTotal);
      acc.value += safeNumber(r.estimated);
      acc.revenue += safeNumber(r.revenue);
      return acc;
    }, { invested: 0, contrib: 0, value: 0, revenue: 0 });

    return { rows, totals };
  }, [list]);

  if (loading && list.length === 0) {
    return (
      <LoadingState className="min-h-[60vh]" label={t('common.loading')} />
    );
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title={t('investments.title')}
        actions={
          <ActionButton
            type="button"
            onClick={openModal}
            iconLeft={<PlusCircle className="h-4 w-4" />}
          >
            {t('investments.addTitle')}
          </ActionButton>
        }
      />

      {formSuccess && (
        <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm font-medium text-emerald-700 dark:border-emerald-400/20 dark:bg-emerald-500/10 dark:text-emerald-300">
          {formSuccess}
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title={t('investments.totalInvested')}
          value={currency(computed.totals.invested, locale)}
          icon={<Banknote className="h-5 w-5" />}
          accent="blue"
        />
        <StatCard
          title={t('investments.totalContrib')}
          value={currency(computed.totals.contrib, locale)}
          icon={<PlusCircle className="h-5 w-5" />}
          accent="neutral"
        />
        <StatCard
          title={t('investments.totalValue')}
          value={currency(computed.totals.value, locale)}
          icon={<TrendingUp className="h-5 w-5" />}
          accent="green"
        />
        <StatCard
          title={t('investments.totalRevenue')}
          value={currency(computed.totals.revenue, locale)}
          icon={<Wallet className="h-5 w-5" />}
          accent={computed.totals.revenue >= 0 ? 'green' : 'red'}
        />
      </div>

      {/* List */}
      <div className="space-y-4">
        {computed.rows.length === 0 ? (
          <AppCard variant="subtle">
            <EmptyState
              icon={<TrendingUp className="h-6 w-6" />}
              title={t('investments.empty')}
              action={
                <ActionButton
                  type="button"
                  onClick={openModal}
                  iconLeft={<PlusCircle className="h-4 w-4" />}
                >
                  {t('investments.addTitle')}
                </ActionButton>
              }
            />
          </AppCard>
        ) : (
          computed.rows.map((r) => (
            <AppCard
              key={r.id}
              variant="interactive"
              className="overflow-hidden"
            >
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div className="min-w-0">
                  <h3 className="truncate text-xl font-semibold text-slate-950 dark:text-white">{r.name}</h3>
                  <div className="mt-2 flex flex-wrap items-center gap-3 text-sm text-slate-500 dark:text-slate-400">
                    <span className="inline-flex items-center gap-1.5">
                      <Calendar className="h-3.5 w-3.5" aria-hidden="true" />
                      {t('investments.start')}: {new Date(r.start_date).toLocaleDateString()}
                    </span>
                    <span className="inline-flex items-center gap-1.5">
                      <Percent className="h-3.5 w-3.5" aria-hidden="true" />
                      {t('investments.rate')}: {Number((r as any).rate ?? (r as any).annual_rate ?? 0).toFixed(2)}%
                    </span>
                  </div>
                </div>
                <button
                  type="button"
                  title={t('common.delete')}
                  onClick={() => handleDelete(r.id)}
                  disabled={deletingId === r.id}
                  className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-red-500 transition hover:bg-red-50 hover:text-red-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-500 focus-visible:ring-offset-2 focus-visible:ring-offset-white disabled:cursor-not-allowed disabled:opacity-60 dark:text-red-300 dark:hover:bg-red-500/10 dark:hover:text-red-200 dark:focus-visible:ring-offset-slate-900"
                >
                  <Trash2 className="h-5 w-5" aria-hidden="true" />
                </button>
              </div>

              <div className="mt-6 grid grid-cols-1 gap-4 md:grid-cols-3">
                <div className="rounded-2xl border border-slate-200/80 bg-slate-50/70 p-4 dark:border-white/10 dark:bg-white/[0.04]">
                  <p className="text-sm font-medium text-slate-500 dark:text-slate-400">{t('investments.amountInvested')}</p>
                  <p className="mt-2 overflow-hidden text-ellipsis whitespace-nowrap text-lg font-bold tracking-tight text-slate-950 dark:text-white">
                    {currency(r.principal + r.contribTotal, locale)}
                  </p>
                </div>
                <div className="rounded-2xl border border-slate-200/80 bg-slate-50/70 p-4 dark:border-white/10 dark:bg-white/[0.04]">
                  <p className="text-sm font-medium text-slate-500 dark:text-slate-400">{t('investments.estimatedValue')}</p>
                  <p className="mt-2 overflow-hidden text-ellipsis whitespace-nowrap text-lg font-bold tracking-tight text-slate-950 dark:text-white">
                    {currency(r.estimated, locale)}
                  </p>
                </div>
                <div className="rounded-2xl border border-slate-200/80 bg-slate-50/70 p-4 dark:border-white/10 dark:bg-white/[0.04]">
                  <p className="text-sm font-medium text-slate-500 dark:text-slate-400">{t('investments.totalRevenue')}</p>
                  <p className={`mt-2 overflow-hidden text-ellipsis whitespace-nowrap text-lg font-bold tracking-tight ${
                    r.revenue >= 0 ? 'text-emerald-600 dark:text-emerald-300' : 'text-red-600 dark:text-red-300'
                  }`}>
                    {currency(r.revenue, locale)}
                  </p>
                </div>
              </div>
            </AppCard>
          ))
        )}
      </div>
      {isModalOpen && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm"
          onClick={closeModal}
        >
          <div
            className="w-full max-w-xl rounded-2xl border border-slate-200/80 bg-white shadow-[0_30px_90px_rgba(15,23,42,0.24)] dark:border-white/10 dark:bg-slate-900 dark:shadow-black/40"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="flex items-start justify-between gap-4 border-b border-slate-200/80 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">{t('investments.addTitle')}</h2>
              <button
                type="button"
                onClick={closeModal}
                className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-slate-500 transition hover:bg-slate-100 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:text-slate-400 dark:hover:bg-white/10 dark:hover:text-white dark:focus-visible:ring-offset-slate-900"
                aria-label={t('common.cancel')}
              >
                <X className="h-5 w-5" aria-hidden="true" />
              </button>
            </div>
            <div className="max-h-[calc(100vh-13rem)] overflow-y-auto px-5 py-5">
            {formError && (
              <p className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-medium text-red-700 dark:border-red-400/20 dark:bg-red-500/10 dark:text-red-300">
                {formError}
              </p>
            )}
            <form className="grid gap-4 md:grid-cols-2" onSubmit={handleCreate}>
              <div className="flex flex-col gap-1.5">
                <label className="text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('investments.form.name')}
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={handleFieldChange('name')}
                  disabled={saving}
                  required
                  className="h-11 w-full rounded-xl border border-slate-300 bg-white px-3 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-blue-400 dark:focus:ring-blue-400/20"
                  placeholder={t('investments.form.name')}
                />
              </div>
              <div className="flex flex-col gap-1.5">
                <label className="text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('investments.form.amount')}
                </label>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formData.principal}
                  onChange={handleFieldChange('principal')}
                  disabled={saving}
                  required
                  className="h-11 w-full rounded-xl border border-slate-300 bg-white px-3 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-blue-400 dark:focus:ring-blue-400/20"
                  placeholder="0.00"
                />
              </div>
              <div className="flex flex-col gap-1.5">
                <label className="text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('investments.form.rate')}
                </label>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formData.annual_rate}
                  onChange={handleFieldChange('annual_rate')}
                  disabled={saving}
                  required
                  className="h-11 w-full rounded-xl border border-slate-300 bg-white px-3 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-blue-400 dark:focus:ring-blue-400/20"
                  placeholder="0.00"
                />
              </div>
              <div className="flex flex-col gap-1.5">
                <label className="text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('investments.form.startDate')}
                </label>
                <input
                  type="date"
                  value={formData.start_date}
                  onChange={handleFieldChange('start_date')}
                  disabled={saving}
                  required
                  className="h-11 w-full rounded-xl border border-slate-300 bg-white px-3 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-blue-400 dark:focus:ring-blue-400/20"
                />
              </div>
              <div className="flex flex-col-reverse gap-2 pt-2 md:col-span-2 sm:flex-row sm:justify-end">
                <ActionButton
                  type="button"
                  variant="outline"
                  onClick={closeModal}
                >
                  {t('common.cancel')}
                </ActionButton>
                <ActionButton
                  type="submit"
                  disabled={saving}
                  loading={saving}
                >
                  {saving ? t('common.loading') : t('investments.form.submit')}
                </ActionButton>
              </div>
            </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}













