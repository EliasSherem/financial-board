import { useState } from 'react';
import { X, User, Mail, Lock, Save, AlertTriangle } from 'lucide-react';
import { useI18n } from '../contexts/I18nContext';
import { api } from '../utils/api';
import { ActionButton } from './ui';
import { authRequest, clearSession, passwordIsValid } from '../utils/authApi';
import { PrivacyPreference } from '../analytics/PrivacyPreference';

interface UpdateProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
}

type CancelMessage = {
  type: 'success' | 'error';
  text: string;
};

export default function UpdateProfileModal({ isOpen, onClose }: UpdateProfileModalProps) {
  let parsedUser: any = {};
  try {
    parsedUser = JSON.parse(localStorage.getItem('user') || '{}');
  } catch {
    parsedUser = {};
  }

  const { language, setLanguage, t } = useI18n();
  const [formData, setFormData] = useState({
    username: parsedUser.username || '',
    email: parsedUser.email || '',
    currentPassword: '',
    newPassword: '',
    confirmPassword: ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const isPro = Boolean(parsedUser?.is_pro);
  const [cancelLoading, setCancelLoading] = useState(false);
  const [cancelMessage, setCancelMessage] = useState<CancelMessage | null>(null);

  const fieldClassName = 'w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-none transition placeholder:text-slate-400 focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:placeholder:text-slate-500 dark:disabled:bg-slate-900 dark:disabled:text-slate-500 dark:focus:border-blue-400 dark:focus:ring-blue-400/20';
  const labelClassName = 'mb-1.5 flex items-center gap-2 text-sm font-semibold text-slate-700 dark:text-slate-300';
  const sectionClassName = 'rounded-2xl border border-slate-200/80 bg-slate-50/70 p-4 dark:border-white/10 dark:bg-slate-950/50';

  if (!isOpen) return null;

  const refreshStoredUser = async () => {
    try {
      const updated = await api.getCurrentUser();
      if (updated && updated.id) {
        localStorage.setItem('user', JSON.stringify(updated));
      }
    } catch {
      // ignore refresh failures
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    if (formData.newPassword) {
      if (formData.newPassword !== formData.confirmPassword) {
        setError(t('profile.err.noMatch'));
        return;
      }
      if (!passwordIsValid(formData.newPassword)) {
        setError(t('profile.err.tooShort'));
        return;
      }
      if (!formData.currentPassword) {
        setError(t('profile.err.currentRequired'));
        return;
      }
    }

    setLoading(true);
    try {
      if (formData.newPassword) {
        await authRequest('change-password', {
          current_password: formData.currentPassword,
          password: formData.newPassword,
          confirm_password: formData.confirmPassword,
          language,
        }, true);
        clearSession();
        window.location.assign('/login');
        return;
      }
      const updatedUser = {
        ...parsedUser,
        username: formData.username,
        email: formData.email,
        language
      };

      localStorage.setItem('user', JSON.stringify(updatedUser));
      setSuccess(t('profile.successUpdated'));

      setTimeout(() => {
        onClose();
        window.location.reload();
      }, 1500);
    } catch {
      setError(formData.newPassword
        ? (language === 'es' ? 'No se pudo cambiar la contraseña. Revisa tu contraseña actual. Si usas Google, administra tu acceso desde Google.' : 'Could not change your password. Check your current password. If you use Google, manage your access through Google.')
        : t('profile.failedUpdate'));
    } finally {
      setLoading(false);
    }
  };

  const handleCancelSubscription = async () => {
    if (cancelLoading) return;
    if (!window.confirm(t('profile.cancelConfirm'))) return;

    setCancelMessage(null);
    setCancelLoading(true);

    try {
      const result = await api.cancelSubscription();
      const text = result?.alreadyCanceled ? t('profile.cancelAlready') : t('profile.cancelSuccess');
      setCancelMessage({ type: 'success', text });
      await refreshStoredUser();
      setTimeout(() => {
        onClose();
        window.location.reload();
      }, 1500);
    } catch (err) {
      const fallback = t('profile.cancelFailed');
      const message = err instanceof Error
        ? err.message || fallback
        : typeof err === 'object' && err && 'message' in err
          ? String((err as { message?: unknown }).message) || fallback
          : fallback;
      setCancelMessage({ type: 'error', text: message });
    } finally {
      setCancelLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="profile-modal-title"
        className="w-full max-w-lg overflow-hidden rounded-2xl border border-white/60 bg-white shadow-2xl shadow-slate-950/20 dark:border-white/10 dark:bg-slate-900 dark:shadow-black/40"
      >
        <div className="flex items-start justify-between gap-4 border-b border-slate-200/80 px-5 py-4 dark:border-white/10">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-blue-600 dark:text-blue-300">
              FinSight
            </p>
            <h2 id="profile-modal-title" className="mt-1 text-lg font-semibold text-slate-950 dark:text-white">
              {t('profile.title')}
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-slate-500 transition hover:bg-slate-100 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:text-slate-400 dark:hover:bg-white/10 dark:hover:text-white dark:focus-visible:ring-offset-slate-900"
            aria-label="Close profile modal"
          >
            <X className="h-5 w-5" aria-hidden="true" />
          </button>
        </div>

        <div className="max-h-[calc(100vh-8rem)] overflow-y-auto px-5 py-5">
          {error && (
            <div className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-medium text-red-700 dark:border-red-400/30 dark:bg-red-500/10 dark:text-red-200">
              {error}
            </div>
          )}

          {success && (
            <div className="mb-4 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm font-medium text-emerald-700 dark:border-emerald-400/30 dark:bg-emerald-500/10 dark:text-emerald-200">
              {success}
            </div>
          )}

          <div className="mb-4"><PrivacyPreference onNavigate={onClose} /></div>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className={sectionClassName}>
              <div className="grid gap-4">
                <div>
                  <label className={labelClassName}>
                    <User className="h-4 w-4 text-blue-600 dark:text-blue-300" aria-hidden="true" />
                    {t('profile.username')}
                  </label>
                  <input
                    type="text"
                    required
                    value={formData.username}
                    onChange={(e) => setFormData({ ...formData, username: e.target.value })}
                    className={fieldClassName}
                    disabled={loading}
                  />
                </div>

                <div>
                  <label className={labelClassName}>
                    <Mail className="h-4 w-4 text-blue-600 dark:text-blue-300" aria-hidden="true" />
                    {t('profile.email')}
                  </label>
                  <input
                    type="email"
                    value={formData.email}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    className={fieldClassName}
                    disabled={loading}
                  />
                </div>

                <div>
                  <label className={labelClassName}>
                    {t('profile.language')}
                  </label>
                  <select
                    value={language}
                    onChange={(e) => setLanguage(e.target.value as any)}
                    className={fieldClassName}
                    disabled={loading}
                  >
                    <option value="en">{t('profile.lang.en')}</option>
                    <option value="es">{t('profile.lang.es')}</option>
                  </select>
                </div>
              </div>
            </div>

            <div className={sectionClassName}>
              <h3 className="mb-3 text-sm font-semibold text-slate-900 dark:text-white">
                {t('profile.changePassword')}
              </h3>

              <div className="space-y-3">
                <div>
                  <label className={labelClassName}>
                    <Lock className="h-4 w-4 text-blue-600 dark:text-blue-300" aria-hidden="true" />
                    {t('profile.currentPassword')}
                  </label>
                  <input
                    type="password"
                    value={formData.currentPassword}
                    onChange={(e) => setFormData({ ...formData, currentPassword: e.target.value })}
                    className={fieldClassName}
                    disabled={loading}
                  />
                </div>

                <div>
                  <label className={labelClassName}>
                    <Lock className="h-4 w-4 text-blue-600 dark:text-blue-300" aria-hidden="true" />
                    {t('profile.newPassword')}
                  </label>
                  <input
                    type="password"
                    value={formData.newPassword}
                    onChange={(e) => setFormData({ ...formData, newPassword: e.target.value })}
                    className={fieldClassName}
                    disabled={loading}
                  />
                </div>

                <div>
                  <label className={labelClassName}>
                    <Lock className="h-4 w-4 text-blue-600 dark:text-blue-300" aria-hidden="true" />
                    {t('profile.confirmNewPassword')}
                  </label>
                  <input
                    type="password"
                    value={formData.confirmPassword}
                    onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
                    className={fieldClassName}
                    disabled={loading}
                  />
                </div>
              </div>
            </div>

            <div className={sectionClassName}>
              <h3 className="text-sm font-semibold text-slate-900 dark:text-white">
                {t('profile.subscription')}
              </h3>
              <p className="mt-2 text-sm text-slate-600 dark:text-slate-400">
                {isPro ? t('profile.plan.pro') : t('profile.plan.free')}
              </p>
              {isPro && (
                <div className="mt-3 space-y-3">
                  {cancelMessage && (
                    <div className={`rounded-xl border px-4 py-3 text-sm font-medium ${cancelMessage.type === 'success' ? 'border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-400/30 dark:bg-emerald-500/10 dark:text-emerald-200' : 'border-red-200 bg-red-50 text-red-700 dark:border-red-400/30 dark:bg-red-500/10 dark:text-red-200'}`}>
                      {cancelMessage.text}
                    </div>
                  )}
                  <ActionButton
                    type="button"
                    variant="danger"
                    onClick={handleCancelSubscription}
                    loading={cancelLoading}
                    disabled={cancelLoading}
                    iconLeft={<AlertTriangle className="h-4 w-4" aria-hidden="true" />}
                    className="w-full sm:w-auto"
                  >
                    {cancelLoading ? t('profile.canceling') : t('profile.cancelSubscription')}
                  </ActionButton>
                </div>
              )}
            </div>

            <div className="flex flex-col-reverse gap-2 border-t border-slate-200/80 pt-4 dark:border-white/10 sm:flex-row sm:justify-end">
              <ActionButton
                type="button"
                variant="outline"
                onClick={onClose}
                disabled={loading}
                className="w-full sm:w-auto"
              >
                {t('common.cancel')}
              </ActionButton>
              <ActionButton
                type="submit"
                loading={loading}
                disabled={loading}
                iconLeft={<Save className="h-4 w-4" aria-hidden="true" />}
                className="w-full sm:w-auto"
              >
                {loading ? t('profile.updating') : t('profile.title')}
              </ActionButton>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
