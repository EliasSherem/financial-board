import { randomUUID } from 'node:crypto';
export const platforms = ['web', 'android', 'ios', 'unknown'] as const;
export type Platform = typeof platforms[number];
export const screens = ['dashboard', 'accounts', 'transactions', 'payments', 'projects', 'invoices', 'investments', 'categories', 'analytics', 'settings', 'momentum', 'achievements', 'ai', 'receipt', 'onboarding', 'paywall'] as const;
export const clientEvents = ['session_started', 'app_foregrounded', 'screen_view', 'feature_used', 'onboarding_step_completed', 'paywall_viewed', 'checkout_started', 'purchase_pending', 'purchase_failed', 'restore_completed'] as const;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export type AnalyticsInput = {
    event_id: string;
    schema_version: 1;
    event_type: string;
    session_id: string;
    install_id?: string;
    client_platform: Platform;
    app_version?: string;
    app_build?: string;
    source_screen?: string;
    client_occurred_at: string;
    metadata?: Record<string, string>;
};
export class AnalyticsValidationError extends Error {
}
function reject(): never { throw new AnalyticsValidationError('INVALID_ANALYTICS_EVENT'); }
export function platform(value: unknown): Platform { return platforms.includes(value as Platform) ? value as Platform : 'unknown'; }
export function validateEvent(input: unknown, now = new Date()): AnalyticsInput {
    if (!input || typeof input !== 'object' || Array.isArray(input))
        reject();
    const event = input as Record<string, unknown>;
    const allowed = ['event_id', 'schema_version', 'event_type', 'session_id', 'install_id', 'client_platform', 'app_version', 'app_build', 'source_screen', 'client_occurred_at', 'metadata'];
    if (Object.keys(event).some(key => !allowed.includes(key)) || event.schema_version !== 1)
        reject();
    if (typeof event.event_id !== 'string' || !uuidPattern.test(event.event_id) || typeof event.session_id !== 'string' || !uuidPattern.test(event.session_id))
        reject();
    if (event.install_id !== undefined && (typeof event.install_id !== 'string' || !uuidPattern.test(event.install_id)))
        reject();
    if (!clientEvents.includes(event.event_type as typeof clientEvents[number]) || !platforms.includes(event.client_platform as Platform))
        reject();
    for (const key of ['app_version', 'app_build'])
        if (event[key] !== undefined && (typeof event[key] !== 'string' || !/^[A-Za-z0-9._+-]{1,32}$/.test(event[key] as string)))
            reject();
    if (event.source_screen !== undefined && !screens.includes(event.source_screen as typeof screens[number]))
        reject();
    if (typeof event.client_occurred_at !== 'string')
        reject();
    const at = new Date(event.client_occurred_at as string).getTime();
    if (!Number.isFinite(at) || at > now.getTime() + 60000 || at < now.getTime() - 86400000)
        reject();
    if (event.metadata !== undefined) {
        if (!event.metadata || typeof event.metadata !== 'object' || Array.isArray(event.metadata))
            reject();
        const metadata = event.metadata as Record<string, unknown>;
        if (Object.keys(metadata).some(key => !['feature', 'step', 'flow_id', 'outcome'].includes(key)))
            reject();
        if (metadata.feature !== undefined && !screens.includes(metadata.feature as typeof screens[number]))
            reject();
        if (metadata.step !== undefined && !['account', 'transactions', 'categories', 'payment', 'insight', 'review'].includes(String(metadata.step)))
            reject();
        if (metadata.flow_id !== undefined && (typeof metadata.flow_id !== 'string' || !uuidPattern.test(metadata.flow_id)))
            reject();
        if (metadata.outcome !== undefined && !['canceled', 'network', 'pending', 'failed', 'success'].includes(String(metadata.outcome)))
            reject();
    }
    if (Buffer.byteLength(JSON.stringify(event)) > 1500)
        reject();
    return { ...(event as AnalyticsInput), event_id: event.event_id.toLowerCase(), session_id: event.session_id.toLowerCase(), client_occurred_at: new Date(at).toISOString() };
}
export function domainEventIdentity(eventId?: string) { return eventId && uuidPattern.test(eventId) ? eventId : randomUUID(); }
