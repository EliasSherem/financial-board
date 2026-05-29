import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, DollarSign, X, Edit2, Trash2 } from 'lucide-react';
import { api } from '../utils/api';
import ProUpgradeBanner from '../components/ProUpgradeBanner';
import { formatDate } from '../utils/date';
import { useI18n } from '../contexts/I18nContext';
import {
  ActionButton,
  DataTableShell,
  EmptyState,
  LoadingState,
  PageHeader,
  StatusBadge,
} from '../components/ui';
import type { StatusBadgeVariant } from '../components/ui';

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

  const fieldClassName = 'w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-blue-400 dark:focus:ring-blue-400/20';
  const modalLabelClassName = 'mb-1.5 block text-sm font-semibold text-slate-700 dark:text-slate-300';
  const invoiceStatusVariant = (status: Invoice['status']): StatusBadgeVariant => {
    switch (status) {
      case 'paid':
        return 'paid';
      case 'partial':
        return 'partial';
      case 'sent':
        return 'sent';
      case 'draft':
        return 'neutral';
      case 'void':
        return 'paused';
      default:
        return 'neutral';
    }
  };

  if (loading) {
    return (
      <LoadingState className="min-h-[60vh]" label={`${t('common.loading')} ${t('invoices.title').toLowerCase()}...`} />
    );
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title={t('invoices.title')}
        subtitle={t('invoices.subtitle')}
        actions={
          <>
            <ActionButton type="button" variant="outline" onClick={openNewCustomer}>
              {t('invoices.newCustomer')}
            </ActionButton>
            <ActionButton
              type="button"
              onClick={openCreate}
              iconLeft={<Plus className="h-4 w-4" />}
            >
              {t('invoices.newInvoice')}
            </ActionButton>
          </>
        }
      />

      <DataTableShell>
        {invoices.length === 0 ? (
          <EmptyState
            icon={<Plus className="h-6 w-6" />}
            title={t('invoices.subtitle')}
            action={
              <ActionButton
                type="button"
                onClick={openCreate}
                iconLeft={<Plus className="h-4 w-4" />}
              >
                {t('invoices.newInvoice')}
              </ActionButton>
            }
          />
        ) : (
          <table className="min-w-[1080px] divide-y divide-slate-200 dark:divide-white/10">
            <thead className="bg-slate-50 dark:bg-slate-950">
              <tr>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">{t('invoices.table.number')}</th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">{t('invoices.table.customer')}</th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">{t('invoices.table.issue')}</th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">{t('invoices.table.due')}</th>
                <th className="px-6 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">{t('invoices.table.total')}</th>
                <th className="px-6 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">{t('invoices.table.amountDue')}</th>
                <th className="px-6 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">{t('invoices.table.status')}</th>
                <th className="px-6 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">{t('invoices.table.actions')}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 bg-white dark:divide-white/10 dark:bg-slate-900">
              {invoices.map(inv => (
                <tr key={inv.id} className="cursor-pointer transition hover:bg-blue-50/40 dark:hover:bg-blue-500/10" onClick={() => navigate(`/invoices/${inv.id}`)}>
                  <td className="whitespace-nowrap px-6 py-5 text-sm">
                    <div className="font-semibold text-slate-950 dark:text-white">{inv.number || `#${inv.id}`}</div>
                    <div className="mt-1 text-xs text-slate-500 dark:text-slate-400">{inv.currency}</div>
                  </td>
                  <td className="whitespace-nowrap px-6 py-5 text-sm font-medium text-slate-700 dark:text-slate-300">{inv.customer_name || inv.customer_id}</td>
                  <td className="whitespace-nowrap px-6 py-5 text-sm text-slate-500 dark:text-slate-400">{formatDate(inv.issue_date)}</td>
                  <td className="whitespace-nowrap px-6 py-5 text-sm text-slate-500 dark:text-slate-400">{formatDate(inv.due_date)}</td>
                  <td className="whitespace-nowrap px-6 py-5 text-right text-sm font-semibold text-slate-950 dark:text-white">${Number(inv.total).toLocaleString(locale, { minimumFractionDigits: 2 })}</td>
                  <td className="whitespace-nowrap px-6 py-5 text-right text-sm font-bold text-slate-950 dark:text-white">${Number(inv.amount_due).toLocaleString(locale, { minimumFractionDigits: 2 })}</td>
                  <td className="whitespace-nowrap px-6 py-5 text-right">
                    <StatusBadge variant={invoiceStatusVariant(inv.status)}>
                      {t(`invoices.status.${inv.status}`)}
                    </StatusBadge>
                  </td>
                  <td className="whitespace-nowrap px-6 py-5 text-right text-sm font-medium">
                    <div className="flex justify-end gap-2">
                      {inv.amount_due > 0 && (
                        <ActionButton
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={(e) => { e.stopPropagation(); openPayment(inv); }}
                          className="h-9 w-9 text-emerald-600 hover:text-emerald-700 dark:text-emerald-300 dark:hover:text-emerald-200"
                          title="Record Payment"
                          aria-label="Record Payment"
                        >
                          <DollarSign className="h-4 w-4" />
                        </ActionButton>
                      )}
                      {/* Allow deleting invoices even if paid; server will reverse side effects */}
                      {(
                        <ActionButton
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={async (e) => {
                            e.stopPropagation();
                            if (confirm('Delete this invoice? This will also remove related transactions.')) {
                              try { await api.deleteInvoice(inv.id); await loadAll(); } catch (err) { console.error(err); alert('Failed to delete invoice'); }
                            }
                          }}
                          className="h-9 w-9 text-red-600 hover:text-red-700 dark:text-red-300 dark:hover:text-red-200"
                          title="Delete Invoice"
                          aria-label="Delete Invoice"
                        >
                          <X className="h-4 w-4" />
                        </ActionButton>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </DataTableShell>

      <DataTableShell title="Customers">
        {customers.length === 0 ? (
          <EmptyState
            title="Customers"
            action={
              <ActionButton type="button" variant="outline" onClick={openNewCustomer}>
                {t('invoices.newCustomer')}
              </ActionButton>
            }
          />
        ) : (
          <table className="min-w-[720px] divide-y divide-slate-200 dark:divide-white/10">
            <thead className="bg-slate-50 dark:bg-slate-950">
              <tr>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Name</th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Email</th>
                <th className="px-6 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 bg-white dark:divide-white/10 dark:bg-slate-900">
              {customers.map((c) => (
                <tr key={c.id} className="transition hover:bg-blue-50/40 dark:hover:bg-blue-500/10">
                  <td className="whitespace-nowrap px-6 py-5 text-sm font-semibold text-slate-950 dark:text-white">{c.name}</td>
                  <td className="whitespace-nowrap px-6 py-5 text-sm text-slate-500 dark:text-slate-400">{c.email || '-'}</td>
                  <td className="whitespace-nowrap px-6 py-5 text-right text-sm font-medium">
                    <div className="flex justify-end gap-2">
                      <ActionButton
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => openEditCustomer(c)}
                        className="h-9 w-9 text-blue-600 hover:text-blue-700 dark:text-blue-300 dark:hover:text-blue-200"
                        title="Edit"
                        aria-label="Edit"
                      >
                        <Edit2 className="h-4 w-4" />
                      </ActionButton>
                      <ActionButton
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={async ()=>{ if(confirm('Delete this customer?')) { try { await api.deleteCustomer(c.id); setCustomers(prev => prev.filter(x => x.id !== c.id)); } catch(err){ console.error(err); alert('Failed to delete customer'); } } }}
                        className="h-9 w-9 text-red-600 hover:text-red-700 dark:text-red-300 dark:hover:text-red-200"
                        title="Delete"
                        aria-label="Delete"
                      >
                        <Trash2 className="h-4 w-4" />
                      </ActionButton>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </DataTableShell>

      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-3xl overflow-hidden rounded-2xl border border-white/60 bg-white shadow-2xl shadow-slate-950/20 dark:border-white/10 dark:bg-slate-900">
            <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">{editingInvoice ? 'Edit Invoice' : 'New Invoice'}</h2>
              <ActionButton type="button" variant="ghost" size="icon" onClick={() => setIsModalOpen(false)} aria-label="Close invoice modal" className="h-9 w-9"><X className="h-5 w-5"/></ActionButton>
            </div>
            <form onSubmit={saveInvoice} className="max-h-[calc(100vh-10rem)] space-y-5 overflow-y-auto px-5 py-5">
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label className={modalLabelClassName}>Customer</label>
                  <div className="relative">
                    <input
                      type="text"
                      placeholder="Search customer..."
                      value={customerQuery}
                      onChange={(e)=>{ setCustomerQuery(e.target.value); setShowCustomerList(true);} }
                      onFocus={()=>setShowCustomerList(true)}
                      className={fieldClassName}
                    />
                    {showCustomerList && (
                      <ul className="absolute z-20 mt-2 max-h-48 w-full overflow-y-auto rounded-xl border border-slate-200 bg-white shadow-xl shadow-slate-950/10 dark:border-white/10 dark:bg-slate-950">
                        {filteredCustomers.length === 0 ? (
                          <li className="px-3 py-2 text-sm text-slate-500 dark:text-slate-300">No matches</li>
                        ) : (
                          filteredCustomers.map(c => (
                            <li key={c.id}
                                className="cursor-pointer px-3 py-2 text-sm text-slate-700 transition hover:bg-blue-50 dark:text-slate-100 dark:hover:bg-blue-500/10"
                                onMouseDown={(e)=>{ e.preventDefault(); setFormData({...formData, customer_id: c.id}); setCustomerQuery(c.name); setShowCustomerList(false); }}>
                              <span className="font-medium">{c.name}</span>
                              {c.email && <span className="ml-2 text-xs text-slate-500 dark:text-slate-300">{c.email}</span>}
                            </li>
                          ))
                        )}
                      </ul>
                    )}
                  </div>
                  <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">Start typing to search customers</p>
                </div>
                <div>
                  <label className={modalLabelClassName}>Project (Optional)</label>
                  <select value={formData.project_id} onChange={e=>setFormData({...formData, project_id: Number(e.target.value)})}
                          className={fieldClassName}>
                    <option value={0}>No project</option>
                    {projects.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
                  </select>
                </div>
                <div>
                  <label className={modalLabelClassName}>Issue Date</label>
                  <input type="date" value={formData.issue_date} onChange={e=>setFormData({...formData, issue_date: e.target.value})}
                         className={fieldClassName}/>
                </div>
                <div>
                  <label className={modalLabelClassName}>Due Date</label>
                  <input type="date" value={formData.due_date} onChange={e=>setFormData({...formData, due_date: e.target.value})}
                         className={fieldClassName}/>
                </div>
              </div>

              <div className="space-y-3 rounded-2xl border border-slate-200 bg-slate-50/70 p-4 dark:border-white/10 dark:bg-slate-950/50">
                <div className="flex items-center justify-between">
                  <label className="text-sm font-semibold text-slate-700 dark:text-slate-300">Items</label>
                  <button type="button" onClick={() => setFormData({...formData, items: [...formData.items, { description: '', quantity: 1, unit_price: 0 }]})}
                          className="text-sm font-semibold text-blue-600 transition hover:text-blue-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 dark:text-blue-300 dark:hover:text-blue-200">+ Add Item</button>
                </div>
                <div className="grid grid-cols-6 gap-2 text-xs font-semibold text-slate-500 dark:text-slate-300">
                  <div className="col-span-3">Description</div>
                  <div className="col-span-1">Qty</div>
                  <div className="col-span-2">Unit Price</div>
                </div>
                
                <div className="space-y-2">
                  {formData.items.map((it, idx) => (
                    <div key={idx} className="grid grid-cols-6 gap-2">
                      <input className={`${fieldClassName} col-span-3`} placeholder="Description"
                             value={it.description} onChange={e=>{
                               const items=[...formData.items]; items[idx] = { ...items[idx], description: e.target.value}; setFormData({...formData, items});
                             }}/>
                      <input type="number" className={`${fieldClassName} col-span-1`} placeholder="Qty"
                             value={it.quantity} onChange={e=>{ const items=[...formData.items]; items[idx] = { ...items[idx], quantity: Number(e.target.value)}; setFormData({...formData, items});}}/>
                      <input type="number" className={`${fieldClassName} col-span-2`} placeholder="Unit Price"
                             value={it.unit_price} onChange={e=>{ const items=[...formData.items]; items[idx] = { ...items[idx], unit_price: Number(e.target.value)}; setFormData({...formData, items});}}/>
                    </div>
                  ))}
                </div>
              </div>

              <div className="grid gap-4 lg:grid-cols-3">
                <div>
                  <label className={modalLabelClassName}>Discount (%)</label>
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
                         className={fieldClassName} />
                </div>
                <div>
                  <label className={modalLabelClassName}>Tax (%)</label>
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
                         className={fieldClassName} />
                </div>
                <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4 dark:border-white/10 dark:bg-slate-950">
                  <div className="flex justify-between text-sm"><span className="text-slate-500 dark:text-slate-300">Subtotal</span><span className="font-medium text-slate-950 dark:text-white">${totals.subtotal.toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
                  <div className="flex justify-between text-sm"><span className="text-slate-500 dark:text-slate-300">Discount ({discountPercentLabel}%)</span><span className="font-medium text-slate-950 dark:text-white">-${totals.discountAmount.toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
                  <div className="flex justify-between text-sm"><span className="text-slate-500 dark:text-slate-300">Tax ({taxPercentLabel}%)</span><span className="font-medium text-slate-950 dark:text-white">+${totals.taxAmount.toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
                  <div className="mt-2 flex justify-between border-t border-slate-200 pt-2 text-sm dark:border-white/10"><span className="text-slate-500 dark:text-slate-300">Total</span><span className="font-bold text-slate-950 dark:text-white">${totals.total.toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
                </div>
              </div>

              <div className="flex flex-col-reverse gap-3 pt-2 sm:flex-row sm:justify-end">
                <ActionButton type="button" variant="outline" onClick={()=>setIsModalOpen(false)}>Cancel</ActionButton>
                <ActionButton type="submit">Save</ActionButton>
              </div>
            </form>
          </div>
        </div>
      )}

      {isPaymentOpen && paymentInvoice && (
        <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md overflow-hidden rounded-2xl border border-white/60 bg-white shadow-2xl shadow-slate-950/20 dark:border-white/10 dark:bg-slate-900">
            <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">Record Payment</h2>
              <ActionButton type="button" variant="ghost" size="icon" onClick={() => setIsPaymentOpen(false)} aria-label="Close payment modal" className="h-9 w-9"><X className="h-5 w-5"/></ActionButton>
            </div>
            <form onSubmit={recordPayment} className="max-h-[calc(100vh-10rem)] space-y-4 overflow-y-auto px-5 py-5">
              <div>
                <label className={modalLabelClassName}>Date</label>
                <input type="date" value={paymentData.date} onChange={e=>setPaymentData({...paymentData, date: e.target.value})}
                       className={fieldClassName}/>
              </div>
              <div>
                <label className={modalLabelClassName}>Amount</label>
                <input type="number" step="0.01" value={paymentData.amount} onChange={e=>setPaymentData({...paymentData, amount: Number(e.target.value)})}
                       className={fieldClassName}/>
              </div>
              <div>
                <label className={modalLabelClassName}>Deposit Account</label>
                <select value={paymentData.account_id} onChange={e=>setPaymentData({...paymentData, account_id: Number(e.target.value)})}
                        className={fieldClassName}>
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
                </select>
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label className={modalLabelClassName}>Method</label>
                  <input type="text" value={paymentData.method} onChange={e=>setPaymentData({...paymentData, method: e.target.value})}
                         className={fieldClassName}/>
                </div>
                <div>
                  <label className={modalLabelClassName}>Reference</label>
                  <input type="text" value={paymentData.reference} onChange={e=>setPaymentData({...paymentData, reference: e.target.value})}
                         className={fieldClassName}/>
                </div>
              </div>
              <div className="flex flex-col-reverse gap-3 pt-2 sm:flex-row sm:justify-end">
                <ActionButton type="button" variant="outline" onClick={()=>setIsPaymentOpen(false)}>Cancel</ActionButton>
                <ActionButton type="submit" variant="success">Record Payment</ActionButton>
              </div>
            </form>
          </div>
        </div>
      )}

      {isCustomerModalOpen && (
        <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md overflow-hidden rounded-2xl border border-white/60 bg-white shadow-2xl shadow-slate-950/20 dark:border-white/10 dark:bg-slate-900">
            <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">New Customer</h2>
              <ActionButton type="button" variant="ghost" size="icon" onClick={()=>setIsCustomerModalOpen(false)} aria-label="Close customer modal" className="h-9 w-9"><X className="h-5 w-5"/></ActionButton>
            </div>
            <form onSubmit={async (e)=>{e.preventDefault(); try{ const c = await api.createCustomer(customerForm); setCustomers([...customers, c]); setIsCustomerModalOpen(false);}catch(err){console.error(err); alert('Failed to create customer');}}} className="space-y-4 px-5 py-5">
              <div>
                <label className={modalLabelClassName}>Name</label>
                <input type="text" required value={customerForm.name} onChange={e=>setCustomerForm({...customerForm, name: e.target.value})}
                       className={fieldClassName}/>
              </div>
              <div>
                <label className={modalLabelClassName}>Email (optional)</label>
                <input type="email" value={customerForm.email} onChange={e=>setCustomerForm({...customerForm, email: e.target.value})}
                       className={fieldClassName}/>
              </div>
              <div className="flex flex-col-reverse gap-3 pt-2 sm:flex-row sm:justify-end">
                <ActionButton type="button" variant="outline" onClick={()=>setIsCustomerModalOpen(false)}>Cancel</ActionButton>
                <ActionButton type="submit">Save</ActionButton>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
