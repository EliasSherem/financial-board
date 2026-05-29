import { useEffect, useMemo, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../utils/api';
import { formatDate } from '../utils/date';
import { X, Pencil, ArrowLeft } from 'lucide-react';
import {
  ActionButton,
  AppCard,
  DataTableShell,
  EmptyState,
  LoadingState,
  PageHeader,
  StatusBadge,
} from '../components/ui';
import type { StatusBadgeVariant } from '../components/ui';

export default function InvoiceDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [data, setData] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Edit modal state
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [customers, setCustomers] = useState<any[]>([]);
  const [projects, setProjects] = useState<any[]>([]);
  const [formData, setFormData] = useState({
    customer_id: 0,
    project_id: 0,
    number: '',
    issue_date: '',
    due_date: '',
    currency: 'MXN',
    notes: '',
    discount: 0,
    tax: 0,
    items: [] as Array<{ description: string; quantity: number; unit_price: number }>,
  });

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
  const fieldClassName = 'w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-blue-400 dark:focus:ring-blue-400/20';
  const modalLabelClassName = 'mb-1.5 block text-sm font-semibold text-slate-700 dark:text-slate-300';
  const invoiceStatusVariant = (status: string): StatusBadgeVariant => {
    switch (status) {
      case 'paid':
        return 'paid';
      case 'partial':
        return 'partial';
      case 'sent':
        return 'sent';
      case 'overdue':
        return 'overdue';
      case 'void':
        return 'paused';
      case 'draft':
        return 'neutral';
      default:
        return 'neutral';
    }
  };

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        const resp = await api.getInvoice(Number(id));
        setData(resp);
      } catch (e: any) {
        setError(e?.message || 'Failed to load invoice');
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [id]);

  if (loading) {
    return (
      <LoadingState className="min-h-[60vh]" label="Loading invoice..." />
    );
  }
  if (error || !data) {
    return (
      <AppCard variant="subtle">
        <EmptyState
          title={error || 'Invoice not found'}
          action={
            <ActionButton
              type="button"
              variant="outline"
              onClick={() => navigate('/invoices')}
              iconLeft={<ArrowLeft className="h-4 w-4" />}
            >
              Back to Invoices
            </ActionButton>
          }
        />
      </AppCard>
    );
  }

  const { invoice, items, payments } = data;
  // Editable only before any payment (assume 'sent' is pre-payment)
  const isEditable = invoice.status === 'sent';
  const invoiceSubtotal = Number(invoice.subtotal ?? 0);
  const invoiceDiscountAmount = Number(invoice.discount ?? 0);
  const invoiceTaxBase = Math.max(invoiceSubtotal - invoiceDiscountAmount, 0);
  const invoiceTaxAmount = Number(invoice.tax ?? 0);
  const invoiceDiscountPercent = invoiceSubtotal > 0 ? Number(((invoiceDiscountAmount / invoiceSubtotal) * 100).toFixed(2)) : 0;
  const invoiceTaxPercent = invoiceTaxBase > 0 ? Number(((invoiceTaxAmount / invoiceTaxBase) * 100).toFixed(2)) : 0;

  const openEdit = async () => {
    try {
      // Load selects
      const [cust, proj] = await Promise.all([api.getCustomers(), api.getProjects()]);
      setCustomers(cust);
      setProjects(proj);
      // Prefill form from current invoice
      const subtotal = Number(invoice.subtotal ?? 0);
      const discountAmount = Number(invoice.discount ?? 0);
      const subtotalAfterDiscount = Math.max(subtotal - discountAmount, 0);
      const taxAmount = Number(invoice.tax ?? 0);
      const discountPercent = subtotal > 0 ? Math.min(Math.max((discountAmount / subtotal) * 100, 0), 100) : 0;
      const taxPercent = subtotalAfterDiscount > 0 ? Math.max((taxAmount / subtotalAfterDiscount) * 100, 0) : 0;
      setFormData({
        customer_id: invoice.customer_id,
        project_id: invoice.project_id || 0,
        number: invoice.number || '',
        issue_date: invoice.issue_date?.slice(0,10) || '',
        due_date: invoice.due_date?.slice(0,10) || '',
        currency: invoice.currency || 'MXN',
        notes: invoice.notes || '',
        discount: Math.round(discountPercent * 100) / 100,
        tax: Math.round(taxPercent * 100) / 100,
        items: items.map((it: any) => ({ description: it.description, quantity: Number(it.quantity), unit_price: Number(it.unit_price) })),
      });
      setIsEditOpen(true);
    } catch (e) {
      console.error('Failed to open edit modal:', e);
    }
  };

  const saveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const payload = {
        ...formData,
        discount: totals.discountAmount,
        tax: totals.taxAmount,
      };
      await api.updateInvoice(Number(id), payload);
      // Reload details
      const resp = await api.getInvoice(Number(id));
      setData(resp);
      setIsEditOpen(false);
    } catch (err) {
      console.error('Failed to update invoice:', err);
      alert('Failed to update invoice');
    }
  };

  return (
    <>
    <div className="space-y-8">
      <PageHeader
        title={`Invoice ${invoice.number || `#${invoice.id}`}`}
        subtitle={
          <span className="flex flex-wrap items-center gap-3">
            <StatusBadge variant={invoiceStatusVariant(invoice.status)}>{invoice.status}</StatusBadge>
            <span>Issue: {formatDate(invoice.issue_date)}</span>
            <span>Due: {formatDate(invoice.due_date)}</span>
          </span>
        }
        actions={
          <>
            <ActionButton
              type="button"
              variant="outline"
              onClick={() => navigate('/invoices')}
              iconLeft={<ArrowLeft className="h-4 w-4" />}
            >
              Back to Invoices
            </ActionButton>
            <ActionButton
              type="button"
              disabled={!isEditable}
              onClick={openEdit}
              variant={isEditable ? 'primary' : 'outline'}
              title={isEditable ? 'Edit Invoice' : 'Cannot edit paid/void invoice'}
              iconLeft={<Pencil className="h-4 w-4" />}
            >
              Edit Invoice
            </ActionButton>
          </>
        }
      />

      <AppCard variant="elevated" className="overflow-hidden">
        <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
          <div>
            <p className="text-sm font-semibold uppercase tracking-wide text-blue-600 dark:text-blue-300">Invoice summary</p>
            <div className="mt-4 grid gap-4 sm:grid-cols-3">
              <div className="rounded-2xl border border-slate-200 bg-slate-50/80 p-4 dark:border-white/10 dark:bg-slate-950/50">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Customer</p>
                <p className="mt-2 text-sm font-semibold text-slate-950 dark:text-white">{invoice.customer_name || invoice.customer_id}</p>
              </div>
              <div className="rounded-2xl border border-slate-200 bg-slate-50/80 p-4 dark:border-white/10 dark:bg-slate-950/50">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Status</p>
                <div className="mt-2">
                  <StatusBadge variant={invoiceStatusVariant(invoice.status)}>{invoice.status}</StatusBadge>
                </div>
              </div>
              <div className="rounded-2xl border border-slate-200 bg-slate-50/80 p-4 dark:border-white/10 dark:bg-slate-950/50">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Currency</p>
                <p className="mt-2 text-sm font-semibold text-slate-950 dark:text-white">{invoice.currency || 'MXN'}</p>
              </div>
            </div>
          </div>

          <div className="rounded-2xl border border-blue-100 bg-blue-50/80 p-5 text-right dark:border-blue-400/20 dark:bg-blue-500/10">
            <p className="text-sm font-semibold text-blue-700 dark:text-blue-200">Total</p>
            <p className="mt-2 text-3xl font-bold tracking-normal text-slate-950 dark:text-white">${Number(invoice.total).toLocaleString('en-US',{minimumFractionDigits:2})}</p>
            <p className="mt-2 text-sm text-slate-600 dark:text-slate-300">Amount Due: <span className="font-semibold text-slate-950 dark:text-white">${Number(invoice.amount_due).toLocaleString('en-US',{minimumFractionDigits:2})}</span></p>
            <p className="mt-4 text-xs text-slate-500 dark:text-slate-400">Issue: {formatDate(invoice.issue_date)} | Due: {formatDate(invoice.due_date)}</p>
          </div>
        </div>
      </AppCard>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <DataTableShell title="Items">
            {items.length === 0 ? (
              <EmptyState title="No invoice items." />
            ) : (
              <table className="min-w-[720px] divide-y divide-slate-200 dark:divide-white/10">
                <thead className="bg-slate-50 dark:bg-slate-950">
                <tr>
                  <th className="px-5 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Description</th>
                  <th className="px-5 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Qty</th>
                  <th className="px-5 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Unit Price</th>
                  <th className="px-5 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">Amount</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 bg-white dark:divide-white/10 dark:bg-slate-900">
                {items.map((it: any) => (
                  <tr key={it.id} className="transition hover:bg-blue-50/40 dark:hover:bg-blue-500/10">
                    <td className="px-5 py-4 text-sm font-medium text-slate-950 dark:text-white">{it.description}</td>
                    <td className="whitespace-nowrap px-5 py-4 text-right text-sm text-slate-600 dark:text-slate-300">{Number(it.quantity)}</td>
                    <td className="whitespace-nowrap px-5 py-4 text-right text-sm text-slate-600 dark:text-slate-300">${Number(it.unit_price).toLocaleString('en-US',{minimumFractionDigits:2})}</td>
                    <td className="whitespace-nowrap px-5 py-4 text-right text-sm font-semibold text-slate-950 dark:text-white">${Number(it.amount).toLocaleString('en-US',{minimumFractionDigits:2})}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            )}
          </DataTableShell>

          <AppCard>
            <div className="ml-auto w-full space-y-2 sm:w-96">
              <div className="flex justify-between text-sm"><span className="text-slate-500 dark:text-slate-300">Subtotal</span><span className="font-medium text-slate-950 dark:text-white">${Number(invoice.subtotal).toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
              <div className="flex justify-between text-sm"><span className="text-slate-500 dark:text-slate-300">Discount ({invoiceDiscountPercent}%)</span><span className="font-medium text-slate-950 dark:text-white">-${Number(invoice.discount).toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
              <div className="flex justify-between text-sm"><span className="text-slate-500 dark:text-slate-300">Tax ({invoiceTaxPercent}%)</span><span className="font-medium text-slate-950 dark:text-white">+${Number(invoice.tax).toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
              <div className="mt-2 flex justify-between border-t border-slate-200 pt-3 text-base dark:border-white/10"><span className="font-semibold text-slate-700 dark:text-slate-200">Total</span><span className="font-bold text-slate-950 dark:text-white">${Number(invoice.total).toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
            </div>
          </AppCard>
        </div>

        <div className="space-y-6">
          <AppCard>
            <h3 className="text-lg font-semibold text-slate-950 dark:text-white">Details</h3>
            <div className="mt-4 space-y-3 text-sm text-slate-700 dark:text-slate-300">
              <p><span className="text-slate-500 dark:text-slate-400">Customer:</span> {invoice.customer_name || invoice.customer_id}</p>
              {invoice.project_id && <p><span className="text-slate-500 dark:text-slate-400">Project:</span> {invoice.project_id}</p>}
              {invoice.account_id && <p><span className="text-slate-500 dark:text-slate-400">Account:</span> {invoice.account_id}</p>}

              {invoice.notes && <p><span className="text-slate-500 dark:text-slate-400">Notes:</span> {invoice.notes}</p>}
            </div>
            <div className="mt-5 border-t border-slate-200 pt-4 dark:border-white/10">
              <ActionButton
                type="button"
                variant="ghost"
                onClick={async ()=>{ if(confirm('Delete this invoice? This will also remove related transactions.')) { try{ await api.deleteInvoice(Number(id)); navigate('/invoices'); } catch(err){ console.error(err); alert('Failed to delete invoice'); } } }}
                className="text-red-600 hover:text-red-700 dark:text-red-300 dark:hover:text-red-200"
              >
                Delete Invoice
              </ActionButton>
            </div>
          </AppCard>

          <AppCard>
            <h3 className="text-lg font-semibold text-slate-950 dark:text-white">Payments</h3>
            {payments.length === 0 ? (
              <EmptyState className="min-h-32 px-0 py-6" title="No payments recorded." />
            ) : (
              <ul className="mt-4 divide-y divide-slate-200 dark:divide-white/10">
                {payments.map((p: any) => (
                  <li key={p.id} className="py-3 text-sm">
                    <div className="flex items-center justify-between gap-4">
                      <div className="flex min-w-0 flex-col">
                        <span className="font-medium text-slate-700 dark:text-slate-300">{formatDate(p.date)}</span>
                        <span className="text-xs text-slate-500 dark:text-slate-400">{p.account_name ? `Deposited to: ${p.account_name}` : ''}</span>
                      </div>
                      <span className="shrink-0 font-semibold text-slate-950 dark:text-white">${Number(p.amount).toLocaleString('en-US',{minimumFractionDigits:2})}</span>
                    </div>
                    {p.transaction && (
                      <div className="mt-2 rounded-xl bg-slate-50 px-3 py-2 text-xs text-slate-600 dark:bg-slate-950 dark:text-slate-400">
                        Transaction: #{p.transaction.id} - {p.transaction.description}
                      </div>
                    )}
                    {p.reference && (
                      <div className="mt-1 text-xs text-slate-500 dark:text-slate-400">
                        Reference: {p.reference}
                      </div>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </AppCard>
        </div>
      </div>
    </div>

    {isEditOpen && (
      <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
        <div className="w-full max-w-3xl overflow-hidden rounded-2xl border border-white/60 bg-white shadow-2xl shadow-slate-950/20 dark:border-white/10 dark:bg-slate-900">
          <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4 dark:border-white/10">
            <h2 className="text-lg font-semibold text-slate-950 dark:text-white">Edit Invoice</h2>
            <ActionButton type="button" variant="ghost" size="icon" onClick={()=>setIsEditOpen(false)} aria-label="Close edit invoice modal" className="h-9 w-9"><X className="h-5 w-5"/></ActionButton>
          </div>
          <form onSubmit={saveEdit} className="max-h-[calc(100vh-10rem)] space-y-5 overflow-y-auto px-5 py-5">
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className={modalLabelClassName}>Customer</label>
                <select value={formData.customer_id} onChange={e=>setFormData({...formData, customer_id: Number(e.target.value)})}
                        className={fieldClassName}>
                  {customers.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>
              <div>
                <label className={modalLabelClassName}>Project (Optional)</label>
                <select value={formData.project_id} onChange={e=>setFormData({...formData, project_id: Number(e.target.value)})}
                        className={fieldClassName}>
                  <option value={0}>No project</option>
                  {projects.map((p:any) => <option key={p.id} value={p.id}>{p.name}</option>)}
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
                           value={it.description} onChange={e=>{ const items=[...formData.items]; items[idx] = { ...items[idx], description: e.target.value}; setFormData({...formData, items}); }}/>
                    <input type="number" className={`${fieldClassName} col-span-1`} placeholder="Qty"
                           value={it.quantity} onChange={e=>{ const items=[...formData.items]; items[idx] = { ...items[idx], quantity: Number(e.target.value)}; setFormData({...formData, items}); }}/>
                    <input type="number" className={`${fieldClassName} col-span-2`} placeholder="Unit Price"
                           value={it.unit_price} onChange={e=>{ const items=[...formData.items]; items[idx] = { ...items[idx], unit_price: Number(e.target.value)}; setFormData({...formData, items}); }}/>
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

            <div>
              <label className={modalLabelClassName}>Notes</label>
              <textarea value={formData.notes} onChange={e=>setFormData({...formData, notes: e.target.value})}
                        className={fieldClassName} rows={3} />
            </div>

            <div className="flex flex-col-reverse gap-3 pt-2 sm:flex-row sm:justify-end">
              <ActionButton type="button" variant="outline" onClick={()=>setIsEditOpen(false)}>Cancel</ActionButton>
              <ActionButton type="submit">Save Changes</ActionButton>
            </div>
          </form>
        </div>
      </div>
    )}
    </>
  );
}
