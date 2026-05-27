// No React import needed with modern JSX runtime

type ProUpgradeBannerProps = {
  featureLabel?: string;
  variant?: 'page' | 'inline';
};

export default function ProUpgradeBanner({ featureLabel = 'this feature', variant = 'page' }: ProUpgradeBannerProps) {
  const onUpgrade = async () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        window.location.href = '/login';
        return;
      }
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

  const Price = () => (
    <span className="inline-flex items-baseline gap-1 align-middle">
      <span className="font-semibold text-slate-900 dark:text-slate-100">MX$200 + tax</span>
      <span className="text-xs text-slate-500 dark:text-slate-400">/month on web</span>
    </span>
  );

  if (variant === 'inline') {
    return (
      <div className="w-full rounded-lg border border-slate-200/70 bg-white/70 p-3 backdrop-blur-sm shadow-sm flex items-center justify-between gap-3 dark:border-slate-700/60 dark:bg-slate-800/60">
        <div className="text-sm text-slate-700 dark:text-slate-200">
          Upgrade to Pro to use {featureLabel}. <Price />
        </div>
        <button
          onClick={onUpgrade}
          className="shrink-0 inline-flex items-center justify-center rounded-md bg-blue-600 px-3 py-1.5 text-sm font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:focus-visible:ring-offset-slate-900"
        >
          Upgrade to Pro
        </button>
      </div>
    );
  }

  return (
    <div className="mx-auto mt-16 max-w-xl px-4">
      <div className="rounded-2xl border border-slate-200/70 bg-gradient-to-b from-white to-slate-50 p-6 text-center shadow-sm dark:border-slate-700/60 dark:from-slate-800/80 dark:to-slate-900/80 dark:shadow-[inset_0_1px_0_0_rgba(255,255,255,0.03)]">
        <h2 className="text-xl font-semibold mb-2 text-slate-900 dark:text-slate-100">{featureLabel} is a Pro feature</h2>
        <p className="mb-5 text-slate-600 dark:text-slate-300">Upgrade to unlock {featureLabel.toLowerCase()} and more. <Price /></p>
        <button
          onClick={onUpgrade}
          className="inline-flex items-center justify-center rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow hover:bg-blue-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:focus-visible:ring-offset-slate-900"
        >
          Upgrade to Pro
        </button>
        <p className="mt-3 text-xs text-slate-500 dark:text-slate-400">Includes analytics, projects, invoices, the AI financial consultant, and unlimited accounts.</p>
      </div>
    </div>
  );
}
