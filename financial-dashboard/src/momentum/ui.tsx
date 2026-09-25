import { useCallback, useEffect, useRef, useState } from 'react';
import { Check, ChevronDown, ChevronRight, LockKeyhole, X } from 'lucide-react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { AppCard } from '../components/ui';
import { MomentumAsset } from './Asset';
import { useMomentum } from './context';
import { eventPayload, platformRequest } from './service';
import type { Achievement, Mission, Momentum, MomentumResponse, Review } from './types';
import './momentum.css';
import { button, secondary, useWords, missionLink, mobileOnly } from './utils';

function Progress({ value, max, label }: { value: number; max: number; label: string }) {
    return <div className="space-y-1"><div className="flex justify-between gap-3 text-sm"><span>{label}</span><span>{value}/{max}</span></div><progress className="momentum-progress w-full" max={Math.max(1, max)} value={Math.max(0, Math.min(value, max))} aria-label={label} /></div>;
}

function LevelProgress({ state }: { state: Momentum }) {
    const { w, language } = useWords();
    const next = state.level.next_xp;
    return <div className="momentum-level-progress">
        <div><span>{state.lifetime_xp.toLocaleString(language)} XP</span><span>{next == null ? w('Highest level', 'Nivel máximo') : `${Math.max(0, next - state.lifetime_xp).toLocaleString(language)} ${w('XP to the next level', 'XP al siguiente nivel')}`}</span></div>
        {next != null && <progress className="momentum-progress" aria-label={w('Progress to the next level', 'Progreso al siguiente nivel')} value={Math.max(0, Math.min(state.lifetime_xp - state.level.minimum_xp, next - state.level.minimum_xp))} max={Math.max(1, next - state.level.minimum_xp)} />}
    </div>;
}

function collectionOrder(achievements: Achievement[]) {
    return [...achievements].sort((a, b) => {
        if (Boolean(a.completed_at) !== Boolean(b.completed_at)) return a.completed_at ? -1 : 1;
        if (a.completed_at && b.completed_at) return Date.parse(b.completed_at) - Date.parse(a.completed_at);
        if (a.available !== b.available) return a.available ? -1 : 1;
        return Math.min(1, b.progress / Math.max(1, b.target)) - Math.min(1, a.progress / Math.max(1, a.target));
    });
}

function profileName(userId: number) {
    try {
        const user: unknown = JSON.parse(localStorage.getItem('user') || '{}');
        if (user && typeof user === 'object' && 'id' in user && Number(user.id) === userId && 'username' in user && typeof user.username === 'string') return user.username.trim();
    } catch { /* The level remains the profile title without a saved display name. */ }
    return '';
}

function OfflineNotice() {
    const { refresh } = useMomentum();
    const { w } = useWords();
    return <p className="momentum-offline-status" role="status"><span>{w('Offline · Progress saved', 'Sin conexión · Progreso guardado')}</span><button type="button" onClick={() => void refresh()}>{w('Retry', 'Reintentar')}</button></p>;
}

export function MomentumCard() {
    const { state, loading, error, refresh } = useMomentum();
    const { w, language } = useWords();
    if (loading && !state) return <div className="momentum-card-skeleton" role="status" aria-label={w('Loading Momentum', 'Cargando Momentum')} />;
    if (!state) return error ? <AppCard padding="sm"><p>{w('Momentum could not be refreshed.', 'No se pudo actualizar Momentum.')}</p><button className={secondary} onClick={() => void refresh()}>{w('Retry', 'Reintentar')}</button></AppCard> : null;
    const badges = collectionOrder(state.achievements).slice(0, 3);
    return <AppCard padding="sm" className="momentum-mini-card">
        <div className="momentum-mini-identity"><MomentumAsset assetKey={state.level.key} size={64} /><div><p className="momentum-eyebrow">Momentum</p><h2>{state.level.title[language]}</h2></div></div>
        <div className="momentum-mini-progress"><LevelProgress state={state} /></div>
        <div className="momentum-mini-end"><div className="momentum-mini-badges" aria-label={w('Your collection', 'Tu colección')}>{badges.map(a => <MomentumAsset key={a.key} assetKey={a.key} size={24} locked={!a.completed_at} alt={`${a.title[language]} · ${a.completed_at ? w('Unlocked', 'Desbloqueada') : w('Locked', 'Bloqueada')}`} />)}</div><Link className="momentum-text-link" to="/momentum">{w('View my profile', 'Ver mi perfil')}<ChevronRight size={16} aria-hidden="true" /></Link></div>
        {error && <OfflineNotice />}
    </AppCard>;
}

