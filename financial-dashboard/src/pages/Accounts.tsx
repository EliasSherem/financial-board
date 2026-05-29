import { useState, useEffect } from 'react';
import { Plus, Edit2, Trash2, ArrowRightLeft, Wallet, TrendingUp, DollarSign } from 'lucide-react';
import { api } from '../utils/api';
import { useI18n } from '../contexts/I18nContext';
import {
  ActionButton,
  AppCard,
  DataTableShell,
  EmptyState,
  LoadingState,
  PageHeader,
  StatCard,
  StatusBadge,
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

export default function Accounts() {
  const { t, locale } = useI18n();
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isTransferModalOpen, setIsTransferModalOpen] = useState(false);
  const [isDetailOpen, setIsDetailOpen] = useState(false);
  const [detailAccount, setDetailAccount] = useState<Account | null>(null);
  const [detailTransactions, setDetailTransactions] = useState<any[]>([]);
  const [detailLoading, setDetailLoading] = useState(false);
  const [editingAccount, setEditingAccount] = useState<Account | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    type: 'Checking' as Account['type'],
    balance: 0,
    account_number: '',
    bank_name: '',
    is_active: true
  });
  const [transferData, setTransferData] = useState({
    fromAccountId: 0,
    toAccountId: 0,
    amount: 0,
    description: ''
  });

  useEffect(() => {
    loadAccounts();
  }, []);

  const loadAccounts = async () => {
    try {
      setLoading(true);
      const data = await api.getAccounts();
      setAccounts(data);
    } catch (error) {
      console.error('Failed to load accounts:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      if (editingAccount) {
        await api.updateAccount(editingAccount.id, formData);
      } else {
        await api.createAccount(formData);
      }
      await loadAccounts();
      closeModal();
    } catch (error: any) {
      console.error('Failed to save account:', error);
      alert(error?.message || 'Failed to save account. Please try again.');
    }
  };

  const handleTransfer = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (transferData.fromAccountId === transferData.toAccountId) {
      alert('Cannot transfer to the same account');
      return;
    }

    const fromAccount = accounts.find(a => a.id === transferData.fromAccountId);
    const toAccount = accounts.find(a => a.id === transferData.toAccountId);

    if (!fromAccount || !toAccount) {
      alert('Invalid account selection');
      return;
    }

    if (fromAccount.balance < transferData.amount) {
      alert('Insufficient funds');
      return;
    }

    try {
      // Create transaction records for the transfer (server updates balances based on amounts)
      const transferDate = new Date().toISOString().split('T')[0];
      
      await api.createTransaction({
        account_id: transferData.fromAccountId,
        date: transferDate,
        description: `Transfer to ${toAccount.name}: ${transferData.description || 'Fund transfer'}`,
        amount: -transferData.amount,
        type: 'Transfer',
        category: 'Fund transfer'
      });

      await api.createTransaction({
        account_id: transferData.toAccountId,
        date: transferDate,
        description: `Transfer from ${fromAccount.name}: ${transferData.description || 'Fund transfer'}`,
        amount: transferData.amount,
        type: 'Transfer',
        category: 'Fund transfer'
      });

      await loadAccounts();
      closeTransferModal();
    } catch (error) {
      console.error('Failed to transfer funds:', error);
      alert('Failed to transfer funds. Please try again.');
    }
  };

  const openModal = (account?: Account) => {
    if (account) {
      setEditingAccount(account);
      setFormData({
        name: account.name,
        type: account.type,
        balance: account.balance,
        account_number: account.account_number,
        bank_name: account.bank_name,
        is_active: account.is_active
      });
    } else {
      setEditingAccount(null);
      setFormData({
        name: '',
        type: 'Checking',
        balance: 0,
        account_number: '',
        bank_name: '',
        is_active: true
      });
    }
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setEditingAccount(null);
  };

  const openTransferModal = () => {
    if (accounts.length < 2) {
      alert('You need at least 2 accounts to transfer funds');
      return;
    }
    setTransferData({
      fromAccountId: accounts[0]?.id || 0,
      toAccountId: accounts[1]?.id || 0,
      amount: 0,
      description: ''
    });
    setIsTransferModalOpen(true);
  };

  const closeTransferModal = () => {
    setIsTransferModalOpen(false);
  };

  const deleteAccount = async (id: number) => {
    if (confirm('Are you sure you want to delete this account?')) {
      try {
        await api.deleteAccount(id);
        await loadAccounts();
      } catch (error) {
        console.error('Failed to delete account:', error);
        alert('Failed to delete account. Please try again.');
      }
    }
  };

  const openAccountDetail = async (account: Account) => {
    try {
      setDetailLoading(true);
      setDetailAccount(account);
      setIsDetailOpen(true);
      // Fetch this month's transactions for the account
      const all = await api.getTransactions();
      const now = new Date();
      const y = now.getFullYear();
      const m = String(now.getMonth() + 1).padStart(2, '0');
      const ym = `${y}-${m}-`;
      const filtered = (all as any[])
        .filter(t => t.account_id === account.id && typeof t.date === 'string' && t.date.startsWith(ym))
        .sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : b.id - a.id));
      setDetailTransactions(filtered);
    } catch (err) {
      console.error('Failed to load account details:', err);
    } finally {
      setDetailLoading(false);
    }
  };

  const closeAccountDetail = () => {
    setIsDetailOpen(false);
    setDetailAccount(null);
    setDetailTransactions([]);
  };

  const getAccountTypeVariant = (type: Account['type']): 'info' | 'success' | 'neutral' | 'warning' | 'danger' => {
    switch (type) {
      case 'Checking': return 'info';
      case 'Savings': return 'success';
      case 'Business': return 'neutral';
      case 'Investment': return 'warning';
      case 'Credit': return 'danger';
    }
  };

  const totalBalance = accounts.reduce((sum, account) => sum + Number(account.balance), 0);
  const activeAccounts = accounts.filter(account => account.is_active).length;
  const fieldClassName = 'w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-blue-400 dark:focus:ring-blue-400/20';

  if (loading) {
    return (
      <LoadingState className="min-h-[60vh]" label={t('common.loading')} />
    );
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title={t('sidebar.accounts')}
        subtitle={t('accounts.subtitle')}
        actions={
          <>
            <ActionButton
              type="button"
              variant="success"
              onClick={openTransferModal}
              iconLeft={<ArrowRightLeft className="h-4 w-4" />}
            >
              {t('accounts.transferFunds')}
            </ActionButton>
            <ActionButton
              type="button"
              onClick={() => openModal()}
              iconLeft={<Plus className="h-4 w-4" />}
            >
              {t('dashboard.addAccount')}
            </ActionButton>
          </>
        }
      />

      <div className="grid grid-cols-1 gap-5 md:grid-cols-3">
        <StatCard
          title={t('dashboard.totalBalance')}
          value={`$${totalBalance.toLocaleString(locale, { minimumFractionDigits: 2 })}`}
          icon={<DollarSign className="h-5 w-5" />}
          accent="blue"
        />
        <StatCard
          title={t('accounts.activeAccounts')}
          value={activeAccounts}
          icon={<Wallet className="h-5 w-5" />}
          accent="green"
        />
        <StatCard
          title={t('accounts.highestBalance')}
          value={`$${accounts.length > 0 ? Math.max(...accounts.map(a => Number(a.balance))).toLocaleString(locale, { minimumFractionDigits: 2 }) : '0.00'}`}
          icon={<TrendingUp className="h-5 w-5" />}
          accent="amber"
        />
      </div>

      {accounts.length === 0 ? (
        <AppCard variant="subtle">
          <EmptyState
            icon={<Wallet className="h-6 w-6" />}
            title={t('accounts.subtitle')}
            action={
              <ActionButton
                type="button"
                onClick={() => openModal()}
                iconLeft={<Plus className="h-4 w-4" />}
              >
                {t('dashboard.addAccount')}
              </ActionButton>
            }
          />
        </AppCard>
      ) : (
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2 xl:grid-cols-3">
          {accounts.map((account) => (
            <AppCard
              key={account.id}
              variant="interactive"
              className="cursor-pointer"
              onClick={() => openAccountDetail(account)}
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <h3 className="truncate text-lg font-semibold text-slate-950 dark:text-white">{account.name}</h3>
                  <div className="mt-1 space-y-1 text-sm text-slate-500 dark:text-slate-400">
                    {account.bank_name && <p className="truncate">{account.bank_name}</p>}
                    {account.account_number && <p className="truncate">{account.account_number}</p>}
                  </div>
                </div>
                <StatusBadge variant={getAccountTypeVariant(account.type)}>
                  {account.type}
                </StatusBadge>
              </div>
              
              <div className="mt-6 rounded-2xl border border-slate-200/80 bg-slate-50/70 p-4 dark:border-white/10 dark:bg-white/[0.04]">
                <p className="text-sm font-medium text-slate-500 dark:text-slate-400">{t('accounts.currentBalance')}</p>
                <p className="mt-2 overflow-hidden text-ellipsis whitespace-nowrap text-2xl font-bold tracking-tight text-slate-950 dark:text-white">
                  ${Number(account.balance).toLocaleString(locale, { minimumFractionDigits: 2 })}
                </p>
              </div>
              
              <div className="mt-5 flex items-center justify-between gap-4">
                <StatusBadge variant={account.is_active ? 'active' : 'paused'}>
                  {account.is_active ? 'Active' : 'Inactive'}
                </StatusBadge>
                
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={(e) => { e.stopPropagation(); openModal(account); }}
                    className="inline-flex h-9 w-9 items-center justify-center rounded-xl text-blue-600 transition hover:bg-blue-50 hover:text-blue-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 dark:text-blue-300 dark:hover:bg-blue-500/10 dark:hover:text-blue-200"
                    title="Edit Account"
                    aria-label="Edit Account"
                  >
                    <Edit2 className="h-4 w-4" aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    onClick={(e) => { e.stopPropagation(); deleteAccount(account.id); }}
                    className="inline-flex h-9 w-9 items-center justify-center rounded-xl text-red-600 transition hover:bg-red-50 hover:text-red-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-500 dark:text-red-300 dark:hover:bg-red-500/10 dark:hover:text-red-200"
                    title="Delete Account"
                    aria-label="Delete Account"
                  >
                    <Trash2 className="h-4 w-4" aria-hidden="true" />
                  </button>
                </div>
              </div>
            </AppCard>
          ))}
        </div>
      )}

      {isDetailOpen && detailAccount && (
        <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-3xl overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-[0_30px_90px_rgba(15,23,42,0.24)] dark:border-white/10 dark:bg-slate-900 dark:shadow-black/40">
            <div className="flex items-start justify-between gap-4 border-b border-slate-200/80 px-5 py-4 dark:border-white/10">
              <div>
                <h2 className="text-xl font-semibold text-slate-950 dark:text-white">{detailAccount.name}</h2>
                <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
                  {[detailAccount.bank_name, detailAccount.account_number].filter(Boolean).join(' • ') || '—'}
                </p>
              </div>
              <button
                type="button"
                onClick={closeAccountDetail}
                className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-slate-500 transition hover:bg-slate-100 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 dark:text-slate-400 dark:hover:bg-white/10 dark:hover:text-white"
                aria-label="Close account details"
              >
                ✕
              </button>
            </div>

            <div className="max-h-[calc(100vh-8rem)] overflow-y-auto px-5 py-5">
              <div className="mb-6 rounded-2xl border border-slate-200/80 bg-slate-50/70 p-4 dark:border-white/10 dark:bg-white/[0.04]">
                <p className="text-sm font-medium text-slate-500 dark:text-slate-400">Current Balance</p>
                <p className="mt-2 overflow-hidden text-ellipsis whitespace-nowrap text-3xl font-bold tracking-tight text-slate-950 dark:text-white">${Number(detailAccount.balance).toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
              </div>

              <h3 className="mb-3 text-lg font-semibold text-slate-950 dark:text-white">This Month's Transactions</h3>
              {detailLoading ? (
                <LoadingState className="min-h-40" label="Loading..." />
              ) : detailTransactions.length === 0 ? (
                <EmptyState title="No transactions this month." />
              ) : (
                <DataTableShell>
                <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                  <thead className="bg-slate-50 dark:bg-slate-950">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Date</th>
                      <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Description</th>
                      <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Type</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Amount</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-200 bg-white dark:divide-white/10 dark:bg-slate-900">
                    {detailTransactions.map((t) => (
                      <tr key={t.id} className="transition hover:bg-blue-50/40 dark:hover:bg-blue-500/10">
                        <td className="whitespace-nowrap px-4 py-3 text-sm text-slate-600 dark:text-slate-300">{new Date(t.date).toLocaleDateString('en-GB')}</td>
                        <td className="px-4 py-3 text-sm text-slate-700 dark:text-slate-300">{t.description}</td>
                        <td className="whitespace-nowrap px-4 py-3 text-sm">
                          <StatusBadge variant={t.type === 'Income' ? 'success' : t.type === 'Transfer' ? 'info' : 'danger'}>
                            {t.type}
                          </StatusBadge>
                        </td>
                        <td className={`whitespace-nowrap px-4 py-3 text-right text-sm font-semibold ${t.type === 'Income' ? 'text-emerald-600 dark:text-emerald-300' : 'text-red-600 dark:text-red-300'}`}>
                          {Number(t.amount).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                </DataTableShell>
              )}
            </div>
          </div>
        </div>
      )}

      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-[0_30px_90px_rgba(15,23,42,0.24)] dark:border-white/10 dark:bg-slate-900 dark:shadow-black/40">
            <div className="border-b border-slate-200/80 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">
                {editingAccount ? 'Edit Account' : 'Add New Account'}
              </h2>
            </div>
            
            <form onSubmit={handleSubmit} className="max-h-[calc(100vh-11rem)] space-y-4 overflow-y-auto px-5 py-5">
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  Account Name
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
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  Account Type
                </label>
                <select
                  value={formData.type}
                  onChange={(e) => setFormData({...formData, type: e.target.value as Account['type']})}
                  className={fieldClassName}
                >
                  <option value="Checking">Checking</option>
                  <option value="Savings">Savings</option>
                  <option value="Business">Business</option>
                  <option value="Investment">Investment</option>
                  <option value="Credit">Credit</option>
                </select>
              </div>
              
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  Initial Balance
                </label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={formData.balance}
                  onChange={(e) => setFormData({...formData, balance: Number(e.target.value)})}
                  className={fieldClassName}
                />
              </div>
              
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  Bank Name (Optional)
                </label>
                <input
                  type="text"
                  value={formData.bank_name}
                  onChange={(e) => setFormData({...formData, bank_name: e.target.value})}
                  className={fieldClassName}
                />
              </div>
              
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  Account Number (last 4 digits, Optional)
                </label>
                <input
                  type="text"
                  placeholder="****1234"
                  value={formData.account_number}
                  onChange={(e) => setFormData({...formData, account_number: e.target.value})}
                  className={fieldClassName}
                />
              </div>
              
              <div className="flex items-center">
                <input
                  type="checkbox"
                  id="isActive"
                  checked={formData.is_active}
                  onChange={(e) => setFormData({...formData, is_active: e.target.checked})}
                  className="h-4 w-4 rounded border-slate-300 text-blue-600 focus:ring-blue-500 dark:border-slate-700"
                />
                <label htmlFor="isActive" className="ml-2 block text-sm text-slate-900 dark:text-slate-100">
                  Active Account
                </label>
              </div>
              
              <div className="flex flex-col-reverse gap-2 border-t border-slate-200/80 pt-4 dark:border-white/10 sm:flex-row sm:justify-end">
                <ActionButton
                  type="button"
                  variant="outline"
                  onClick={closeModal}
                >
                  Cancel
                </ActionButton>
                <ActionButton
                  type="submit"
                >
                  {editingAccount ? 'Update' : 'Create'} Account
                </ActionButton>
              </div>
            </form>
          </div>
        </div>
      )}

      {isTransferModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-[0_30px_90px_rgba(15,23,42,0.24)] dark:border-white/10 dark:bg-slate-900 dark:shadow-black/40">
            <div className="border-b border-slate-200/80 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">Transfer Funds</h2>
            </div>
            
            <form onSubmit={handleTransfer} className="max-h-[calc(100vh-11rem)] space-y-4 overflow-y-auto px-5 py-5">
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  From Account
                </label>
                <select
                  value={transferData.fromAccountId}
                  onChange={(e) => setTransferData({...transferData, fromAccountId: Number(e.target.value)})}
                  className={fieldClassName}
                >
                  {accounts.map(account => (
                    <option key={account.id} value={account.id}>
                      {account.name} - ${Number(account.balance).toLocaleString(locale, { minimumFractionDigits: 2 })}
                    </option>
                  ))}
                </select>
              </div>
              
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  To Account
                </label>
                <select
                  value={transferData.toAccountId}
                  onChange={(e) => setTransferData({...transferData, toAccountId: Number(e.target.value)})}
                  className={fieldClassName}
                >
                  {accounts.map(account => (
                    <option key={account.id} value={account.id}>
                      {account.name} - ${Number(account.balance).toLocaleString(locale, { minimumFractionDigits: 2 })}
                    </option>
                  ))}
                </select>
              </div>
              
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  Transfer Amount
                </label>
                <input
                  type="number"
                  step="0.01"
                  required
                  min="0.01"
                  value={transferData.amount}
                  onChange={(e) => setTransferData({...transferData, amount: Number(e.target.value)})}
                  className={fieldClassName}
                />
              </div>
              
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  Description (Optional)
                </label>
                <input
                  type="text"
                  placeholder="Transfer description..."
                  value={transferData.description}
                  onChange={(e) => setTransferData({...transferData, description: e.target.value})}
                  className={fieldClassName}
                />
              </div>
              
              <div className="flex flex-col-reverse gap-2 border-t border-slate-200/80 pt-4 dark:border-white/10 sm:flex-row sm:justify-end">
                <ActionButton
                  type="button"
                  variant="outline"
                  onClick={closeTransferModal}
                >
                  Cancel
                </ActionButton>
                <ActionButton
                  type="submit"
                  variant="success"
                >
                  Transfer Funds
                </ActionButton>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
