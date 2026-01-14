import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, DollarSign, X, Edit2, Trash2 } from 'lucide-react';
import { api } from '../utils/api';
import ProUpgradeBanner from '../components/ProUpgradeBanner';
import { formatDate } from '../utils/date';
import { useI18n } from '../contexts/I18nContext';

interface Customer { id: number; name: string; email?: string; }
interface Account { id: number; name: string; }
interface Project { id: number; name: string; }
interface Invoice {
  id: number;
  customer_id: number;
  customer_name?: string;
  project_id?: number | null;
  account_id?: number | null;
  number?: string | null;
  issue_date: string;
  due_date: string;
  status: 'draft' | 'sent' | 'partial' | 'paid' | 'void';
  currency: string;
  subtotal: number; tax: number; discount: number; total: number; amount_due: number;
}

export default function Invoices() {
  const { t, locale } = useI18n();
  const user = (() => { try { return JSON.parse(localStorage.getItem('user') || '{}'); } catch { return {}; } })();
  const isProOrExempt = Boolean(user?.is_pro) || user?.id === 1 || user?.id === 3;
  if (!isProOrExempt) {
    return <ProUpgradeBanner featureLabel="Invoices" variant="page" />;
  }
  const navigate = useNavigate();
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [, setError] = useState<string | null>(null);

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isPaymentOpen, setIsPaymentOpen] = useState(false);
  const [editingInvoice, setEditingInvoice] = useState<Invoice | null>(null);
  const [paymentInvoice, setPaymentInvoice] = useState<Invoice | null>(null);
  const [isCustomerModalOpen, setIsCustomerModalOpen] = useState(false);
  const [customerForm, setCustomerForm] = useState({ name: '', email: '' });
  const [, setEditingCustomer] = useState<Customer | null>(null);
  const [customerQuery, setCustomerQuery] = useState('');
  const [showCustomerList, setShowCustomerList] = useState(false);

  const [formData, setFormData] = useState({
    customer_id: 0,
    project_id: 0,
    number: '',
    issue_date: new Date().toISOString().slice(0, 10),
    due_date: new Date(Date.now() + 7*24*3600*1000).toISOString().slice(0,10),
    currency: 'MXN',
    notes: '',
    discount: 0,
    tax: 0,
    items: [ { description: '', quantity: 1, unit_price: 0 } ] as Array<{ description: string; quantity: number; unit_price: number }>
  });

  const [paymentData, setPaymentData] = useState({
    date: new Date().toISOString().slice(0,10),
    amount: 0,
    account_id: 0,
    method: '',
    reference: ''
  });

  useEffect(() => { loadAll(); }, []);

  const loadAll = async () => {
    try {
      setLoading(true);
      const [inv, cust, acc, proj] = await Promise.all([
        api.getInvoices(), api.getCustomers(), api.getAccounts(), api.getProjects()
      ]);
      setInvoices(inv);
      setCustomers(cust);
      setAccounts(acc);
      setProjects(proj);
    } catch (e) {
      console.error(e);
      setError(t('common.failedLoad') || 'Failed to load invoices');
    } finally {
      setLoading(false);
    }
  };

  const totals = useMemo(() => {
    const sub = formData.items.reduce((s, it) => s + (Number(it.quantity || 0) * Number(it.unit_price || 0)), 0);
    const subtotal = Math.round(sub * 100) / 100;
    const rawDiscount = Number(formData.discount ?? 0);
    const rawTax = Number(formData.tax ?? 0);
    const discountPercent = Number.isFinite(rawDiscount) ? Math.min(Math.max(rawDiscount, 0), 100) : 0;
    const taxPercent = Number.isFinite(rawTax) ? Math.max(rawTax, 0) : 0;
    const discountAmount = Math.round(subtotal * (discountPercent / 100) * 100) / 100;
    const taxableBase = Math.max(subtotal - discountAmount, 0);
    const taxAmount = Math.round(taxableBase * (taxPercent / 100) * 100) / 100;
    const total = Math.round((taxableBase + taxAmount) * 100) / 100;
    return { subtotal, discountPercent, discountAmount, taxPercent, taxAmount, taxableBase, total };
  }, [formData]);

  const discountPercentLabel = Number.isFinite(totals.discountPercent) ? Number(totals.discountPercent.toFixed(2)) : 0;
  const taxPercentLabel = Number.isFinite(totals.taxPercent) ? Number(totals.taxPercent.toFixed(2)) : 0;

  const getCustomerNameById = (id: number) => customers.find(c => c.id === id)?.name || '';

  const filteredCustomers = useMemo(() => {
    const q = customerQuery.trim().toLowerCase();
    if (!q) return customers;
    return customers.filter(c => c.name.toLowerCase().includes(q) || (c.email || '').toLowerCase().includes(q));
  }, [customerQuery, customers]);

  const openCreate = () => {
    setEditingInvoice(null);
    setFormData({
      customer_id: customers[0]?.id || 0,
      project_id: 0,
      number: '',
      issue_date: new Date().toISOString().slice(0, 10),
      due_date: new Date(Date.now() + 7*24*3600*1000).toISOString().slice(0,10),
      currency: 'USD',
      notes: '',
      discount: 0,
      tax: 0,
      items: [{ description: '', quantity: 1, unit_price: 0 }]
    });
    // Prefill customer search input with selected customer's name
    const name = getCustomerNameById(customers[0]?.id || 0);
    setCustomerQuery(name);
    setShowCustomerList(false);
    setIsModalOpen(true);
  };

  const openNewCustomer = () => {
    setEditingCustomer(null);
    setCustomerForm({ name: '', email: '' });
    setIsCustomerModalOpen(true);
  };

  const openEditCustomer = (c: Customer) => {
    setEditingCustomer(c);
    setCustomerForm({ name: c.name, email: c.email || '' });
    setIsCustomerModalOpen(true);
  };

  // saveCustomer handled inline in JSX; function removed to avoid unused warnings

  const openPayment = (invoice: Invoice) => {
    setPaymentInvoice(invoice);
    setPaymentData({
      date: new Date().toISOString().slice(0,10),
      amount: Math.max(Number(invoice.amount_due || 0), 0),
      account_id: accounts[0]?.id || 0,
      method: 'Card',
      reference: ''
    });
    setIsPaymentOpen(true);
  };

  const saveInvoice = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const payload = {
        ...formData,
        discount: totals.discountAmount,
        tax: totals.taxAmount,
      };
      if (editingInvoice) {
        await api.updateInvoice(editingInvoice.id, payload);
      } else {
        await api.createInvoice(payload);
      }
      await loadAll();
      setIsModalOpen(false);
    } catch (err) {
      console.error('Failed to save invoice:', err);
      alert('Failed to save invoice');
    }
  };

  // markSent previously unused; keep action wiring inline if needed

  const recordPayment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!paymentInvoice) return;
    try {
      await api.recordInvoicePayment(paymentInvoice.id, paymentData);
      await loadAll();
      setIsPaymentOpen(false);
    } catch (err) {
      console.error('Failed to record payment:', err);
      alert('Failed to record payment');
    }
  };

  // Keep customerQuery in sync when the selected customer_id changes
  useEffect(() => {
    if (formData.customer_id) {
      const name = getCustomerNameById(formData.customer_id);
      if (name) setCustomerQuery(name);
    }
  }, [formData.customer_id]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">{t('invoices.title')}</h1>
          <p className="text-gray-600 dark:text-gray-400">{t('invoices.subtitle')}</p>
        </div>
        <div className="flex gap-2">
          <button onClick={openNewCustomer} className="border border-blue-600 text-blue-600 px-4 py-2 rounded-lg hover:bg-blue-50 dark:hover:bg-gray-700">{t('invoices.newCustomer')}</button>
          <button onClick={openCreate} className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700">
            <Plus className="h-5 w-5" /> {t('invoices.newInvoice')}
          </button>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">{t('invoices.table.number')}</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">{t('invoices.table.customer')}</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">{t('invoices.table.issue')}</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">{t('invoices.table.due')}</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">{t('invoices.table.total')}</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">{t('invoices.table.amountDue')}</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">{t('invoices.table.status')}</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">{t('invoices.table.actions')}</th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              {invoices.map(inv => (
                <tr key={inv.id} className="hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer" onClick={() => navigate(`/invoices/${inv.id}`)}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">{inv.number || `#${inv.id}`}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700 dark:text-gray-300">{inv.customer_name || inv.customer_id}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700 dark:text-gray-300">{formatDate(inv.issue_date)}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700 dark:text-gray-300">{formatDate(inv.due_date)}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100 text-right">${Number(inv.total).toLocaleString(locale, { minimumFractionDigits: 2 })}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100 text-right">${Number(inv.amount_due).toLocaleString(locale, { minimumFractionDigits: 2 })}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-right">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                      inv.status === 'paid' ? 'bg-green-100 text-green-800' :
                      inv.status === 'partial' ? 'bg-yellow-100 text-yellow-800' :
                      inv.status === 'void' ? 'bg-gray-100 text-gray-800' : 'bg-blue-100 text-blue-800'
                    }`}>{t(`invoices.status.${inv.status}`)}</span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <div className="flex justify-end gap-2">
                      {inv.amount_due > 0 && (
                        <button onClick={(e) => { e.stopPropagation(); openPayment(inv); }} className="text-green-600 hover:text-green-900" title="Record Payment">
                          <DollarSign className="h-4 w-4" />
                        </button>
                      )}
                      {/* Allow deleting invoices even if paid; server will reverse side effects */}
                      {(
                        <button
                          onClick={async (e) => {
                            e.stopPropagation();
                            if (confirm('Delete this invoice? This will also remove related transactions.')) {
                              try { await api.deleteInvoice(inv.id); await loadAll(); } catch (err) { console.error(err); alert('Failed to delete invoice'); }
                            }
                          }}
                          className="text-red-600 hover:text-red-900"
                          title="Delete Invoice"
                        >
                          <X className="h-4 w-4" />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Section Divider */}
      <div className="my-8 border-t border-gray-200 dark:border-gray-700" />

      {/* Customers Management */}
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-sm overflow-hidden mt-14">
        <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Customers</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Name</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Email</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              {customers.map((c) => (
                <tr key={c.id} className="hover:bg-gray-50 dark:hover:bg-gray-700">
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">{c.name}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700 dark:text-gray-300">{c.email || '-'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <div className="flex justify-end gap-2">
                      <button onClick={() => openEditCustomer(c)} className="text-blue-600 hover:text-blue-900" title="Edit">
                        <Edit2 className="h-4 w-4" />
                      </button>
                      <button onClick={async ()=>{ if(confirm('Delete this customer?')) { try { await api.deleteCustomer(c.id); setCustomers(prev => prev.filter(x => x.id !== c.id)); } catch(err){ console.error(err); alert('Failed to delete customer'); } } }} className="text-red-600 hover:text-red-900" title="Delete">
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
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto shadow-lg">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">{editingInvoice ? 'Edit Invoice' : 'New Invoice'}</h2>
              <button onClick={() => setIsModalOpen(false)} className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"><X className="h-5 w-5"/></button>
            </div>
            <form onSubmit={saveInvoice} className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Customer</label>
                  <div className="relative">
                    <input
                      type="text"
                      placeholder="Search customer..."
                      value={customerQuery}
                      onChange={(e)=>{ setCustomerQuery(e.target.value); setShowCustomerList(true);} }
                      onFocus={()=>setShowCustomerList(true)}
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100"
                    />
                    {showCustomerList && (
                      <ul className="absolute z-20 mt-1 w-full max-h-48 overflow-y-auto bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-md shadow">
                        {filteredCustomers.length === 0 ? (
                          <li className="px-3 py-2 text-sm text-gray-500 dark:text-gray-300">No matches</li>
                        ) : (
                          filteredCustomers.map(c => (
                            <li key={c.id}
                                className="px-3 py-2 text-sm text-gray-700 dark:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-600 cursor-pointer"
                                onMouseDown={(e)=>{ e.preventDefault(); setFormData({...formData, customer_id: c.id}); setCustomerQuery(c.name); setShowCustomerList(false); }}>
                              <span className="font-medium">{c.name}</span>
                              {c.email && <span className="ml-2 text-xs text-gray-500 dark:text-gray-300">{c.email}</span>}
                            </li>
                          ))
                        )}
                      </ul>
                    )}
                  </div>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Start typing to search customers</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Project (Optional)</label>
                  <select value={formData.project_id} onChange={e=>setFormData({...formData, project_id: Number(e.target.value)})}
                          className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100">
                    <option value={0}>No project</option>
                    {projects.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Issue Date</label>
                  <input type="date" value={formData.issue_date} onChange={e=>setFormData({...formData, issue_date: e.target.value})}
                         className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100"/>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Due Date</label>
                  <input type="date" value={formData.due_date} onChange={e=>setFormData({...formData, due_date: e.target.value})}
                         className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100"/>
                </div>
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Items</label>
                  <button type="button" onClick={() => setFormData({...formData, items: [...formData.items, { description: '', quantity: 1, unit_price: 0 }]})}
                          className="text-sm text-blue-600 hover:text-blue-800">+ Add Item</button>
                </div>
                <div className="grid grid-cols-6 gap-2 text-xs font-semibold text-gray-600 dark:text-gray-300">
                  <div className="col-span-3">Description</div>
                  <div className="col-span-1">Qty</div>
                  <div className="col-span-2">Unit Price</div>
                </div>
                
                <div className="space-y-2">
                  {formData.items.map((it, idx) => (
                    <div key={idx} className="grid grid-cols-6 gap-2">
                      <input className="col-span-3 border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100" placeholder="Description"
                             value={it.description} onChange={e=>{
                               const items=[...formData.items]; items[idx] = { ...items[idx], description: e.target.value}; setFormData({...formData, items});
                             }}/>
                      <input type="number" className="col-span-1 border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100" placeholder="Qty"
                             value={it.quantity} onChange={e=>{ const items=[...formData.items]; items[idx] = { ...items[idx], quantity: Number(e.target.value)}; setFormData({...formData, items});}}/>
                      <input type="number" className="col-span-2 border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100" placeholder="Unit Price"
                             value={it.unit_price} onChange={e=>{ const items=[...formData.items]; items[idx] = { ...items[idx], unit_price: Number(e.target.value)}; setFormData({...formData, items});}}/>
                    </div>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Discount (%)</label>
                  <input
                         type="number"
                         min={0}
                         max={100}
                         step="0.01"
                         value={formData.discount}
                         onChange={e=>{
                           const value = Number(e.target.value);
                           const next = Number.isFinite(value) ? Math.min(Math.max(value, 0), 100) : 0;
                           setFormData({...formData, discount: next});
                         }}
                         className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Tax (%)</label>
                  <input
                         type="number"
                         min={0}
                         step="0.01"
                         value={formData.tax}
                         onChange={e=>{
                           const value = Number(e.target.value);
                           const next = Number.isFinite(value) ? Math.max(value, 0) : 0;
                           setFormData({...formData, tax: next});
                         }}
                         className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100" />
                </div>
                <div className="p-3 bg-gray-50 dark:bg-gray-700 rounded-md">
                  <div className="flex justify-between text-sm"><span className="text-gray-600 dark:text-gray-300">Subtotal</span><span className="font-medium text-gray-900 dark:text-gray-100">${totals.subtotal.toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
                  <div className="flex justify-between text-sm"><span className="text-gray-600 dark:text-gray-300">Discount ({discountPercentLabel}%)</span><span className="font-medium text-gray-900 dark:text-gray-100">-${totals.discountAmount.toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
                  <div className="flex justify-between text-sm"><span className="text-gray-600 dark:text-gray-300">Tax ({taxPercentLabel}%)</span><span className="font-medium text-gray-900 dark:text-gray-100">+${totals.taxAmount.toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
                  <div className="flex justify-between text-sm mt-1 border-t border-gray-200 dark:border-gray-600 pt-1"><span className="text-gray-600 dark:text-gray-300">Total</span><span className="font-semibold text-gray-900 dark:text-gray-100">${totals.total.toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
                </div>
              </div>

              <div className="flex justify-end gap-3 pt-2">
                <button type="button" onClick={()=>setIsModalOpen(false)} className="px-4 py-2 text-gray-700 dark:text-gray-300 bg-gray-200 dark:bg-gray-700 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600">Cancel</button>
                <button type="submit" className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">Save</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {isPaymentOpen && paymentInvoice && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center z-50 overflow-y-auto p-4">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-md max-h-[90vh] overflow-y-auto shadow-lg">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Record Payment</h2>
              <button onClick={() => setIsPaymentOpen(false)} className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"><X className="h-5 w-5"/></button>
            </div>
            <form onSubmit={recordPayment} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Date</label>
                <input type="date" value={paymentData.date} onChange={e=>setPaymentData({...paymentData, date: e.target.value})}
                       className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100"/>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Amount</label>
                <input type="number" step="0.01" value={paymentData.amount} onChange={e=>setPaymentData({...paymentData, amount: Number(e.target.value)})}
                       className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100"/>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Deposit Account</label>
                <select value={paymentData.account_id} onChange={e=>setPaymentData({...paymentData, account_id: Number(e.target.value)})}
                        className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100">
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
                </select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Method</label>
                  <input type="text" value={paymentData.method} onChange={e=>setPaymentData({...paymentData, method: e.target.value})}
                         className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100"/>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Reference</label>
                  <input type="text" value={paymentData.reference} onChange={e=>setPaymentData({...paymentData, reference: e.target.value})}
                         className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100"/>
                </div>
              </div>
              <div className="flex justify-end gap-3 pt-2">
                <button type="button" onClick={()=>setIsPaymentOpen(false)} className="px-4 py-2 text-gray-700 dark:text-gray-300 bg-gray-200 dark:bg-gray-700 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600">Cancel</button>
                <button type="submit" className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700">Record Payment</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {isCustomerModalOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center z-50 overflow-y-auto p-4">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-md shadow-lg">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">New Customer</h2>
              <button onClick={()=>setIsCustomerModalOpen(false)} className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"><X className="h-5 w-5"/></button>
            </div>
            <form onSubmit={async (e)=>{e.preventDefault(); try{ const c = await api.createCustomer(customerForm); setCustomers([...customers, c]); setIsCustomerModalOpen(false);}catch(err){console.error(err); alert('Failed to create customer');}}} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Name</label>
                <input type="text" required value={customerForm.name} onChange={e=>setCustomerForm({...customerForm, name: e.target.value})}
                       className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100"/>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email (optional)</label>
                <input type="email" value={customerForm.email} onChange={e=>setCustomerForm({...customerForm, email: e.target.value})}
                       className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100"/>
              </div>
              <div className="flex justify-end gap-3 pt-2">
                <button type="button" onClick={()=>setIsCustomerModalOpen(false)} className="px-4 py-2 text-gray-700 dark:text-gray-300 bg-gray-200 dark:bg-gray-700 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600">Cancel</button>
                <button type="submit" className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">Save</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}