function BadgeTile({ item, onOpen }: { item: Achievement; onOpen: (key: string) => void }) {
    const { w, language } = useWords();
    const unlocked = Boolean(item.completed_at);
    const status = unlocked ? w('Unlocked', 'Desbloqueada') : w('Locked', 'Bloqueada');
    return <button type="button" className={`momentum-badge-tile ${unlocked ? 'is-unlocked' : 'is-locked'}`} onClick={() => onOpen(item.key)} aria-label={`${item.title[language]} · ${status}${unlocked && !item.seen_at ? ` · ${w('New', 'Nueva')}` : ''}`} aria-haspopup="dialog">
        <span className="momentum-badge-art"><MomentumAsset assetKey={item.key} size={96} locked={!unlocked} /></span>
        <span className="momentum-badge-title">{item.title[language]}</span>
        <span className="momentum-badge-status">{unlocked ? <Check size={13} aria-hidden="true" /> : <LockKeyhole size={12} aria-hidden="true" />}{status}{unlocked && !item.seen_at && <span className="momentum-new-dot" aria-hidden="true" />}</span>
    </button>;
}

function AchievementDialog({ item, onClose }: { item: Achievement; onClose: () => void }) {
    const { w, language } = useWords();
    const { acknowledgeAchievement } = useMomentum();
    const dialog = useRef<HTMLDialogElement>(null);
    const [busy, setBusy] = useState(false), [error, setError] = useState(false);
    useEffect(() => {
        const element = dialog.current;
        const previous = document.activeElement instanceof HTMLElement ? document.activeElement : null;
        element?.showModal();
        return () => { element?.close(); if (previous?.isConnected) previous.focus(); };
    }, []);
    const acknowledge = async () => {
        setBusy(true); setError(false);
        try {
            await acknowledgeAchievement(item.key);
            onClose();
        } catch { setError(true); } finally { setBusy(false); }
    };
    const unlocked = Boolean(item.completed_at);
    return <dialog ref={dialog} className="momentum-badge-dialog" aria-labelledby="badge-detail-title" aria-describedby="badge-detail-requirement" onCancel={event => { event.preventDefault(); onClose(); }}>
        <button type="button" className="momentum-dialog-close" onClick={onClose} aria-label={w('Close details', 'Cerrar detalle')} autoFocus><X size={20} aria-hidden="true" /></button>
        <div className={`momentum-detail-art ${unlocked ? 'is-unlocked' : ''}`}><MomentumAsset assetKey={item.key} size={128} locked={!unlocked} /></div>
        <p className="momentum-eyebrow">{unlocked ? w('Achievement unlocked', 'Insignia desbloqueada') : w('Your next achievement', 'Tu próximo logro')}</p>
        <h2 id="badge-detail-title">{item.title[language]}</h2>
        <p id="badge-detail-requirement" className="momentum-detail-requirement">{item.requirement[language]}</p>
        <div className="momentum-detail-progress"><Progress value={item.progress} max={item.target} label={w('Progress', 'Progreso')} /></div>
        <dl className="momentum-detail-facts"><div><dt>{w('Achievement XP', 'XP de la insignia')}</dt><dd>{item.xp.toLocaleString(language)} XP</dd></div><div><dt>{w('Status', 'Estado')}</dt><dd>{unlocked ? w('Unlocked', 'Desbloqueada') : item.available ? w('In progress', 'En progreso') : w('Unavailable', 'No disponible')}</dd></div>{item.completed_at && <div><dt>{w('Unlocked on', 'Desbloqueada el')}</dt><dd>{new Date(item.completed_at).toLocaleDateString(language, { dateStyle: 'medium' })}</dd></div>}</dl>
        {item.reason && <p className="momentum-detail-reason">{item.reason[language]}</p>}
        {error && <p role="alert">{w('Could not save acknowledgement. Try again.', 'No se pudo guardar la confirmación. Reintenta.')}</p>}
        <button disabled={busy} type="button" className={`${button} momentum-dialog-action`} onClick={unlocked && !item.seen_at ? () => void acknowledge() : onClose}>{busy ? w('Saving…', 'Guardando…') : unlocked && !item.seen_at ? w('Got it', 'Entendido') : w('Close', 'Cerrar')}</button>
    </dialog>;
}

