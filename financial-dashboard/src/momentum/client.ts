import type { Achievement, Mission, Momentum, MomentumResponse } from './types';

export const MOMENTUM_CACHE_KEY = 'finsight:momentum:v1';
export const MOMENTUM_FRESH_MS = 30_000;
export const MOMENTUM_CACHE_MS = 10 * 60_000;
export type MomentumSession = { userId: number; token: string; expiresAt?: number };
export type MomentumSnapshot = { state: Momentum | null; loading: boolean; error: boolean };
type Storage = Pick<globalThis.Storage, 'getItem' | 'setItem' | 'removeItem'>;
type Options = {
    session: () => MomentumSession | null;
    request: (signal: AbortSignal) => Promise<MomentumResponse>;
    seen: (key: string) => Promise<unknown>;
    storage: Storage;
    fingerprint: (token: string) => Promise<string>;
    now?: () => number;
    visible?: () => boolean;
    transition?: (before: Momentum | null, after: Momentum) => void;
};
const object = (v: unknown): v is Record<string, unknown> => v !== null && typeof v === 'object';
const number = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);
const text = (v: unknown) => object(v) && typeof v.en === 'string' && typeof v.es === 'string';
const nullableText = (v: unknown) => v === null || text(v);
function achievement(v: unknown): v is Achievement {
    return object(v) && typeof v.key === 'string' && text(v.title) && text(v.requirement) && number(v.progress) && number(v.target) && number(v.xp) && typeof v.available === 'boolean' && nullableText(v.reason) && (v.completed_at === null || typeof v.completed_at === 'string') && (v.seen_at === null || typeof v.seen_at === 'string');
}
function mission(v: unknown): v is Mission {
    return object(v) && typeof v.key === 'string' && text(v.title) && text(v.requirement) && typeof v.deeplink === 'string' && typeof v.period === 'string' && ['activation', 'feature', 'weekly', 'monthly', 'comeback'].includes(String(v.scope)) && ['active', 'completed', 'unavailable', 'replaced'].includes(String(v.status)) && [null, 'review', 'maintenance', 'goal'].includes(v.slot as string | null) && number(v.target) && number(v.progress) && number(v.nominal_xp) && number(v.granted_xp) && typeof v.review === 'boolean' && nullableText(v.reason);
}
/** Cache is optional and untrusted. Only the display DTO is accepted; it never grants progress. */
export function isMomentum(value: unknown): value is Momentum {
    if (!object(value) || value.enabled !== true || !Number.isSafeInteger(value.user_id) || !number(value.lifetime_xp) || !number(value.rhythm) || typeof value.generated_at !== 'string' || !Number.isFinite(Date.parse(value.generated_at))) return false;
    const { level, week, month, preferences, backfill, ai_credits: credits } = value;
    return object(level) && typeof level.key === 'string' && text(level.title) && number(level.minimum_xp) && (level.next_xp === null || number(level.next_xp)) &&
        object(week) && ['key', 'timezone', 'starts_at', 'ends_at'].every(k => typeof week[k] === 'string') && ['completed', 'total', 'bonus_xp', 'repeatable_xp', 'cap'].every(k => number(week[k])) && ['assigned', 'new_week', 'unavailable', 'grace_applied'].every(k => typeof week[k] === 'boolean') &&
        object(month) && typeof month.key === 'string' && number(month.repeatable_xp) && number(month.cap) &&
        object(preferences) && typeof preferences.notifications_enabled === 'boolean' && number(preferences.quiet_start) && number(preferences.quiet_end) && ['en', 'es'].includes(String(preferences.locale)) &&
        object(backfill) && typeof backfill.completed === 'boolean' && typeof backfill.unseen === 'boolean' && typeof value.coachmark_seen === 'boolean' &&
        object(credits) && typeof credits.available === 'boolean' && number(credits.balance) && (credits.expires_at === null || typeof credits.expires_at === 'string') &&
        Array.isArray(value.achievements) && value.achievements.length <= 200 && value.achievements.every(achievement) &&
        Array.isArray(value.missions) && value.missions.length <= 300 && value.missions.every(mission) &&
        Array.isArray(value.xp_history) && value.xp_history.length <= 100 && value.xp_history.every(row => object(row) && typeof row.period === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(row.period) && number(row.xp));
}

