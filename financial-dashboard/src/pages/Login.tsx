import { useState, useEffect, useRef } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { LogIn, UserPlus } from 'lucide-react';
import { useI18n } from '../contexts/I18nContext';
import { resolveApi } from '../utils/api';
import AuthShell, { authVisualIcons } from '../components/auth/AuthShell';

export default function Login() {
  const navigate = useNavigate();
  const { t } = useI18n();
  const googleDiv = useRef<HTMLDivElement | null>(null);
  const [credentials, setCredentials] = useState({
    username: '',
    password: ''
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  // state not currently used but kept if we need to disable controls while loading
  // const [googleReady, setGoogleReady] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const API_BASE = resolveApi();
      const response = await fetch(`${API_BASE}/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(credentials),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        // Store token in localStorage
        localStorage.setItem('token', data.token);
        localStorage.setItem('user', JSON.stringify(data.user));
        window.dispatchEvent(new Event('finsight:session-changed'));
        
        // Navigate to onboarding if not completed for this user
        const uid = data?.user?.id;
        const onboarded = uid ? localStorage.getItem(`onboarded:${uid}`) : '1';
        if (!onboarded) {
          navigate('/onboarding');
        } else {
          navigate('/');
        }
      } else {
        setError(data.message || t('login.err.failed'));
      }
    } catch (err) {
      setError(t('login.err.unreachable'));
    } finally {
      setLoading(false);
    }
  };

  // Load Google Identity Services and render button
  useEffect(() => {
    const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID?.trim() ||
      document.querySelector('meta[name="google-signin-client_id"]')?.getAttribute('content')?.trim() || '';
    if (!clientId || /YOUR_WEB_CLIENT_ID/i.test(clientId)) {
      console.warn('Google Client ID is missing or placeholder. Set VITE_GOOGLE_CLIENT_ID at build time or add <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com" /> to index.html');
      return;
    }
    // GIS needs the public origin; restore the stricter policy when leaving login.
    const referrerMeta = document.querySelector<HTMLMetaElement>('meta[name="referrer"]');
    const previousReferrer = referrerMeta?.getAttribute('content') ?? null;
    referrerMeta?.setAttribute('content', 'strict-origin-when-cross-origin');
    let active = true;
    let initialized = false;
    function init() {
      if (!active || initialized) return;
      // @ts-ignore
      if (window.google && window.google.accounts && window.google.accounts.id) {
        initialized = true;
        // @ts-ignore
        window.google.accounts.id.initialize({
          client_id: clientId,
          ux_mode: 'popup',
          callback: async (response: any) => {
            if (!active) return;
            try {
              const API_BASE = resolveApi();
              const resp = await fetch(`${API_BASE}/login/google`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id_token: response.credential, client_platform: 'web' }),
              });
              const data = await resp.json();
              if (!active) return;
              if (resp.ok && data.success) {
                localStorage.setItem('token', data.token);
                localStorage.setItem('user', JSON.stringify(data.user));
        window.dispatchEvent(new Event('finsight:session-changed'));
                navigate('/');
              } else {
                alert(data.message || 'Google login failed');
              }
            } catch (err) {
              if (active) alert('Google login failed');
            }
          },
        });
        if (googleDiv.current) {
          // @ts-ignore
          window.google.accounts.id.renderButton(googleDiv.current, { theme: 'outline', size: 'large', type: 'standard', text: 'signin_with' });
        }
        // setGoogleReady(true);
      }
    }
    const src = 'https://accounts.google.com/gsi/client';
    const existing = document.querySelector<HTMLScriptElement>(`script[src="${src}"]`);
    const script = existing ?? document.createElement('script');
    script.addEventListener('load', init);
    if (!existing) {
      script.src = src;
      script.async = true;
      script.defer = true;
      document.head.appendChild(script);
    }
    init();
    return () => {
      active = false;
      script.removeEventListener('load', init);
      if (referrerMeta) {
        if (previousReferrer === null) referrerMeta.removeAttribute('content');
        else referrerMeta.setAttribute('content', previousReferrer);
      }
    };
  }, [navigate]);

  return (
    <AuthShell
      title={t('login.heading')}
      subtitle={t('login.subtitlePremium')}
      visualTitle={t('login.visualTitle')}
      visualBody={t('login.visualBody')}
      backLabel={t('auth.backToLanding')}
      platformLabel={t('auth.platformLabel')}
      workspaceLabel={t('auth.workspaceLabel')}
      statusLabel={t('auth.statusLive')}
      visualCards={[
        { label: t('auth.card.cashFlow'), value: '+18%', icon: authVisualIcons.cashFlow },
        { label: t('auth.card.budgets'), value: '72%', icon: authVisualIcons.budgets },
        { label: t('auth.card.insights'), value: '4', icon: authVisualIcons.insights },
        { label: t('auth.card.subscriptions'), value: '$96', icon: authVisualIcons.subscriptions },
      ]}
    >
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="username" className="mb-2 block text-sm font-semibold text-slate-700">
              {t('login.username')}
            </label>
            <input
              id="username"
              type="text"
              required
              value={credentials.username}
              onChange={(e) => setCredentials({ ...credentials, username: e.target.value })}
              className="h-12 w-full rounded-xl border border-slate-200 bg-white px-4 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500"
              placeholder={t('login.placeholder.username')}
              disabled={loading}
            />
          </div>

          <div>
            <label htmlFor="password" className="mb-2 block text-sm font-semibold text-slate-700">
              {t('login.password')}
            </label>
            <input
              id="password"
              type="password"
              required
              value={credentials.password}
              onChange={(e) => setCredentials({ ...credentials, password: e.target.value })}
              className="h-12 w-full rounded-xl border border-slate-200 bg-white px-4 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500"
              placeholder={t('login.placeholder.password')}
              disabled={loading}
            />
          </div>

          <Link to="/forgot-password" className="block text-right text-sm font-semibold text-blue-600 underline underline-offset-4">{t('login.forgotPassword')}</Link>
          {error && (
            <div role="alert" className="rounded-xl border border-red-100 bg-red-50 px-4 py-3 text-sm font-medium text-red-700">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="flex h-12 w-full items-center justify-center gap-2 rounded-xl bg-blue-600 px-4 font-semibold text-white shadow-lg shadow-blue-600/20 transition hover:-translate-y-0.5 hover:bg-blue-700 hover:shadow-blue-600/30 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:translate-y-0 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading ? (
              <>
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
                {t('login.signingIn')}
              </>
            ) : (
              <>
                <LogIn className="h-5 w-5" />
                {t('login.signIn')}
              </>
            )}
          </button>
          <div className="relative my-4">
            <div className="absolute inset-0 flex items-center" aria-hidden="true">
              <div className="w-full border-t border-slate-200" />
            </div>
            <div className="relative flex justify-center text-xs">
              <span className="bg-white px-3 text-slate-500">or</span>
            </div>
          </div>
          <div className="flex justify-center">
            <div ref={googleDiv} />
          </div>
        </form>

        <div className="mt-6 text-center">
          <p className="text-sm text-slate-600">
            {t('login.noAccount')}
          </p>
          <Link
            to="/signup"
            className="mt-2 inline-flex items-center gap-2 font-semibold text-blue-600 transition-colors hover:text-blue-700"
          >
            <UserPlus className="h-4 w-4" />
            {t('login.signupFree')}
          </Link>
        </div>

        <div className="mt-6 text-center text-xs leading-6 text-slate-500">
          By using FinSight, you agree to our{' '}
          <Link to="/terms" className="text-blue-600 hover:text-blue-700">Terms &amp; Conditions</Link>
          {' '}and{' '}
          <Link to="/privacy" className="text-blue-600 hover:text-blue-700">Privacy Policy</Link>.
        </div>
    </AuthShell>
  );
}
