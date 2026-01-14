import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CheckCircle2, ArrowRight, ArrowLeft, Sparkles } from 'lucide-react';

export default function Onboarding() {
  const [step, setStep] = useState(0);
  const navigate = useNavigate();

  const user = (() => {
    try { return JSON.parse(localStorage.getItem('user') || '{}'); } catch { return {}; }
  })();
  const userId = user?.id;

  function finish() {
    if (userId) localStorage.setItem(`onboarded:${userId}`, '1');
    navigate('/');
  }

  const steps = [
    {
      title: 'Welcome to FinSight',
      body: 'Let’s set you up in a minute: create accounts, add your first transactions, and explore analytics.',
    },
    {
      title: 'Create your accounts',
      body: 'Head to Accounts to add checking, savings, or cards. Set starting balances to match reality.',
      tip: 'You can always edit balances later.',
    },
    {
      title: 'Track and analyze',
      body: 'Record income/expenses in Transactions and view insights in Analytics. Upgrade to Pro anytime for full dashboards.',
    },
  ];

  const s = steps[step];

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-950 flex items-center justify-center px-4 py-10">
      <div className="w-full max-w-2xl rounded-2xl bg-white dark:bg-gray-900 shadow-xl ring-1 ring-black/5 dark:ring-white/10 p-8">
        <div className="flex items-center gap-3 text-blue-600 mb-2">
          <Sparkles className="h-5 w-5" />
          <div className="text-xs font-semibold uppercase tracking-wide">Getting Started</div>
        </div>
        <h1 className="text-2xl font-bold text-slate-900 dark:text-slate-100">{s.title}</h1>
        <p className="mt-2 text-slate-600 dark:text-slate-300">{s.body}</p>
        {s.tip && <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">Tip: {s.tip}</p>}

        <div className="mt-6 flex items-center justify-between">
          <div className="text-xs text-slate-500">Step {step + 1} of {steps.length}</div>
          <div className="flex items-center gap-2">
            {step > 0 && (
              <button onClick={() => setStep(step - 1)} className="inline-flex items-center gap-2 rounded-lg px-3 py-2 text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800">
                <ArrowLeft className="h-4 w-4" /> Back
              </button>
            )}
            {step < steps.length - 1 ? (
              <button onClick={() => setStep(step + 1)} className="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-white font-semibold hover:bg-blue-700">
                Next <ArrowRight className="h-4 w-4" />
              </button>
            ) : (
              <button onClick={finish} className="inline-flex items-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-white font-semibold hover:bg-emerald-700">
                <CheckCircle2 className="h-4 w-4" /> Finish
              </button>
            )}
          </div>
        </div>

        <button onClick={finish} className="mt-4 text-xs text-slate-500 hover:text-slate-700 dark:hover:text-slate-200">
          Skip for now
        </button>
      </div>
    </div>
  );
}

