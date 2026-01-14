import { useEffect, useMemo, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../utils/api';
import { formatDate } from '../utils/date';
import { X, Pencil, ArrowLeft } from 'lucide-react';

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
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600" />
      </div>
    );
  }
  if (error || !data) {
    return <div className="text-red-600 dark:text-red-400">{error || 'Invoice not found'}</div>;
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
    <div className="space-y-6">
      <div>
        <button
          onClick={() => navigate('/invoices')}
          className="inline-flex items-center gap-2 text-sm text-blue-600 hover:text-blue-800 px-3 py-1.5 rounded-md border border-blue-600 hover:bg-blue-50 dark:hover:bg-gray-700"
        >
          <ArrowLeft className="h-4 w-4" /> Back to Invoices
        </button>
      </div>
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">Invoice {invoice.number || `#${invoice.id}`}</h1>
          <p className="text-gray-600 dark:text-gray-400">Status: <span className="font-medium">{invoice.status}</span></p>
        </div>
        <div className="text-right space-y-2">
          <div>
            <button
              disabled={!isEditable}
              onClick={openEdit}
              className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-md text-sm ${isEditable ? 'bg-blue-600 text-white hover:bg-blue-700' : 'bg-gray-300 text-gray-600 cursor-not-allowed'}`}
              title={isEditable ? 'Edit Invoice' : 'Cannot edit paid/void invoice'}
            >
              <Pencil className="h-4 w-4" /> Edit Invoice
            </button>
          </div>
          <p className="text-sm text-gray-600 dark:text-gray-400">Issue: {formatDate(invoice.issue_date)} | Due: {formatDate(invoice.due_date)}</p>
          <p className="text-2xl font-bold text-gray-900 dark:text-gray-100">${Number(invoice.total).toLocaleString('en-US',{minimumFractionDigits:2})}</p>
          <p className="text-sm text-gray-600 dark:text-gray-400">Amount Due: ${Number(invoice.amount_due).toLocaleString('en-US',{minimumFractionDigits:2})}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-3">Items</h3>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead className="bg-gray-50 dark:bg-gray-900">
                <tr>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Description</th>
                  <th className="px-4 py-2 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Qty</th>
                  <th className="px-4 py-2 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Unit Price</th>
                  <th className="px-4 py-2 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Amount</th>
                </tr>
              </thead>
              <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                {items.map((it: any) => (
                  <tr key={it.id}>
                    <td className="px-4 py-2 text-sm text-gray-700 dark:text-gray-300">{it.description}</td>
                    <td className="px-4 py-2 text-sm text-right text-gray-700 dark:text-gray-300">{Number(it.quantity)}</td>
                    <td className="px-4 py-2 text-sm text-right text-gray-700 dark:text-gray-300">${Number(it.unit_price).toLocaleString('en-US',{minimumFractionDigits:2})}</td>
                    <td className="px-4 py-2 text-sm text-right text-gray-900 dark:text-gray-100">${Number(it.amount).toLocaleString('en-US',{minimumFractionDigits:2})}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-4 flex justify-end">
            <div className="w-full sm:w-80 p-3 bg-gray-50 dark:bg-gray-700 rounded-md">
              <div className="flex justify-between text-sm"><span className="text-gray-600 dark:text-gray-300">Subtotal</span><span className="font-medium text-gray-900 dark:text-gray-100">${Number(invoice.subtotal).toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
              <div className="flex justify-between text-sm"><span className="text-gray-600 dark:text-gray-300">Discount ({invoiceDiscountPercent}%)</span><span className="font-medium text-gray-900 dark:text-gray-100">-${Number(invoice.discount).toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
              <div className="flex justify-between text-sm"><span className="text-gray-600 dark:text-gray-300">Tax ({invoiceTaxPercent}%)</span><span className="font-medium text-gray-900 dark:text-gray-100">+${Number(invoice.tax).toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
              <div className="flex justify-between text-sm mt-1 border-t border-gray-200 dark:border-gray-600 pt-1"><span className="text-gray-600 dark:text-gray-300">Total</span><span className="font-semibold text-gray-900 dark:text-gray-100">${Number(invoice.total).toLocaleString('en-US',{minimumFractionDigits:2})}</span></div>
            </div>
          </div>
        </div>

        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-3">Details</h3>
          <div className="space-y-1 text-sm text-gray-700 dark:text-gray-300">
            <p><span className="text-gray-500 dark:text-gray-400">Customer:</span> {invoice.customer_name || invoice.customer_id}</p>
            {invoice.project_id && <p><span className="text-gray-500 dark:text-gray-400">Project:</span> {invoice.project_id}</p>}
            {invoice.account_id && <p><span className="text-gray-500 dark:text-gray-400">Account:</span> {invoice.account_id}</p>}

            {invoice.notes && <p><span className="text-gray-500 dark:text-gray-400">Notes:</span> {invoice.notes}</p>}
          </div>
          <div className="mt-4">
            <button
              onClick={async ()=>{ if(confirm('Delete this invoice? This will also remove related transactions.')) { try{ await api.deleteInvoice(Number(id)); navigate('/invoices'); } catch(err){ console.error(err); alert('Failed to delete invoice'); } } }}
              className="text-red-600 hover:text-red-800 text-sm"
            >
              Delete Invoice
            </button>
          </div>

          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mt-6 mb-2">Payments</h3>
          {payments.length === 0 ? (
            <p className="text-sm text-gray-600 dark:text-gray-400">No payments recorded.</p>
          ) : (
            <ul className="divide-y divide-gray-200 dark:divide-gray-700">
              {payments.map((p: any) => (
                <li key={p.id} className="py-2 text-sm">
                  <div className="flex items-center justify-between">
                    <div className="flex flex-col">
                      <span className="text-gray-700 dark:text-gray-300">{formatDate(p.date)}</span>
                      <span className="text-xs text-gray-500 dark:text-gray-400">{p.account_name ? `Deposited to: ${p.account_name}` : ''}</span>
                    </div>
                    <span className="font-medium text-gray-900 dark:text-gray-100">${Number(p.amount).toLocaleString('en-US',{minimumFractionDigits:2})}</span>
                  </div>
                  {p.transaction && (
                    <div className="mt-1 text-xs text-gray-600 dark:text-gray-400">
                      Transaction: #{p.transaction.id} - {p.transaction.description}
                    </div>
                  )}
                  {p.reference && (
                    <div className="mt-1 text-xs text-gray-600 dark:text-gray-400">
                      Reference: {p.reference}
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>

    {isEditOpen && (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center z-50 overflow-y-auto p-4">
        <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto shadow-lg">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Edit Invoice</h2>
            <button onClick={()=>setIsEditOpen(false)} className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"><X className="h-5 w-5"/></button>
          </div>
          <form onSubmit={saveEdit} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Customer</label>
                <select value={formData.customer_id} onChange={e=>setFormData({...formData, customer_id: Number(e.target.value)})}
                        className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100">
                  {customers.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Project (Optional)</label>
                <select value={formData.project_id} onChange={e=>setFormData({...formData, project_id: Number(e.target.value)})}
                        className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100">
                  <option value={0}>No project</option>
                  {projects.map((p:any) => <option key={p.id} value={p.id}>{p.name}</option>)}
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
                           value={it.description} onChange={e=>{ const items=[...formData.items]; items[idx] = { ...items[idx], description: e.target.value}; setFormData({...formData, items}); }}/>
                    <input type="number" className="col-span-1 border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100" placeholder="Qty"
                           value={it.quantity} onChange={e=>{ const items=[...formData.items]; items[idx] = { ...items[idx], quantity: Number(e.target.value)}; setFormData({...formData, items}); }}/>
                    <input type="number" className="col-span-2 border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100" placeholder="Unit Price"
                           value={it.unit_price} onChange={e=>{ const items=[...formData.items]; items[idx] = { ...items[idx], unit_price: Number(e.target.value)}; setFormData({...formData, items}); }}/>
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

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Notes</label>
              <textarea value={formData.notes} onChange={e=>setFormData({...formData, notes: e.target.value})}
                        className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 dark:bg-gray-700 dark:text-gray-100" rows={3} />
            </div>

            <div className="flex justify-end gap-3 pt-2">
              <button type="button" onClick={()=>setIsEditOpen(false)} className="px-4 py-2 text-gray-700 dark:text-gray-300 bg-gray-200 dark:bg-gray-700 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600">Cancel</button>
              <button type="submit" className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">Save Changes</button>
            </div>
          </form>
        </div>
      </div>
    )}
    </>
  );
}
