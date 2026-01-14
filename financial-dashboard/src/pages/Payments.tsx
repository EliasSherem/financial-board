import { useState, useEffect, useMemo } from 'react';
import { Plus, Edit2, Trash2, Calendar, DollarSign, Play, Pause } from 'lucide-react';
import { api } from '../utils/api';
import ProUpgradeBanner from '../components/ProUpgradeBanner';
import { useI18n } from '../contexts/I18nContext';
import { CategoryPicker } from '../components/CategoryPicker';
import type { CategorySelection } from '../components/CategoryPicker';
import type { ExpenseCategory } from '../types/expense';
import { useNavigate } from 'react-router-dom';

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

  const getFrequencyColor = (frequency: Payment['frequency']) => {
    switch (frequency) {
      case 'Weekly': return 'bg-green-100 text-green-800';
      case 'Monthly': return 'bg-blue-100 text-blue-800';
      case 'Quarterly': return 'bg-yellow-100 text-yellow-800';
      case 'Yearly': return 'bg-purple-100 text-purple-800';
    }
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

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-gray-600 dark:text-gray-400">Loading payments...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-red-600 dark:text-red-400">{error}</div>
      </div>
    );
  }

  try {
    return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">{t('payments.title')}</h1>
          <p className="text-gray-600 dark:text-gray-400">{t('payments.subtitle')}</p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={handleProcessOverdue}
            className="bg-green-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-green-700"
          >
            <Play className="h-4 w-4" />
            {t('payments.processOverdue')}
          </button>
          <button
            onClick={() => openModal()}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700"
          >
            <Plus className="h-4 w-4" />
            {t('payments.add')}
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">{t('payments.card.active')}</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-gray-100">{payments.filter(p => p.is_active).length}</p>
            </div>
            <Play className="h-12 w-12 text-green-500" />
          </div>
        </div>
        
        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">{t('payments.card.paused')}</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-gray-100">{payments.filter(p => !p.is_active).length}</p>
            </div>
            <Pause className="h-12 w-12 text-yellow-500" />
          </div>
        </div>
        
        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">{t('payments.card.monthlyTotal')}</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-gray-100">
                ${Number(payments.filter(p => p.is_active && p.frequency === 'Monthly')
                  .reduce((sum, p) => sum + (Number(p.amount) || 0), 0) || 0).toLocaleString(locale, { minimumFractionDigits: 2 })}
              </p>
            </div>
            <DollarSign className="h-12 w-12 text-blue-500" />
          </div>
        </div>
        
        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">{t('payments.card.dueThisWeek')}</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-gray-100">
                {payments.filter(p => {
                  const nextDate = new Date(p.next_date);
                  const nextWeek = new Date();
                  nextWeek.setDate(nextWeek.getDate() + 7);
                  return p.is_active && nextDate <= nextWeek;
                }).length}
              </p>
            </div>
            <Calendar className="h-12 w-12 text-red-500" />
          </div>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('payments.table.payment')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('payments.table.amount')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('payments.table.frequency')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('payments.table.nextPayment')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('payments.table.account')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('payments.table.project')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('payments.table.status')}
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('payments.table.actions')}
                </th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              {payments.map((payment) => (
                <tr key={payment.id} className="hover:bg-gray-50 dark:hover:bg-gray-700">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div>
                      <div className="text-sm font-medium text-gray-900 dark:text-gray-100">{payment.name}</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400">{payment.description}</div>
                      <div className="text-xs text-gray-400 dark:text-gray-500">{payment.category}</div>
                      {payment.installments_total ? (
                        <div className="mt-1">
                          <span className={`inline-flex px-2 py-0.5 text-xs font-semibold rounded-full ${
                            payment.is_active && (payment.installments_remaining ?? 0) > 0
                              ? 'bg-purple-100 text-purple-800'
                              : 'bg-gray-100 text-gray-700'
                          }`}>
                          {Math.max(payment.installments_remaining ?? 0, 0)} / {payment.installments_total} {t('payments.left')}
                          </span>
                        </div>
                      ) : null}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                    ${(payment.amount || 0).toLocaleString(locale, { minimumFractionDigits: 2 })}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getFrequencyColor(payment.frequency)}`}>
                      {t(`payments.frequency.${payment.frequency.toLowerCase()}`)}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                    <div>
                      {payment.next_date ? new Date(payment.next_date).toLocaleDateString(locale) : t('payments.noDate')}
                      <div className={`text-xs ${
                        calculateNextPayment(payment.next_date) === t('payments.status.overdue') ? 'text-red-600 dark:text-red-400' :
                        calculateNextPayment(payment.next_date) === t('common.today') ? 'text-orange-600 dark:text-orange-400' :
                        'text-gray-500 dark:text-gray-400'
                      }`}>
                        {calculateNextPayment(payment.next_date)}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {payment.account_name}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {payment.project_name || t('payments.noProject')}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                      payment.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                    }`}>
                      {payment.is_active ? t('payments.status.active') : t('payments.status.paused')}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => togglePaymentStatus(payment.id)}
                        className={`${payment.is_active ? 'text-yellow-600 hover:text-yellow-900' : 'text-green-600 hover:text-green-900'}`}
                        title={payment.is_active ? t('payments.tooltip.pause') : t('payments.tooltip.activate')}
                      >
                        {payment.is_active ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                      </button>
                      <button
                        onClick={() => openModal(payment)}
                        className="text-blue-600 hover:text-blue-900"
                      >
                        <Edit2 className="h-4 w-4" />
                      </button>
                      <button
                        onClick={() => deletePayment(payment.id)}
                        className="text-red-600 hover:text-red-900"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {isModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center z-50 overflow-y-auto p-4">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-md max-h-[90vh] overflow-y-auto shadow-lg">
            <h2 className="text-lg font-semibold mb-4 text-gray-900 dark:text-gray-100">
              {editingPayment ? t('payments.modal.edit') : t('payments.modal.new')}
            </h2>
            
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  {t('payments.form.name')}
                </label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({...formData, name: e.target.value})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  {t('payments.form.description')}
                </label>
                <input
                  type="text"
                  value={formData.description}
                  onChange={(e) => setFormData({...formData, description: e.target.value})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    {t('payments.form.amount')}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    required={!isInstallment}
                    value={formData.amount}
                    onChange={(e) => setFormData({...formData, amount: Number(e.target.value)})}
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                    disabled={isInstallment}
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    {t('payments.form.frequency')}
                  </label>
                  <select
                    value={formData.frequency}
                    onChange={(e) => setFormData({...formData, frequency: e.target.value as Payment['frequency']})}
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
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
                <div className="mt-2 p-3 border rounded-md border-gray-200 dark:border-gray-700">
                  <label className="flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300">
                    <input
                      type="checkbox"
                      checked={isInstallment}
                      onChange={(e) => setIsInstallment(e.target.checked)}
                      className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                    />
                    Create as credit installment plan
                  </label>
                  {isInstallment && (
                    <div className="grid grid-cols-2 gap-4 mt-3">
                      <div>
                        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                          Total Amount
                        </label>
                        <input
                          type="number"
                          required
                          value={installmentData.total_amount}
                          onChange={(e) => setInstallmentData({...installmentData, total_amount: Number(e.target.value)})}
                          className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                          Months
                        </label>
                        <input
                          type="number"
                          min={1}
                          required
                          value={installmentData.months}
                          onChange={(e) => setInstallmentData({...installmentData, months: Number(e.target.value)})}
                          className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                        />
                      </div>
                      <div className="col-span-2 text-xs text-gray-500 dark:text-gray-400">
                        {t('payments.installmentsNote')}
                      </div>
                    </div>
                  )}
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
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
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
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
                  <p className="mt-1 text-sm text-red-500">{categoryError}</p>
                )}
                <button
                  type="button"
                  onClick={() => navigate('/categories')}
                  className="mt-2 text-sm font-medium text-blue-600 hover:text-blue-500"
                >
                  {t('categories.manageLink')}
                </button>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  {t('payments.form.nextDate')}
                </label>
                <input
                  type="date"
                  required
                  value={formData.next_date}
                  onChange={(e) => setFormData({...formData, next_date: e.target.value})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  {t('payments.form.account')}
                </label>
                <select
                  value={formData.account_id}
                  onChange={(e) => setFormData({...formData, account_id: Number(e.target.value)})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                >
                  {accounts.map(account => (
                    <option key={account.id} value={account.id}>{account.name}</option>
                  ))}
                </select>
              </div>

              <div>
                <div className="flex items-center justify-between">
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
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
                  className={`w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100 ${!isProOrExempt ? 'opacity-60 cursor-not-allowed' : ''}`}
                >
                  <option value={0}>{t('payments.noProject')}</option>
                  {projects.map(project => (
                    <option key={project.id} value={project.id}>{project.name}</option>
                  ))}
                </select>
              </div>
              
              <div className="flex items-center">
                <input
                  type="checkbox"
                  id="isActive"
                  checked={formData.is_active}
                  onChange={(e) => setFormData({...formData, is_active: e.target.checked})}
                  className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
                <label htmlFor="isActive" className="ml-2 block text-sm text-gray-900 dark:text-gray-100">
                  {t('payments.form.activePayment')}
                </label>
              </div>
              
              <div className="flex justify-end gap-3 pt-4">
                <button
                  type="button"
                  onClick={closeModal}
                  className="px-4 py-2 text-gray-700 dark:text-gray-300 bg-gray-200 dark:bg-gray-700 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600"
                >
                  {t('common.cancel')}
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                  {editingPayment ? t('payments.form.update') : t('payments.form.create')} {t('payments.add')}
                </button>
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