function MomentumNotice({ onOpen, onActivities }: { onOpen: (key: string) => void; onActivities?: () => void }) {
    const { state, replace, acknowledgeAchievement } = useMomentum();
    const { w, language } = useWords();
    const { pathname } = useLocation();
    const [busy, setBusy] = useState(false), [error, setError] = useState(false);
    if (!state) return null;
    const achievement = state.achievements.find(a => a.completed_at && !a.seen_at);
    const type = state.backfill.unseen ? 'backfill_seen' : !state.coachmark_seen ? 'coachmark_seen' : null;
    if (!type && !achievement) return null;
    const acknowledge = async () => {
        setBusy(true); setError(false);
        try {
            if (type) replace(await platformRequest<MomentumResponse>('/engagement/client-events', eventPayload(type)));
            else if (achievement) await acknowledgeAchievement(achievement.key);
        } catch { setError(true); } finally { setBusy(false); }
    };
    const text = type === 'backfill_seen' ? w('Your earlier progress is part of your collection.', 'Tu progreso anterior ya forma parte de tu colección.') : type === 'coachmark_seen' ? w('Your collection grows with useful financial habits.', 'Tu colección crece con hábitos financieros útiles.') : `${w('New in your collection', 'Nueva en tu colección')}: ${achievement!.title[language]}`;
    return <aside className="momentum-notice" aria-label={w('Momentum update', 'Novedad de Momentum')}><MomentumAsset assetKey={type ? 'momentum_mark' : achievement!.key} size={24} /><p>{text}</p><div className="momentum-notice-actions">{type === 'backfill_seen' ? pathname === '/momentum/achievements' ? null : <Link to="/momentum/achievements" className="momentum-text-link">{w('View', 'Ver')}</Link> : type === 'coachmark_seen' ? onActivities ? <button type="button" className="momentum-text-link" onClick={onActivities}>{w('View activities', 'Ver actividades')}</button> : <Link to="/momentum#activities" className="momentum-text-link">{w('View activities', 'Ver actividades')}</Link> : <button type="button" className="momentum-text-link" aria-haspopup="dialog" onClick={() => onOpen(achievement!.key)}>{w('View', 'Ver')}</button>}<button type="button" disabled={busy} className="momentum-notice-dismiss" onClick={() => void acknowledge()}>{w('Got it', 'Entendido')}</button></div>{error && <p role="alert">{w('Could not save. Try again.', 'No se pudo guardar. Reintenta.')}</p>}</aside>;
}

function ProfileHero({ state }: { state: Momentum }) {
    const { w, language } = useWords();
    const unlocked = state.achievements.filter(a => a.completed_at).length;
    const username = profileName(state.user_id);
    return <section className="momentum-profile-hero" aria-labelledby="momentum-profile-title">
        <div className="momentum-profile-medal"><MomentumAsset assetKey={state.level.key} size={128} /></div>
        <div className="momentum-profile-copy"><p className="momentum-eyebrow">{username && <span>{username} <span aria-hidden="true">/</span> </span>}Momentum</p><h1 id="momentum-profile-title">{state.level.title[language]}</h1><p className="momentum-profile-caption">{w('A collection of the progress you make.', 'Una colección del progreso que construyes.')}</p><LevelProgress state={state} /></div>
        <dl className="momentum-profile-stats"><div><dt>{w('Collection', 'Colección')}</dt><dd>{unlocked}<span> / {state.achievements.length}</span></dd></div><div><dt>{w('Rhythm', 'Ritmo')}</dt><dd>{state.rhythm}<span> {state.rhythm === 1 ? w('week', 'semana') : w('weeks', 'semanas')}</span></dd></div></dl>
    </section>;
}

function ProgressDetails({ state }: { state: Momentum }) {
    const { w, language } = useWords();
    return <div className="momentum-detail-sections">
        <section><h3>{w('Your XP', 'Tu XP')}</h3><dl className="momentum-detail-facts"><div><dt>{w('Lifetime XP', 'XP acumulado')}</dt><dd>{state.lifetime_xp.toLocaleString(language)}</dd></div><div><dt>{w('Weekly repeatable XP', 'XP semanal repetible')}</dt><dd>{state.week.repeatable_xp}/{state.week.cap}</dd></div><div><dt>{w('Weekly completion bonus', 'Bono por completar la semana')}</dt><dd>{state.week.bonus_xp} XP</dd></div><div><dt>{w('Monthly repeatable XP', 'XP mensual repetible')}</dt><dd>{state.month.repeatable_xp}/{state.month.cap}</dd></div></dl><p className="momentum-muted">{w('Limits can reduce awarded XP. Achievement bonuses are separate, and lifetime XP never resets.', 'Los límites pueden reducir el XP concedido. Los bonos de insignias son independientes y el XP acumulado no se reinicia.')}</p></section>
        <section><h3>{w('Your weekly rhythm', 'Tu ritmo semanal')}</h3><p>{state.week.key} · {state.week.timezone}</p>{state.week.grace_applied && <p className="momentum-muted">{w('A grace week protected your rhythm. It adds no XP or completed review.', 'Una semana de gracia protegió tu ritmo. No añade XP ni revisiones completadas.')}</p>}</section>
        {state.xp_history?.length > 0 && <section><h3>{w('XP history · last 30 days', 'Historial de XP · últimos 30 días')}</h3><div className="momentum-history-table"><table><thead><tr><th>{w('Day', 'Día')}</th><th>XP</th></tr></thead><tbody>{state.xp_history.map(row => <tr key={row.period}><td>{new Intl.DateTimeFormat(language, { dateStyle: 'medium', timeZone: 'UTC' }).format(new Date(`${row.period}T00:00:00Z`))}</td><td>{row.xp.toLocaleString(language)}</td></tr>)}</tbody></table></div></section>}
        {state.ai_credits.available && <section className="momentum-credit-detail"><MomentumAsset assetKey="ai_credit" size={40} /><div><h3>{state.ai_credits.balance} {w('AI questions available', 'preguntas IA disponibles')}</h3>{state.ai_credits.expires_at && <p>{w('Expires', 'Vencen')}: {new Date(state.ai_credits.expires_at).toLocaleDateString(language)}</p>}<p className="momentum-muted">{w('Use them in the AI assistant in the mobile app. Credits do not change your subscription.', 'Úsalas en el asistente IA de la app móvil. Los créditos no cambian tu suscripción.')}</p></div></section>}
    </div>;
}

