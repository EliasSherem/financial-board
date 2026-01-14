import { useState, useEffect, useMemo } from 'react';
import { Plus, Edit2, Trash2, Filter } from 'lucide-react';
import { api } from '../utils/api';
import { formatDate } from '../utils/date';
import { useI18n } from '../contexts/I18nContext';
import { CategoryPicker } from '../components/CategoryPicker';
import type { CategorySelection } from '../components/CategoryPicker';
import type { ExpenseCategory } from '../types/expense';
import { useNavigate } from 'react-router-dom';

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
  const [, setLoading] = useState(true);

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

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">{t('transactions.title')}</h1>
          <p className="text-gray-600 dark:text-gray-400">{t('transactions.subtitle')}</p>
        </div>
        <button
          onClick={() => openModal()}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" />
          {t('transactions.add')}
        </button>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-lg p-4 shadow-sm">
        <div className="flex flex-wrap gap-4 items-center">
          <div className="flex items-center gap-2">
            <Filter className="h-4 w-4 text-gray-500" />
            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">{t('transactions.filters')}</span>
          </div>
          
          <select
            value={filter.type}
            onChange={(e) => setFilter({...filter, type: e.target.value})}
            className="border border-gray-300 dark:border-gray-600 rounded-md px-3 py-1 text-sm dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="">{t('transactions.allTypes')}</option>
            <option value="Income">{t('transactions.income')}</option>
            <option value="Expense">{t('transactions.expense')}</option>
          </select>
          
          <select
            value={filter.category}
            onChange={(e) => setFilter({...filter, category: e.target.value})}
            className="border border-gray-300 dark:border-gray-600 rounded-md px-3 py-1 text-sm dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="">All Categories</option>
            {categoryOptions.map((cat) => (
              <option key={cat} value={cat}>{cat}</option>
            ))}
          </select>
          
          <select
            value={filter.account}
            onChange={(e) => setFilter({...filter, account: e.target.value})}
            className="border border-gray-300 dark:border-gray-600 rounded-md px-3 py-1 text-sm dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="">{t('transactions.allAccounts')}</option>
            {accounts.map(account => (
              <option key={account.id} value={account.id.toString()}>{account.name}</option>
            ))}
          </select>
          
          <button
            onClick={() => setFilter({ type: '', category: '', account: '' })}
            className="text-sm text-blue-600 hover:text-blue-800"
          >
            {t('transactions.clearFilters')}
          </button>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('transactions.table.date')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('transactions.table.description')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('transactions.table.category')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('transactions.table.account')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('transactions.table.project')}
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {t('transactions.table.amount')}
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {t('transactions.table.actions')}
                </th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              {filteredTransactions.map((transaction) => (
                <tr key={transaction.id} className="hover:bg-gray-50 dark:hover:bg-gray-700">
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                    {formatDate(transaction.date)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900 dark:text-gray-100">{transaction.description}</div>
                    <div className={`text-xs ${transaction.type === 'Income' ? 'text-green-600' : 'text-red-600'}`}>
                      {transaction.type === 'Income' ? t('transactions.income') : t('transactions.expense')}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {transaction.category}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {transaction.account_name}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {transaction.project_name || '-'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`text-sm font-semibold ${
                      transaction.amount > 0 ? 'text-green-600' : 'text-red-600'
                    }`}>
                      {transaction.amount > 0 ? '+' : ''}${Math.abs(transaction.amount).toLocaleString(locale, { minimumFractionDigits: 2 })}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => openModal(transaction)}
                        className="text-blue-600 hover:text-blue-900"
                      >
                        <Edit2 className="h-4 w-4" />
                      </button>
                      <button
                        onClick={() => deleteTransaction(transaction.id)}
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
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4 text-gray-900 dark:text-gray-100">
              {editingTransaction ? t('transactions.modal.edit') : t('transactions.modal.new')}
            </h2>
            
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  {t('transactions.form.date')}
                </label>
                <input
                  type="date"
                  required
                  value={formData.date}
                  onChange={(e) => setFormData({...formData, date: e.target.value})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  {t('transactions.form.description')}
                </label>
                <input
                  type="text"
                  required
                  value={formData.description}
                  onChange={(e) => setFormData({...formData, description: e.target.value})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    {t('transactions.form.type')}
                  </label>
                  <select
                    value={formData.type}
                    onChange={(e) => setFormData({...formData, type: e.target.value as Transaction['type']})}
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                  >
                    <option value="Income">{t('transactions.income')}</option>
                    <option value="Expense">{t('transactions.expense')}</option>
                  </select>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    {t('transactions.form.amount')}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={formData.amount}
                    onChange={(e) => setFormData({...formData, amount: Number(e.target.value)})}
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                  />
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
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
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
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
                  {t('transactions.form.account')}
                </label>
                <select
                  value={formData.account_id}
                  onChange={(e) => setFormData({...formData, account_id: Number(e.target.value)})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                  required
                >
                  {accounts.map(account => (
                    <option key={account.id} value={account.id}>{account.name}</option>
                  ))}
                </select>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  {t('transactions.form.projectOpt')}
                </label>
                <select
                  value={formData.project_id || ''}
                  onChange={(e) => setFormData({...formData, project_id: e.target.value ? Number(e.target.value) : undefined})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                >
                  <option value="">{t('transactions.form.noProject')}</option>
                  {projects.filter(p => p.status === 'Active').map(project => (
                    <option key={project.id} value={project.id}>{project.name}</option>
                  ))}
                </select>
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
                  {editingTransaction ? t('transactions.form.update') : t('transactions.form.create')} {t('transactions.title')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
