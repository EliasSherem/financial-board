import { Link } from 'react-router-dom';
import {
  ArrowRight,
  BarChart3,
  Building2,
  Calendar,
  CheckCircle2,
  CreditCard,
  FileSpreadsheet,
  Headphones,
  LockKeyhole,
  Shield,
  Sparkles,
  Zap,
} from 'lucide-react';
import { motion, useReducedMotion } from 'framer-motion';
import AppCarousel from '../components/AppCarousel';
import { lazy, Suspense, useEffect } from 'react';
import { useI18n } from '../contexts/I18nContext';

const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.finsight.finsight&pcampaignid=web_share';
const APP_STORE_URL = 'https://apps.apple.com/mx/app/finsight/id6761848896';
const LandingHeroScene = lazy(() => import('../components/LandingHeroScene'));

function PlayStoreIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className="h-5 w-5">
      <path d="M3 2.5v19l10.5-9.5L3 2.5Z" fill="#00C853" />
      <path d="M13.5 12 18 7.9 7.2 2 13.5 12Z" fill="#00B0FF" />
      <path d="M13.5 12 7.2 22 18 16.1 13.5 12Z" fill="#FFAB00" />
      <path d="M18 7.9 13.5 12 18 16.1 21.5 14c1-.6 1-1.5 0-2.1L18 7.9Z" fill="#FF5252" />
    </svg>
  );
}

function AppStoreIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className="h-5 w-5">
      <path
        fill="currentColor"
        d="M16.1 2.2c.1 1-.3 2-1 2.8-.7.8-1.8 1.4-2.8 1.3-.1-1 .3-2 1-2.7.7-.8 1.9-1.4 2.8-1.4Zm3.4 15.5c-.5 1.1-.8 1.6-1.5 2.6-1 1.4-2.4 3.1-4.1 3.1-1.5 0-1.9-1-3.9-1s-2.5 1-3.9 1c-1.7 0-3-1.5-4.1-3-2.8-4-3.1-8.7-1.4-11.1 1.2-1.7 3-2.7 4.8-2.7 1.8 0 3 1 4.5 1 1.4 0 2.3-1 4.4-1 1.6 0 3.3.9 4.5 2.4-4 2.2-3.3 7.9.7 8.7Z"
      />
    </svg>
  );
}