export function MomentumPage() {
    const { state, loading, error, refresh, replace } = useMomentum();
    const { w } = useWords();
    const location = useLocation();
    const [selectedKey, setSelectedKey] = useState<string | null>(null);
    const [notice, setNotice] = useState('');
    const activities = useRef<HTMLDetailsElement>(null);
    const presented = useRef('');
    const presentWeek = useCallback(async () => {
        try { replace(await platformRequest<MomentumResponse>('/engagement/client-events', eventPayload('week_presented'))); }
        catch { setNotice(w('Could not save the weekly update. Refresh to try again.', 'No se pudo guardar la novedad semanal. Actualiza para reintentar.')); }
    }, [replace, w]);
    useEffect(() => {
        if (state?.week.new_week && presented.current !== state.week.key) { presented.current = state.week.key; void presentWeek(); }
    }, [presentWeek, state?.week.new_week, state?.week.key]);
    const openActivities = useCallback(() => {
        if (!activities.current) return;
        activities.current.open = true;
        activities.current.scrollIntoView({ block: 'start' });
        activities.current.querySelector('summary')?.focus();
    }, []);
    const hasState = Boolean(state);
    useEffect(() => { if (location.hash === '#activities' && hasState) openActivities(); }, [location.hash, hasState, openActivities]);
    if (loading && !state) return <p role="status">{w('Loading your profile…', 'Cargando tu perfil…')}</p>;
    if (!state) return <AppCard><h1 className="text-2xl font-semibold">Momentum</h1><p>{error ? w('Connection unavailable. Your progress is safe.', 'Sin conexión. Tu progreso está guardado.') : w('Momentum is not available for this account yet.', 'Momentum aún no está disponible para esta cuenta.')}</p><button className={`${secondary} mt-4`} onClick={() => void refresh()}>{w('Refresh', 'Actualizar')}</button></AppCard>;
    const activation = state.missions.filter(m => m.scope === 'activation' && m.status !== 'replaced');
    const weekly = state.missions.filter(m => m.scope === 'weekly' && m.status !== 'replaced');
    const other = state.missions.filter(m => ['monthly', 'comeback', 'feature'].includes(m.scope) && m.status !== 'replaced');
    const featured = collectionOrder(state.achievements).slice(0, 6);
    const selected = state.achievements.find(a => a.key === selectedKey);
    const weekComplete = state.week.assigned && state.week.total > 0 && state.week.completed === state.week.total;
    return <div className="momentum-profile">
        <ProfileHero state={state} />
        {error && <OfflineNotice />}
        <section className="momentum-collection" aria-labelledby="profile-collection-title"><div className="momentum-section-heading"><div><h2 id="profile-collection-title">{w('Your collection', 'Tu colección')}</h2><p>{w('Small steps, lasting achievements.', 'Pequeños pasos, logros que permanecen.')}</p></div><Link className="momentum-text-link" to="/momentum/achievements">{w('View collection', 'Ver colección')}<ChevronRight size={16} aria-hidden="true" /></Link></div><div className="momentum-badge-grid">{featured.map(a => <BadgeTile key={a.key} item={a} onOpen={setSelectedKey} />)}</div></section>
        {!error && <MomentumNotice onOpen={setSelectedKey} onActivities={openActivities} />}
        {notice && <p className="momentum-muted" role="status">{notice}</p>}
        <details className="momentum-week-panel" id="activities" ref={activities}><summary><span className="momentum-week-icon"><MomentumAsset assetKey={weekComplete ? 'week_complete' : 'weekly_review'} size={40} /></span><span className="momentum-week-copy"><strong>{w('This week', 'Esta semana')}</strong><span>{weekComplete ? w('Your week is complete', 'Tu semana está completa') : state.week.assigned ? `${state.week.completed} ${w('of', 'de')} ${state.week.total} ${w('activities complete', 'actividades completas')}` : w('Start with one useful step.', 'Empieza con un paso útil.')}</span></span>{state.week.assigned && <progress className="momentum-progress momentum-week-progress" value={state.week.completed} max={Math.max(1, state.week.total)} aria-label={w('Weekly activities completed', 'Actividades semanales completadas')} />}<span className="momentum-disclosure-cta">{w('View activities', 'Ver actividades')}<ChevronDown size={17} aria-hidden="true" /></span></summary><div className="momentum-activities">
            {weekly.length > 0 ? <section><h3>{w('Your weekly activities', 'Tus actividades semanales')}</h3><MissionGroup missions={weekly} /></section> : <p className="momentum-muted">{w('Your weekly activities will appear as you build your foundation.', 'Tus actividades semanales aparecerán mientras construyes tu base.')}</p>}
            {state.week.unavailable && <p className="momentum-muted">{w('A suitable replacement is not available yet. Your rhythm will not be penalized.', 'Aún no hay una sustitución adecuada. Tu ritmo no se penalizará.')}</p>}
            {activation.length > 0 && <section><h3>{w('Getting started', 'Primeros pasos')}</h3><MissionGroup missions={activation} /></section>}
            {other.length > 0 && <section><h3>{w('More to explore', 'Más por descubrir')}</h3><MissionGroup missions={other} /></section>}
        </div></details>
        <div className="momentum-secondary-panels"><details className="momentum-secondary-panel"><summary><span>{w('Progress details', 'Detalles del progreso')}</span><ChevronDown size={17} aria-hidden="true" /></summary><ProgressDetails state={state} /></details><details className="momentum-secondary-panel"><summary><span>{w('Preferences', 'Preferencias')}</span><ChevronDown size={17} aria-hidden="true" /></summary><MomentumPreferences /></details></div>
        {selected && <AchievementDialog key={selected.key} item={selected} onClose={() => setSelectedKey(current => current === selected.key ? null : current)} />}
    </div>;
}

