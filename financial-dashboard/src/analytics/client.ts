import { platformRequest } from '../momentum/service';
const screens = ['dashboard', 'accounts', 'transactions', 'payments', 'projects', 'invoices', 'investments', 'categories', 'analytics', 'settings', 'momentum', 'achievements', 'ai', 'receipt', 'onboarding', 'paywall'];
type EventType = 'session_started' | 'app_foregrounded' | 'screen_view' | 'feature_used' | 'onboarding_step_completed' | 'paywall_viewed' | 'checkout_started' | 'purchase_pending' | 'purchase_failed' | 'restore_completed';
type Event = {
    event_id: string;
    schema_version: 1;
    event_type: EventType;
    session_id: string;
    install_id: string;
    client_platform: 'web';
    app_version?: string;
    source_screen?: string;
    client_occurred_at: string;
    metadata?: Record<string, string>;
};
let identity: string | null = null, allowed = false, session = crypto.randomUUID(), lastActive = 0, queue: Event[] = [], sending = false, install = crypto.randomUUID();
const prefix = 'finsight:telemetry:';
function persist() { if (identity)
    try {
        localStorage.setItem(prefix + identity, JSON.stringify({ queue, session, lastActive, install, rotatedAt: rotation }));
    }
    catch { /* Storage may be unavailable; in-memory retry remains. */ } }
let rotation = Date.now();
export function clearTelemetry() { identity = null; allowed = false; queue = []; lastActive = 0; session = crypto.randomUUID(); install = crypto.randomUUID(); for (let i = localStorage.length - 1; i >= 0; i--) {
    const key = localStorage.key(i);
    if (key?.startsWith(prefix))
        localStorage.removeItem(key);
} }
window.addEventListener('finsight:session-changed', clearTelemetry);
window.addEventListener('storage', event => { if (event.key === 'token') clearTelemetry(); });
let initialization: Promise<void> | null = null;
export async function initializeTelemetry() {
    let id: string | null = null;
    try {
        id = String(JSON.parse(localStorage.getItem('user') ?? '{}').id ?? '') || null;
    }
    catch { /* no session */ }
    if (!localStorage.getItem('token') || !id) {
        clearTelemetry();
        return;
    }
    if (identity === id)
        return initialization ?? undefined;
    identity = id;
    allowed = false;
    queue = [];
    session = crypto.randomUUID();
    lastActive = 0;
    install = crypto.randomUUID();
    rotation = Date.now();
    try {
        const saved = JSON.parse(localStorage.getItem(prefix + id) ?? 'null');
        if (saved && Array.isArray(saved.queue)) {
            queue = saved.queue.filter((e: Event) => Date.now() - Date.parse(e.client_occurred_at) < 86400000).slice(-100);
            session = saved.session;
            lastActive = saved.lastActive;
            install = saved.install;
            rotation = saved.rotatedAt;
        }
    }
    catch { /* invalid cache discarded */ }
    if (Date.now() - rotation > 30 * 86400000) {
        rotation = Date.now();
        install = crypto.randomUUID();
    }
    initialization = (async () => { try {
        const p = await platformRequest<{
            enabled: boolean;
            available: boolean;
        }>('/analytics/preferences');
        if (identity === id) {
            allowed = p.enabled && p.available;
            if (!allowed) {
                queue = [];
                persist();
            }
        }
    }
    catch {
        allowed = false;
        if (identity === id) identity = null;
    } })();
    return initialization;
}
function enqueue(type: EventType, screen?: string, metadata?: Record<string, string>) { const version = import.meta.env.VITE_APP_VERSION as string | undefined; queue.push({ event_id: crypto.randomUUID(), schema_version: 1, event_type: type, session_id: session, install_id: install, client_platform: 'web', ...(version && /^[A-Za-z0-9._+-]{1,32}$/.test(version) ? { app_version: version } : {}), ...(screen && screens.includes(screen) ? { source_screen: screen } : {}), client_occurred_at: new Date().toISOString(), ...(metadata ? { metadata } : {}) }); queue = queue.slice(-100); persist(); }
export async function track(type: EventType, screen?: string, metadata?: Record<string, string>) {
    const token = localStorage.getItem('token');
    try { await initializeTelemetry(); } catch { return; }
    if (!allowed || !identity || token !== localStorage.getItem('token') || document.visibilityState !== 'visible') return;
    if (Date.now() - lastActive >= 30 * 60000) {
        session = crypto.randomUUID();
        enqueue('session_started', screen);
    }
    lastActive = Date.now();
    enqueue(type, screen, metadata);
    void flushTelemetry();
}
export function touchTelemetry() { if (allowed && document.visibilityState === 'visible') {
    if (Date.now() - lastActive >= 30 * 60000)
        track('app_foregrounded');
    else {
        lastActive = Date.now();
        persist();
    }
} }
export function foregroundHeartbeat(screen: string) {
    // Foreground-only heartbeat after recent interaction; never keeps an idle session alive.
    if (allowed && identity && document.visibilityState === 'visible' && Date.now() - lastActive < 60000) {
        enqueue('app_foregrounded', screen);
        void flushTelemetry();
    }
}
export async function flushTelemetry() { if (!allowed || !identity || sending || !navigator.onLine)
    return; sending = true; const owner = identity; try {
    queue = queue.filter(e => Date.now() - Date.parse(e.client_occurred_at) < 86400000);
    while (queue.length && identity === owner) {
        const batch = queue.slice(0, 20);
        await platformRequest('/analytics/events', { events: batch });
        if (identity !== owner)
            break;
        const ids = new Set(batch.map(e => e.event_id));
        queue = queue.filter(e => !ids.has(e.event_id));
        persist();
    }
}
catch { /* Stable UUIDs are retried while younger than 24 hours. */ }
finally {
    sending = false;
} }
export async function setTelemetryEnabled(value: boolean) { await platformRequest('/analytics/preferences', { enabled: value }); allowed = value; queue = []; persist(); }
export function screenForPath(path: string) { if (path === '/')
    return 'dashboard'; if (path.startsWith('/momentum/achievements'))
    return 'achievements'; const screen = path.split('/')[1]; return screens.includes(screen) ? screen : undefined; }