export default function Landing() {
  const { language, setLanguage } = useI18n();
  const shouldReduceMotion = useReducedMotion();
  const L = (key: keyof typeof STR, vars?: Record<string, string>) => {
    const s = STR[key][language] as unknown as string;
    if (!vars) return s;
    return Object.entries(vars).reduce((acc, [k, v]) => (acc as string).replace(`{${k}}`, v), s);
  };

  // Force light theme while on the landing page
  useEffect(() => {
    const hadDark = document.documentElement.classList.contains('dark');
    document.documentElement.classList.remove('dark');
    return () => {
      const saved = localStorage.getItem('theme');
      if (saved === 'dark' || hadDark) document.documentElement.classList.add('dark');
    };
  }, []);

  return (
    <div className="min-h-screen bg-white dark:bg-gray-950">
      {/* Header */}
      <header className="border-b border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900">
        <div className="max-w-6xl mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <img src="/finsight-icon.svg" alt="FinSight" className="w-8 h-8" />
            <span className="text-xl font-bold text-gray-900 dark:text-gray-100">FinSight</span>
          </div>
          <nav className="hidden md:flex items-center space-x-6">
            <a href="#features" className="text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100 transition-colors">{L('nav_features')}</a>
            <a href="#pricing" className="text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100 transition-colors">{L('nav_pricing')}</a>
            <a href="#about" className="text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100 transition-colors">{L('nav_about')}</a>
            <div className="flex items-center gap-1 mr-2">
              <button onClick={() => setLanguage('en')} className={`px-2 py-1 text-xs rounded ${language==='en'?'bg-gray-200 text-gray-900':'text-gray-600 hover:bg-gray-100'}`}>EN</button>
              <button onClick={() => setLanguage('es')} className={`px-2 py-1 text-xs rounded ${language==='es'?'bg-gray-200 text-gray-900':'text-gray-600 hover:bg-gray-100'}`}>ES</button>
            </div>
            <Link to="/login" className="inline-flex items-center rounded-md border border-gray-300 dark:border-gray-700 px-3 py-1.5 text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800">{L('nav_signin')}</Link>
            <Link to="/signup" className="inline-flex items-center rounded-md bg-blue-600 hover:bg-blue-700 px-3 py-1.5 text-sm text-white">{L('nav_getStarted')}</Link>
          </nav>
        </div>
      </header>

      {/* Hero Section */}
      <section className="relative overflow-hidden bg-slate-950 px-4 py-16 sm:py-20 lg:min-h-[720px] lg:py-0">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_75%_35%,rgba(59,130,246,0.3),transparent_34%),radial-gradient(circle_at_24%_20%,rgba(16,185,129,0.14),transparent_28%),linear-gradient(180deg,#020617_0%,#08111f_58%,#020617_100%)]" />
        <div className="pointer-events-none absolute inset-y-0 left-0 w-full bg-gradient-to-r from-slate-950 via-slate-950/90 to-slate-950/10 lg:w-[62%] lg:to-transparent" />
        <div className="relative z-10 mx-auto grid max-w-7xl items-center gap-10 lg:min-h-[720px] lg:grid-cols-[minmax(0,0.9fr)_minmax(460px,1.1fr)] lg:gap-8">
          <div className="max-w-[600px] text-left">
            <div
              className="mb-4 inline-flex max-w-full items-center gap-2 rounded-full border border-green-200 bg-green-50 px-4 py-2 text-sm font-medium text-green-800 transition-colors hover:bg-green-100"
            >
              <span className="shrink-0 rounded-full bg-green-600 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-white">
                {L('news_label')}
              </span>
              <span className="min-w-0">{L('news_androidRelease')}</span>
            </div>
            <span className="mb-5 inline-flex items-center gap-1 rounded-full bg-white/10 px-3 py-1 text-xs font-medium text-slate-200 ring-1 ring-white/15">
              <Zap className="w-3 h-3" /> {L('hero_badge')}
            </span>
            <h1 className="mb-6 text-4xl font-bold text-white sm:text-5xl lg:text-6xl">
              {L('hero_title_1')} <span className="text-sky-300">{L('hero_title_2')}</span>
            </h1>
            <p className="mb-8 max-w-xl text-lg leading-8 text-slate-200 sm:text-xl">{L('hero_subtitle')}</p>
            <div className="flex flex-col gap-4 sm:flex-row sm:flex-wrap">
              <Link to="/signup" className="inline-flex items-center justify-center rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-lg px-8 py-3">{L('cta_getStarted')}</Link>
              <a
                href={PLAY_STORE_URL}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center justify-center gap-2 rounded-lg border border-white/70 bg-white/95 px-8 py-3 text-lg font-medium text-gray-900 hover:bg-white"
              >
                <PlayStoreIcon />
                {L('cta_downloadAndroid')}
              </a>
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center justify-center gap-2 rounded-lg border border-white/70 bg-white/95 px-8 py-3 text-lg font-medium text-gray-900 hover:bg-white"
              >
                <AppStoreIcon />
                {L('cta_downloadIos')}
              </a>
            </div>
          </div>
          <div className="relative h-[300px] min-h-[300px] sm:h-[380px] lg:h-[620px] lg:min-h-[620px]">
            <Suspense fallback={<div className="pointer-events-none absolute inset-0 bg-slate-950" />}>
              <LandingHeroScene variant="side-hero" />
            </Suspense>
          </div>
        </div>
      </section>

      {/* Dashboard Preview (Carousel) */}
      <section className="relative overflow-hidden bg-gradient-to-b from-slate-50 via-white to-slate-50 px-4 py-20 dark:from-gray-900 dark:via-gray-950 dark:to-gray-900">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-64 bg-[radial-gradient(circle_at_50%_0%,rgba(59,130,246,0.14),transparent_55%)]" />
        <div className="relative mx-auto max-w-7xl">
          <div className="mx-auto mb-12 max-w-3xl text-center sm:mb-14" id="demo">
            <h2 className="mb-4 text-3xl font-bold text-gray-900 dark:text-gray-100 md:text-4xl">{L('preview_title')}</h2>
            <p className="text-lg text-gray-600 dark:text-gray-300">{L('preview_sub')}</p>
          </div>
          <AppCarousel />
        </div>
      </section>

      {/* Why FinSight */}
      <section id="about" className="relative overflow-hidden bg-gradient-to-b from-white via-slate-50 to-white px-4 py-20 dark:from-gray-950 dark:via-gray-900 dark:to-gray-950">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-80 bg-[radial-gradient(circle_at_18%_12%,rgba(59,130,246,0.14),transparent_36%),radial-gradient(circle_at_82%_26%,rgba(14,165,233,0.12),transparent_34%)]" />
        <div className="relative mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-[minmax(0,0.95fr)_minmax(420px,1fr)]">
          <motion.div
            initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.25 }}
            transition={{ duration: shouldReduceMotion ? 0 : 0.6 }}
          >
            <span className="inline-flex items-center gap-2 rounded-full border border-blue-200 bg-blue-50 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-blue-700">
              <Sparkles className="h-3.5 w-3.5" />
              {L('about_eyebrow')}
            </span>
            <h2 className="mt-5 max-w-2xl text-3xl font-bold tracking-tight text-gray-950 dark:text-gray-100 md:text-5xl">
              {L('about_title')}
            </h2>
            <p className="mt-5 max-w-2xl text-lg leading-8 text-gray-600 dark:text-gray-300">
              {L('about_body')}
            </p>
            <div className="mt-7 grid max-w-2xl gap-3 text-sm text-gray-700 dark:text-gray-300 sm:grid-cols-2">
              {[
                L('about_point_accounts'),
                L('about_point_decisions'),
                L('about_point_spreadsheets'),
                L('about_point_upgrade'),
              ].map((point) => (
                <div key={point} className="flex items-start gap-2">
                  <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-blue-600" />
                  <span>{point}</span>
                </div>
              ))}
            </div>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:flex-wrap">
              <a href="#pricing" className="inline-flex items-center justify-center rounded-lg bg-blue-600 px-5 py-3 font-medium text-white shadow-sm shadow-blue-600/20 hover:bg-blue-700">{L('btn_pricing')}</a>
              <a href="#features" className="inline-flex items-center justify-center rounded-lg border border-gray-300 bg-white px-5 py-3 font-medium text-gray-800 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200 dark:hover:bg-gray-800">{L('btn_learnMore')}</a>
              <Link to="/guide" className="inline-flex items-center justify-center rounded-lg border border-gray-300 bg-white px-5 py-3 font-medium text-gray-800 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200 dark:hover:bg-gray-800">{L('btn_guide')}</Link>
            </div>
          </motion.div>

          <div className="grid gap-4 sm:grid-cols-2">
            {[
              {
                icon: <Zap className="h-5 w-5" />,
                value: '99.9%',
                label: L('trust_uptime'),
                body: L('trust_uptime_body'),
              },
              {
                icon: <Headphones className="h-5 w-5" />,
                value: '24/7',
                label: L('trust_support'),
                body: L('trust_support_body'),
              },
              {
                icon: <LockKeyhole className="h-5 w-5" />,
                label: L('trust_secure_title'),
                body: L('trust_secure_body'),
              },
              {
                icon: <Building2 className="h-5 w-5" />,
                label: L('trust_growth_title'),
                body: L('trust_growth_body'),
              },
              {
                icon: <FileSpreadsheet className="h-5 w-5" />,
                label: L('trust_spreadsheets_title'),
                body: L('trust_spreadsheets_body'),
              },
              {
                icon: <BarChart3 className="h-5 w-5" />,
                label: L('trust_visibility_title'),
                body: L('trust_visibility_body'),
              },
            ].map((card, index) => (
              <motion.div
                key={card.label}
                className="rounded-2xl border border-slate-200/80 bg-white/85 p-5 shadow-[0_20px_60px_rgba(15,23,42,0.08)] backdrop-blur dark:border-white/10 dark:bg-gray-900/80"
                initial={shouldReduceMotion ? { opacity: 1, y: 0, scale: 1 } : { opacity: 0, y: 20, scale: 0.98 }}
                whileInView={{ opacity: 1, y: 0, scale: 1 }}
                viewport={{ once: true, amount: 0.25 }}
                transition={{ duration: shouldReduceMotion ? 0 : 0.5, delay: shouldReduceMotion ? 0 : index * 0.05 }}
              >
                <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-xl bg-blue-600/10 text-blue-600">
                  {card.icon}
                </div>
                {'value' in card && (
                  <div className="mb-2 text-3xl font-bold tracking-tight text-gray-950 dark:text-white">{card.value}</div>
                )}
                <h3 className="text-base font-semibold text-gray-950 dark:text-gray-100">{card.label}</h3>
                <p className="mt-2 text-sm leading-6 text-gray-600 dark:text-gray-300">{card.body}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Workflow */}
      <section id="features" className="relative overflow-hidden bg-gradient-to-br from-white via-blue-50/50 to-slate-50 px-4 py-20 dark:from-gray-950 dark:via-gray-900 dark:to-slate-950">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-blue-200 to-transparent" />
        <div className="pointer-events-none absolute bottom-0 right-0 h-96 w-96 translate-x-1/3 rounded-full bg-blue-200/30 blur-3xl dark:bg-blue-900/20" />
        <div className="relative mx-auto grid max-w-6xl items-start gap-12 lg:grid-cols-[minmax(0,0.9fr)_minmax(480px,1.1fr)]">
          <motion.div
            initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.3 }}
            transition={{ duration: shouldReduceMotion ? 0 : 0.6 }}
          >
            <span className="inline-flex items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-1 text-xs font-semibold uppercase tracking-wide text-slate-600 shadow-sm dark:border-white/10 dark:bg-gray-900 dark:text-slate-300">
              <ArrowRight className="h-3.5 w-3.5 text-blue-600" />
              {L('features_eyebrow')}
            </span>
            <h2 className="mt-5 max-w-2xl text-3xl font-bold tracking-tight text-gray-950 dark:text-gray-100 md:text-5xl">
              {L('features_title')}
            </h2>
            <p className="mt-5 max-w-2xl text-lg leading-8 text-gray-600 dark:text-gray-300">
              {L('features_sub')}
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Link to="/signup" className="inline-flex items-center justify-center rounded-lg bg-blue-600 px-5 py-3 font-medium text-white shadow-sm shadow-blue-600/20 hover:bg-blue-700">
                {L('workflow_cta_primary')}
              </Link>
              <a href="#pricing" className="inline-flex items-center justify-center rounded-lg border border-gray-300 bg-white px-5 py-3 font-medium text-gray-800 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200 dark:hover:bg-gray-800">
                {L('btn_pricing')}
              </a>
            </div>

            <motion.div
              className="mt-10 overflow-hidden rounded-2xl border border-slate-200 bg-white/85 shadow-[0_24px_70px_rgba(15,23,42,0.09)] backdrop-blur dark:border-white/10 dark:bg-gray-900/80"
              initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 18 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.4 }}
              transition={{ duration: shouldReduceMotion ? 0 : 0.55, delay: shouldReduceMotion ? 0 : 0.15 }}
            >
              <div className="flex items-center justify-between border-b border-slate-200/80 px-4 py-3 dark:border-white/10">
                <div className="text-sm font-semibold text-gray-950 dark:text-gray-100">{L('workflow_preview_title')}</div>
                <div className="rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-medium text-emerald-700 dark:bg-emerald-400/10 dark:text-emerald-300">{L('workflow_preview_status')}</div>
              </div>
              <div className="space-y-3 p-4">
                {[
                  { icon: <CreditCard className="h-4 w-4" />, label: L('workflow_preview_raw'), value: '-$128.40' },
                  { icon: <FileSpreadsheet className="h-4 w-4" />, label: L('workflow_preview_category'), value: L('workflow_preview_operations') },
                  { icon: <Calendar className="h-4 w-4" />, label: L('workflow_preview_budget'), value: '72%' },
                  { icon: <BarChart3 className="h-4 w-4" />, label: L('workflow_preview_insight'), value: '+18%' },
                ].map((item, index) => (
                  <motion.div
                    key={item.label}
                    className="flex items-center gap-3 rounded-xl bg-slate-50 px-3 py-2.5 dark:bg-white/5"
                    initial={shouldReduceMotion ? { opacity: 1, x: 0 } : { opacity: 0, x: -12 }}
                    whileInView={{ opacity: 1, x: 0 }}
                    viewport={{ once: true, amount: 0.5 }}
                    transition={{ duration: shouldReduceMotion ? 0 : 0.4, delay: shouldReduceMotion ? 0 : 0.22 + index * 0.06 }}
                  >
                    <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-blue-600/10 text-blue-600">{item.icon}</span>
                    <span className="min-w-0 flex-1 text-sm text-gray-600 dark:text-gray-300">{item.label}</span>
                    <span className="shrink-0 text-sm font-semibold text-gray-950 dark:text-white">{item.value}</span>
                  </motion.div>
                ))}
              </div>
            </motion.div>
          </motion.div>

          <div className="relative">
            <div className="absolute left-5 top-6 hidden h-[calc(100%-3rem)] w-px overflow-hidden sm:block">
              <motion.div
                className="h-full w-px bg-gradient-to-b from-blue-200 via-blue-500/40 to-transparent dark:from-blue-400/30 dark:via-blue-400/20"
                initial={shouldReduceMotion ? { scaleY: 1 } : { scaleY: 0 }}
                whileInView={{ scaleY: 1 }}
                viewport={{ once: true, amount: 0.35 }}
                transition={{ duration: shouldReduceMotion ? 0 : 0.9, ease: 'easeOut' }}
                style={{ transformOrigin: 'top' }}
              />
            </div>
            <ol className="space-y-5">
              {[
                { title: L('workflow_step1_title'), desc: L('workflow_step1_desc') },
                { title: L('workflow_step2_title'), desc: L('workflow_step2_desc') },
                { title: L('workflow_step3_title'), desc: L('workflow_step3_desc') },
                { title: L('workflow_step4_title'), desc: L('workflow_step4_desc') },
              ].map((step, index) => (
                <motion.li
                  key={step.title}
                  className="group relative flex gap-4 sm:gap-5"
                  initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 22 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  whileHover={shouldReduceMotion ? undefined : { y: -2 }}
                  viewport={{ once: true, amount: 0.35 }}
                  transition={{ duration: shouldReduceMotion ? 0 : 0.5, delay: shouldReduceMotion ? 0 : index * 0.08, ease: 'easeOut' }}
                >
                  <div className="relative z-10 flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-blue-200 bg-white text-sm font-bold text-blue-700 shadow-sm dark:border-blue-400/30 dark:bg-gray-900 dark:text-blue-300">
                    {index + 1}
                  </div>
                  <div className="min-w-0 rounded-2xl border border-white/80 bg-white/75 p-5 shadow-[0_18px_50px_rgba(15,23,42,0.07)] backdrop-blur transition-colors duration-300 group-hover:border-blue-200 group-hover:bg-white dark:border-white/10 dark:bg-gray-900/70 dark:group-hover:border-blue-400/30">
                    <h3 className="text-lg font-semibold text-gray-950 dark:text-gray-100">{step.title}</h3>
                    <p className="mt-2 text-sm leading-6 text-gray-600 dark:text-gray-300">{step.desc}</p>
                  </div>
                </motion.li>
              ))}
            </ol>
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="py-20 px-4">
        <div className="max-w-6xl mx-auto">
          <motion.div
            className="text-center mb-10"
            initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.35 }}
            transition={{ duration: shouldReduceMotion ? 0 : 0.55, ease: 'easeOut' }}
          >
            <h2 className="text-3xl font-bold text-gray-900 dark:text-gray-100">{L('pricing_title')}</h2>
            <p className="text-gray-600 dark:text-gray-300">{L('pricing_sub')}</p>
          </motion.div>
          <div className="grid sm:grid-cols-2 gap-6">
            <motion.div
              className="rounded-2xl bg-white p-6 ring-1 ring-black/5 shadow-sm transition-shadow duration-300 hover:shadow-[0_24px_70px_rgba(15,23,42,0.10)] dark:bg-gray-900 dark:ring-white/10"
              initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              whileHover={shouldReduceMotion ? undefined : { y: -3 }}
              viewport={{ once: true, amount: 0.35 }}
              transition={{ duration: shouldReduceMotion ? 0 : 0.5, ease: 'easeOut' }}
            >
              <div className="text-xs font-semibold text-gray-500">{L('plan_free')}</div>
              <div className="mt-2 text-3xl font-extrabold text-gray-900 dark:text-white">$0</div>
              <ul className="mt-4 space-y-2 text-sm text-gray-600 dark:text-gray-300">
                {[L('free_core'), L('free_accounts'), L('free_secure')].map((feature, index) => (
                  <motion.li
                    key={feature}
                    className="flex items-start gap-2"
                    initial={shouldReduceMotion ? { opacity: 1, x: 0 } : { opacity: 0, x: -8 }}
                    whileInView={{ opacity: 1, x: 0 }}
                    viewport={{ once: true, amount: 0.5 }}
                    transition={{ duration: shouldReduceMotion ? 0 : 0.35, delay: shouldReduceMotion ? 0 : 0.12 + index * 0.05 }}
                  >
                    <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-blue-600" />
                    <span>{feature}</span>
                  </motion.li>
                ))}
              </ul>
              <motion.div whileHover={shouldReduceMotion ? undefined : { y: -1 }} whileTap={shouldReduceMotion ? undefined : { y: 0 }} className="inline-flex">
                <Link to="/signup" className="mt-5 inline-flex items-center gap-2 rounded-lg bg-gray-800 px-4 py-2 font-semibold text-white shadow-sm transition-colors hover:bg-gray-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-800 dark:bg-gray-700">{L('btn_createFree')}</Link>
              </motion.div>
            </motion.div>
            <motion.div
              className="relative overflow-hidden rounded-2xl bg-gradient-to-b from-blue-500 to-indigo-600 p-[1px] shadow-[0_24px_70px_rgba(37,99,235,0.16)]"
              initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              whileHover={shouldReduceMotion ? undefined : { y: -3 }}
              viewport={{ once: true, amount: 0.35 }}
              transition={{ duration: shouldReduceMotion ? 0 : 0.5, delay: shouldReduceMotion ? 0 : 0.08, ease: 'easeOut' }}
            >
              <motion.div
                aria-hidden="true"
                className="pointer-events-none absolute inset-0 rounded-2xl bg-[linear-gradient(110deg,transparent,rgba(255,255,255,0.45),transparent)]"
                initial={{ opacity: 0, x: '-80%' }}
                whileInView={shouldReduceMotion ? { opacity: 0, x: '-80%' } : { opacity: [0, 0.55, 0], x: ['-80%', '0%', '80%'] }}
                viewport={{ once: true, amount: 0.45 }}
                transition={{ duration: shouldReduceMotion ? 0 : 1.1, delay: shouldReduceMotion ? 0 : 0.32, ease: 'easeOut' }}
              />
              <div className="relative rounded-2xl bg-white p-6 dark:bg-gray-900">
                <div className="flex items-center justify-between">
                  <div className="text-xs font-semibold text-gray-500 dark:text-gray-400">{L('plan_pro')}</div>
                  <div className="inline-flex items-center gap-1 rounded-full border border-blue-200 bg-blue-50 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wide text-blue-700">Popular</div>
                </div>
                <div className="mt-2 text-3xl font-extrabold text-gray-900 dark:text-white">{L('price_pro')} <span className="text-sm font-medium text-gray-500">/{L('per_month')}</span></div>
                <div className="mt-2 space-y-1 text-xs text-gray-500 dark:text-gray-400">
                  <div>{L('price_web')}</div>
                  <div>{L('price_googlePlay')}</div>
                  <div>{L('price_appStore')}</div>
                </div>
                <ul className="mt-4 space-y-2 text-sm text-gray-600 dark:text-gray-300">
                  {[L('pro_unlimited'), L('pro_analytics'), L('pro_projects'), L('pro_ai'), L('pro_support')].map((feature, index) => (
                    <motion.li
                      key={feature}
                      className="flex items-start gap-2"
                      initial={shouldReduceMotion ? { opacity: 1, x: 0 } : { opacity: 0, x: -8 }}
                      whileInView={{ opacity: 1, x: 0 }}
                      viewport={{ once: true, amount: 0.5 }}
                      transition={{ duration: shouldReduceMotion ? 0 : 0.35, delay: shouldReduceMotion ? 0 : 0.18 + index * 0.05 }}
                    >
                      <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-blue-600" />
                      <span>{feature}</span>
                    </motion.li>
                  ))}
                </ul>
                <motion.div whileHover={shouldReduceMotion ? undefined : { y: -1 }} whileTap={shouldReduceMotion ? undefined : { y: 0 }} className="inline-flex">
                  <Link to="/signup" className="mt-5 inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 font-semibold text-white shadow-sm shadow-blue-600/20 transition-colors hover:bg-blue-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600">{L('btn_upgrade')}</Link>
                </motion.div>
              </div>
            </motion.div>
          </div>
          <div className="mt-6 text-xs text-gray-500 flex items-center justify-center gap-2">
            <Shield className="h-4 w-4" /> {L('pricing_note')}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="relative overflow-hidden bg-gradient-to-b from-white via-slate-50 to-slate-950 px-4 py-20">
        <motion.div
          className="relative mx-auto max-w-6xl overflow-hidden rounded-[2rem] border border-white/10 bg-slate-950 px-6 py-12 text-center shadow-[0_36px_110px_rgba(2,6,23,0.32)] sm:px-10 sm:py-16"
          initial={shouldReduceMotion ? { opacity: 1, y: 0 } : { opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: shouldReduceMotion ? 0 : 0.65, ease: 'easeOut' }}
        >
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_22%_20%,rgba(59,130,246,0.32),transparent_34%),radial-gradient(circle_at_78%_18%,rgba(14,165,233,0.22),transparent_30%),linear-gradient(180deg,rgba(15,23,42,0)_0%,rgba(15,23,42,0.8)_100%)]" />
          <motion.div
            aria-hidden="true"
            className="pointer-events-none absolute inset-0 opacity-20 [background-image:linear-gradient(rgba(255,255,255,0.12)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.12)_1px,transparent_1px)] [background-size:44px_44px]"
            initial={shouldReduceMotion ? { opacity: 0.16 } : { opacity: 0 }}
            whileInView={{ opacity: 0.16 }}
            viewport={{ once: true, amount: 0.4 }}
            transition={{ duration: shouldReduceMotion ? 0 : 0.9, delay: shouldReduceMotion ? 0 : 0.1 }}
          />
          <div className="pointer-events-none absolute left-10 top-10 h-1.5 w-1.5 rounded-full bg-sky-300/70" />
          <div className="pointer-events-none absolute right-16 top-24 h-2 w-2 rounded-full bg-blue-200/60" />
          <div className="pointer-events-none absolute bottom-12 left-1/4 h-1 w-1 rounded-full bg-white/60" />

          <div className="relative mx-auto max-w-3xl">
            <span className="mb-5 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-sky-100">
              <Shield className="h-3.5 w-3.5" />
              FinSight
            </span>
            <h2 className="text-3xl font-bold tracking-tight text-white md:text-5xl">{L('cta_title')}</h2>
            <p className="mx-auto mt-5 max-w-2xl text-lg leading-8 text-slate-200">{L('cta_sub')}</p>
            <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row sm:flex-wrap">
              <motion.div whileHover={shouldReduceMotion ? undefined : { y: -2 }} whileTap={shouldReduceMotion ? undefined : { y: 0 }} className="flex">
                <Link to="/signup" className="inline-flex w-full items-center justify-center rounded-xl bg-white px-7 py-3 text-base font-semibold text-slate-950 shadow-lg shadow-blue-950/20 transition-colors hover:bg-slate-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white sm:w-auto">{L('cta_getStarted')}</Link>
              </motion.div>
              <motion.div whileHover={shouldReduceMotion ? undefined : { y: -2 }} whileTap={shouldReduceMotion ? undefined : { y: 0 }} className="flex">
                <a
                  href={PLAY_STORE_URL}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex w-full items-center justify-center gap-2 rounded-xl border border-white/20 bg-white/10 px-7 py-3 text-base font-medium text-white shadow-sm transition-colors hover:bg-white/15 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white sm:w-auto"
                >
                  <PlayStoreIcon />
                  {L('cta_downloadAndroid')}
                </a>
              </motion.div>
              <motion.div whileHover={shouldReduceMotion ? undefined : { y: -2 }} whileTap={shouldReduceMotion ? undefined : { y: 0 }} className="flex">
                <a
                  href={APP_STORE_URL}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex w-full items-center justify-center gap-2 rounded-xl border border-white/20 bg-white/10 px-7 py-3 text-base font-medium text-white shadow-sm transition-colors hover:bg-white/15 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white sm:w-auto"
                >
                  <AppStoreIcon />
                  {L('cta_downloadIos')}
                </a>
              </motion.div>
            </div>
            <p className="mt-5 text-sm text-slate-300">{L('cta_note')}</p>
          </div>
        </motion.div>
      </section>

      {/* Footer */}
      <footer className="border-t border-white/10 bg-slate-950 px-4 py-12">
        <div className="mx-auto max-w-6xl">
          <div className="flex flex-col items-center justify-between gap-8 md:flex-row">
            <div className="flex flex-col items-center gap-3 text-center md:items-start md:text-left">
              <div className="flex items-center space-x-2">
                <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-white ring-1 ring-white/20">
                  <img src="/finsight-icon.svg" alt="FinSight" className="h-7 w-7" />
                </span>
                <span className="text-xl font-bold text-white">FinSight</span>
              </div>
              <p className="max-w-sm text-sm leading-6 text-slate-400">{L('footer_tagline')}</p>
            </div>
            <nav aria-label="Footer" className="flex flex-wrap items-center justify-center gap-x-6 gap-y-3 text-sm text-slate-400">
              <Link to="/privacy" className="transition-colors hover:text-white">Privacy</Link>
              <Link to="/terms" className="transition-colors hover:text-white">Terms</Link>
              <Link to="/guide" className="transition-colors hover:text-white">User Guide</Link>
              <a href="mailto:sheremelias@gmail.com" className="transition-colors hover:text-white">Contact</a>
            </nav>
          </div>
          <div className="mt-10 flex flex-col items-center justify-between gap-3 border-t border-white/10 pt-6 text-center text-sm text-slate-500 md:flex-row md:text-left">
            <span>© {new Date().getFullYear()} FinSight. All rights reserved.</span>
            <span>{L('footer_note')}</span>
          </div>
        </div>
      </footer>
    </div>
  );
}

