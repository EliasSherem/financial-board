import { useCallback } from 'react';
import { useI18n } from '../contexts/I18nContext';
import type { Mission } from './types';
export const button = 'inline-flex min-h-11 items-center justify-center rounded-xl bg-blue-600 px-4 py-2 font-medium text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500 disabled:opacity-50';
export const secondary = 'inline-flex min-h-11 items-center justify-center rounded-xl border border-slate-300 px-4 py-2 font-medium dark:border-slate-600 focus-visible:outline focus-visible:outline-2 focus-visible:outline-blue-500 disabled:opacity-50';
export function useWords() { const { language } = useI18n(); const w = useCallback((en: string, es: string) => language === 'es' ? es : en, [language]); return { language, w }; }
export function mobileOnly(m: Mission) { return ['feature_first_ai_question','weekly_ai_action','feature_first_receipt','weekly_receipt_confirm','feature_first_report','monthly_report'].includes(m.key); }
export function missionLink(m: Mission) { if (mobileOnly(m)) return '/momentum'; if (m.review) {
    const kind = ['weekly_summary', 'activation_weekly_review'].includes(m.key) ? 'weekly' : m.key === 'monthly_review' ? 'monthly' : m.key;
    return `/momentum/review/${encodeURIComponent(kind)}`;
} return m.deeplink.startsWith('/') && !m.deeplink.startsWith('//') ? m.deeplink : '/momentum'; }
