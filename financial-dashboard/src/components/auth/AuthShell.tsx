import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, BarChart3, CreditCard, Sparkles, Target, WalletCards } from 'lucide-react';
import { motion, useReducedMotion } from 'framer-motion';

type AuthShellProps = {
  children: ReactNode;
  title: string;
  subtitle: string;
  visualTitle: string;
  visualBody: string;
  backLabel: string;
  platformLabel: string;
  workspaceLabel: string;
  statusLabel: string;
  visualCards: Array<{
    label: string;
    value: string;
    icon: ReactNode;
  }>;
};

export const authVisualIcons = {
  cashFlow: <BarChart3 className="h-4 w-4" />,
  budgets: <Target className="h-4 w-4" />,
  insights: <Sparkles className="h-4 w-4" />,
  subscriptions: <CreditCard className="h-4 w-4" />,
};

export default function AuthShell({
  children,
  title,
  subtitle,
  visualTitle,
  visualBody,
  backLabel,
  platformLabel,
  workspaceLabel,
  statusLabel,
  visualCards,
}: AuthShellProps) {
  const shouldReduceMotion = useReducedMotion();

  return (
    <main className="relative min-h-screen overflow-hidden bg-slate-950 px-4 py-6 text-slate-950 sm:px-6 lg:px-8">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_18%_12%,rgba(59,130,246,0.35),transparent_32%),radial-gradient(circle_at_82%_22%,rgba(14,165,233,0.18),transparent_30%),linear-gradient(180deg,#020617_0%,#08111f_58%,#020617_100%)]" />
      <div className="pointer-events-none absolute inset-0 opacity-[0.16] [background-image:linear-gradient(rgba(255,255,255,0.12)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.12)_1px,transparent_1px)] [background-size:44px_44px]" />

      <div className="relative z-10 mx-auto flex min-h-[calc(100vh-3rem)] w-full max-w-6xl items-center">
        <motion.div
          className="grid w-full overflow-hidden rounded-[2rem] border border-white/15 bg-white/10 shadow-[0_32px_110px_rgba(2,6,23,0.38)] backdrop-blur-xl lg:grid-cols-[minmax(0,0.95fr)_minmax(440px,1fr)]"
          initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: shouldReduceMotion ? 0 : 0.55, ease: 'easeOut' }}
        >
          <section className="relative hidden min-h-[680px] overflow-hidden p-10 text-white lg:flex lg:flex-col lg:justify-between">
            <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_32%_24%,rgba(96,165,250,0.28),transparent_34%),linear-gradient(135deg,rgba(15,23,42,0.1),rgba(15,23,42,0.86))]" />
            <div className="relative">
              <Link
                to="/landing"
                className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-sm font-medium text-slate-200 transition-colors hover:bg-white/15 hover:text-white"
              >
                <ArrowLeft className="h-4 w-4" />
                {backLabel}
              </Link>

              <div className="mt-12 flex items-center gap-3">
                <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-white shadow-lg shadow-blue-950/20">
                  <img src="/finsight-icon.svg" alt="FinSight" className="h-8 w-8" />
                </span>
                <div>
                  <div className="text-xl font-bold">FinSight</div>
                  <div className="text-sm text-slate-300">{platformLabel}</div>
                </div>
              </div>

              <div className="mt-12 max-w-xl">
                <h1 className="text-4xl font-bold tracking-tight">{visualTitle}</h1>
                <p className="mt-5 text-lg leading-8 text-slate-200">{visualBody}</p>
              </div>
            </div>

            <div className="relative">
              <div className="rounded-3xl border border-white/15 bg-white/10 p-4 shadow-2xl shadow-blue-950/20 backdrop-blur">
                <div className="mb-4 flex items-center justify-between">
                  <div className="flex items-center gap-2 text-sm font-semibold text-slate-200">
                    <WalletCards className="h-4 w-4 text-sky-300" />
                    {workspaceLabel}
                  </div>
                  <span className="rounded-full bg-emerald-400/10 px-2.5 py-1 text-xs font-medium text-emerald-200">{statusLabel}</span>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  {visualCards.map((card, index) => (
                    <motion.div
                      key={card.label}
                      className="rounded-2xl border border-white/10 bg-white/10 p-4"
                      initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 12 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ duration: shouldReduceMotion ? 0 : 0.45, delay: shouldReduceMotion ? 0 : 0.15 + index * 0.06 }}
                    >
                      <div className="mb-4 flex h-9 w-9 items-center justify-center rounded-xl bg-sky-400/10 text-sky-200">{card.icon}</div>
                      <div className="text-2xl font-bold">{card.value}</div>
                      <div className="mt-1 text-sm text-slate-300">{card.label}</div>
                    </motion.div>
                  ))}
                </div>
              </div>
            </div>
          </section>

          <section className="relative bg-white px-5 py-8 sm:px-8 lg:px-10">
            <Link
              to="/landing"
              className="mb-8 inline-flex items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-600 shadow-sm transition-colors hover:bg-slate-50 hover:text-slate-950 lg:hidden"
            >
              <ArrowLeft className="h-4 w-4" />
              {backLabel}
            </Link>

            <motion.div
              className="mx-auto w-full max-w-md"
              initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: shouldReduceMotion ? 0 : 0.5, delay: shouldReduceMotion ? 0 : 0.08, ease: 'easeOut' }}
            >
              <div className="mb-8 text-center">
                <div className="mb-5 flex justify-center lg:hidden">
                  <span className="flex h-14 w-14 items-center justify-center rounded-2xl bg-blue-600 shadow-lg shadow-blue-600/20">
                    <img src="/finsight-icon.svg" alt="FinSight" className="h-9 w-9" />
                  </span>
                </div>
                <h2 className="text-3xl font-bold tracking-tight text-slate-950 sm:text-4xl">{title}</h2>
                <p className="mt-3 text-base leading-7 text-slate-600">{subtitle}</p>
              </div>
              {children}
            </motion.div>
          </section>
        </motion.div>
      </div>
    </main>
  );
}
