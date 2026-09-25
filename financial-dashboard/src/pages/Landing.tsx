import { lazy, Suspense, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, ArrowUpRight, Check, ChevronRight, Menu, X, WalletCards, Target, ChartNoAxesCombined } from 'lucide-react';
import { motion, useReducedMotion } from 'framer-motion';
import AppCarousel from '../components/AppCarousel';
import { useI18n } from '../contexts/I18nContext';
import './landing.css';

const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.finsight.finsight&pcampaignid=web_share';
const APP_STORE_URL = 'https://apps.apple.com/mx/app/finsight/id6761848896';
const LandingHeroScene = lazy(() => import('../components/LandingHeroScene'));
const EASE = [0.22, 1, 0.36, 1] as const;

export default function Landing() {
  const { language, setLanguage } = useI18n();
  const reduced = Boolean(useReducedMotion());
  const [menuOpen, setMenuOpen] = useState(false);
  const [activeSection, setActiveSection] = useState('overview');
  const menuButton = useRef<HTMLButtonElement>(null);
  const L = (en: string, es: string) => language === 'es' ? es : en;
  const navigation = [
    { id: 'overview', title: L('Overview', 'Vista general') },
    { id: 'features', title: L('Features', 'Funciones') },
    { id: 'momentum', title: 'Momentum' },
    { id: 'pricing', title: L('Plans', 'Planes') },
  ];
  const reveal = (delay = 0) => ({
    initial: reduced ? false as const : { opacity: 0, y: 32 },
    whileInView: { opacity: 1, y: 0 },
    viewport: { once: true, amount: 0.12 },
    transition: { duration: reduced ? 0 : 0.9, ease: EASE, delay: reduced ? 0 : delay },
  });

  useEffect(() => {
    document.documentElement.classList.add('finsight-landing-scroll');
    const anchor = window.location.hash.slice(1);
    const frame = requestAnimationFrame(() => {
      if (['overview', 'momentum', 'features', 'pricing', 'about', 'demo'].includes(anchor)) {
        document.getElementById(anchor)?.scrollIntoView({ behavior: 'instant', block: 'start' });
      }
    });
    let observer: IntersectionObserver;
    const observeSections = () => {
      observer?.disconnect();
      const top = Math.min(100, window.innerHeight * 0.2);
      const bottom = Math.max(0, window.innerHeight - top - 160);
      observer = new IntersectionObserver(entries => {
        for (const entry of entries) if (entry.isIntersecting) setActiveSection(entry.target.id);
      }, { rootMargin: `-${top}px 0px -${bottom}px 0px` });
      ['overview', 'features', 'momentum', 'pricing'].forEach(id => {
        const section = document.getElementById(id);
        if (section) observer.observe(section);
      });
    };
    observeSections();
    window.addEventListener('resize', observeSections);
    return () => {
      cancelAnimationFrame(frame);
      observer.disconnect();
      window.removeEventListener('resize', observeSections);
      document.documentElement.classList.remove('finsight-landing-scroll');
    };
  }, []);

  useEffect(() => {
    if (!menuOpen) return;
    const close = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setMenuOpen(false);
        menuButton.current?.focus();
      }
    };
    document.addEventListener('keydown', close);
    return () => document.removeEventListener('keydown', close);
  }, [menuOpen]);

  return (
    <div className="landing-page">
      <a href="#overview" className="landing-skip">{L('Skip to content', 'Ir al contenido')}</a>
      <header className="landing-nav">
        <div className="landing-nav-inner">
          <a href="#overview" onClick={() => setMenuOpen(false)} className="landing-brand" aria-label={L('FinSight overview', 'Vista general de FinSight')}>
            <img src="/finsight-icon.svg" alt="" width={25} height={25} />
            <span>FinSight</span>
          </a>
          <nav className="landing-nav-desktop" aria-label={L('Main navigation', 'Navegación principal')}>
            {navigation.map(item => <a key={item.id} href={`#${item.id}`} aria-current={activeSection === item.id ? 'location' : undefined}>{item.title}</a>)}
          </nav>
          <div className="landing-nav-actions">
            <button className="landing-language" type="button" onClick={() => setLanguage(language === 'es' ? 'en' : 'es')} aria-label={L('Cambiar a español', 'Switch to English')}>{language === 'es' ? 'EN' : 'ES'}</button>
            <Link className="landing-signin" to="/login">{L('Sign in', 'Iniciar sesión')}</Link>
            <Link className="landing-button landing-button-small" to="/signup">{L('Get started', 'Comenzar')}</Link>
            <button className="landing-menu-button" ref={menuButton} onClick={() => setMenuOpen(!menuOpen)} aria-expanded={menuOpen} aria-controls="landing-mobile-menu" aria-label={menuOpen ? L('Close menu', 'Cerrar menú') : L('Open menu', 'Abrir menú')}>
              {menuOpen ? <X size={20} /> : <Menu size={20} />}
            </button>
          </div>
        </div>
        <nav id="landing-mobile-menu" className="landing-mobile-menu" hidden={!menuOpen} aria-label={L('Mobile navigation', 'Navegación móvil')}>
          {navigation.map(item => <a key={item.id} href={`#${item.id}`} onClick={() => setMenuOpen(false)} aria-current={activeSection === item.id ? 'location' : undefined}>{item.title}<ChevronRight size={17} aria-hidden="true" /></a>)}
          <div className="landing-mobile-menu-bottom">
            <Link to="/login">{L('Sign in', 'Iniciar sesión')}</Link>
            <button type="button" onClick={() => setLanguage(language === 'es' ? 'en' : 'es')}>{L('Español', 'English')}</button>
          </div>
        </nav>
      </header>

      <main>
        <section id="overview" className="landing-overview" aria-labelledby="landing-title">
          <div className="landing-hero-copy">
            <motion.a {...reveal()} href="#momentum" className="landing-announcement">{L('Meet FinSight Momentum', 'Conoce FinSight Momentum')}<ChevronRight size={16} aria-hidden="true" /></motion.a>
            <h1 id="landing-title" className="landing-hero-title">
              {[L('Your money.', 'Tu dinero.'), L('A clearer picture.', 'Todo en perspectiva.')].map((line, index) => <span className="landing-title-mask" key={line}>
                <motion.span initial={reduced ? false : { y: '105%' }} animate={{ y: 0 }} transition={{ duration: reduced ? 0 : 1.05, delay: reduced ? 0 : 0.12 + index * 0.12, ease: EASE }}>{line}</motion.span>
              </span>)}
            </h1>
            <motion.p {...reveal(0.16)} className="landing-hero-description">{L('Accounts, spending, and goals. Finally, together.', 'Cuentas, gastos y metas. Juntos, por fin.')}</motion.p>
            <motion.div {...reveal(0.24)} className="landing-hero-actions">
              <Link to="/signup" className="landing-button">{L('Start free', 'Empieza gratis')}</Link>
              <a href="#features" className="landing-text-link">{L('Explore FinSight', 'Explora FinSight')}<ChevronRight size={17} aria-hidden="true" /></a>
            </motion.div>
          </div>
          <motion.div className="landing-cinema" initial={reduced ? false : { opacity: 0, y: 60, scale: 0.96 }} whileInView={{ opacity: 1, y: 0, scale: 1 }} viewport={{ once: true, amount: 0.1 }} transition={{ duration: reduced ? 0 : 1.25, ease: EASE }}>
            <Suspense fallback={<div className="landing-scene-loading"><span>FinSight</span><span>{L('Your financial overview', 'Tu panorama financiero')}</span></div>}>
              <LandingHeroScene variant="side-hero" />
            </Suspense>
          </motion.div>
          <p className="landing-platform-note">{L('On the web. On iPhone. On Android.', 'En la web. En iPhone. En Android.')}</p>
        </section>

        <section id="features" className="landing-section landing-section-muted" aria-labelledby="features-title">
          <div className="landing-container">
            <motion.div className="landing-section-heading" {...reveal()}>
              <p className="landing-eyebrow">{L('Your everyday, in focus', 'Tu día a día, más claro')}</p>
              <h2 id="features-title">{L('Everything connects.', 'Todo encaja.')}<br /><span>{L('It all makes sense.', 'Todo se entiende.')}</span></h2>
              <p>{L('See what comes in, where it goes, and what comes next. Explore a few of the things you can do with FinSight.', 'Mira lo que entra, en qué se va y qué viene después. Explora lo que puedes hacer con FinSight.')}</p>
            </motion.div>
            <div id="demo" className="landing-demo"><AppCarousel /></div>
          </div>
        </section>

        <section id="momentum" className="landing-section landing-momentum" aria-labelledby="momentum-title">
          <div className="landing-container landing-momentum-grid">
            <motion.div className="landing-momentum-copy" {...reveal()}>
              <div className="landing-momentum-label"><img src="/momentum/assets/ui/momentum_mark__light.svg" alt="" width={30} height={30} loading="lazy" /><span>FinSight Momentum</span></div>
              <h2 id="momentum-title">{L('Small steps.', 'Pequeños pasos.')}<br /><span>{L('Progress you can see.', 'Logros que se ven.')}</span></h2>
              <p>{L('Organize an account. Review your week. Build a habit. Every step becomes part of your story.', 'Organiza una cuenta. Revisa tu semana. Crea un hábito. Cada paso forma parte de tu historia.')}</p>
              <p className="landing-momentum-detail">{L('Discover your level and collect the badges you earn, all in your profile.', 'Descubre tu nivel y reúne las insignias que ganas, todo en tu perfil.')}</p>
              <Link to="/signup" className="landing-text-link">{L('Start your collection', 'Empieza tu colección')}<ChevronRight size={17} aria-hidden="true" /></Link>
            </motion.div>
            <motion.figure className="landing-achievement" initial={reduced ? false : 'hidden'} whileInView="visible" viewport={{ once: true, amount: 0.25 }} variants={{ hidden: { opacity: 0, y: 48, rotateX: 14 }, visible: { opacity: 1, y: 0, rotateX: 0, transition: { duration: reduced ? 0 : 1.1, ease: EASE, staggerChildren: reduced ? 0 : 0.16, delayChildren: reduced ? 0 : 0.22 } } }}>
              <div className="landing-profile-card">
                <div className="landing-profile-top"><span>Momentum</span><span>{L('Preview', 'Vista previa')}</span></div>
                <div className="landing-profile-level">
                  <motion.img variants={{ hidden: { scale: 0.65, rotate: -15 }, visible: { scale: 1, rotate: 0, transition: { duration: reduced ? 0 : 1, ease: EASE } } }} src="/momentum/assets/levels/organizer__light.svg" alt="" width={100} height={100} loading="lazy" />
                  <div><p>{L('Your level', 'Tu nivel')}</p><h3>{L('Organizer', 'Organizador')}</h3><span>{L('One habit at a time.', 'Un hábito a la vez.')}</span></div>
                </div>
                <p className="landing-collection-title">{L('A collection of small wins', 'Una colección de pequeños logros')}</p>
                <ul className="landing-badges">
                  {[
                    { asset: 'account_organizer', title: L('Account Organizer', 'Organizador de cuentas') },
                    { asset: 'money_mapper', title: L('Money Mapper', 'Mapa financiero') },
                    { asset: 'weekly_rhythm', title: L('Weekly Rhythm', 'Ritmo semanal') },
                  ].map(badge => <motion.li key={badge.asset} variants={{ hidden: { opacity: 0, y: 36, scale: 0.78, rotate: -6 }, visible: { opacity: 1, y: 0, scale: 1, rotate: 0, transition: { duration: reduced ? 0 : 0.85, ease: EASE } } }}>
                    <img src={`/momentum/assets/badges/${badge.asset}__light.svg`} alt="" width={80} height={80} loading="lazy" /><span>{badge.title}</span>
                  </motion.li>)}
                </ul>
              </div>
              <figcaption>{L('An example of the profile you build with Momentum.', 'Una muestra del perfil que construyes con Momentum.')}</figcaption>
            </motion.figure>
          </div>
        </section>

        <section id="about" className="landing-section landing-section-muted" aria-labelledby="everyday-title">
          <div className="landing-container">
            <motion.div className="landing-section-heading landing-heading-wide" {...reveal()}><p className="landing-eyebrow">{L('A little more perspective', 'Un poco más de perspectiva')}</p><h2 id="everyday-title">{L('Made for real life.', 'Hecho para la vida real.')}</h2></motion.div>
            <div className="landing-benefits">
              {[
                { icon: <WalletCards size={30} strokeWidth={1.5} />, title: L('A place for every account.', 'Un lugar para cada cuenta.'), copy: L('Your balances and transactions, together in one view.', 'Tus saldos y movimientos, juntos en una sola vista.') },
                { icon: <ChartNoAxesCombined size={30} strokeWidth={1.5} />, title: L('Clarity for your next move.', 'Claridad para decidir.'), copy: L('Understand your spending with categories, budgets, and charts.', 'Entiende tus gastos con categorías, presupuestos y gráficos.') },
                { icon: <Target size={30} strokeWidth={1.5} />, title: L('Space for what matters.', 'Espacio para lo que importa.'), copy: L('Plan your goals and keep upcoming payments in view.', 'Planea tus metas y ten a la vista tus próximos pagos.') },
              ].map((item, index) => <motion.article key={item.title} className="landing-benefit" {...reveal(index * 0.12)}><span>{item.icon}</span><h3>{item.title}</h3><p>{item.copy}</p></motion.article>)}
            </div>
            <Link className="landing-text-link landing-guide-link" to="/guide">{L('Discover how it works', 'Descubre cómo funciona')}<ChevronRight size={17} aria-hidden="true" /></Link>
          </div>
        </section>

        <section id="pricing" className="landing-section" aria-labelledby="plans-title">
          <div className="landing-container">
            <motion.div className="landing-section-heading landing-centered" {...reveal()}><p className="landing-eyebrow">{L('Your FinSight', 'Tu FinSight')}</p><h2 id="plans-title">{L('Choose your starting point.', 'Elige tu punto de partida.')}</h2><p>{L('Start free. Make room for more when you need it.', 'Empieza gratis. Da el siguiente paso cuando lo necesites.')}</p></motion.div>
            <div className="landing-plans">
              <motion.article className="landing-plan" {...reveal()}>
                <p className="landing-plan-label">FinSight</p><h3>{L('Free', 'Gratis')}</h3><p className="landing-plan-description">{L('A clearer view of your everyday.', 'Tu día a día, mucho más claro.')}</p>
                <p className="landing-plan-price">$0<span> MXN</span></p><p className="landing-plan-period">{L('No subscription required', 'Sin suscripción')}</p>
                <Link to="/signup" className="landing-button">{L('Start free', 'Empieza gratis')}</Link>
                <ul>{[L('Up to 3 accounts', 'Hasta 3 cuentas'), L('Core budgeting tools', 'Herramientas básicas de presupuesto'), L('Your finances, in one place', 'Tus finanzas, en un solo lugar')].map(text => <li key={text}><Check size={16} aria-hidden="true" />{text}</li>)}</ul>
              </motion.article>
              <motion.article className="landing-plan landing-plan-pro" {...reveal(0.12)}>
                <p className="landing-plan-label">FinSight</p><h3>Pro</h3><p className="landing-plan-description">{L('More room for your plans.', 'Más espacio para tus planes.')}</p>
                <p className="landing-plan-price">$200<span> MXN</span></p><p className="landing-plan-period">{L('+ tax / month on the web', '+ impuestos / mes en la web')}</p>
                <Link to="/signup" className="landing-button">{L('Choose Pro', 'Elige Pro')}</Link>
                <ul>{[L('Unlimited accounts', 'Cuentas ilimitadas'), L('Analytics and charts', 'Analíticas y gráficos'), L('Projects and invoices', 'Proyectos y facturas'), L('AI financial consultant', 'Consultor financiero con IA'), L('Priority support', 'Soporte prioritario')].map(text => <li key={text}><Check size={16} aria-hidden="true" />{text}</li>)}</ul>
                <p className="landing-store-prices">Google Play: $235 MXN/{L('month', 'mes')}<br />App Store: $249 MXN/{L('month', 'mes')}</p>
              </motion.article>
            </div>
            <p className="landing-pricing-note">{L('Cancel anytime. Web payments processed by Stripe.', 'Cancela cuando quieras. Pagos web procesados por Stripe.')}</p>
          </div>
        </section>

        <section className="landing-section landing-download" aria-labelledby="download-title">
          <motion.div className="landing-container landing-centered" {...reveal()}>
            <img src="/finsight-icon.svg" alt="" width={64} height={64} className="landing-app-icon" loading="lazy" />
            <h2 id="download-title">{L('A fresh look at your money.', 'Mira tu dinero con otros ojos.')}</h2>
            <p>{L('Wherever life takes you.', 'Donde sea que estés.')}</p>
            <Link to="/signup" className="landing-button">{L('Open FinSight', 'Abre FinSight')}<ArrowRight size={17} aria-hidden="true" /></Link>
            <div className="landing-download-links"><a href={APP_STORE_URL} target="_blank" rel="noreferrer">App Store<ArrowUpRight size={15} aria-hidden="true" /></a><a href={PLAY_STORE_URL} target="_blank" rel="noreferrer">Google Play<ArrowUpRight size={15} aria-hidden="true" /></a></div>
          </motion.div>
        </section>
      </main>
      <footer className="landing-footer"><div className="landing-container">
        <div className="landing-footer-top"><span className="landing-brand">FinSight</span><span>{L('A clearer perspective on your finances.', 'Una perspectiva más clara de tus finanzas.')}</span></div>
        <div className="landing-footer-bottom"><span>© {new Date().getFullYear()} FinSight.</span><nav aria-label={L('Footer', 'Pie de página')}><Link to="/privacy">{L('Privacy', 'Privacidad')}</Link><Link to="/terms">{L('Terms', 'Términos')}</Link><Link to="/guide">{L('Guide', 'Guía')}</Link><a href="mailto:sheremelias@gmail.com">{L('Contact', 'Contacto')}</a></nav><button type="button" onClick={() => setLanguage(language === 'es' ? 'en' : 'es')}>{language === 'es' ? 'English' : 'Español'}</button></div>
      </div></footer>
    </div>
  );
}
