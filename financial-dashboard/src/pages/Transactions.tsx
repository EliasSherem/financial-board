import { useState, useEffect, useMemo } from 'react';
import { Plus, Edit2, Trash2, Filter } from 'lucide-react';
import { api } from '../utils/api';
import { formatDate } from '../utils/date';
import { useI18n } from '../contexts/I18nContext';
import { CategoryPicker } from '../components/CategoryPicker';
import type { CategorySelection } from '../components/CategoryPicker';
import type { ExpenseCategory } from '../types/expense';
import { useNavigate } from 'react-router-dom';
import {
  ActionButton,
  DataTableShell,
  EmptyState,
  FilterBar,
  LoadingState,
  PageHeader,
  StatusBadge,
} from '../components/ui';

interface Transaction {
  id: number;
  date: string;
  description: string;
  amount: number;
  type: 'Income' | 'Expense' | 'Transfer';
  category: string;
  category_id?: number | null;
  subcategory_id?: number | null;
  category_name?: string | null;
  subcategory_name?: string | null;
  account_id: number;
  account_name?: string;
  project_id?: number;
  project_name?: string;
}

interface Account {
  id: number;
  name: string;
  type: string;
  balance: number;
}

interface Project {
  id: number;
  name: string;
  status: string;
}

export default function Transactions() {
  const { t, locale } = useI18n();
  const navigate = useNavigate();
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [expenseCategories, setExpenseCategories] = useState<ExpenseCategory[]>([]);
  const [categoryError, setCategoryError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const categoryPromise = api.getExpenseCategories().catch(() => []);
      const projectsPromise = api.getProjects().catch((error: any) => {
        if (typeof error?.message === 'string' && error.message.toLowerCase().includes('pro plan')) {
          return [];
        }
        console.warn('Projects unavailable:', error);
        return [];
      });
      const [transData, accData, projData, catData] = await Promise.all([
        api.getTransactions(),
        api.getAccounts(),
        projectsPromise,
        categoryPromise
      ]);
      setTransactions(transData);
      setAccounts(accData);
      setProjects(Array.isArray(projData) ? projData : []);
      if (Array.isArray(catData)) {
        const normalized = (catData as ExpenseCategory[]).map((cat) => ({
          ...cat,
          subcategories: [...(cat.subcategories ?? [])].sort((a, b) =>
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
    } finally {
      setLoading(false);
    }
  };
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingTransaction, setEditingTransaction] = useState<Transaction | null>(null);
  const [filter, setFilter] = useState({
    type: '',
    category: '',
    account: ''
  });
  const [formData, setFormData] = useState({
    date: '',
    description: '',
    amount: 0,
    type: 'Expense' as Transaction['type'],
    category: '',
    category_id: undefined as number | undefined,
    subcategory_id: undefined as number | undefined,
    account_id: 1,
    project_id: undefined as number | undefined
  });

  const categoryLookup = useMemo(() => {
    const map = new Map<string, ExpenseCategory>();
    expenseCategories.forEach((category) => {
      map.set(category.name.toLowerCase(), category);
    });
    return map;
  }, [expenseCategories]);

  const subcategoryLookup = useMemo(() => {
    const map = new Map<string, { id: number; categoryId: number }>();
    expenseCategories.forEach((category) => {
      category.subcategories?.forEach((sub) => {
        map.set(sub.name.toLowerCase(), { id: sub.id, categoryId: category.id });
      });
    });
    return map;
  }, [expenseCategories]);

  const filteredTransactions = useMemo(() => {
    const categoryFilter = filter.category.trim();
    const normalizedFilter = categoryFilter.toLowerCase();
    const selectedCategory = normalizedFilter ? categoryLookup.get(normalizedFilter) : undefined;
    const selectedSubcategory =
      normalizedFilter && !selectedCategory ? subcategoryLookup.get(normalizedFilter) : undefined;

    return transactions.filter((transaction) => {
      if (filter.type && transaction.type !== filter.type) return false;
      if (filter.account && transaction.account_id.toString() !== filter.account) return false;

      if (categoryFilter) {
        if (selectedCategory) {
          return transaction.category_id === selectedCategory.id;
        }
        if (selectedSubcategory) {
          return transaction.subcategory_id === selectedSubcategory.id;
        }
        const txnCategory = (transaction.category ?? '').toLowerCase();
        return txnCategory === normalizedFilter;
      }
      return true;
    });
  }, [transactions, filter, categoryLookup, subcategoryLookup]);

  const categoryOptions = useMemo(() => {
    const labels = new Set<string>();
    expenseCategories.forEach((category) => {
      if (category.name) labels.add(category.name);
      category.subcategories?.forEach((sub) => {
        if (sub.name) labels.add(sub.name);
      });
    });
    if (labels.size === 0) {
      transactions.forEach((transaction) => {
        if (transaction.category) labels.add(transaction.category);
      });
    }
    return Array.from(labels).sort((a, b) =>
      a.localeCompare(b, locale, { sensitivity: 'base' })
    );
  }, [expenseCategories, transactions, locale]);

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
    
    const transactionData = {
      ...formData,
      category_id: formData.category_id ?? null,
      subcategory_id: formData.subcategory_id ?? null,
      project_id: formData.project_id ?? null,
      type: formData.type, // Already in correct format
      amount: formData.type === 'Expense' ? -Math.abs(formData.amount) : Math.abs(formData.amount)
    };

    try {
      if (editingTransaction) {
        await api.updateTransaction(editingTransaction.id, transactionData);
      } else {
        await api.createTransaction(transactionData);
      }
      await loadData();
      closeModal();
    } catch (error) {
      console.error('Failed to save transaction:', error);
    }
  };

  const openModal = (transaction?: Transaction) => {
    if (transaction) {
      setEditingTransaction(transaction);
      setFormData({
        date: transaction.date,
        description: transaction.description,
        amount: Math.abs(transaction.amount),
        type: transaction.type,
        category: transaction.category,
        category_id: transaction.category_id ?? undefined,
        subcategory_id: transaction.subcategory_id ?? undefined,
        account_id: transaction.account_id,
        project_id: transaction.project_id ?? undefined
      });
    } else {
      setEditingTransaction(null);
      setFormData({
        date: '',
        description: '',
        amount: 0,
        type: 'Expense',
        category: '',
        category_id: undefined,
        subcategory_id: undefined,
        account_id: accounts[0]?.id || 1,
        project_id: undefined
      });
    }
    setCategoryError(null);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setEditingTransaction(null);
    setCategoryError(null);
  };

  const deleteTransaction = async (id: number) => {
    try {
      await api.deleteTransaction(id);
      await loadData();
    } catch (error) {
      console.error('Failed to delete transaction:', error);
    }
  };

  const fieldClassName = 'w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-blue-400 dark:focus:ring-blue-400/20';
  const filterSelectClassName = 'min-w-[160px] rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 dark:focus:border-blue-400 dark:focus:ring-blue-400/20';
  const modalLabelClassName = 'mb-1.5 block text-sm font-semibold text-slate-700 dark:text-slate-300';

  if (loading && transactions.length === 0) {
    return (
      <LoadingState
        className="min-h-[60vh]"
        label={`${t('common.loading')} ${t('transactions.title').toLowerCase()}...`}
      />
    );
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title={t('transactions.title')}
        subtitle={t('transactions.subtitle')}
        actions={
          <ActionButton
            type="button"
            onClick={() => openModal()}
            iconLeft={<Plus className="h-4 w-4" />}
          >
            {t('transactions.add')}
          </ActionButton>
        }
      />

      <FilterBar>
        <div className="flex items-center gap-2 self-center sm:self-auto">
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-blue-50 text-blue-600 dark:bg-blue-500/10 dark:text-blue-300">
            <Filter className="h-4 w-4" aria-hidden="true" />
          </span>
          <span className="text-sm font-semibold text-slate-700 dark:text-slate-300">
            {t('transactions.filters')}
          </span>
        </div>

        <select
          value={filter.type}
          onChange={(e) => setFilter({...filter, type: e.target.value})}
          className={filterSelectClassName}
        >
          <option value="">{t('transactions.allTypes')}</option>
          <option value="Income">{t('transactions.income')}</option>
          <option value="Expense">{t('transactions.expense')}</option>
        </select>

        <select
          value={filter.category}
          onChange={(e) => setFilter({...filter, category: e.target.value})}
          className={filterSelectClassName}
        >
          <option value="">All Categories</option>
          {categoryOptions.map((cat) => (
            <option key={cat} value={cat}>{cat}</option>
          ))}
        </select>

        <select
          value={filter.account}
          onChange={(e) => setFilter({...filter, account: e.target.value})}
          className={filterSelectClassName}
        >
          <option value="">{t('transactions.allAccounts')}</option>
          {accounts.map(account => (
            <option key={account.id} value={account.id.toString()}>{account.name}</option>
          ))}
        </select>

        <ActionButton
          type="button"
          variant="ghost"
          size="sm"
          onClick={() => setFilter({ type: '', category: '', account: '' })}
          className="self-center"
        >
          {t('transactions.clearFilters')}
        </ActionButton>
      </FilterBar>

      <DataTableShell>
        {filteredTransactions.length === 0 ? (
          <EmptyState
            icon={<Plus className="h-6 w-6" />}
            title={t('transactions.subtitle')}
            action={
              <ActionButton
                type="button"
                onClick={() => openModal()}
                iconLeft={<Plus className="h-4 w-4" />}
              >
                {t('transactions.add')}
              </ActionButton>
            }
          />
        ) : (
          <table className="min-w-[980px] divide-y divide-slate-200 dark:divide-white/10">
            <thead className="bg-slate-50 dark:bg-slate-950">
              <tr>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('transactions.table.date')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('transactions.table.description')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('transactions.table.category')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('transactions.table.account')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('transactions.table.project')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('transactions.table.amount')}
                </th>
                <th className="px-6 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('transactions.table.actions')}
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 bg-white dark:divide-white/10 dark:bg-slate-900">
              {filteredTransactions.map((transaction) => {
                const categoryLabel = transaction.category_name || transaction.category;
                const subcategoryLabel = transaction.subcategory_name;
                const typeLabel =
                  transaction.type === 'Income'
                    ? t('transactions.income')
                    : transaction.type === 'Expense'
                      ? t('transactions.expense')
                      : transaction.type;
                const typeVariant =
                  transaction.type === 'Income'
                    ? 'success'
                    : transaction.type === 'Expense'
                      ? 'danger'
                      : 'neutral';

                return (
                  <tr key={transaction.id} className="transition hover:bg-blue-50/40 dark:hover:bg-blue-500/10">
                    <td className="whitespace-nowrap px-6 py-5 text-sm font-medium text-slate-700 dark:text-slate-300">
                      {formatDate(transaction.date)}
                    </td>
                    <td className="px-6 py-5">
                      <div className="min-w-56">
                        <div className="font-semibold text-slate-950 dark:text-white">{transaction.description}</div>
                        <div className="mt-1">
                          <StatusBadge variant={typeVariant}>
                            {typeLabel}
                          </StatusBadge>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-5">
                      <div className="flex min-w-40 flex-wrap items-center gap-2">
                        <span className="rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1 text-xs font-semibold text-slate-700 dark:border-white/10 dark:bg-white/10 dark:text-slate-200">
                          {categoryLabel}
                        </span>
                        {subcategoryLabel && (
                          <span className="rounded-full border border-blue-200 bg-blue-50 px-2.5 py-1 text-xs font-semibold text-blue-700 dark:border-blue-400/20 dark:bg-blue-500/10 dark:text-blue-300">
                            {subcategoryLabel}
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="whitespace-nowrap px-6 py-5 text-sm text-slate-500 dark:text-slate-400">
                      {transaction.account_name}
                    </td>
                    <td className="whitespace-nowrap px-6 py-5 text-sm text-slate-500 dark:text-slate-400">
                      {transaction.project_name || '-'}
                    </td>
                    <td className="whitespace-nowrap px-6 py-5">
                      <span className={`text-sm font-bold tabular-nums ${
                        transaction.amount > 0 ? 'text-emerald-600 dark:text-emerald-300' : 'text-red-600 dark:text-red-300'
                      }`}>
                        {transaction.amount > 0 ? '+' : ''}${Math.abs(transaction.amount).toLocaleString(locale, { minimumFractionDigits: 2 })}
                      </span>
                    </td>
                    <td className="whitespace-nowrap px-6 py-5 text-right text-sm font-medium">
                      <div className="flex justify-end gap-2">
                        <ActionButton
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => openModal(transaction)}
                          aria-label={t('transactions.modal.edit')}
                          className="h-9 w-9 text-blue-600 hover:text-blue-700 dark:text-blue-300 dark:hover:text-blue-200"
                        >
                          <Edit2 className="h-4 w-4" />
                        </ActionButton>
                        <ActionButton
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => deleteTransaction(transaction.id)}
                          aria-label={t('transactions.table.actions')}
                          className="h-9 w-9 text-red-600 hover:text-red-700 dark:text-red-300 dark:hover:text-red-200"
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
        <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-lg overflow-hidden rounded-2xl border border-white/60 bg-white shadow-2xl shadow-slate-950/20 dark:border-white/10 dark:bg-slate-900">
            <div className="border-b border-slate-200 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">
                {editingTransaction ? t('transactions.modal.edit') : t('transactions.modal.new')}
              </h2>
            </div>

            <form onSubmit={handleSubmit} className="max-h-[calc(100vh-11rem)] space-y-4 overflow-y-auto px-5 py-5">
              <div>
                <label className={modalLabelClassName}>
                  {t('transactions.form.date')}
                </label>
                <input
                  type="date"
                  required
                  value={formData.date}
                  onChange={(e) => setFormData({...formData, date: e.target.value})}
                  className={fieldClassName}
                />
              </div>
              
              <div>
                <label className={modalLabelClassName}>
                  {t('transactions.form.description')}
                </label>
                <input
                  type="text"
                  required
                  value={formData.description}
                  onChange={(e) => setFormData({...formData, description: e.target.value})}
                  className={fieldClassName}
                />
              </div>
              
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label className={modalLabelClassName}>
                    {t('transactions.form.type')}
                  </label>
                  <select
                    value={formData.type}
                    onChange={(e) => setFormData({...formData, type: e.target.value as Transaction['type']})}
                    className={fieldClassName}
                  >
                    <option value="Income">{t('transactions.income')}</option>
                    <option value="Expense">{t('transactions.expense')}</option>
                  </select>
                </div>
                
                <div>
                  <label className={modalLabelClassName}>
                    {t('transactions.form.amount')}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={formData.amount}
                    onChange={(e) => setFormData({...formData, amount: Number(e.target.value)})}
                    className={fieldClassName}
                  />
                </div>
              </div>
              
              <div>
                <label className={modalLabelClassName}>
                  {t('transactions.form.category')}
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
                    placeholder={t('transactions.form.category')}
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
                  {t('transactions.form.account')}
                </label>
                <select
                  value={formData.account_id}
                  onChange={(e) => setFormData({...formData, account_id: Number(e.target.value)})}
                  className={fieldClassName}
                  required
                >
                  {accounts.map(account => (
                    <option key={account.id} value={account.id}>{account.name}</option>
                  ))}
                </select>
              </div>
              
              <div>
                <label className={modalLabelClassName}>
                  {t('transactions.form.projectOpt')}
                </label>
                <select
                  value={formData.project_id || ''}
                  onChange={(e) => setFormData({...formData, project_id: e.target.value ? Number(e.target.value) : undefined})}
                  className={fieldClassName}
                >
                  <option value="">{t('transactions.form.noProject')}</option>
                  {projects.filter(p => p.status === 'Active').map(project => (
                    <option key={project.id} value={project.id}>{project.name}</option>
                  ))}
                </select>
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
                  {editingTransaction ? t('transactions.form.update') : t('transactions.form.create')} {t('transactions.title')}
                </ActionButton>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