export function AchievementsPage() {
    const { state, loading, refresh } = useMomentum();
    const { w } = useWords();
    const [filter, setFilter] = useState<'all' | 'unlocked' | 'locked'>('all');
    const [selectedKey, setSelectedKey] = useState<string | null>(null);
    const unlocked = state?.achievements.filter(a => a.completed_at).length ?? 0;
    const list = collectionOrder(state?.achievements ?? []).filter(a => filter === 'all' || (filter === 'unlocked' ? Boolean(a.completed_at) : !a.completed_at));
    const selected = state?.achievements.find(a => a.key === selectedKey);
    return <div className="momentum-profile momentum-gallery">
        <header className="momentum-gallery-header"><Link className="momentum-text-link" to="/momentum">{w('Back to my profile', 'Volver a mi perfil')}</Link><div className="momentum-section-heading"><div><p className="momentum-eyebrow">Momentum</p><h1>{w('Your collection', 'Tu colección')}</h1>{state && <p>{unlocked} {w('of', 'de')} {state.achievements.length} {w('achievements unlocked', 'insignias desbloqueadas')}</p>}</div><MomentumAsset assetKey="all_achievements" size={64} /></div></header>
        <div className="momentum-collection-filters" role="group" aria-label={w('Show achievements', 'Mostrar insignias')}>{(['all', 'unlocked', 'locked'] as const).map(value => <button type="button" key={value} aria-pressed={filter === value} onClick={() => setFilter(value)}>{value === 'all' ? w('All', 'Todas') : value === 'unlocked' ? w('Unlocked', 'Desbloqueadas') : w('Locked', 'Bloqueadas')} {state && <span>{value === 'all' ? state.achievements.length : value === 'unlocked' ? unlocked : state.achievements.length - unlocked}</span>}</button>)}</div>
        {loading && !state ? <p role="status">{w('Loading your collection…', 'Cargando tu colección…')}</p> : !state ? <AppCard><p>{w('Your collection could not be loaded.', 'No se pudo cargar tu colección.')}</p><button className={secondary} onClick={() => void refresh()}>{w('Retry', 'Reintentar')}</button></AppCard> : list.length ? <div className="momentum-badge-grid">{list.map(a => <BadgeTile key={a.key} item={a} onOpen={setSelectedKey} />)}</div> : <div className="momentum-empty-collection"><MomentumAsset assetKey="all_achievements" size={64} /><p>{!state.achievements.length ? w('Your collection will appear here.', 'Tu colección aparecerá aquí.') : filter === 'unlocked' ? w('Your first achievement is ahead. Explore an activity to get started.', 'Tu primera insignia te espera. Explora una actividad para empezar.') : w('You have unlocked every achievement in this collection.', 'Has desbloqueado todas las insignias de esta colección.')}</p><Link className="momentum-text-link" to="/momentum#activities">{w('View activities', 'Ver actividades')}<ChevronRight size={16} aria-hidden="true" /></Link></div>}
        <MomentumNotice onOpen={setSelectedKey} />
        {selected && <AchievementDialog key={selected.key} item={selected} onClose={() => setSelectedKey(current => current === selected.key ? null : current)} />}
    </div>;
}

