import { useEffect, useState, type FormEvent, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { Moon, Sun, ShieldCheck } from 'lucide-react';
import { useI18n } from '../contexts/I18nContext';
import { useTheme } from '../contexts/ThemeContext';
import { ActionButton, AppCard } from '../components/ui';
import { AuthRequestError, authRequest, clearSession, passwordIsValid } from '../utils/authApi';

let capturedToken = '';
function captureToken(): string {
  if (window.location.pathname !== '/reset-password') return '';
  const url = new URL(window.location.href);
  const token = new URLSearchParams(url.hash.slice(1)).get('token') || url.searchParams.get('token');
  if (token) capturedToken = /^[A-Za-z0-9_-]{43}$/.test(token) ? token : '';
  url.hash = '';
  url.searchParams.delete('token');
  window.history.replaceState(window.history.state, '', `${url.pathname}${url.search}`);
  return capturedToken;
}
// Capture before rendering any application components; retain in memory for React StrictMode.
captureToken();

const inputClass = 'mt-2 w-full rounded-xl border border-slate-300 bg-white px-4 py-3 text-slate-950 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:border-slate-600 dark:bg-slate-950 dark:text-white';

function RecoveryShell({ title, children }: { title: string; children: ReactNode }) {
  const { language, setLanguage } = useI18n();
  const { theme, toggleTheme } = useTheme();
  const es = language === 'es';
  return <main className="flex min-h-screen items-center justify-center bg-slate-100 px-4 py-12 text-slate-950 dark:bg-slate-950 dark:text-white">
    <AppCard className="w-full max-w-lg" variant="elevated" padding="lg">
      <div className="mb-8 flex items-center justify-between gap-3">
        <Link to="/landing" className="text-lg font-bold text-blue-600 dark:text-blue-300">FinSight</Link>
        <div className="flex gap-2">
          <ActionButton variant="outline" size="sm" onClick={() => setLanguage(es ? 'en' : 'es')} aria-label={es ? 'Switch to English' : 'Cambiar a español'}>{es ? 'EN' : 'ES'}</ActionButton>
          <ActionButton variant="outline" size="icon" onClick={toggleTheme} aria-label={es ? 'Cambiar tema' : 'Switch theme'}>{theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}</ActionButton>
        </div>
      </div>
      <ShieldCheck className="mb-4 text-blue-600 dark:text-blue-300" size={32} aria-hidden="true" />
      <h1 className="mb-5 text-2xl font-bold">{title}</h1>
      {children}
      <Link to="/login" className="mt-8 inline-block font-semibold text-blue-600 underline underline-offset-4 dark:text-blue-300">{es ? 'Volver a iniciar sesión' : 'Back to sign in'}</Link>
    </AppCard>
  </main>;
}

export function ForgotPassword() {
  const { language } = useI18n();
  const es = language === 'es';
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  useEffect(() => {
    if (!cooldown) return;
    const timer = window.setTimeout(() => setCooldown(value => Math.max(0, value - 1)), 1000);
    return () => window.clearTimeout(timer);
  }, [cooldown]);
  const submit = async (event: FormEvent) => {
    event.preventDefault(); if (loading || cooldown) return;
    setLoading(true); setError(false);
    try {
      const result = await authRequest<{ retry_after_seconds: number }>('forgot-password', { email: email.trim(), language });
      setSent(true); setCooldown(Math.max(60, result.retry_after_seconds || 60));
    } catch { setError(true); } finally { setLoading(false); }
  };
  return <RecoveryShell title={es ? 'Recupera tu contraseña' : 'Forgot password?'}>
    <p className="mb-5 text-sm leading-6 text-slate-600 dark:text-slate-300">{es ? 'Ingresa el correo de tu cuenta para solicitar un enlace seguro.' : 'Enter your account email to request a secure recovery link.'}</p>
    {sent && <p role="status" className="mb-5 rounded-xl bg-blue-50 p-4 text-sm leading-6 text-blue-900 dark:bg-blue-950 dark:text-blue-100">{es ? 'Si este correo tiene una cuenta con contraseña, recibirás instrucciones en breve. Revisa también la carpeta de spam. Si usas Google, continúa con Google desde el inicio de sesión.' : 'If this email has a password account, instructions will arrive shortly. Check your spam folder too. If you use Google, continue with Google on the sign-in page.'}</p>}
    <form onSubmit={submit} className="space-y-5">
      <label htmlFor="recovery-email" className="block text-sm font-semibold">{es ? 'Correo electrónico' : 'Email address'}<input id="recovery-email" className={inputClass} autoComplete="email" type="email" required maxLength={100} value={email} onChange={event => setEmail(event.target.value)} disabled={loading} /></label>
      {error && <p role="alert" className="text-sm text-red-700 dark:text-red-300">{es ? 'No se pudo conectar. Intenta de nuevo.' : 'Unable to connect. Please try again.'}</p>}
      <ActionButton type="submit" loading={loading} disabled={cooldown > 0} className="w-full">{cooldown ? `${es ? 'Reenviar en' : 'Resend in'} ${cooldown}s` : sent ? (es ? 'Reenviar enlace' : 'Resend link') : (es ? 'Enviar enlace' : 'Send recovery link')}</ActionButton>
    </form>
  </RecoveryShell>;
}

export function ResetPassword() {
  const { language } = useI18n();
  const es = language === 'es';
  const [token, setToken] = useState(captureToken);
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [loading, setLoading] = useState(false);
  const [completed, setCompleted] = useState(false);
  const [error, setError] = useState('');
  const submit = async (event: FormEvent) => {
    event.preventDefault(); if (loading) return;
    if (!passwordIsValid(password) || password !== confirmation) {
      setError(es ? 'Las contraseñas deben coincidir, tener al menos 6 caracteres y no superar 72 bytes UTF-8.' : 'Passwords must match, contain at least 6 characters, and fit within 72 UTF-8 bytes.'); return;
    }
    setLoading(true); setError('');
    try {
      await authRequest('reset-password', { token, password, confirm_password: confirmation, language });
      setCompleted(true); setToken(''); capturedToken = ''; setPassword(''); setConfirmation(''); clearSession();
    } catch (failure) {
      const error = failure instanceof AuthRequestError ? failure : new AuthRequestError('RECOVERY_UNAVAILABLE');
      if (error.code === 'INVALID_OR_EXPIRED_LINK') {
        setError(error.reason === 'used' ? (es ? 'Este enlace ya se utilizó. Solicita uno nuevo.' : 'This link has already been used. Request a new one.') : error.reason === 'expired' ? (es ? 'Este enlace venció. Solicita uno nuevo.' : 'This link has expired. Request a new one.') : (es ? 'El enlace no es válido. Solicita uno nuevo.' : 'This link is invalid. Request a new one.'));
        setToken(''); capturedToken = '';
      } else setError(error.code === 'RATE_LIMITED' ? (es ? 'Demasiados intentos. Intenta de nuevo más tarde.' : 'Too many attempts. Please try again later.') : (es ? 'No se pudo restablecer la contraseña. Intenta de nuevo.' : 'Unable to reset the password. Please try again.'));
    } finally { setLoading(false); }
  };
  return <RecoveryShell title={es ? 'Nueva contraseña' : 'New password'}>
    {completed ? <p role="status" className="leading-7">{es ? 'Tu contraseña cambió. Cerramos tus sesiones en todos los dispositivos. Vuelve a iniciar sesión con tu nueva contraseña.' : 'Your password changed. All devices were signed out. Sign in again using your new password.'}</p> : <>
      {error && <p role="alert" className="mb-5 text-sm text-red-700 dark:text-red-300">{error}</p>}
      {!token ? <div><p className="text-sm leading-6">{!error && (es ? 'El enlace no es válido, venció o ya se utilizó.' : 'This link is invalid, expired, or already used.')}</p><Link className="mt-4 inline-block text-blue-600 underline dark:text-blue-300" to="/forgot-password">{es ? 'Solicitar otro enlace' : 'Request another link'}</Link></div> : <form onSubmit={submit} className="space-y-5">
        <p id="password-guidance" className="text-sm leading-6 text-slate-600 dark:text-slate-300">{es ? 'Usa al menos 6 caracteres. Un enlace sólo funciona una vez y vence después de 30 minutos, salvo otra duración indicada en tu correo.' : 'Use at least 6 characters. A link works once and expires after 30 minutes unless your email states a different duration.'}</p>
        <label htmlFor="new-password" className="block text-sm font-semibold">{es ? 'Nueva contraseña' : 'New password'}<input id="new-password" className={inputClass} autoComplete="new-password" aria-describedby="password-guidance" type="password" minLength={6} required value={password} onChange={event => setPassword(event.target.value)} disabled={loading} /></label>
        <label htmlFor="confirm-password" className="block text-sm font-semibold">{es ? 'Confirma tu contraseña' : 'Confirm password'}<input id="confirm-password" className={inputClass} autoComplete="new-password" type="password" minLength={6} required value={confirmation} onChange={event => setConfirmation(event.target.value)} disabled={loading} /></label>
        <ActionButton type="submit" loading={loading} className="w-full">{es ? 'Guardar contraseña' : 'Save password'}</ActionButton>
        <a href={`financialboard://reset-password#token=${encodeURIComponent(token)}`} className="block text-center text-sm text-blue-600 underline dark:text-blue-300">{es ? 'Abrir en la app FinSight' : 'Open in the FinSight app'}</a>
      </form>}
    </>}
  </RecoveryShell>;
}
