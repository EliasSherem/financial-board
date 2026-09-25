import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { platformRequest } from '../momentum/service';
import { setTelemetryEnabled } from './client';
import { useI18n } from '../contexts/I18nContext';
export function PrivacyPreference({ onNavigate }: { onNavigate?: () => void }) { const { language } = useI18n(); const [enabled, setEnabled] = useState<boolean | null>(null), [error, setError] = useState(false); useEffect(() => { void platformRequest<{
    enabled: boolean;
}>('/analytics/preferences').then(p => setEnabled(p.enabled)).catch(() => setError(true)); }, []); const es = language === 'es'; return <section className="rounded-2xl border border-slate-200 p-4 dark:border-slate-700"><Link onClick={onNavigate} to="/momentum/achievements" className="font-medium text-blue-700 underline dark:text-blue-300">{es ? 'Logros y XP' : 'Achievements & XP'}</Link><label className="mt-3 flex min-h-11 items-center gap-3"><input type="checkbox" disabled={enabled === null} checked={enabled === true} onChange={async (e) => { const value = e.target.checked; try {
    await setTelemetryEnabled(value);
    setEnabled(value);
    setError(false);
}
catch {
    setError(true);
} }}/>{es ? 'Compartir actividad de uso para mejorar FinSight' : 'Share usage activity to improve FinSight'}</label><p className="text-sm text-slate-600 dark:text-slate-300">{es ? 'No incluye importes, descripciones financieras ni preguntas IA. Puedes desactivarlo en cualquier momento.' : 'Excludes financial amounts, descriptions and AI questions. You can turn it off at any time.'}</p>{error && <p role="alert">{es ? 'No se pudo actualizar la preferencia.' : 'Could not update this preference.'}</p>}</section>; }