export function ContextualMission() { const { pathname } = useLocation(); const { state } = useMomentum(); const { language, w } = useWords(); if (!['/transactions', '/payments', '/projects', '/invoices', '/investments', '/categories', '/analytics'].includes(pathname))
    return null; const mission = state?.missions.find(m => m.status === 'active' && m.deeplink.split('?')[0] === pathname); return mission ? <aside className="mb-5 flex flex-wrap items-center gap-3 rounded-2xl border border-blue-200 bg-blue-50 p-4 dark:border-blue-800 dark:bg-blue-950/50"><MomentumAsset assetKey="momentum_mark" size={24}/><div className="flex-1"><p className="font-medium">{mission.title[language]}</p><p className="text-sm">{mission.progress}/{mission.target} · {mission.nominal_xp} XP</p></div><Link className={secondary} to={mission.review ? missionLink(mission) : '/momentum'}>{w('View activity', 'Ver actividad')}</Link></aside> : null; }
function MissionCard({ mission: m }: { mission: Mission }) {
    const { language, w } = useWords();
    return <AppCard className="momentum-activity-card">
        <div className="flex items-start gap-3"><MomentumAsset assetKey={m.scope === 'comeback' ? 'comeback' : m.slot ? `mission_${m.slot}` : 'momentum_mark'} /><h3>{m.title[language]}</h3></div>
        <div className="my-4"><Progress value={m.progress} max={m.target} label={m.status === 'completed' ? w('Completed', 'Completada') : w('Your progress', 'Tu progreso')} /></div>
        {m.status === 'active' && !mobileOnly(m) && <Link className={button} to={missionLink(m)}>{m.review ? w('Review and confirm', 'Revisar y confirmar') : m.progress > 0 ? w('Continue', 'Continuar') : w('Start', 'Empezar')}</Link>}
        {m.status === 'active' && mobileOnly(m) && <p className="momentum-muted">{w('Continue in the mobile app', 'Continúa en la app móvil')}</p>}
        {m.status === 'unavailable' && <p className="momentum-muted">{w('Not available right now', 'No disponible por ahora')}</p>}
        <details className="momentum-activity-details"><summary>{w('Details', 'Detalles')}<ChevronDown size={14} aria-hidden="true" /></summary><p>{m.requirement[language]}</p><p>{m.status === 'completed' ? `${m.granted_xp} XP ${w('earned', 'obtenidos')}` : `${w('Up to', 'Hasta')} ${m.nominal_xp} XP`}</p>{m.reason && <p>{m.reason[language]}</p>}{m.status === 'active' && mobileOnly(m) && <p>{w('This activity uses a tool available in the FinSight mobile app.', 'Esta actividad usa una herramienta de la app móvil FinSight.')}</p>}</details>
    </AppCard>;
}
function MissionGroup({ missions }: { missions: Mission[] }) {
    const { w } = useWords();
    const active = missions.filter(m => m.status !== 'completed');
    const completed = missions.filter(m => m.status === 'completed');
    return <>{active.length > 0 && <div className="momentum-mission-grid">{active.map(m => <MissionCard key={`${m.key}:${m.period}`} mission={m} />)}</div>}{completed.length > 0 && <details className="momentum-completed-activities"><summary>{w('Completed', 'Completadas')} ({completed.length})<ChevronDown size={15} aria-hidden="true" /></summary><div className="momentum-mission-grid">{completed.map(m => <MissionCard key={`${m.key}:${m.period}`} mission={m} />)}</div></details>}</>;
}

function MomentumPreferences() { const { state, replace } = useMomentum(); const { w, language } = useWords(); const [busy, setBusy] = useState(false), [error, setError] = useState(false); if (!state)
    return null; return <AppCard><h2 className="font-semibold">{w('Preferences', 'Preferencias')}</h2><p className="text-sm">{w('Reminders are delivered only on devices with push permission. Quiet hours use your assigned timezone.', 'Los recordatorios se entregan sólo en dispositivos con permiso de notificaciones. Las horas de silencio usan tu zona asignada.')}</p><form className="mt-3 flex flex-wrap items-end gap-4" onSubmit={async (e) => { e.preventDefault(); const f = new FormData(e.currentTarget); setBusy(true); setError(false); try {
    replace(await platformRequest<MomentumResponse>('/engagement/preferences', { notifications_enabled: f.has('notifications'), quiet_start: Number(f.get('start')), quiet_end: Number(f.get('end')), locale: language, timezone_name: String(f.get('timezone')), timezone_offset_min: -new Date().getTimezoneOffset() }));
}
catch {
    setError(true);
}
finally {
    setBusy(false);
} }}><label>{w('Preferred timezone (IANA)', 'Zona preferida (IANA)')}<input name="timezone" className="momentum-input block" required defaultValue={state.preferences.timezone_name || Intl.DateTimeFormat().resolvedOptions().timeZone} aria-describedby="timezone-hint"/></label><label className="flex min-h-11 items-center gap-2"><input name="notifications" type="checkbox" defaultChecked={state.preferences.notifications_enabled}/>{w('Weekly reminders', 'Recordatorios semanales')}</label><label>{w('Quiet from', 'Silencio desde')}<input className="momentum-input block" type="number" name="start" min="0" max="23" defaultValue={state.preferences.quiet_start}/></label><label>{w('Until', 'Hasta')}<input className="momentum-input block" type="number" name="end" min="0" max="23" defaultValue={state.preferences.quiet_end}/></label><button disabled={busy} className={button}>{w('Save', 'Guardar')}</button></form><p id="timezone-hint" className="mt-2 text-sm">{w('Timezone changes apply to new periods. The current week keeps its original boundaries.', 'Los cambios de zona se aplican a nuevos períodos. La semana actual mantiene sus límites originales.')}</p>{error && <p role="alert">{w('Could not save preferences.', 'No se pudieron guardar las preferencias.')}</p>}</AppCard>; }

