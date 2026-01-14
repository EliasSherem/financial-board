import { useState, useEffect, useRef } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { LogIn, UserPlus } from 'lucide-react';
import { useI18n } from '../contexts/I18nContext';
import { resolveApi } from '../utils/api';

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
    const clientId = (import.meta as any)?.env?.VITE_GOOGLE_CLIENT_ID ||
      document.querySelector('meta[name="google-signin-client_id"]')?.getAttribute('content') || '';
    if (!clientId || /YOUR_WEB_CLIENT_ID/i.test(clientId)) {
      console.warn('Google Client ID is missing or placeholder. Set VITE_GOOGLE_CLIENT_ID at build time or add <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com" /> to index.html');
      return;
    }
    if (!clientId) return;
    function init() {
      // @ts-ignore
      if (window.google && window.google.accounts && window.google.accounts.id) {
        // @ts-ignore
        window.google.accounts.id.initialize({
          client_id: clientId,
          ux_mode: 'popup',
          callback: async (response: any) => {
            try {
              const API_BASE = resolveApi();
              const resp = await fetch(`${API_BASE}/login/google`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id_token: response.credential }),
              });
              const data = await resp.json();
              if (resp.ok && data.success) {
                localStorage.setItem('token', data.token);
                localStorage.setItem('user', JSON.stringify(data.user));
                navigate('/');
              } else {
                alert(data.message || 'Google login failed');
              }
            } catch (err) {
              alert('Google login failed');
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
    const existing = document.querySelector(`script[src="${src}"]`);
    if (existing) {
      init();
    } else {
      const s = document.createElement('script');
      s.src = src;
      s.async = true;
      s.defer = true;
      s.onload = init;
      document.head.appendChild(s);
    }
  }, [navigate]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-start sm:items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-8 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-center mb-8">
          <div className="bg-blue-600 p-3 rounded-full">
            <img src="/finsight-icon.svg" alt="FinSight" className="h-8 w-8 text-white" />
          </div>
        </div>
        
        <h2 className="text-3xl font-bold text-center text-gray-900 mb-2">
          FinSight
        </h2>
        <p className="text-center text-gray-600 mb-8">
          {t('login.title')}
        </p>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="username" className="block text-sm font-medium text-gray-700 mb-2">
              {t('login.username')}
            </label>
            <input
              id="username"
              type="text"
              required
              value={credentials.username}
              onChange={(e) => setCredentials({ ...credentials, username: e.target.value })}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder={t('login.placeholder.username')}
              disabled={loading}
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
              {t('login.password')}
            </label>
            <input
              id="password"
              type="password"
              required
              value={credentials.password}
              onChange={(e) => setCredentials({ ...credentials, password: e.target.value })}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder={t('login.placeholder.password')}
              disabled={loading}
            />
          </div>

          {error && (
            <div className="bg-red-50 text-red-600 px-4 py-3 rounded-lg text-sm">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-blue-600 text-white py-3 px-4 rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 font-medium"
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
              <div className="w-full border-t border-gray-200" />
            </div>
            <div className="relative flex justify-center text-xs">
              <span className="bg-white px-2 text-gray-500">or</span>
            </div>
          </div>
          <div className="flex justify-center">
            <div ref={googleDiv} />
          </div>
        </form>

        <div className="mt-6 text-center">
          <p className="text-sm text-gray-600">
            {t('login.noAccount')}
          </p>
          <Link
            to="/signup"
            className="inline-flex items-center gap-2 mt-2 text-blue-600 hover:text-blue-700 font-medium"
          >
            <UserPlus className="h-4 w-4" />
            {t('login.signupFree')}
          </Link>
        </div>

        <div className="mt-6 text-center text-xs text-gray-500">
          By using FinSight, you agree to our{' '}
          <Link to="/terms" className="text-blue-600 hover:text-blue-700">Terms &amp; Conditions</Link>
          {' '}and{' '}
          <Link to="/privacy" className="text-blue-600 hover:text-blue-700">Privacy Policy</Link>.
        </div>
      </div>
    </div>
  );
}
