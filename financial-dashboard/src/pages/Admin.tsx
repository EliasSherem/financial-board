import { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { Bar, BarChart, CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { useI18n } from '../contexts/I18nContext';
import { useTheme } from '../contexts/ThemeContext';
import { AppCard } from '../components/ui';
import { platformRequest, PlatformError } from '../momentum/service';
import { authApiBase } from '../utils/authApi';
import { button, secondary, useWords } from '../momentum/utils';
import type { Text } from '../momentum/types';
import { adminLabels } from './adminLabels';
type Row = Record<string, unknown>;
type Series = {
    key: string;
    title: Text;
    kind: 'line' | 'bar' | 'cohort' | 'funnel';
    rows: Record<string, string | number | null>[];
    x: string;
    values: string[];
};
type Report = {
    meta: {
        generated_at: string;
        filters: Record<string, unknown>;
        tracking_started_at: string | null;
        partial_day: boolean;
        notes: (string | Text)[];
    };
    cards: {
        key: string;
        label: Text;
        value: number | string | null;
        unit?: string;
    }[];
    series: Series[];
    tables: {
        key: string;
        title: Text;
        rows: Row[];
    }[];
    pagination?: {
        page: number;
        page_size: number;
        total: number;
    };
};
const pages = [['overview', 'Overview', 'Resumen'], ['usage', 'Usage', 'Uso'], ['users', 'Users', 'Usuarios'], ['subscriptions', 'Subscriptions', 'Suscripciones'], ['momentum', 'Momentum', 'Momentum'], ['data-health', 'Data health', 'Salud de datos']];
const labels: Record<string, [
    string,
    string
]> = { id: ['ID', 'ID'], user_id: ['User ID', 'ID usuario'], email: ['Email', 'Correo'], created_at: ['Registered', 'Alta'], last_seen: ['Last seen', 'Última actividad'], last_seen_at: ['Last seen', 'Última actividad'], signup_platform: ['Signup platform', 'Plataforma de alta'], platforms: ['Platforms', 'Plataformas'], last_platform: ['Last platform', 'Última plataforma'], version: ['Version', 'Versión'], provider: ['Provider', 'Proveedor'], product_id: ['Plan', 'Plan'], status: ['Status', 'Estado'], raw_state: ['Provider state', 'Estado proveedor'], access_until: ['Access until', 'Acceso hasta'], effective_access: ['Effective access', 'Acceso efectivo'], verified: ['Verified', 'Verificado'], auto_renewing: ['Auto renewal', 'Renovación automática'], is_trial: ['Trial', 'Prueba'], currency: ['Currency', 'Moneda'], recurring_amount: ['Recurring amount', 'Importe recurrente'], period_months: ['Period (months)', 'Período (meses)'], synced_at: ['Last synchronized', 'Última sincronización'], environment: ['Environment', 'Entorno'], lifetime_xp: ['Lifetime XP', 'XP vitalicio'], level: ['Level', 'Nivel'], date: ['Date', 'Fecha'], day: ['Day', 'Día'], dau: ['DAU', 'DAU'], wau: ['WAU', 'WAU'], mau: ['MAU', 'MAU'], users: ['Users', 'Usuarios'], sessions: ['Sessions', 'Sesiones'], count: ['Count', 'Cantidad'], mission_key: ['Mission', 'Misión'], assigned: ['Assigned', 'Asignadas'], completed: ['Completed', 'Completadas'], abandoned: ['Abandoned', 'Abandonadas'], feature: ['Feature', 'Función'], cohort: ['Cohort', 'Cohorte'], eligible: ['Eligible', 'Elegibles'], retained: ['Retained', 'Retenidos'], d7: ['D7', 'D7'], d30: ['D30', 'D30'], ratio: ['Rate', 'Tasa'], total: ['Total', 'Total'], paid: ['Paid', 'Pagado'], trials: ['Trials', 'Pruebas'], grants: ['Grants', 'Concesiones'], mrr: ['Estimated MRR', 'MRR estimado'], amount: ['Amount', 'Importe'], kind: ['Type', 'Tipo'], event_type: ['Event', 'Evento'], received_at: ['Received', 'Recibido'], occurred_at: ['Occurred', 'Ocurrió'], client_platform: ['Usage platform', 'Plataforma de uso'], app_version: ['Version', 'Versión'], source_screen: ['Screen', 'Pantalla'], error_code: ['Error code', 'Código de error'], status_count: ['Count', 'Cantidad'], unknown: ['Unknown', 'Desconocido'], activation: ['Activation', 'Activación'], step: ['Step', 'Paso'], charges: ['Charges', 'Cobros'], refunds: ['Refunds', 'Reembolsos'], net: ['Net of refunds', 'Neto de reembolsos'] };
const enums: Record<string, [
    string,
    string
]> = { unknown: ['Unknown', 'Desconocido'], active: ['Active', 'Activa'], trial: ['Trial', 'Prueba'], pending: ['Pending', 'Pendiente'], cancel_at_period_end: ['Cancels at period end', 'Cancela al fin del período'], grace: ['Grace', 'Gracia'], hold: ['On hold', 'Suspendida'], paused: ['Paused', 'Pausada'], expired: ['Expired', 'Vencida'], revoked: ['Revoked', 'Revocada'], refunded: ['Refunded', 'Reembolsada'], legacy: ['Legacy', 'Heredada'], production: ['Production', 'Producción'], test: ['Test', 'Prueba'], internal: ['Internal', 'Interna'], explorer: ['Explorer', 'Explorador'], organizer: ['Organizer', 'Organizador'], planner: ['Planner', 'Planificador'], strategist: ['Strategist', 'Estratega'] };
function useAdminLabels() { const { language, locale } = useI18n(); const es = language === 'es'; return { field: (key: string) => (labels[key] ?? adminLabels[key])?.[es ? 1 : 0] ?? key.replaceAll('_', ' '), value: (v: unknown): string => v === null || v === undefined ? 'N/D' : typeof v === 'boolean' ? (v ? (es ? 'Sí' : 'Yes') : (es ? 'No' : 'No')) : typeof v === 'number' ? v.toLocaleString(locale, { maximumFractionDigits: 2 }) : typeof v === 'object' ? JSON.stringify(v) : enums[String(v)]?.[es ? 1 : 0] ?? String(v) }; }
function DataTable({ rows, caption, linkUsers = false }: {
    rows: Row[];
    caption: string;
    linkUsers?: boolean;
}) { const { field, value } = useAdminLabels(); const { w } = useWords(); const keys = [...new Set(rows.flatMap(Object.keys))]; if (!rows.length)
    return <p className="py-5 text-slate-600 dark:text-slate-300">{w('No records for these filters.', 'No hay registros con estos filtros.')}</p>; return <div className="overflow-x-auto"><table className="w-full text-left text-sm"><caption className="sr-only">{caption}</caption><thead><tr>{keys.map(k => <th className="whitespace-nowrap p-3" key={k}>{field(k)}</th>)}</tr></thead><tbody>{rows.map((row, i) => <tr className="border-t border-slate-200 dark:border-slate-700" key={i}>{keys.map(k => <td className="max-w-xs break-words p-3 align-top" key={k}>{linkUsers && (k === 'id' || k === 'user_id') ? <Link className="text-blue-700 underline dark:text-blue-300" to={`/admin/users/${encodeURIComponent(String(row[k]))}`}>{value(row[k])}</Link> : value(['cached_pro','effective_pro','verified_pro','granted_pro','verified','is_trial','auto_renewing','effective_access','sync_stale','replaced'].includes(k) && row[k] != null ? Boolean(row[k]) : row[k])}</td>)}</tr>)}</tbody></table></div>; }
function Chart({ series }: {
    series: Series;
}) { const { language, w } = useWords(); const { field } = useAdminLabels(); const colors = ['#2563EB', '#22B66F', '#7C83FD', '#F59E0B']; if (!series.rows.length)
    return <AppCard><h2 className="font-semibold">{series.title[language]}</h2><p>{w('No observations yet.', 'Aún no hay observaciones.')}</p></AppCard>; return <AppCard><h2 className="mb-4 text-lg font-semibold">{series.title[language]}</h2>{series.kind === 'cohort' ? <div className="overflow-x-auto"><table className="w-full text-sm"><thead><tr><th>{field(series.x)}</th>{series.values.map(v => <th className="p-2" key={v}>{field(v)}</th>)}</tr></thead><tbody>{series.rows.map((r, i) => <tr key={i}><th className="p-2">{r[series.x]}</th>{series.values.map(v => <td key={v} className="border border-white/30 p-3 text-center dark:border-slate-800" style={{ backgroundColor: r[v] == null ? 'transparent' : `rgba(37,99,235,${.08 + Math.min(1, Number(r[v])/100) * .35})` }}>{r[v] == null ? 'N/D' : (Number(r[v])/100).toLocaleString(language, { style: 'percent', maximumFractionDigits: 1 })}</td>)}</tr>)}</tbody></table></div> : <div className="h-72 w-full" role="img" aria-label={series.title[language]}><ResponsiveContainer>{series.kind === 'line' ? <LineChart data={series.rows} margin={{ top: 8, right: 12, bottom: 12, left: 0 }}><CartesianGrid strokeDasharray="3 3" opacity={.2}/><XAxis dataKey={series.x} tick={{ fontSize: 11 }}/><YAxis tick={{ fontSize: 11 }}/><Tooltip /><Legend />{series.values.map((v, i) => <Line key={v} dataKey={v} name={field(v)} stroke={colors[i % colors.length]} dot={false} connectNulls={false} isAnimationActive={false}/>)}</LineChart> : <BarChart data={series.rows} margin={{ top: 8, right: 12, bottom: 12, left: 0 }}><CartesianGrid strokeDasharray="3 3" opacity={.2}/><XAxis dataKey={series.x} tick={{ fontSize: 11 }}/><YAxis tick={{ fontSize: 11 }}/><Tooltip /><Legend />{series.values.map((v, i) => <Bar key={v} dataKey={v} name={field(v)} fill={colors[i % colors.length]} isAnimationActive={false}/>)}</BarChart>}</ResponsiveContainer></div>}<details className="mt-4"><summary className="cursor-pointer py-2 font-medium">{w('Accessible data table', 'Tabla de datos accesible')}</summary><DataTable rows={series.rows} caption={series.title[language]}/></details></AppCard>; }
const initialFilters = () => ({ start: new Date(Date.now() - 29 * 86400000).toISOString().slice(0, 10), end: new Date().toISOString().slice(0, 10), timezone: Intl.DateTimeFormat().resolvedOptions().timeZone, platform: 'all', provider: 'all', plan: '', status: 'all', version: '', cohort: '', environment: 'production', include_internal: 'false', q: '', page: '1', page_size: '25' });
export default function AdminPage() {
    const { pathname } = useLocation(), navigate = useNavigate();
    const section = pathname.slice('/admin/'.length) || 'overview';
    const route = pathname === '/admin' ? 'overview' : section;
    const { language, setLanguage } = useI18n(), { theme, toggleTheme } = useTheme(), { w } = useWords(), { value } = useAdminLabels();
    const [filters, setFilters] = useState(initialFilters), [applied, setApplied] = useState(initialFilters), [allowed, setAllowed] = useState<boolean | null>(null), [report, setReport] = useState<Report | null>(null), [loading, setLoading] = useState(true), [error, setError] = useState(''), [reload, setReload] = useState(0), [exporting, setExporting] = useState(false);
    useEffect(() => { const abort = new AbortController(); setLoading(true); setError(''); setReport(null); void platformRequest<{
        allowed: boolean;
    }>('/admin/access', undefined, abort.signal).then(async (access) => { setAllowed(access.allowed); const q = new URLSearchParams(Object.entries(applied).filter(([, v]) => v !== '')); const data = await platformRequest<Report>(`/admin/${route}?${q}`, undefined, abort.signal); setReport(data); }).catch(e => { if (abort.signal.aborted)
        return; if (e instanceof PlatformError && e.status === 403) {
        setAllowed(false);
        setError(w('Owner access required.', 'Se requiere acceso de propietario.'));
    }
    else
        setError(w('Could not load this report. Check the filters and connection.', 'No se pudo cargar el informe. Revisa los filtros y la conexión.')); }).finally(() => { if (!abort.signal.aborted)
        setLoading(false); }); return () => abort.abort(); }, [route, applied, reload, language, w]);
    const change = (key: keyof typeof filters, v: string) => setFilters(old => ({ ...old, [key]: v }));
    const download = async () => { setExporting(true); try {
        const q = new URLSearchParams(Object.entries(applied).filter(([, v]) => v !== ''));
        const r = await fetch(`${authApiBase()}/admin/export/${route}?${q}`, { headers: { Authorization: `Bearer ${localStorage.getItem('token') ?? ''}` }, cache: 'no-store', referrerPolicy: 'no-referrer' });
        if (!r.ok)
            throw new Error();
        const blob = await r.blob(), url = URL.createObjectURL(blob), a = document.createElement('a');
        a.href = url;
        a.download = `finsight-${route}-${applied.end}.csv`;
        a.click();
        URL.revokeObjectURL(url);
    }
    catch {
        setError(w('Export failed.', 'No se pudo exportar.'));
    }
    finally {
        setExporting(false);
    } };
    return <div className="min-h-screen bg-slate-100 text-slate-950 dark:bg-slate-950 dark:text-slate-100"><header className="border-b border-slate-200 bg-white px-4 py-5 dark:border-slate-800 dark:bg-slate-900 sm:px-8"><div className="mx-auto flex max-w-[1600px] flex-wrap items-center justify-between gap-4"><div><p className="text-sm font-semibold text-blue-700 dark:text-blue-300">FinSight · {w('Owner dashboard', 'Panel del propietario')}</p><h1 className="text-2xl font-semibold">{pages.find(p => p[0] === route)?.[language === 'es' ? 2 : 1] ?? w('User detail', 'Detalle de usuario')}</h1></div><div className="flex flex-wrap gap-2"><Link className={secondary} to="/">{w('My finances', 'Mis finanzas')}</Link><button className={secondary} onClick={() => setLanguage(language === 'es' ? 'en' : 'es')}>{language === 'es' ? 'English' : 'Español'}</button><button className={secondary} onClick={toggleTheme}>{theme === 'light' ? w('Dark mode', 'Modo oscuro') : w('Light mode', 'Modo claro')}</button></div></div></header><div className="mx-auto max-w-[1600px] space-y-6 p-4 sm:p-8"><nav className="flex flex-wrap gap-2" aria-label={w('Admin sections', 'Secciones administrativas')}>{pages.map(([key, en, es]) => <Link className={route === key ? button : secondary} aria-current={route === key ? 'page' : undefined} to={`/admin/${key}`} key={key}>{w(en, es)}</Link>)}</nav>{allowed !== false && <AppCard><form onSubmit={e => { e.preventDefault(); setApplied({ ...filters, page: '1' }); }}><div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4"><label>{w('From', 'Desde')}<input className="momentum-input mt-1 w-full" type="date" required value={filters.start} onChange={e => change('start', e.target.value)}/></label><label>{w('Through', 'Hasta')}<input className="momentum-input mt-1 w-full" type="date" required value={filters.end} onChange={e => change('end', e.target.value)}/></label><label>{w('Report timezone (IANA)', 'Zona de informe (IANA)')}<input className="momentum-input mt-1 w-full" value={filters.timezone} onChange={e => change('timezone', e.target.value)}/></label><label>{w('Usage platform', 'Plataforma de uso')}<select className="momentum-input mt-1 w-full" value={filters.platform} onChange={e => change('platform', e.target.value)}>{['all', 'web', 'android', 'ios', 'unknown'].map(k => <option key={k} value={k}>{k === 'all' ? w('All platforms', 'Todas las plataformas') : value(k)}</option>)}</select></label></div><details className="mt-4"><summary className="cursor-pointer py-2 font-medium">{w('More filters', 'Más filtros')}</summary><div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-4"><label>{w('Payment provider', 'Proveedor de pago')}<select className="momentum-input mt-1 w-full" value={filters.provider} onChange={e => change('provider', e.target.value)}>{['all', 'google', 'apple', 'stripe', 'unknown'].map(k => <option key={k} value={k}>{k === 'all' ? w('All providers', 'Todos los proveedores') : value(k)}</option>)}</select></label><label>{w('Subscription state', 'Estado de suscripción')}<select className="momentum-input mt-1 w-full" value={filters.status} onChange={e => change('status', e.target.value)}>{['all', 'pending', 'trial', 'active', 'cancel_at_period_end', 'grace', 'hold', 'paused', 'expired', 'revoked', 'refunded', 'unknown', 'legacy'].map(k => <option key={k} value={k}>{k === 'all' ? w('All states', 'Todos los estados') : value(k)}</option>)}</select></label><label>{w('Plan (exact ID)', 'Plan (ID exacto)')}<input className="momentum-input mt-1 w-full" value={filters.plan} onChange={e => change('plan', e.target.value)}/></label><label>{w('App version', 'Versión de app')}<input className="momentum-input mt-1 w-full" value={filters.version} onChange={e => change('version', e.target.value)}/></label><label>{w('Signup cohort date', 'Fecha de cohorte de alta')}<input type="date" className="momentum-input mt-1 w-full" value={filters.cohort} onChange={e => change('cohort', e.target.value)}/></label><label>{w('Environment', 'Entorno')}<select className="momentum-input mt-1 w-full" value={filters.environment} onChange={e => change('environment', e.target.value)}>{['production', 'test', 'internal', 'unknown', 'all'].map(k => <option key={k} value={k}>{k === 'all' ? w('All environments', 'Todos los entornos') : value(k)}</option>)}</select></label><label>{w('User ID or email', 'ID de usuario o correo')}<input className="momentum-input mt-1 w-full" value={filters.q} maxLength={100} onChange={e => change('q', e.target.value)}/></label><label className="flex items-center gap-2"><input type="checkbox" checked={filters.include_internal === 'true'} onChange={e => change('include_internal', String(e.target.checked))}/>{w('Include internal accounts', 'Incluir cuentas internas')}</label></div></details><div className="mt-4 flex flex-wrap gap-3"><button className={button} disabled={loading}>{w('Apply filters', 'Aplicar filtros')}</button><button type="button" className={secondary} onClick={() => setReload(v => v + 1)}>{w('Refresh', 'Actualizar')}</button>{['users', 'subscriptions'].includes(route) && <button type="button" className={secondary} disabled={exporting || loading} onClick={() => void download()}>{exporting ? w('Exporting…', 'Exportando…') : w('Export CSV (max 10,000)', 'Exportar CSV (máx. 10,000)')}</button>}</div></form></AppCard>}{loading && <AppCard><p role="status">{w('Loading verified data…', 'Cargando datos verificados…')}</p></AppCard>}{error && <AppCard><p role="alert">{error}</p>{allowed !== false && <button className={`${secondary} mt-4`} onClick={() => setReload(v => v + 1)}>{w('Retry', 'Reintentar')}</button>}</AppCard>}{report && !loading && <><AppCard padding="sm"><p className="text-sm">{report.meta.filters.start as string} → {report.meta.filters.end as string} · {report.meta.filters.timezone as string} · {w('Updated', 'Actualizado')}: {new Date(report.meta.generated_at).toLocaleString(language)} · {w('Tracking since', 'Registro desde')}: {report.meta.tracking_started_at ? new Date(report.meta.tracking_started_at).toLocaleDateString(language) : 'N/D'}</p>{report.meta.partial_day && <p className="mt-2 font-medium text-amber-800 dark:text-amber-200">{w('The selected end day is partial.', 'El último día seleccionado está incompleto.')}</p>}<ul className="mt-2 list-disc space-y-1 pl-5 text-sm">{report.meta.notes.map((note, i) => <li key={i}>{typeof note === 'string' ? note : note[language]}</li>)}</ul></AppCard><div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{report.cards.map(card => <AppCard key={card.key}><h2 className="text-sm text-slate-600 dark:text-slate-300">{card.label[language]}</h2><p className="mt-2 text-3xl font-semibold">{value(card.value)}{card.unit && <span className="ml-2 text-base">{card.unit}</span>}</p></AppCard>)}</div><div className="grid gap-5 xl:grid-cols-2">{report.series.map(series => <Chart key={series.key} series={series}/>)}</div>{report.tables.map(table => <AppCard key={table.key}><h2 className="mb-3 text-lg font-semibold">{table.title[language]}</h2><DataTable rows={table.rows} caption={table.title[language]} linkUsers={route === 'users'}/></AppCard>)}{report.pagination && <nav className="flex items-center justify-between gap-3" aria-label={w('Pagination', 'Paginación')}><button className={secondary} disabled={report.pagination.page <= 1} onClick={() => setApplied(old => ({ ...old, page: String(Number(old.page) - 1) }))}>{w('Previous', 'Anterior')}</button><span>{report.pagination.page} / {Math.max(1, Math.ceil(report.pagination.total / report.pagination.page_size))} · {report.pagination.total} {w('records', 'registros')}</span><button className={secondary} disabled={report.pagination.page * report.pagination.page_size >= report.pagination.total} onClick={() => setApplied(old => ({ ...old, page: String(Number(old.page) + 1) }))}>{w('Next', 'Siguiente')}</button></nav>}{route.startsWith('users/') && <button className={secondary} onClick={() => navigate('/admin/users')}>{w('Back to users', 'Volver a usuarios')}</button>}</>}</div></div>;
}