const fieldNames: Record<string, [
    string,
    string
]> = { name: ['Name', 'Nombre'], type: ['Type', 'Tipo'], balance: ['Balance', 'Saldo'], currency: ['Currency', 'Moneda'], amount: ['Amount', 'Importe'], date: ['Date', 'Fecha'], category: ['Category', 'Categoría'], status: ['Status', 'Estado'], description: ['Description', 'Descripción'], total: ['Total', 'Total'], income: ['Income', 'Ingresos'], expense: ['Expense', 'Gastos'], net: ['Net', 'Neto'], account_name: ['Account', 'Cuenta'], next_date: ['Next date', 'Próxima fecha'], budget: ['Budget', 'Presupuesto'], spent: ['Spent', 'Gastado'], progress: ['Progress', 'Progreso'], end_date: ['End date', 'Fecha final'], paid: ['Paid', 'Pagado'], due_date: ['Due date', 'Vencimiento'], current_value: ['Current value', 'Valor actual'], quantity: ['Quantity', 'Cantidad'] };
Object.assign(fieldNames,{expenses:['Expenses','Gastos'],frequency:['Frequency','Frecuencia'],records:['Records','Registros'],number:['Number','Número'],amount_due:['Amount due','Importe pendiente'],principal:['Principal','Capital'],annual_rate:['Annual rate','Tasa anual'],start_date:['Start date','Fecha inicial']});
function reviewValue(value: unknown, language: 'en'|'es', key: string) { if(typeof value === 'string' && ['date','next_date','due_date','start_date','end_date'].includes(key) && /^\d{4}-\d{2}-\d{2}/.test(value)) return new Intl.DateTimeFormat(language,{dateStyle:'medium',timeZone:'UTC'}).format(new Date(value.slice(0,10)+'T00:00:00Z')); if (typeof value === 'number' || (typeof value === 'string' && ['balance','amount','income','expense','expenses','net','budget','spent','paid','amount_due','principal','annual_rate','quantity','current_value','total'].includes(key) && /^-?\d+(\.\d+)?$/.test(value))) return Number(value).toLocaleString(language,{maximumFractionDigits:2}); const translated:Record<string,string>={Income:'Ingreso',Expense:'Gasto',Transfer:'Transferencia',Checking:'Corriente',Savings:'Ahorros',Business:'Negocio',Investment:'Inversión',Credit:'Crédito',Active:'Activo',Completed:'Completado','On Hold':'En pausa',Weekly:'Semanal',Monthly:'Mensual',Quarterly:'Trimestral',Yearly:'Anual',Uncategorized:'Sin categoría'};if(language==='es'&&typeof value==='string'&&translated[value])return translated[value]; return value == null ? '—' : typeof value === 'object' ? Object.entries(value as Record<string, unknown>).map(([k, v]) => `${k}: ${String(v)}`).join(' · ') : String(value); }
export function ReviewPage() {
    const { kind = 'weekly' } = useParams();
    const { w, language } = useWords();
    const { replace } = useMomentum();
    const navigate = useNavigate();
    const [review, setReview] = useState<Review | null>(null), [checked, setChecked] = useState<string[]>([]), [step, setStep] = useState('keep_plan'), [error, setError] = useState(''), [busy, setBusy] = useState(false);
    const retry = useRef<{
        snapshot: string;
        payload: Record<string, unknown>;
        expires: string;
    } | null>(null);
    const loadRequest = useRef<AbortController | null>(null);
    const load = useCallback(async () => {
        loadRequest.current?.abort();
        const controller = new AbortController();
        loadRequest.current = controller;
        setBusy(true); setReview(null); setChecked([]); setError(''); retry.current = null; try {
        const snapshot = await platformRequest<Review>(`/engagement/review/${encodeURIComponent(kind)}`, undefined, controller.signal);
        if (!controller.signal.aborted) setReview(snapshot);
    }
    catch {
        if (!controller.signal.aborted) setError('load_failed');
    }
    finally {
        if (!controller.signal.aborted) setBusy(false);
    } }, [kind]);
    useEffect(() => {
        let active = true;
        queueMicrotask(() => { if (active) void load(); });
        return () => { active = false; loadRequest.current?.abort(); };
    }, [load]);
    const applicable = review?.sections.filter(s => s.applicable) ?? [];
    const submit = async () => { if (!review)
        return; if (Date.now() >= Date.parse(review.expires_at)) {
        setError(w('This snapshot expired. Load current data.', 'Esta captura venció. Carga datos actuales.'));
        return;
    } setBusy(true); setError(''); const isPeriod = ['weekly', 'monthly'].includes(kind); const payload = retry.current?.snapshot === review.snapshot_id ? retry.current.payload : isPeriod ? { snapshot_id: review.snapshot_id, confirmed_sections: checked, next_step: step } : { ...eventPayload('review_confirmed'), mission_key: kind, snapshot_id: review.snapshot_id, confirmed_sections: checked }; retry.current = { snapshot: review.snapshot_id, payload, expires: review.expires_at }; try {
        const result = await platformRequest<MomentumResponse>(isPeriod ? `/engagement/${kind}-review` : '/engagement/client-events', payload);
        replace(result);
        retry.current = null;
        navigate('/momentum');
    }
    catch {
        setError(w('Not confirmed. Check your connection and retry before expiry, or load current data.', 'No se confirmó. Revisa la conexión y reintenta antes del vencimiento, o carga datos actuales.'));
    }
    finally {
        setBusy(false);
    } };
    return <div className="space-y-6"><Link className="text-blue-700 underline dark:text-blue-300" to="/momentum">Momentum</Link><h1 className="text-3xl font-semibold">{kind === 'monthly' ? w('Monthly review', 'Revisión mensual') : kind === 'weekly' ? w('Weekly review', 'Revisión semanal') : w('Review your data', 'Revisa tus datos')}</h1><p>{w('Review each section, then confirm when you’re ready.', 'Revisa cada sección y confirma cuando termines.')}</p><details className="momentum-review-help"><summary>{w('How it works', 'Cómo funciona')}</summary><p>{w('Read each applicable section, then confirm it. Opening this page does not complete a mission.', 'Lee cada sección aplicable y después confírmala. Abrir esta página no completa una misión.')}</p></details>{busy && !review && <p role="status">{w('Loading review…', 'Cargando revisión…')}</p>}{error && <p role="alert" className="rounded-xl bg-amber-50 p-4 text-amber-900 dark:bg-amber-950 dark:text-amber-100">{error === 'load_failed' ? w('This review could not be loaded. Try again.', 'No se pudo cargar la revisión. Reintenta.') : error}</p>}{review && <><p className="text-sm">{review.period} · {w('Valid until', 'Válido hasta')} {new Date(review.expires_at).toLocaleTimeString(language)}</p>{review.sections.map(section => <AppCard key={section.key}><h2 className="text-xl font-semibold">{section.title[language]}</h2>{!section.applicable ? <p className="mt-3">{w('No data to review', 'Sin datos para revisar')}</p> : <><div className="my-4 overflow-x-auto"><table className="w-full text-left text-sm"><caption className="sr-only">{section.title[language]}</caption><thead><tr>{Object.keys(section.data[0] ?? {}).filter(k => !/(^id$|_id$)/.test(k)).map(k => <th className="p-2" key={k}>{fieldNames[k]?.[language === 'es' ? 1 : 0] ?? k.replaceAll('_', ' ')}</th>)}</tr></thead><tbody>{section.data.map((row, index) => <tr key={index} className="border-t border-slate-200 dark:border-slate-700">{Object.entries(row).filter(([k]) => !/(^id$|_id$)/.test(k)).map(([k, v]) => <td className="max-w-sm break-words p-2" key={k}>{reviewValue(v,language,k)}</td>)}</tr>)}</tbody></table></div><label className="flex min-h-11 items-center gap-3"><input type="checkbox" checked={checked.includes(section.key)} onChange={e => { retry.current = null; setChecked(old => e.target.checked ? [...old, section.key] : old.filter(k => k !== section.key)); }}/>{w('I reviewed this section', 'Revisé esta sección')}</label></>}</AppCard>)}{['weekly', 'monthly'].includes(kind) && <label className="block">{w('Your next step', 'Tu siguiente paso')}<select className="momentum-input mt-2 block w-full" value={step} onChange={e => { setStep(e.target.value); retry.current = null; }}>{[['keep_plan', 'Keep my current plan', 'Mantener mi plan'], ['review_spending', 'Review spending', 'Revisar gastos'], ['organize_categories', 'Organize categories', 'Organizar categorías'], ['check_obligations', 'Check obligations', 'Revisar obligaciones'], ['review_goal', 'Review a goal', 'Revisar un objetivo']].map(([key, en, es]) => <option key={key} value={key}>{w(en, es)}</option>)}</select></label>}<button disabled={busy || applicable.some(s => !checked.includes(s.key))} className={button} onClick={() => void submit()}>{w('Confirm review', 'Confirmar revisión')}</button></>}<button disabled={busy} className={`${secondary} ml-3`} onClick={() => void load()}>{w('Load current data', 'Cargar datos actuales')}</button></div>;
}
