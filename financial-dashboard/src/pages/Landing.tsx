import { Link } from 'react-router-dom';
import { TrendingUp, Shield, Zap, Users, CreditCard, PieChart, Calendar } from 'lucide-react';
import AppCarousel from '../components/AppCarousel';
import { useEffect } from 'react';
import { useI18n } from '../contexts/I18nContext';

const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.finsight.finsight&pcampaignid=web_share';

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

export default function Landing() {
  const { language, setLanguage } = useI18n();
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
      <section className="py-20 px-4">
        <div className="max-w-4xl mx-auto text-center">
          <a
            href={PLAY_STORE_URL}
            target="_blank"
            rel="noreferrer"
            className="mb-4 inline-flex items-center justify-center gap-2 rounded-full border border-green-200 bg-green-50 px-4 py-2 text-sm font-medium text-green-800 transition-colors hover:bg-green-100"
          >
            <span className="rounded-full bg-green-600 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-white">
              {L('news_label')}
            </span>
            <span>{L('news_androidRelease')}</span>
          </a>
          <span className="inline-flex items-center gap-1 rounded-full bg-gray-100 dark:bg-gray-800 px-3 py-1 text-xs font-medium text-gray-700 dark:text-gray-300 mb-4">
            <Zap className="w-3 h-3" /> {L('hero_badge')}
          </span>
          <h1 className="text-4xl md:text-6xl font-bold text-gray-900 dark:text-gray-100 mb-6">
            {L('hero_title_1')} <span className="text-blue-600">{L('hero_title_2')}</span>
          </h1>
          <p className="text-xl text-gray-600 dark:text-gray-300 mb-8 max-w-2xl mx-auto">{L('hero_subtitle')}</p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link to="/signup" className="inline-flex items-center justify-center rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-lg px-8 py-3">{L('cta_getStarted')}</Link>
            <a
              href={PLAY_STORE_URL}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center justify-center gap-2 rounded-lg border border-gray-300 px-8 py-3 text-lg font-medium text-gray-900 hover:bg-gray-50"
            >
              <PlayStoreIcon />
              {L('cta_downloadAndroid')}
            </a>
          </div>
        </div>
      </section>

      {/* Dashboard Preview (Carousel) */}
      <section className="py-16 px-4 bg-gray-50 dark:bg-gray-900/40">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-12" id="demo">
            <h2 className="text-3xl font-bold text-gray-900 dark:text-gray-100 mb-4">{L('preview_title')}</h2>
            <p className="text-lg text-gray-600 dark:text-gray-300">{L('preview_sub')}</p>
          </div>
          <AppCarousel />
        </div>
      </section>

      {/* Key Metrics */}
      <section className="py-16 px-4">
        <div className="max-w-6xl mx-auto">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-2xl mx-auto">
            {[
              { label: 'Uptime', value: '99.9%' },
              { label: 'Support', value: '24/7' },
            ].map((m) => (
              <div key={m.label} className="text-center rounded-xl bg-white dark:bg-gray-900 ring-1 ring-black/5 dark:ring-white/10 p-6">
                <div className="text-3xl font-bold text-blue-600 mb-2">{m.value}</div>
                <div className="text-sm text-gray-500 dark:text-gray-400">{m.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* About */}
      <section id="about" className="py-16 px-4 bg-gray-50 dark:bg-gray-900/40">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-3xl font-bold text-gray-900 dark:text-gray-100 mb-4">{L('about_title')}</h2>
          <p className="text-lg text-gray-600 dark:text-gray-300 max-w-3xl mx-auto">
            {L('about_body')}
          </p>
          <div className="mt-6 flex items-center justify-center gap-3">
            <a href="#pricing" className="inline-flex items-center rounded-md bg-blue-600 hover:bg-blue-700 px-4 py-2 text-white">{L('btn_pricing')}</a>
            <a href="#features" className="inline-flex items-center rounded-md border border-gray-300 dark:border-gray-700 px-4 py-2 text-gray-800 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800">{L('btn_learnMore')}</a>
            <Link to="/guide" className="inline-flex items-center rounded-md border border-gray-300 dark:border-gray-700 px-4 py-2 text-gray-800 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800">{L('btn_guide')}</Link>
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="py-20 px-4 bg-gray-50 dark:bg-gray-900/40">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 dark:text-gray-100 mb-4">{L('features_title')}</h2>
            <p className="text-xl text-gray-600 dark:text-gray-300 max-w-2xl mx-auto">{L('features_sub')}</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 max-w-6xl mx-auto">
            {[
              { icon: <TrendingUp className="w-6 h-6 text-blue-600" />, title: 'Real-time Analytics', desc: 'Track financial performance with live data updates and comprehensive dashboards.' },
              { icon: <PieChart className="w-6 h-6 text-blue-600" />, title: 'Account Management', desc: 'Centralize all accounts in one place with summaries and balance tracking.' },
              { icon: <CreditCard className="w-6 h-6 text-blue-600" />, title: 'Transaction Insights', desc: 'Monitor transactions with intelligent categorization and spending analysis.' },
              { icon: <Calendar className="w-6 h-6 text-blue-600" />, title: 'Upcoming Events', desc: 'Never miss important dates with smart reminders and event tracking.' },
              { icon: <Shield className="w-6 h-6 text-blue-600" />, title: 'Bank-level Security', desc: 'Enterprise-grade encryption and security practices to protect your data.' },
              { icon: <Users className="w-6 h-6 text-blue-600" />, title: 'Multi-user Access', desc: 'Collaborate with role-based permissions for your team and advisors.' },
            ].map((f) => (
              <div key={f.title} className="rounded-xl bg-white dark:bg-gray-900 ring-1 ring-black/5 dark:ring-white/10 p-6">
                <div className="w-12 h-12 bg-blue-600/10 rounded-lg flex items-center justify-center mb-4">{f.icon}</div>
                <div className="text-lg font-semibold text-gray-900 dark:text-gray-100">{f.title}</div>
                <div className="text-sm text-gray-600 dark:text-gray-300 mt-1">{f.desc}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="py-20 px-4">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-10">
            <h2 className="text-3xl font-bold text-gray-900 dark:text-gray-100">{L('pricing_title')}</h2>
            <p className="text-gray-600 dark:text-gray-300">{L('pricing_sub')}</p>
          </div>
          <div className="grid sm:grid-cols-2 gap-6">
            <div className="rounded-2xl bg-white dark:bg-gray-900 ring-1 ring-black/5 dark:ring-white/10 p-6">
              <div className="text-xs font-semibold text-gray-500">{L('plan_free')}</div>
              <div className="mt-2 text-3xl font-extrabold text-gray-900 dark:text-white">$0</div>
              <ul className="mt-4 space-y-2 text-sm text-gray-600 dark:text-gray-300">
                <li>{L('free_core')}</li>
                <li>{L('free_accounts')}</li>
                <li>{L('free_secure')}</li>
              </ul>
              <Link to="/signup" className="mt-5 inline-flex items-center gap-2 rounded-lg bg-gray-800 dark:bg-gray-700 px-4 py-2 text-white font-semibold hover:bg-gray-900">{L('btn_createFree')}</Link>
            </div>
            <div className="rounded-2xl bg-gradient-to-b from-blue-600 to-indigo-600 p-[1px]">
              <div className="rounded-2xl bg-white dark:bg-gray-900 p-6">
                <div className="flex items-center justify-between">
                  <div className="text-xs font-semibold text-gray-500 dark:text-gray-400">{L('plan_pro')}</div>
                  <div className="inline-flex items-center gap-1 text-[10px] uppercase tracking-wide text-white bg-amber-500/80 px-2 py-0.5 rounded">Popular</div>
                </div>
                <div className="mt-2 text-3xl font-extrabold text-gray-900 dark:text-white">{L('price_pro')} <span className="text-sm font-medium text-gray-500">/{L('per_month')}</span></div>
                <ul className="mt-4 space-y-2 text-sm text-gray-600 dark:text-gray-300">
                  <li>{L('pro_unlimited')}</li>
                  <li>{L('pro_analytics')}</li>
                  <li>{L('pro_projects')}</li>
                  <li>{L('pro_support')}</li>
                </ul>
                <Link to="/signup" className="mt-5 inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-white font-semibold hover:bg-blue-700">{L('btn_upgrade')}</Link>
              </div>
            </div>
          </div>
          <div className="mt-6 text-xs text-gray-500 flex items-center justify-center gap-2">
            <Shield className="h-4 w-4" /> {L('pricing_note')}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-4">
        <div className="max-w-3xl mx-auto text-center">
          <h2 className="text-3xl md:text-4xl font-bold text-gray-900 dark:text-gray-100 mb-6">{L('cta_title')}</h2>
          <p className="text-xl text-gray-600 dark:text-gray-300 mb-8">{L('cta_sub')}</p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link to="/signup" className="inline-flex items-center justify-center rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-lg px-8 py-3">{L('cta_getStarted')}</Link>
            <a
              href={PLAY_STORE_URL}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center justify-center gap-2 rounded-lg border border-gray-300 px-8 py-3 text-lg font-medium text-gray-900 hover:bg-gray-50"
            >
              <PlayStoreIcon />
              {L('cta_downloadAndroid')}
            </a>
          </div>
          <p className="text-sm text-gray-500 mt-4">{L('cta_note')}</p>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 py-12 px-4">
        <div className="max-w-6xl mx-auto">
          <div className="flex flex-col md:flex-row justify-between items-center">
            <div className="flex items-center space-x-2 mb-4 md:mb-0">
              <img src="/finsight-icon.svg" alt="FinSight" className="w-8 h-8" />
              <span className="text-xl font-bold text-gray-900 dark:text-gray-100">FinSight</span>
            </div>
            <div className="flex space-x-6 text-sm text-gray-500 dark:text-gray-400">
              <Link to="/privacy" className="hover:text-gray-900 dark:hover:text-gray-100 transition-colors">Privacy</Link>
              <Link to="/terms" className="hover:text-gray-900 dark:hover:text-gray-100 transition-colors">Terms</Link>
              <Link to="/guide" className="hover:text-gray-900 dark:hover:text-gray-100 transition-colors">User Guide</Link>
              <a href="mailto:sheremelias@gmail.com" className="hover:text-gray-900 dark:hover:text-gray-100 transition-colors">Contact</a>
            </div>
          </div>
          <div className="mt-8 pt-8 border-t border-gray-200 dark:border-gray-800 text-center text-sm text-gray-500 dark:text-gray-400">
            © {new Date().getFullYear()} FinSight. All rights reserved.
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
  news_androidRelease: { en: 'FinSight has just launched on Android. Download it on Google Play.', es: 'FinSight acaba de lanzarse en Android. Descárgala en Google Play.' },
  hero_badge: { en: 'Financial Intelligence Platform', es: 'Plataforma de inteligencia financiera' },
  hero_title_1: { en: 'Master Your Financial', es: 'Domina tu' },
  hero_title_2: { en: 'Overview', es: 'Panorama financiero' },
  hero_subtitle: {
    en: 'Get complete visibility into your finances with real-time analytics, intelligent insights, and powerful dashboard tools designed for modern financial management.',
    es: 'Obtén visibilidad completa de tus finanzas con analíticas en tiempo real, insights inteligentes y potentes tableros para la gestión moderna.'
  },
  cta_getStarted: { en: 'Get Started Now', es: 'Comenzar ahora' },
  cta_downloadAndroid: { en: 'Download on Google Play', es: 'Descargar en Google Play' },
  preview_title: { en: "Explore FinSight's Powerful Features", es: 'Explora las funciones de FinSight' },
  preview_sub: { en: 'See how FinSight transforms your financial management experience', es: 'Mira cómo FinSight transforma la gestión de tus finanzas' },
  about_title: { en: 'About FinSight', es: 'Sobre FinSight' },
  about_body: {
    en: 'FinSight is a modern personal finance platform built to help you make better decisions. Track accounts and transactions, plan projects and budgets, manage invoices and subscriptions, and visualize trends with clean, actionable analytics. Start free and upgrade to Pro for advanced dashboards and unlimited accounts.',
    es: 'FinSight es una plataforma moderna de finanzas personales para ayudarte a tomar mejores decisiones. Registra cuentas y transacciones, planifica proyectos y presupuestos, gestiona facturas y suscripciones, y visualiza tendencias con analíticas claras y accionables. Comienza gratis y mejora a Pro para tableros avanzados y cuentas ilimitadas.'
  },
  btn_pricing: { en: 'See Pricing', es: 'Ver precios' },
  btn_learnMore: { en: 'Learn More', es: 'Conocer más' },
  btn_guide: { en: 'User Guide', es: 'Guía de uso' },
  features_title: { en: 'Everything You Need for Financial Success', es: 'Todo lo que necesitas para tu éxito financiero' },
  features_sub: { en: 'Comprehensive tools and insights to manage, analyze, and optimize your financial portfolio.', es: 'Herramientas e insights para gestionar, analizar y optimizar tus finanzas.' },
  pricing_title: { en: 'Simple pricing', es: 'Precios simples' },
  pricing_sub: { en: 'Start free. Upgrade anytime.', es: 'Comienza gratis. Mejora cuando quieras.' },
  price_pro: { en: '200 MXN', es: '200 MXN' },
  per_month: { en: 'month', es: 'mes' },
  plan_free: { en: 'Free', es: 'Gratis' },
  plan_pro: { en: 'Pro', es: 'Pro' },
  free_core: { en: 'Core budgeting tools', es: 'Herramientas básicas de presupuesto' },
  free_accounts: { en: 'Up to 2 accounts', es: 'Hasta 2 cuentas' },
  free_secure: { en: 'Secure by design', es: 'Seguro por diseño' },
  btn_createFree: { en: 'Create free account', es: 'Crear cuenta gratis' },
  pro_unlimited: { en: 'Unlimited accounts', es: 'Cuentas ilimitadas' },
  pro_analytics: { en: 'Analytics & charts', es: 'Analíticas y gráficos' },
  pro_projects: { en: 'Projects & invoices', es: 'Proyectos y facturas' },
  pro_support: { en: 'Priority support', es: 'Soporte prioritario' },
  btn_upgrade: { en: 'Upgrade to Pro', es: 'Mejorar a Pro' },
  pricing_note: { en: 'Cancel anytime. Stripe-secured payments.', es: 'Cancela cuando quieras. Pagos seguros con Stripe.' },
  cta_title: { en: 'Ready to Transform Your Financial Management?', es: '¿Listo para transformar tus finanzas?' },
  cta_sub: { en: 'Join users who trust FinSight for insights and decision-making.', es: 'Únete a quienes confían en FinSight para obtener insights y decidir mejor.' },
  cta_note: { en: 'Free and Pro plans available.', es: 'Planes Gratis y Pro disponibles.' },
} as const;
