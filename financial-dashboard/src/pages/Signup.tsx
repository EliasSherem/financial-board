import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { UserPlus, ArrowLeft } from 'lucide-react';
import { useI18n } from '../contexts/I18nContext';
import AuthShell, { authVisualIcons } from '../components/auth/AuthShell';

export default function Signup() {
  const navigate = useNavigate();
  const { t } = useI18n();
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
    confirmPassword: ''
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    // Validate passwords match
    if (formData.password !== formData.confirmPassword) {
      setError(t('signup.err.noMatch'));
      return;
    }

    // Validate password strength
    if (formData.password.length < 6) {
      setError(t('signup.err.tooShort'));
      return;
    }

    setLoading(true);

    try {
    const API_BASE = (import.meta as any)?.env?.VITE_API_URL || 'http://localhost:3001/api';
    const response = await fetch(`${API_BASE}/signup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          username: formData.username,
          email: formData.email,
          password: formData.password
        }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        // Store token and user info
        localStorage.setItem('token', data.token);
        localStorage.setItem('user', JSON.stringify(data.user));
        
        // New accounts go to onboarding
        navigate('/onboarding');
      } else {
        setError(data.message || t('signup.err.failed'));
      }
    } catch (err: any) {
      setError(err?.message || t('signup.err.unreachable'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthShell
      title={t('signup.heading')}
      subtitle={t('signup.subtitlePremium')}
      visualTitle={t('signup.visualTitle')}
      visualBody={t('signup.visualBody')}
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
              {t('signup.username')}
            </label>
            <input
              id="username"
              type="text"
              required
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
              className="h-12 w-full rounded-xl border border-slate-200 bg-white px-4 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500"
              placeholder={t('signup.placeholder.username')}
              disabled={loading}
            />
          </div>

          <div>
            <label htmlFor="email" className="mb-2 block text-sm font-semibold text-slate-700">
              {t('signup.email')}
            </label>
            <input
              id="email"
              type="email"
              required
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              className="h-12 w-full rounded-xl border border-slate-200 bg-white px-4 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500"
              placeholder={t('signup.placeholder.email')}
              disabled={loading}
            />
          </div>

          <div>
            <label htmlFor="password" className="mb-2 block text-sm font-semibold text-slate-700">
              {t('signup.password')}
            </label>
            <input
              id="password"
              type="password"
              required
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              className="h-12 w-full rounded-xl border border-slate-200 bg-white px-4 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500"
              placeholder={t('signup.placeholder.password')}
              disabled={loading}
            />
          </div>

          <div>
            <label htmlFor="confirmPassword" className="mb-2 block text-sm font-semibold text-slate-700">
              {t('signup.confirmPassword')}
            </label>
            <input
              id="confirmPassword"
              type="password"
              required
              value={formData.confirmPassword}
              onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
              className="h-12 w-full rounded-xl border border-slate-200 bg-white px-4 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500"
              placeholder={t('signup.placeholder.confirm')}
              disabled={loading}
            />
          </div>

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
                {t('signup.creating')}
              </>
            ) : (
              <>
                <UserPlus className="h-5 w-5" />
                {t('signup.signUp')}
              </>
            )}
          </button>
        </form>

        <div className="mt-6 text-center">
          <p className="text-sm text-slate-600">
            {t('signup.alreadyHave')}
          </p>
          <Link
            to="/login"
            className="mt-2 inline-flex items-center gap-2 font-semibold text-blue-600 transition-colors hover:text-blue-700"
          >
            <ArrowLeft className="h-4 w-4" />
            {t('signup.backToLogin')}
          </Link>
        </div>

        <div className="mt-6 text-center text-xs leading-6 text-slate-500">
          By creating an account, you agree to our{' '}
          <Link to="/terms" className="text-blue-600 hover:text-blue-700">Terms &amp; Conditions</Link>
          {' '}and{' '}
          <Link to="/privacy" className="text-blue-600 hover:text-blue-700">Privacy Policy</Link>.
        </div>
    </AuthShell>
  );
}
