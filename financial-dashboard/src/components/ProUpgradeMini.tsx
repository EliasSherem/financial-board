import { useEffect, useRef } from 'react';

type Props = {
  open: boolean;
  onClose: () => void;
};

export default function ProUpgradeMini({ open, onClose }: Props) {
  const ref = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    function onDocClick(e: MouseEvent) {
      if (!open) return;
      const el = ref.current;
      if (el && !el.contains(e.target as Node)) onClose();
    }
    document.addEventListener('mousedown', onDocClick);
    return () => document.removeEventListener('mousedown', onDocClick);
  }, [open, onClose]);

  const startCheckout = async () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) return (window.location.href = '/login');
      const API_BASE = (import.meta as any)?.env?.VITE_API_URL || 'http://localhost:3001/api';
      const resp = await fetch(`${API_BASE}/stripe/checkout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      });
      const data = await resp.json();
      if (!resp.ok) throw new Error(data.message || 'Failed to create checkout');
      window.location.href = data.url;
    } catch (e) {
      console.error(e);
      alert('Unable to start checkout.');
    }
  };

  if (!open) return null;

  return (
    <div
      ref={ref}
      className="fixed left-4 bottom-4 z-50 w-80 rounded-xl border border-slate-200/70 bg-gradient-to-b from-white to-slate-50 shadow-xl ring-1 ring-black/5 p-4 dark:border-slate-700/60 dark:from-slate-800 dark:to-slate-900"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="text-sm font-semibold text-slate-900 dark:text-slate-100">Upgrade to Pro</h3>
          <p className="mt-1 text-xs text-slate-600 dark:text-slate-300">Unlock everything for <span className="font-semibold text-slate-900 dark:text-slate-100">MX$200 + tax</span> <span className="text-slate-500 dark:text-slate-400">/month on web</span>.</p>
        </div>
        <button aria-label="Close" onClick={onClose} className="text-slate-400 hover:text-slate-600 dark:text-slate-500 dark:hover:text-slate-300">
          ✕
        </button>
      </div>

      <ul className="mt-3 space-y-1 text-sm text-slate-700 dark:text-slate-200">
        <li className="flex items-start gap-2"><span className="text-green-600">•</span> Analytics dashboards and charts</li>
        <li className="flex items-start gap-2"><span className="text-green-600">•</span> Projects planning and budgets</li>
        <li className="flex items-start gap-2"><span className="text-green-600">•</span> Invoices with payments tracking</li>
        <li className="flex items-start gap-2"><span className="text-green-600">•</span> AI financial consultant</li>
        <li className="flex items-start gap-2"><span className="text-green-600">•</span> Unlimited accounts</li>
      </ul>

      <div className="mt-4 flex items-center justify-between">
        <div className="text-xs text-slate-500 dark:text-slate-400">Cancel anytime.</div>
        <button
          onClick={startCheckout}
          className="inline-flex items-center justify-center rounded-md bg-blue-600 px-3 py-1.5 text-sm font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:focus-visible:ring-offset-slate-900"
        >
          Upgrade
        </button>
      </div>
    </div>
  );
}
