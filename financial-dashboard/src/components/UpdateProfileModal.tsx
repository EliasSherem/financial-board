import { useState } from 'react';
import { X, User, Mail, Lock, Save, AlertTriangle } from 'lucide-react';
import { useI18n } from '../contexts/I18nContext';
import { api } from '../utils/api';

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
      if (formData.newPassword.length < 6) {
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
      setError(t('profile.failedUpdate'));
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
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-md">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">
            {t('profile.title')}
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {error && (
          <div className="mb-4 p-3 bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400 rounded-lg text-sm">
            {error}
          </div>
        )}

        {success && (
          <div className="mb-4 p-3 bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400 rounded-lg text-sm">
            {success}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              <User className="inline h-4 w-4 mr-1" />
              {t('profile.username')}
            </label>
            <input
              type="text"
              required
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
              disabled={loading}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              <Mail className="inline h-4 w-4 mr-1" />
              {t('profile.email')}
            </label>
            <input
              type="email"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
              disabled={loading}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              {t('profile.language')}
            </label>
            <select
              value={language}
              onChange={(e) => setLanguage(e.target.value as any)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
              disabled={loading}
            >
              <option value="en">{t('profile.lang.en')}</option>
              <option value="es">{t('profile.lang.es')}</option>
            </select>
          </div>

          <div className="border-t dark:border-gray-700 pt-4">
            <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
              {t('profile.changePassword')}
            </h3>

            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  <Lock className="inline h-4 w-4 mr-1" />
                  {t('profile.currentPassword')}
                </label>
                <input
                  type="password"
                  value={formData.currentPassword}
                  onChange={(e) => setFormData({ ...formData, currentPassword: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                  disabled={loading}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  <Lock className="inline h-4 w-4 mr-1" />
                  {t('profile.newPassword')}
                </label>
                <input
                  type="password"
                  value={formData.newPassword}
                  onChange={(e) => setFormData({ ...formData, newPassword: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                  disabled={loading}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  <Lock className="inline h-4 w-4 mr-1" />
                  {t('profile.confirmNewPassword')}
                </label>
                <input
                  type="password"
                  value={formData.confirmPassword}
                  onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-gray-100"
                  disabled={loading}
                />
              </div>
            </div>
          </div>

          <div className="border-t dark:border-gray-700 pt-4">
            <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              {t('profile.subscription')}
            </h3>
            <p className="text-sm text-gray-600 dark:text-gray-400">
              {isPro ? t('profile.plan.pro') : t('profile.plan.free')}
            </p>
            {isPro && (
              <div className="mt-3 space-y-3">
                {cancelMessage && (
                  <div className={`p-3 rounded-lg text-sm ${cancelMessage.type === 'success' ? 'bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400' : 'bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400'}`}>
                    {cancelMessage.text}
                  </div>
                )}
                <button
                  type="button"
                  onClick={handleCancelSubscription}
                  disabled={cancelLoading}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-red-600 text-white hover:bg-red-700 disabled:opacity-60 disabled:cursor-not-allowed"
                >
                  {cancelLoading ? (
                    <>
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                      {t('profile.canceling')}
                    </>
                  ) : (
                    <>
                      <AlertTriangle className="h-4 w-4" />
                      {t('profile.cancelSubscription')}
                    </>
                  )}
                </button>
              </div>
            )}
          </div>

          <div className="flex justify-end gap-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-gray-700 dark:text-gray-300 bg-gray-200 dark:bg-gray-700 rounded-lg hover:bg-gray-300 dark:hover:bg-gray-600"
              disabled={loading}
            >
              {t('common.cancel')}
            </button>
            <button
              type="submit"
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              disabled={loading}
            >
              {loading ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                  {t('profile.updating')}
                </>
              ) : (
                <>
                  <Save className="h-4 w-4" />
                  {t('profile.title')}
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

