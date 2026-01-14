import { useCallback, useEffect, useMemo, useState } from 'react';
import type { ChangeEvent, FormEvent } from 'react';
import { api } from '../utils/api';
import { useI18n } from '../contexts/I18nContext';
import { Banknote, TrendingUp, PlusCircle, Trash2, X } from 'lucide-react';
import ProUpgradeBanner from '../components/ProUpgradeBanner';

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
      <div className="flex items-center justify-center min-h-[50vh]">
        <div className="text-gray-500">{t('common.loading')}</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">{t('investments.title')}</h1>
      </div>

      <div className="flex justify-end">
        <div className="text-right">
          {formSuccess && (
            <p className="mb-2 text-sm text-green-600 dark:text-green-400">{formSuccess}</p>
          )}
          <button
            type="button"
            onClick={openModal}
            className="inline-flex items-center gap-2 rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-700"
          >
            <PlusCircle className="h-4 w-4" />
            {t('investments.addTitle')}
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-900">
          <div className="flex items-center gap-3">
            <Banknote className="h-8 w-8 text-blue-500" />
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-300">{t('investments.totalInvested')}</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-gray-100">{currency(computed.totals.invested, locale)}</p>
            </div>
          </div>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-900">
          <div className="flex items-center gap-3">
            <PlusCircle className="h-8 w-8 text-blue-500" />
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-300">{t('investments.totalContrib')}</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-gray-100">{currency(computed.totals.contrib, locale)}</p>
            </div>
          </div>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-900">
          <div className="flex items-center gap-3">
            <TrendingUp className="h-8 w-8 text-blue-500" />
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-300">{t('investments.totalValue')}</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-gray-100">{currency(computed.totals.value, locale)}</p>
            </div>
          </div>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-900">
          <div className="flex items-center gap-3">
            <TrendingUp className="h-8 w-8 text-blue-500" />
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-300">{t('investments.totalRevenue')}</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-gray-100">{currency(computed.totals.revenue, locale)}</p>
            </div>
          </div>
        </div>
      </div>

      {/* List */}
      <div className="space-y-4">
        {computed.rows.length === 0 ? (
          <div className="flex flex-col items-center justify-center rounded-xl border border-dashed border-gray-300 py-12 text-center text-gray-500 dark:border-gray-700 dark:text-gray-400">
            <TrendingUp className="mb-3 h-10 w-10 text-gray-400 dark:text-gray-500" />
            <p>{t('investments.empty')}</p>
          </div>
        ) : (
          computed.rows.map((r) => (
            <div
              key={r.id}
              className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-900"
            >
              <div className="flex items-start justify-between gap-4">
                <h3 className="text-xl font-semibold text-gray-900 dark:text-gray-100">{r.name}</h3>
                <button
                  title={t('common.delete')}
                  onClick={() => handleDelete(r.id)}
                  disabled={deletingId === r.id}
                  className="text-red-500 hover:text-red-600 disabled:cursor-not-allowed disabled:opacity-60 dark:text-red-400 dark:hover:text-red-500"
                >
                  <Trash2 className="h-5 w-5" />
                </button>
              </div>
              <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
                {t('investments.start')}: {new Date(r.start_date).toLocaleDateString()} - {t('investments.rate')}: {Number((r as any).rate ?? (r as any).annual_rate ?? 0).toFixed(2)}%
              </p>
              <div className="mt-4 grid grid-cols-1 gap-6 md:grid-cols-2">
                <div>
                  <p className="text-sm text-gray-500 dark:text-gray-400">{t('investments.amountInvested')}</p>
                  <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">{currency(r.principal + r.contribTotal, locale)}</p>
                </div>
                <div>
                  <p className="text-sm text-gray-500 dark:text-gray-400">{t('investments.estimatedValue')}</p>
                  <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">{currency(r.estimated, locale)}</p>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
      {isModalOpen && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4"
          onClick={closeModal}
        >
          <div
            className="w-full max-w-xl rounded-lg bg-white p-6 shadow-xl dark:bg-gray-800"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">{t('investments.addTitle')}</h2>
              <button
                type="button"
                onClick={closeModal}
                className="rounded-full p-1 text-gray-500 hover:text-gray-700 dark:text-gray-300 dark:hover:text-white"
                aria-label={t('common.cancel')}
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            {formError && <p className="mb-3 text-sm text-red-500">{formError}</p>}
            <form className="grid gap-4 md:grid-cols-2" onSubmit={handleCreate}>
              <div className="flex flex-col gap-1">
                <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
                  {t('investments.form.name')}
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={handleFieldChange('name')}
                  disabled={saving}
                  required
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                  placeholder={t('investments.form.name')}
                />
              </div>
              <div className="flex flex-col gap-1">
                <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
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
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                  placeholder="0.00"
                />
              </div>
              <div className="flex flex-col gap-1">
                <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
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
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                  placeholder="0.00"
                />
              </div>
              <div className="flex flex-col gap-1">
                <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
                  {t('investments.form.startDate')}
                </label>
                <input
                  type="date"
                  value={formData.start_date}
                  onChange={handleFieldChange('start_date')}
                  disabled={saving}
                  required
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
              <div className="md:col-span-2 flex justify-end gap-3">
                <button
                  type="button"
                  onClick={closeModal}
                  className="rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
                >
                  {t('common.cancel')}
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="inline-flex items-center justify-center rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {saving ? t('common.loading') : t('investments.form.submit')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}



