/** One owner, one GET in flight, and one follow-up after a burst of financial changes. */
export class MomentumClient {
    private readonly options: Options;
    private value: MomentumSnapshot = { state: null, loading: true, error: false };
    private readonly listeners = new Set<() => void>();
    private owner: MomentumSession | null = null;
    private generation = 0;
    private revision = 0;
    private postRevision = 0;
    private initialized = false;
    private hydrated: Promise<void> = Promise.resolve();
    private hash: string | null = null;
    private successfulAt = 0;
    private attemptedAt = -Infinity;
    private dirty = false;
    private pending: { controller: AbortController; promise: Promise<void> } | null = null;
    private mutationTimer: ReturnType<typeof setTimeout> | null = null;
    private readonly seen = new Map<string, string>();
    private readonly acknowledgements = new Map<string, Promise<void>>();
    constructor(options: Options) { this.options = options; }
    private now() { return this.options.now?.() ?? Date.now(); }
    readonly snapshot = () => this.value;
    readonly subscribe = (listener: () => void) => { this.listeners.add(listener); return () => { this.listeners.delete(listener); }; };
    private publish(value: MomentumSnapshot) { this.value = value; for (const listener of this.listeners) listener(); }
    private clearCache() { try { this.options.storage.removeItem(MOMENTUM_CACHE_KEY); } catch { /* Storage is optional. */ } }
    private sameSession(session: MomentumSession | null) { return session?.userId === this.owner?.userId && session?.token === this.owner?.token; }
    private current(generation: number) { return generation === this.generation && this.sameSession(this.options.session()); }
    private synchronize() {
        const session = this.options.session();
        if (this.initialized && this.sameSession(session)) return;
        const hadOwner = this.initialized;
        this.initialized = true;
        this.generation++; this.revision++;
        this.pending?.controller.abort(); this.pending = null;
        if (this.mutationTimer) clearTimeout(this.mutationTimer);
        this.mutationTimer = null;
        this.owner = session; this.hash = null; this.successfulAt = 0; this.attemptedAt = -Infinity; this.dirty = false;
        this.seen.clear(); this.acknowledgements.clear();
        if (hadOwner || !session) this.clearCache();
        this.publish({ state: null, loading: Boolean(session), error: false });
        this.hydrated = session ? this.restore(session, this.generation) : Promise.resolve();
    }
    private async restore(owner: MomentumSession, generation: number) {
        try {
            const hash = await this.options.fingerprint(owner.token);
            if (!this.current(generation)) return;
            this.hash = hash;
            if (this.value.state || this.successfulAt) { this.persist(); return; }
            const raw = this.options.storage.getItem(MOMENTUM_CACHE_KEY);
            if (!raw) return;
            if (raw.length > 256_000) { this.clearCache(); return; }
            const saved: unknown = JSON.parse(raw);
            const now = this.now();
            if (!object(saved) || saved.version !== 1 || saved.fingerprint !== hash || saved.userId !== owner.userId || !number(saved.savedAt) || saved.savedAt > now || now - saved.savedAt > MOMENTUM_CACHE_MS || (owner.expiresAt !== undefined && owner.expiresAt <= now) || !isMomentum(saved.state) || saved.state.user_id !== owner.userId) { this.clearCache(); return; }
            // Hydration never replaces a response that arrived during its storage read.
            if (this.value.state || this.successfulAt) return;
            this.successfulAt = saved.savedAt;
            this.publish({ state: saved.state, loading: false, error: false });
        } catch { if (this.current(generation)) this.clearCache(); }
    }
    private persist() {
        if (!this.hash || !this.owner || !this.value.state) return;
        try {
            const raw = JSON.stringify({ version: 1, userId: this.owner.userId, fingerprint: this.hash, savedAt: this.successfulAt, state: this.value.state });
            if (raw.length <= 256_000) this.options.storage.setItem(MOMENTUM_CACHE_KEY, raw);
        } catch { /* Cache failure must not block current server progress. */ }
    }
    private accept(response: MomentumResponse) {
        if (!this.owner || response.user_id !== this.owner.userId) throw new Error('MOMENTUM_IDENTITY');
        if (!response.enabled) { this.successfulAt = 0; this.clearCache(); this.publish({ state: null, loading: false, error: false }); return true; }
        if (!isMomentum(response)) throw new Error('MOMENTUM_RESPONSE');
        if (this.value.state && Date.parse(response.generated_at) < Date.parse(this.value.state.generated_at)) return false;
        const state = { ...response, achievements: response.achievements.map(item => item.completed_at && !item.seen_at && this.seen.has(item.key) ? { ...item, seen_at: this.seen.get(item.key)! } : item) };
        this.options.transition?.(this.value.state, state);
        this.successfulAt = this.now();
        this.publish({ state, loading: false, error: false });
        this.persist();
        return true;
    }
    /** Explicit user retries force a read; foreground/timer reads observe a short freshness window. */
    async refresh(force = false): Promise<void> {
        this.synchronize();
        const generation = this.generation;
        await this.hydrated;
        if (!this.current(generation) || !this.owner) return;
        if (this.pending) return this.pending.promise;
        const now = this.now();
        const ended = this.value.state && Date.parse(this.value.state.week.ends_at) <= now;
        if (!force && !this.dirty && !ended && ((this.successfulAt > 0 && now - this.successfulAt < MOMENTUM_FRESH_MS) || now - this.attemptedAt < 5_000)) return;
        if (this.mutationTimer) clearTimeout(this.mutationTimer);
        this.mutationTimer = null;
        this.dirty = false;
        this.attemptedAt = now;
        const revision = this.revision;
        const postRevision = this.postRevision;
        const controller = new AbortController();
        this.publish({ ...this.value, loading: !this.value.state });
        const request = { controller, promise: Promise.resolve() };
        this.pending = request;
        request.promise = (async () => {
            try {
                const response = await this.options.request(controller.signal);
                if (this.current(generation) && !controller.signal.aborted && revision === this.revision) {
                    // If timestamps tie, prefer a POST accepted after this GET began.
                    const newerPost = postRevision !== this.postRevision && response.enabled && this.value.state && Date.parse(response.generated_at) <= Date.parse(this.value.state.generated_at);
                    if (!newerPost) this.accept(response);
                }
            } catch {
                if (this.current(generation) && !controller.signal.aborted && revision === this.revision && postRevision === this.postRevision) this.publish({ ...this.value, error: true, loading: false });
            } finally {
                if (this.pending === request) {
                    this.pending = null;
                    if (this.current(generation)) {
                        this.publish({ ...this.value, loading: false });
                        if (this.dirty && (this.options.visible?.() ?? true)) await this.refresh(true);
                    }
                }
            }
        })();
        return request.promise;
    }
    /** Server POST responses are already authoritative; don't refetch or let an older GET undo them. */
    replace = (response: MomentumResponse) => {
        this.synchronize();
        if (!this.owner || response.user_id !== this.owner.userId) return;
        // A financial change during this POST still needs its queued refresh.
        if (this.accept(response)) {
            this.postRevision++;
            if (!response.enabled) this.revision++;
        }
    };
    invalidate = () => {
        this.synchronize();
        if (!this.owner) return;
        this.revision++; this.dirty = true; this.successfulAt = 0;
        if (this.mutationTimer) clearTimeout(this.mutationTimer);
        this.mutationTimer = setTimeout(() => {
            this.mutationTimer = null;
            if (this.options.visible?.() ?? true) void this.refresh(true);
        }, 450);
    };
    acknowledgeAchievement = (key: string): Promise<void> => {
        this.synchronize();
        if (!this.owner) return Promise.reject(new Error('MOMENTUM_SESSION'));
        const pending = this.acknowledgements.get(key);
        if (pending) return pending;
        const generation = this.generation;
        const request = (async () => {
            await this.options.seen(key);
            if (!this.current(generation)) return;
            const at = new Date(this.now()).toISOString();
            this.seen.set(key, at);
            const state = this.value.state;
            if (state) {
                // Only display acknowledgement changes after server success; XP/progress are untouched.
                this.publish({ ...this.value, state: { ...state, achievements: state.achievements.map(item => item.key === key && item.completed_at ? { ...item, seen_at: item.seen_at ?? at } : item) } });
                this.persist();
            }
        })().finally(() => { if (this.current(generation)) this.acknowledgements.delete(key); });
        this.acknowledgements.set(key, request);
        return request;
    };
    /** React StrictMode reattaches synchronously; real unmounts cancel work without a duplicate GET. */
    stopWhenUnused = () => {
        queueMicrotask(() => {
            if (this.listeners.size) return;
            this.pending?.controller.abort(); this.pending = null;
            if (this.mutationTimer) clearTimeout(this.mutationTimer);
            this.mutationTimer = null;
        });
    };
}
