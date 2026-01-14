import { useState, useEffect } from 'react';
import { Plus, Edit2, Trash2, ArrowRightLeft, Wallet, TrendingUp, DollarSign } from 'lucide-react';
import { api } from '../utils/api';
import { useI18n } from '../contexts/I18nContext';

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
        type: 'Expense',
        category: 'Transfer'
      });

      await api.createTransaction({
        account_id: transferData.toAccountId,
        date: transferDate,
        description: `Transfer from ${fromAccount.name}: ${transferData.description || 'Fund transfer'}`,
        amount: transferData.amount,
        type: 'Income',
        category: 'Transfer'
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

  const getAccountTypeColor = (type: Account['type']) => {
    switch (type) {
      case 'Checking': return 'bg-blue-100 text-blue-800';
      case 'Savings': return 'bg-green-100 text-green-800';
      case 'Business': return 'bg-purple-100 text-purple-800';
      case 'Investment': return 'bg-yellow-100 text-yellow-800';
      case 'Credit': return 'bg-red-100 text-red-800';
    }
  };

  const totalBalance = accounts.reduce((sum, account) => sum + Number(account.balance), 0);
  const activeAccounts = accounts.filter(account => account.is_active).length;

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">{t('sidebar.accounts')}</h1>
          <p className="text-gray-600 dark:text-gray-400">{t('accounts.subtitle')}</p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={openTransferModal}
            className="bg-green-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-green-700"
          >
            <ArrowRightLeft className="h-4 w-4" />
            {t('accounts.transferFunds')}
          </button>
          <button
            onClick={() => openModal()}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700"
          >
            <Plus className="h-4 w-4" />
            {t('dashboard.addAccount')}
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">{t('dashboard.totalBalance')}</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-gray-100">
                ${totalBalance.toLocaleString(locale, { minimumFractionDigits: 2 })}
              </p>
            </div>
            <DollarSign className="h-12 w-12 text-blue-500" />
          </div>
        </div>
        
        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">{t('accounts.activeAccounts')}</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-gray-100">{activeAccounts}</p>
            </div>
            <Wallet className="h-12 w-12 text-green-500" />
          </div>
        </div>
        
        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">{t('accounts.highestBalance')}</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-gray-100">
                ${accounts.length > 0 ? Math.max(...accounts.map(a => Number(a.balance))).toLocaleString(locale, { minimumFractionDigits: 2 }) : '0.00'}
              </p>
            </div>
            <TrendingUp className="h-12 w-12 text-yellow-500" />
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
        {accounts.map((account) => (
          <div
            key={account.id}
            className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-200 dark:border-gray-700 cursor-pointer hover:shadow-md transition"
            onClick={() => openAccountDetail(account)}
          >
            <div className="flex justify-between items-start mb-4">
              <div>
                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">{account.name}</h3>
                {account.bank_name && (
                  <p className="text-sm text-gray-500 dark:text-gray-400">{account.bank_name}</p>
                )}
                {account.account_number && (
                  <p className="text-sm text-gray-500 dark:text-gray-400">{account.account_number}</p>
                )}
              </div>
              <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getAccountTypeColor(account.type)}`}>
                {account.type}
              </span>
            </div>
            
            <div className="mb-4">
              <p className="text-sm text-gray-600 dark:text-gray-400">{t('accounts.currentBalance')}</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                ${Number(account.balance).toLocaleString(locale, { minimumFractionDigits: 2 })}
              </p>
            </div>
            
            <div className="flex justify-between items-center">
              <div className="flex items-center">
                <div className={`w-2 h-2 rounded-full mr-2 ${account.is_active ? 'bg-green-500' : 'bg-gray-400'}`} />
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  {account.is_active ? 'Active' : 'Inactive'}
                </span>
              </div>
              
              <div className="flex gap-2">
                <button
                  onClick={(e) => { e.stopPropagation(); openModal(account); }}
                  className="text-blue-600 hover:text-blue-900"
                  title="Edit Account"
                >
                  <Edit2 className="h-4 w-4" />
                </button>
                <button
                  onClick={(e) => { e.stopPropagation(); deleteAccount(account.id); }}
                  className="text-red-600 hover:text-red-900"
                  title="Delete Account"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {isDetailOpen && detailAccount && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center z-50 overflow-y-auto p-4">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto shadow-lg">
            <div className="flex items-start justify-between mb-4">
              <div>
                <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">{detailAccount.name}</h2>
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  {[detailAccount.bank_name, detailAccount.account_number].filter(Boolean).join(' • ') || '—'}
                </p>
              </div>
              <button onClick={closeAccountDetail} className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200">✕</button>
            </div>

            <div className="mb-6">
              <p className="text-sm text-gray-600 dark:text-gray-400">Current Balance</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-gray-100">${Number(detailAccount.balance).toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
            </div>

            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-3">This Month's Transactions</h3>
            {detailLoading ? (
              <div className="text-gray-600 dark:text-gray-400">Loading...</div>
            ) : detailTransactions.length === 0 ? (
              <div className="text-gray-600 dark:text-gray-400">No transactions this month.</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                  <thead className="bg-gray-50 dark:bg-gray-900">
                    <tr>
                      <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Date</th>
                      <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Description</th>
                      <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Type</th>
                      <th className="px-4 py-2 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Amount</th>
                    </tr>
                  </thead>
                  <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                    {detailTransactions.map((t) => (
                      <tr key={t.id}>
                        <td className="px-4 py-2 text-sm text-gray-700 dark:text-gray-300">{new Date(t.date).toLocaleDateString('en-GB')}</td>
                        <td className="px-4 py-2 text-sm text-gray-700 dark:text-gray-300">{t.description}</td>
                        <td className="px-4 py-2 text-sm">
                          <span className={`px-2 py-0.5 rounded-full text-xs font-semibold ${t.type === 'Income' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                            {t.type}
                          </span>
                        </td>
                        <td className={`px-4 py-2 text-sm text-right ${t.type === 'Income' ? 'text-green-600' : 'text-red-600'}`}>
                          {Number(t.amount).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {isModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4 text-gray-900 dark:text-gray-100">
              {editingAccount ? 'Edit Account' : 'Add New Account'}
            </h2>
            
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Account Name
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
                  Account Type
                </label>
                <select
                  value={formData.type}
                  onChange={(e) => setFormData({...formData, type: e.target.value as Account['type']})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                >
                  <option value="Checking">Checking</option>
                  <option value="Savings">Savings</option>
                  <option value="Business">Business</option>
                  <option value="Investment">Investment</option>
                  <option value="Credit">Credit</option>
                </select>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Initial Balance
                </label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={formData.balance}
                  onChange={(e) => setFormData({...formData, balance: Number(e.target.value)})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Bank Name (Optional)
                </label>
                <input
                  type="text"
                  value={formData.bank_name}
                  onChange={(e) => setFormData({...formData, bank_name: e.target.value})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Account Number (last 4 digits, Optional)
                </label>
                <input
                  type="text"
                  placeholder="****1234"
                  value={formData.account_number}
                  onChange={(e) => setFormData({...formData, account_number: e.target.value})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
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
                  Active Account
                </label>
              </div>
              
              <div className="flex justify-end gap-3 pt-4">
                <button
                  type="button"
                  onClick={closeModal}
                  className="px-4 py-2 text-gray-700 dark:text-gray-300 bg-gray-200 dark:bg-gray-700 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                  {editingAccount ? 'Update' : 'Create'} Account
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {isTransferModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-md">
            <h2 className="text-lg font-semibold mb-4 text-gray-900 dark:text-gray-100">Transfer Funds</h2>
            
            <form onSubmit={handleTransfer} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  From Account
                </label>
                <select
                  value={transferData.fromAccountId}
                  onChange={(e) => setTransferData({...transferData, fromAccountId: Number(e.target.value)})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                >
                  {accounts.map(account => (
                    <option key={account.id} value={account.id}>
                      {account.name} - ${Number(account.balance).toLocaleString(locale, { minimumFractionDigits: 2 })}
                    </option>
                  ))}
                </select>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  To Account
                </label>
                <select
                  value={transferData.toAccountId}
                  onChange={(e) => setTransferData({...transferData, toAccountId: Number(e.target.value)})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                >
                  {accounts.map(account => (
                    <option key={account.id} value={account.id}>
                      {account.name} - ${Number(account.balance).toLocaleString(locale, { minimumFractionDigits: 2 })}
                    </option>
                  ))}
                </select>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Transfer Amount
                </label>
                <input
                  type="number"
                  step="0.01"
                  required
                  min="0.01"
                  value={transferData.amount}
                  onChange={(e) => setTransferData({...transferData, amount: Number(e.target.value)})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Description (Optional)
                </label>
                <input
                  type="text"
                  placeholder="Transfer description..."
                  value={transferData.description}
                  onChange={(e) => setTransferData({...transferData, description: e.target.value})}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
              
              <div className="flex justify-end gap-3 pt-4">
                <button
                  type="button"
                  onClick={closeTransferModal}
                  className="px-4 py-2 text-gray-700 dark:text-gray-300 bg-gray-200 dark:bg-gray-700 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
                >
                  Transfer Funds
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