export async function beginCheckout(flowId = crypto.randomUUID()) {
    // Analytics must not hold checkout hostage to a slow collection endpoint.
    await Promise.race([track('checkout_started', 'paywall', { flow_id: flowId }), new Promise(resolve => window.setTimeout(resolve,250))]);
    try { if (identity && allowed) sessionStorage.setItem(`finsight:checkout:${identity}`,JSON.stringify({flowId,at:Date.now()})); } catch { /* Optional correlation storage. */ }
    try {
        return await platformRequest<{
            url: string;
        }>('/stripe/checkout', { flow_id: flowId });
    }
    catch (error) {
        track('purchase_failed', 'paywall', { flow_id: flowId, outcome: 'failed' });
        throw error;
    }
}

export async function observeCheckoutReturn() {
    const params = new URLSearchParams(window.location.search);
    if (window.location.pathname !== '/payments' || (!params.has('canceled') && !params.has('upgraded'))) return;
    try {
        await initializeTelemetry();
        if (!identity) return;
        const key = `finsight:checkout:${identity}`, raw = sessionStorage.getItem(key);
        sessionStorage.removeItem(key);
        if (!raw) return;
        const saved = JSON.parse(raw) as {flowId:string;at:number};
        if (Date.now()-saved.at>86400000 || !/^[0-9a-f-]{36}$/i.test(saved.flowId)) return;
        if (params.get('canceled') === '1') await track('purchase_failed','paywall',{flow_id:saved.flowId,outcome:'canceled'});
        // A browser success redirect is never proof of verified payment.
    } catch { /* Billing is independent of telemetry. */ }
}