const STR = {
  nav_features: { en: 'Features', es: 'Funciones' },
  nav_pricing: { en: 'Pricing', es: 'Precios' },
  nav_about: { en: 'About', es: 'Acerca de' },
  nav_signin: { en: 'Sign In', es: 'Iniciar sesión' },
  nav_getStarted: { en: 'Get Started', es: 'Comenzar' },
  news_label: { en: 'New', es: 'Nuevo' },
  news_androidRelease: { en: 'FinSight is now available on the App Store and Google Play.', es: 'FinSight ya está disponible en App Store y Google Play.' },
  hero_badge: { en: 'Financial Intelligence Platform', es: 'Plataforma de inteligencia financiera' },
  hero_title_1: { en: 'Master Your Financial', es: 'Domina tu' },
  hero_title_2: { en: 'Overview', es: 'Panorama financiero' },
  hero_subtitle: {
    en: 'Get complete visibility into your finances with real-time analytics, intelligent insights, and powerful dashboard tools designed for modern financial management.',
    es: 'Obtén visibilidad completa de tus finanzas con analíticas en tiempo real, insights inteligentes y potentes tableros para la gestión moderna.'
  },
  cta_getStarted: { en: 'Get Started Now', es: 'Comenzar ahora' },
  cta_downloadAndroid: { en: 'Download on Google Play', es: 'Descargar en Google Play' },
  cta_downloadIos: { en: 'Download on the App Store', es: 'Descargar en App Store' },
  preview_title: { en: "Explore FinSight's Powerful Features", es: 'Explora las funciones de FinSight' },
  preview_sub: { en: 'See how FinSight transforms your financial management experience', es: 'Mira cómo FinSight transforma la gestión de tus finanzas' },
  about_eyebrow: { en: 'Why FinSight', es: 'Por qué FinSight' },
  about_title: { en: 'Financial clarity for real business decisions', es: 'Claridad financiera para decisiones reales' },
  about_body: {
    en: 'FinSight brings your accounts, transactions, budgets, projects, invoices, and subscriptions into one clean dashboard so freelancers, entrepreneurs, and microbusinesses can understand cash flow, control expenses, and make better decisions without relying on spreadsheets.',
    es: 'FinSight reúne tus cuentas, transacciones, presupuestos, proyectos, facturas y suscripciones en un tablero claro para que freelancers, emprendedores y microempresas entiendan su flujo de efectivo, controlen gastos y tomen mejores decisiones sin depender de hojas de cálculo.'
  },
  about_point_accounts: { en: 'Organize accounts, expenses, projects, budgets, invoices, and subscriptions.', es: 'Organiza cuentas, gastos, proyectos, presupuestos, facturas y suscripciones.' },
  about_point_decisions: { en: 'See where your money goes with clear visual insights.', es: 'Ve a dónde va tu dinero con insights visuales claros.' },
  about_point_spreadsheets: { en: 'Move beyond spreadsheet-only financial management.', es: 'Gestiona tus finanzas sin depender solo de hojas de cálculo.' },
  about_point_upgrade: { en: 'Start simple and upgrade to Pro when your business needs more.', es: 'Empieza simple y mejora a Pro cuando tu negocio necesite más.' },
  trust_uptime: { en: 'Uptime', es: 'Disponibilidad' },
  trust_uptime_body: { en: 'Dependable access for the moments when cash flow decisions cannot wait.', es: 'Acceso confiable para los momentos en que las decisiones de flujo no pueden esperar.' },
  trust_support: { en: 'Support', es: 'Soporte' },
  trust_support_body: { en: 'Help is available when your financial workflow needs a clear next step.', es: 'Ayuda disponible cuando tu flujo financiero necesita un siguiente paso claro.' },
  trust_secure_title: { en: 'Secure by design', es: 'Seguro por diseño' },
  trust_secure_body: { en: 'Built with protected access patterns and Stripe-secured payments for Pro.', es: 'Construido con acceso protegido y pagos Pro seguros mediante Stripe.' },
  trust_growth_title: { en: 'Built for growing businesses', es: 'Hecho para negocios en crecimiento' },
  trust_growth_body: { en: 'Fits solo operators today and scales toward teams, projects, and advisors.', es: 'Funciona para trabajo individual y escala hacia equipos, proyectos y asesores.' },
  trust_spreadsheets_title: { en: 'No spreadsheets required', es: 'Sin depender de hojas de calculo' },
  trust_spreadsheets_body: { en: 'Replace scattered files with one organized financial workspace.', es: 'Reemplaza archivos dispersos con un espacio financiero organizado.' },
  trust_visibility_title: { en: 'Real-time financial visibility', es: 'Visibilidad financiera en tiempo real' },
  trust_visibility_body: { en: 'Turn daily activity into cash flow, budget, and subscription signals.', es: 'Convierte la actividad diaria en señales de flujo, presupuestos y suscripciones.' },
  btn_pricing: { en: 'See Pricing', es: 'Ver precios' },
  btn_learnMore: { en: 'Learn More', es: 'Conocer más' },
  btn_guide: { en: 'User Guide', es: 'Guía de uso' },
  features_eyebrow: { en: 'How it works', es: 'Cómo funciona' },
  features_title: { en: 'From scattered finances to clear decisions', es: 'De finanzas dispersas a decisiones claras' },
  features_sub: {
    en: 'FinSight helps you organize your financial workflow step by step, so you can understand cash flow, control expenses, and act with confidence.',
    es: 'FinSight te ayuda a ordenar tu flujo financiero paso a paso para entender tu efectivo, controlar gastos y actuar con confianza.'
  },
  workflow_cta_primary: { en: 'Get Started', es: 'Comenzar' },
  workflow_preview_title: { en: 'Workflow preview', es: 'Vista del flujo' },
  workflow_preview_status: { en: 'Updated', es: 'Actualizado' },
  workflow_preview_raw: { en: 'New transaction imported', es: 'Nueva transacción importada' },
  workflow_preview_category: { en: 'Category assigned', es: 'Categoría asignada' },
  workflow_preview_operations: { en: 'Operations', es: 'Operaciones' },
  workflow_preview_budget: { en: 'Budget updated', es: 'Presupuesto actualizado' },
  workflow_preview_insight: { en: 'Insight generated', es: 'Insight generado' },
  workflow_step1_title: { en: 'Add your financial data', es: 'Agrega tu información financiera' },
  workflow_step1_desc: {
    en: 'Bring accounts, transactions, projects, invoices, and subscriptions into one clean workspace.',
    es: 'Reúne cuentas, transacciones, proyectos, facturas y suscripciones en un espacio limpio.'
  },
  workflow_step2_title: { en: 'Organize your money', es: 'Organiza tu dinero' },
  workflow_step2_desc: {
    en: 'Categorize spending, track budgets, monitor projects, and keep important dates visible.',
    es: 'Categoriza gastos, da seguimiento a presupuestos, monitorea proyectos y mantén fechas importantes a la vista.'
  },
  workflow_step3_title: { en: 'Understand what changed', es: 'Entiende qué cambió' },
  workflow_step3_desc: {
    en: 'Use dashboards and visual insights to spot trends, expense changes, and recurring costs.',
    es: 'Usa tableros e insights visuales para detectar tendencias, cambios de gasto y costos recurrentes.'
  },
  workflow_step4_title: { en: 'Make better decisions', es: 'Toma mejores decisiones' },
  workflow_step4_desc: {
    en: 'Move from scattered spreadsheets to clear financial actions for your business.',
    es: 'Pasa de hojas de cálculo dispersas a acciones financieras claras para tu negocio.'
  },
  pricing_title: { en: 'Simple pricing', es: 'Precios simples' },
  pricing_sub: { en: 'Start free. Upgrade anytime.', es: 'Comienza gratis. Mejora cuando quieras.' },
  price_pro: { en: '200 MXN + tax', es: '200 MXN + impuestos' },
  price_web: { en: 'Web: 200 MXN + tax/month', es: 'Web: 200 MXN + impuestos/mes' },
  price_googlePlay: { en: 'Google Play: 235 MXN/month', es: 'Google Play: 235 MXN/mes' },
  price_appStore: { en: 'App Store: 249 MXN/month', es: 'App Store: 249 MXN/mes' },
  per_month: { en: 'month', es: 'mes' },
  plan_free: { en: 'Free', es: 'Gratis' },
  plan_pro: { en: 'Pro', es: 'Pro' },
  free_core: { en: 'Core budgeting tools', es: 'Herramientas básicas de presupuesto' },
  free_accounts: { en: 'Up to 3 accounts', es: 'Hasta 3 cuentas' },
  free_secure: { en: 'Secure by design', es: 'Seguro por diseño' },
  btn_createFree: { en: 'Create free account', es: 'Crear cuenta gratis' },
  pro_unlimited: { en: 'Unlimited accounts', es: 'Cuentas ilimitadas' },
  pro_analytics: { en: 'Analytics & charts', es: 'Analíticas y gráficos' },
  pro_projects: { en: 'Projects & invoices', es: 'Proyectos y facturas' },
  pro_ai: { en: 'AI financial consultant', es: 'Consultor financiero con IA' },
  pro_support: { en: 'Priority support', es: 'Soporte prioritario' },
  btn_upgrade: { en: 'Upgrade to Pro', es: 'Mejorar a Pro' },
  pricing_note: { en: 'Cancel anytime. Stripe-secured payments.', es: 'Cancela cuando quieras. Pagos seguros con Stripe.' },
  cta_title: { en: 'Ready to take control of your financial workflow?', es: '¿Listo para tomar control de tu flujo financiero?' },
  cta_sub: { en: 'Start with a clean overview of your money, expenses, budgets, and decisions - all in one place.', es: 'Empieza con una vista clara de tu dinero, gastos, presupuestos y decisiones - todo en un solo lugar.' },
  cta_note: { en: 'Free and Pro plans available. Cancel anytime.', es: 'Planes Free y Pro disponibles. Cancela cuando quieras.' },
  footer_tagline: { en: 'Financial clarity for freelancers, entrepreneurs, and growing businesses.', es: 'Claridad financiera para freelancers, emprendedores y negocios en crecimiento.' },
  footer_note: { en: 'Built for clear financial decisions.', es: 'Creado para tomar decisiones financieras claras.' },
} as const;
