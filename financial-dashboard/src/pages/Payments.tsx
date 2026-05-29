import { useState, useEffect, useMemo } from 'react';
import { Plus, Edit2, Trash2, Calendar, DollarSign, Play, Pause } from 'lucide-react';
import { api } from '../utils/api';
import ProUpgradeBanner from '../components/ProUpgradeBanner';
import { useI18n } from '../contexts/I18nContext';
import { CategoryPicker } from '../components/CategoryPicker';
import type { CategorySelection } from '../components/CategoryPicker';
import type { ExpenseCategory } from '../types/expense';
import { useNavigate } from 'react-router-dom';
import {
  ActionButton,
  DataTableShell,
  EmptyState,
  LoadingState,
  PageHeader,
  StatCard,
  StatusBadge,
} from '../components/ui';
import type { StatCardAccent, StatusBadgeVariant } from '../components/ui';

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
  project_id?: number;
  project_name?: string;
  // Installments (optional)
  installments_total?: number | null;
  installments_remaining?: number | null;
  installment_total_amount?: number | null;
}

interface Account {
  id: number;
  name: string;
  type: 'Checking' | 'Savings' | 'Business' | 'Investment' | 'Credit';
}

interface Project {
  id: number;
  name: string;
  status: string;
}

export default function Payments() {
  const { t, locale } = useI18n();
  const navigate = useNavigate();
  const user = (() => { try { return JSON.parse(localStorage.getItem('user') || '{}'); } catch { return {}; } })();
  const isProOrExempt = Boolean(user?.is_pro) || user?.id === 1 || user?.id === 3;
  // Refresh user profile after returning from Stripe Checkout
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get('upgraded') === '1') {
      const token = localStorage.getItem('token');
      if (token) {
        // Try to sync subscription from Stripe (fallback if webhook didn't run yet)
        fetch(`${(import.meta as any)?.env?.VITE_API_URL || 'http://localhost:3001/api'}/stripe/sync`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` } })
          .catch(() => undefined)
          .finally(() => {
            fetch(`${(import.meta as any)?.env?.VITE_API_URL || 'http://localhost:3001/api'}/me`, { headers: { Authorization: `Bearer ${token}` } })
              .then(r => r.json())
              .then(u => {
                if (u && u.id) {
                  localStorage.setItem('user', JSON.stringify(u));
                  // Reload to ensure all components reflect the new Pro status
                  window.location.replace('/payments');
                }
              })
              .catch(() => {});
          });
      }
    }
  }, []);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [expenseCategories, setExpenseCategories] = useState<ExpenseCategory[]>([]);
  const [categoryError, setCategoryError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    console.log('Payments component mounted, loading data...');
    loadData();
  }, []);

  const loadData = async () => {
    try {
      console.log('Starting to load payments data...');
      setLoading(true);
      setError(null);
      const categoryPromise = api.getExpenseCategories().catch(() => []);
      const [paymentsData, accountsData, catData] = await Promise.all([
        api.getPayments(),
        api.getAccounts(),
        categoryPromise,
      ]);
      let projectsData: Project[] = [];
      if (isProOrExempt) {
        try {
          projectsData = await api.getProjects();
        } catch (e) {
          console.warn('Projects not available; continuing without projects');
        }
      }
      console.log('Payments data loaded:', paymentsData);
      console.log('Accounts data loaded:', accountsData);
      console.log('Projects data loaded:', projectsData);
      setPayments(paymentsData);
      setAccounts(accountsData);
      setProjects(projectsData);
      if (Array.isArray(catData)) {
        const normalized = (catData as ExpenseCategory[]).map((category) => ({
          ...category,
          subcategories: [...(category.subcategories ?? [])].sort((a, b) =>
            a.name.localeCompare(b.name)
          ),
        }));
        normalized.sort((a, b) => a.name.localeCompare(b.name));
        setExpenseCategories(normalized);
      } else {
        setExpenseCategories([]);
      }
    } catch (error) {
      console.error('Failed to load data:', error);
      setError(t('common.failedLoad'));
    } finally {
      setLoading(false);
    }
  };
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingPayment, setEditingPayment] = useState<Payment | null>(null);
  const [isInstallment, setIsInstallment] = useState(false);
  const [installmentData, setInstallmentData] = useState({ total_amount: 0, months: 12 });
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    amount: 0,
    frequency: 'Monthly' as Payment['frequency'],
    next_date: '',
    account_id: 1,
    is_active: true,
    category: '',
    category_id: undefined as number | undefined,
    subcategory_id: undefined as number | undefined,
    project_id: 0
  });

  const categorySelection = useMemo<CategorySelection>(() => {
    if (expenseCategories.length === 0) return null;
    if (formData.subcategory_id != null) {
      for (const category of expenseCategories) {
        const match = category.subcategories.find((sub) => sub.id === formData.subcategory_id);
        if (match) {
          return { category, subcategory: match };
        }
      }
    }
    if (formData.category_id != null) {
      const category = expenseCategories.find((cat) => cat.id === formData.category_id);
      if (category) {
        return { category, subcategory: null };
      }
    }
    if (formData.category.trim()) {
      const normalized = formData.category.trim().toLowerCase();
      for (const category of expenseCategories) {
        if (category.name.toLowerCase() === normalized) {
          return { category, subcategory: null };
        }
        const sub = category.subcategories.find((s) => s.name.toLowerCase() === normalized);
        if (sub) {
          return { category, subcategory: sub };
        }
      }
    }
    return null;
  }, [expenseCategories, formData.category, formData.category_id, formData.subcategory_id]);

  useEffect(() => {
    if (!isModalOpen || expenseCategories.length === 0) return;
    setFormData((prev) => {
      if (!prev.category.trim()) return prev;
      if (prev.category_id != null || prev.subcategory_id != null) return prev;
      const normalized = prev.category.trim().toLowerCase();
      for (const category of expenseCategories) {
        if (category.name.toLowerCase() === normalized) {
          if (prev.category_id === category.id && prev.subcategory_id == null) {
            return prev;
          }
          return { ...prev, category_id: category.id, subcategory_id: undefined };
        }
        const sub = category.subcategories.find((s) => s.name.toLowerCase() === normalized);
        if (sub) {
          if (prev.category_id === category.id && prev.subcategory_id === sub.id) {
            return prev;
          }
          return { ...prev, category_id: category.id, subcategory_id: sub.id };
        }
      }
      return prev;
    });
  }, [expenseCategories, isModalOpen]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (expenseCategories.length > 0 && !formData.category.trim()) {
      setCategoryError(t('categories.errorRequired'));
      return;
    }
    setCategoryError(null);
    
    try {
      const payload = {
        ...formData,
        category_id: formData.category_id ?? null,
        subcategory_id: formData.subcategory_id ?? null,
      };

      if (editingPayment) {
        await api.updatePayment(editingPayment.id, payload);
      } else {
        if (isInstallment) {
          const acct = accounts.find(a => a.id === formData.account_id);
          if (!acct || acct.type !== 'Credit') {
            throw new Error('Installments are only allowed on Credit accounts');
          }
          await api.createInstallmentPlan({
            account_id: formData.account_id,
            project_id: formData.project_id || undefined,
            name: formData.name || 'Installment',
            description: formData.description,
            total_amount: Number(installmentData.total_amount),
            months: Number(installmentData.months),
            first_due_date: formData.next_date,
            category: formData.category || 'Loan Payments',
            category_id: payload.category_id ?? undefined,
            subcategory_id: payload.subcategory_id ?? undefined,
          });
        } else {
          await api.createPayment(payload);
        }
      }
      await loadData();
      closeModal();
    } catch (error) {
      console.error('Failed to save payment:', error);
    }
  };

  const openModal = (payment?: Payment) => {
    if (payment) {
      setEditingPayment(payment);
      setIsInstallment(false);
      setFormData({
        name: payment.name,
        description: payment.description,
        amount: payment.amount,
        frequency: payment.frequency,
        next_date: payment.next_date,
        account_id: payment.account_id,
        is_active: payment.is_active,
        category: payment.category,
        category_id: undefined,
        subcategory_id: undefined,
        project_id: payment.project_id || 0
      });
    } else {
      setEditingPayment(null);
      setIsInstallment(false);
      setInstallmentData({ total_amount: 0, months: 12 });
      setFormData({
        name: '',
        description: '',
        amount: 0,
        frequency: 'Monthly',
        next_date: '',
        account_id: accounts[0]?.id || 1,
        is_active: true,
        category: '',
        category_id: undefined,
        subcategory_id: undefined,
        project_id: isProOrExempt ? 0 : 0
      });
    }
    setCategoryError(null);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setEditingPayment(null);
    setCategoryError(null);
  };

  const deletePayment = async (id: number) => {
    try {
      await api.deletePayment(id);
      await loadData();
    } catch (error) {
      console.error('Failed to delete payment:', error);
    }
  };

  const togglePaymentStatus = async (id: number) => {
    const payment = payments.find(p => p.id === id);
    if (payment) {
      try {
        await api.updatePayment(id, { ...payment, is_active: !payment.is_active });
        await loadData();
      } catch (error) {
        console.error('Failed to toggle payment status:', error);
      }
    }
  };

  const getFrequencyVariant = (frequency: Payment['frequency']): StatusBadgeVariant => {
    switch (frequency) {
      case 'Weekly': return 'success';
      case 'Monthly': return 'info';
      case 'Quarterly': return 'warning';
      case 'Yearly': return 'neutral';
    }
  };

  const getPaymentStatusVariant = (payment: Payment): StatusBadgeVariant => {
    const nextPayment = calculateNextPayment(payment.next_date);
    if (payment.is_active && nextPayment === 'Overdue') return 'overdue';
    return payment.is_active ? 'active' : 'paused';
  };

  const getDueTextClassName = (nextPayment: string) => {
    if (nextPayment === t('payments.status.overdue') || nextPayment === 'Overdue') {
      return 'text-red-600 dark:text-red-300';
    }
    if (nextPayment === t('common.today') || nextPayment === 'Today') {
      return 'text-amber-600 dark:text-amber-300';
    }
    return 'text-slate-500 dark:text-slate-400';
  };

  const calculateNextPayment = (next_date: string) => {
    // Handle invalid or missing dates
    if (!next_date || next_date === 'null' || next_date === 'undefined' || next_date === '') {
      return 'No date set';
    }
    
    const today = new Date();
    const paymentDate = new Date(next_date);
    
    // Check if the date is valid
    if (isNaN(paymentDate.getTime())) {
      console.error('Invalid date format:', next_date);
      return 'Invalid date';
    }
    
    const diffTime = paymentDate.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays < 0) return 'Overdue';
    if (diffDays === 0) return 'Today';
    if (diffDays === 1) return 'Tomorrow';
    return `${diffDays} days`;
  };

  const handleProcessOverdue = async () => {
    try {
      const result = await api.processOverduePayments();
      if (result.success) {
        alert(`Processed ${result.processed_count} overdue payments successfully!`);
        await loadData(); // Reload data to show updated balances and next dates
      }
    } catch (error) {
      console.error('Failed to process overdue payments:', error);
      alert('Failed to process overdue payments. Please try again.');
    }
  };

  const activePayments = payments.filter(p => p.is_active).length;
  const pausedPayments = payments.filter(p => !p.is_active).length;
  const monthlyTotal = Number(payments.filter(p => p.is_active && p.frequency === 'Monthly')
    .reduce((sum, p) => sum + (Number(p.amount) || 0), 0) || 0);
  const dueThisWeek = payments.filter(p => {
    const nextDate = new Date(p.next_date);
    const nextWeek = new Date();
    nextWeek.setDate(nextWeek.getDate() + 7);
    return p.is_active && nextDate <= nextWeek;
  }).length;
  const fieldClassName = 'w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:disabled:bg-slate-900 dark:disabled:text-slate-500 dark:focus:border-blue-400 dark:focus:ring-blue-400/20';
  const modalLabelClassName = 'mb-1.5 block text-sm font-semibold text-slate-700 dark:text-slate-300';
  const statAccent = {
    active: 'green',
    paused: 'amber',
    total: 'blue',
    due: 'red',
  } satisfies Record<string, StatCardAccent>;

  if (loading) {
    return (
      <LoadingState className="min-h-[60vh]" label="Loading payments..." />
    );
  }

  if (error) {
    return (
      <EmptyState title={error} />
    );
  }

  try {
    return (
    <div className="space-y-8">
      <PageHeader
        title={t('payments.title')}
        subtitle={t('payments.subtitle')}
        actions={
          <>
            <ActionButton
              type="button"
              variant="success"
              onClick={handleProcessOverdue}
              iconLeft={<Play className="h-4 w-4" />}
            >
              {t('payments.processOverdue')}
            </ActionButton>
            <ActionButton
              type="button"
              onClick={() => openModal()}
              iconLeft={<Plus className="h-4 w-4" />}
            >
              {t('payments.add')}
            </ActionButton>
          </>
        }
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title={t('payments.card.active')}
          value={activePayments}
          icon={<Play className="h-5 w-5" />}
          accent={statAccent.active}
        />
        <StatCard
          title={t('payments.card.paused')}
          value={pausedPayments}
          icon={<Pause className="h-5 w-5" />}
          accent={statAccent.paused}
        />
        <StatCard
          title={t('payments.card.monthlyTotal')}
          value={`$${monthlyTotal.toLocaleString(locale, { minimumFractionDigits: 2 })}`}
          icon={<DollarSign className="h-5 w-5" />}
          accent={statAccent.total}
        />
        <StatCard
          title={t('payments.card.dueThisWeek')}
          value={dueThisWeek}
          icon={<Calendar className="h-5 w-5" />}
          accent={statAccent.due}
        />
      </div>

      <DataTableShell>
        {payments.length === 0 ? (
          <EmptyState
            icon={<Plus className="h-6 w-6" />}
            title={t('payments.subtitle')}
            action={
              <ActionButton
                type="button"
                onClick={() => openModal()}
                iconLeft={<Plus className="h-4 w-4" />}
              >
                {t('payments.add')}
              </ActionButton>
            }
          />
        ) : (
          <table className="min-w-[1120px] divide-y divide-slate-200 dark:divide-white/10">
            <thead className="bg-slate-50 dark:bg-slate-950">
              <tr>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('payments.table.payment')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('payments.table.amount')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('payments.table.frequency')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('payments.table.nextPayment')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('payments.table.account')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('payments.table.project')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('payments.table.status')}
                </th>
                <th className="px-6 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('payments.table.actions')}
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 bg-white dark:divide-white/10 dark:bg-slate-900">
              {payments.map((payment) => {
                const nextPayment = calculateNextPayment(payment.next_date);
                return (
                  <tr key={payment.id} className="transition hover:bg-blue-50/40 dark:hover:bg-blue-500/10">
                    <td className="px-6 py-5">
                      <div className="min-w-60">
                        <div className="font-semibold text-slate-950 dark:text-white">{payment.name}</div>
                        {payment.description && (
                          <div className="mt-1 text-sm text-slate-500 dark:text-slate-400">{payment.description}</div>
                        )}
                        <div className="mt-2 flex flex-wrap items-center gap-2">
                          {payment.category && (
                            <span className="rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1 text-xs font-semibold text-slate-700 dark:border-white/10 dark:bg-white/10 dark:text-slate-200">
                              {payment.category}
                            </span>
                          )}
                          {payment.installments_total ? (
                            <StatusBadge variant={payment.is_active && (payment.installments_remaining ?? 0) > 0 ? 'info' : 'neutral'}>
                              {Math.max(payment.installments_remaining ?? 0, 0)} / {payment.installments_total} {t('payments.left')}
                            </StatusBadge>
                          ) : null}
                        </div>
                      </div>
                    </td>
                    <td className="whitespace-nowrap px-6 py-5 text-sm font-bold text-slate-950 dark:text-white">
                      ${(payment.amount || 0).toLocaleString(locale, { minimumFractionDigits: 2 })}
                    </td>
                    <td className="whitespace-nowrap px-6 py-5">
                      <StatusBadge variant={getFrequencyVariant(payment.frequency)}>
                        {t(`payments.frequency.${payment.frequency.toLowerCase()}`)}
                      </StatusBadge>
                    </td>
                    <td className="whitespace-nowrap px-6 py-5 text-sm text-slate-950 dark:text-white">
                      <div>
                        {payment.next_date ? new Date(payment.next_date).toLocaleDateString(locale) : t('payments.noDate')}
                        <div className={`mt-1 text-xs font-medium ${getDueTextClassName(nextPayment)}`}>
                          {nextPayment}
                        </div>
                      </div>
                    </td>
                    <td className="whitespace-nowrap px-6 py-5 text-sm text-slate-500 dark:text-slate-400">
                      {payment.account_name}
                    </td>
                    <td className="whitespace-nowrap px-6 py-5 text-sm text-slate-500 dark:text-slate-400">
                      {payment.project_name || t('payments.noProject')}
                    </td>
                    <td className="whitespace-nowrap px-6 py-5">
                      <StatusBadge variant={getPaymentStatusVariant(payment)}>
                        {payment.is_active ? t('payments.status.active') : t('payments.status.paused')}
                      </StatusBadge>
                    </td>
                    <td className="whitespace-nowrap px-6 py-5 text-right text-sm font-medium">
                      <div className="flex justify-end gap-2">
                        <ActionButton
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => togglePaymentStatus(payment.id)}
                          className={`h-9 w-9 ${payment.is_active ? 'text-amber-600 hover:text-amber-700 dark:text-amber-300 dark:hover:text-amber-200' : 'text-emerald-600 hover:text-emerald-700 dark:text-emerald-300 dark:hover:text-emerald-200'}`}
                          title={payment.is_active ? t('payments.tooltip.pause') : t('payments.tooltip.activate')}
                          aria-label={payment.is_active ? t('payments.tooltip.pause') : t('payments.tooltip.activate')}
                        >
                          {payment.is_active ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                        </ActionButton>
                        <ActionButton
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => openModal(payment)}
                          className="h-9 w-9 text-blue-600 hover:text-blue-700 dark:text-blue-300 dark:hover:text-blue-200"
                          aria-label={t('payments.modal.edit')}
                        >
                          <Edit2 className="h-4 w-4" />
                        </ActionButton>
                        <ActionButton
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => deletePayment(payment.id)}
                          className="h-9 w-9 text-red-600 hover:text-red-700 dark:text-red-300 dark:hover:text-red-200"
                          aria-label={t('payments.table.actions')}
                        >
                          <Trash2 className="h-4 w-4" />
                        </ActionButton>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </DataTableShell>

      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-lg overflow-hidden rounded-2xl border border-white/60 bg-white shadow-2xl shadow-slate-950/20 dark:border-white/10 dark:bg-slate-900">
            <div className="border-b border-slate-200 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">
                {editingPayment ? t('payments.modal.edit') : t('payments.modal.new')}
              </h2>
            </div>

            <form onSubmit={handleSubmit} className="max-h-[calc(100vh-10rem)] space-y-4 overflow-y-auto px-5 py-5">
              <div>
                <label className={modalLabelClassName}>
                  {t('payments.form.name')}
                </label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({...formData, name: e.target.value})}
                  className={fieldClassName}
                />
              </div>
              
              <div>
                <label className={modalLabelClassName}>
                  {t('payments.form.description')}
                </label>
                <input
                  type="text"
                  value={formData.description}
                  onChange={(e) => setFormData({...formData, description: e.target.value})}
                  className={fieldClassName}
                />
              </div>
              
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label className={modalLabelClassName}>
                    {t('payments.form.amount')}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    required={!isInstallment}
                    value={formData.amount}
                    onChange={(e) => setFormData({...formData, amount: Number(e.target.value)})}
                    className={fieldClassName}
                    disabled={isInstallment}
                  />
                </div>
                
                <div>
                  <label className={modalLabelClassName}>
                    {t('payments.form.frequency')}
                  </label>
                  <select
                    value={formData.frequency}
                    onChange={(e) => setFormData({...formData, frequency: e.target.value as Payment['frequency']})}
                    className={fieldClassName}
                    disabled={isInstallment}
                  >
                    <option value="Weekly">Weekly</option>
                    <option value="Monthly">Monthly</option>
                    <option value="Quarterly">Quarterly</option>
                    <option value="Yearly">Yearly</option>
                  </select>
                </div>
              </div>
              
              {/* Installments toggle for Credit accounts (create flow only) */}
              {!editingPayment && (
                <div className="mt-2 rounded-2xl border border-slate-200 bg-slate-50/80 p-4 dark:border-white/10 dark:bg-slate-950/50">
                  <label className="flex items-center gap-2 text-sm font-semibold text-slate-700 dark:text-slate-300">
                    <input
                      type="checkbox"
                      checked={isInstallment}
                      onChange={(e) => setIsInstallment(e.target.checked)}
                      className="h-4 w-4 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
                    />
                    Create as credit installment plan
                  </label>
                  {isInstallment && (
                    <div className="mt-3 grid gap-4 sm:grid-cols-2">
                      <div>
                        <label className={modalLabelClassName}>
                          Total Amount
                        </label>
                        <input
                          type="number"
                          required
                          value={installmentData.total_amount}
                          onChange={(e) => setInstallmentData({...installmentData, total_amount: Number(e.target.value)})}
                          className={fieldClassName}
                        />
                      </div>
                      <div>
                        <label className={modalLabelClassName}>
                          Months
                        </label>
                        <input
                          type="number"
                          min={1}
                          required
                          value={installmentData.months}
                          onChange={(e) => setInstallmentData({...installmentData, months: Number(e.target.value)})}
                          className={fieldClassName}
                        />
                      </div>
                      <div className="text-xs leading-5 text-slate-500 dark:text-slate-400 sm:col-span-2">
                        {t('payments.installmentsNote')}
                      </div>
                    </div>
                  )}
                </div>
              )}

              <div>
                <label className={modalLabelClassName}>
                  {t('payments.form.category')}
                </label>
                {expenseCategories.length === 0 ? (
                  <input
                    type="text"
                    value={formData.category}
                    onChange={(e) => {
                      setFormData({
                        ...formData,
                        category: e.target.value,
                        category_id: undefined,
                        subcategory_id: undefined,
                      });
                      setCategoryError(null);
                    }}
                    required
                    className={fieldClassName}
                    placeholder={t('payments.form.category')}
                  />
                ) : (
                  <CategoryPicker
                    categories={expenseCategories}
                    value={categorySelection}
                    fallbackLabel={formData.category}
                    placeholder={t('payments.form.selectCategory')}
                    onChange={(selection) => {
                      if (!selection) {
                        setFormData({
                          ...formData,
                          category: '',
                          category_id: undefined,
                          subcategory_id: undefined,
                        });
                        setCategoryError(t('categories.errorRequired'));
                        return;
                      }
                      setFormData({
                        ...formData,
                        category: selection.subcategory?.name ?? selection.category?.name ?? '',
                        category_id: selection.category?.id,
                        subcategory_id: selection.subcategory?.id ?? undefined,
                      });
                      setCategoryError(null);
                    }}
                  />
                )}
                {categoryError && (
                  <p className="mt-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm font-medium text-red-700 dark:border-red-400/20 dark:bg-red-500/10 dark:text-red-300">{categoryError}</p>
                )}
                <button
                  type="button"
                  onClick={() => navigate('/categories')}
                  className="mt-2 text-sm font-semibold text-blue-600 transition hover:text-blue-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 dark:text-blue-300 dark:hover:text-blue-200"
                >
                  {t('categories.manageLink')}
                </button>
              </div>
              
              <div>
                <label className={modalLabelClassName}>
                  {t('payments.form.nextDate')}
                </label>
                <input
                  type="date"
                  required
                  value={formData.next_date}
                  onChange={(e) => setFormData({...formData, next_date: e.target.value})}
                  className={fieldClassName}
                />
              </div>
              
              <div>
                <label className={modalLabelClassName}>
                  {t('payments.form.account')}
                </label>
                <select
                  value={formData.account_id}
                  onChange={(e) => setFormData({...formData, account_id: Number(e.target.value)})}
                  className={fieldClassName}
                >
                  {accounts.map(account => (
                    <option key={account.id} value={account.id}>{account.name}</option>
                  ))}
                </select>
              </div>

              <div>
                <div className="flex items-center justify-between">
                  <label className={modalLabelClassName}>
                    {t('payments.form.projectOpt')}
                  </label>
                </div>
                {!isProOrExempt && (
                  <div className="mb-2">
                    <ProUpgradeBanner featureLabel="Projects integration" variant="inline" />
                  </div>
                )}
                <select
                  value={formData.project_id}
                  onChange={(e) => setFormData({...formData, project_id: Number(e.target.value)})}
                  disabled={!isProOrExempt}
                  className={`${fieldClassName} ${!isProOrExempt ? 'cursor-not-allowed opacity-60' : ''}`}
                >
                  <option value={0}>{t('payments.noProject')}</option>
                  {projects.map(project => (
                    <option key={project.id} value={project.id}>{project.name}</option>
                  ))}
                </select>
              </div>
              
              <div className="flex items-center rounded-2xl border border-slate-200 bg-slate-50/80 px-3 py-2 dark:border-white/10 dark:bg-slate-950/50">
                <input
                  type="checkbox"
                  id="isActive"
                  checked={formData.is_active}
                  onChange={(e) => setFormData({...formData, is_active: e.target.checked})}
                  className="h-4 w-4 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
                />
                <label htmlFor="isActive" className="ml-2 block text-sm font-medium text-slate-900 dark:text-slate-100">
                  {t('payments.form.activePayment')}
                </label>
              </div>
              
              <div className="flex flex-col-reverse gap-3 pt-3 sm:flex-row sm:justify-end">
                <ActionButton
                  type="button"
                  variant="outline"
                  onClick={closeModal}
                >
                  {t('common.cancel')}
                </ActionButton>
                <ActionButton type="submit">
                  {editingPayment ? t('payments.form.update') : t('payments.form.create')} {t('payments.add')}
                </ActionButton>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
  } catch (renderError) {
    console.error('Render error in Payments component:', renderError);
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-red-600 dark:text-red-400">
          Error rendering payments: {renderError instanceof Error ? renderError.message : 'Unknown error'}
        </div>
      </div>
    );
  }
}
