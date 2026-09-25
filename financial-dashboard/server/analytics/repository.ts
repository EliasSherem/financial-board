import type { PoolConnection, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { db } from '../db.js';
import { domainEventIdentity, platform, screens, type AnalyticsInput, type Platform } from './validation.js';
const sqlDate = (date: Date) => date.toISOString().slice(0, 23).replace('T', ' ');
export const analyticsEnvironment = () => process.env.ANALYTICS_ENVIRONMENT === 'test' || process.env.NODE_ENV === 'test' ? 'test' : process.env.ANALYTICS_ENVIRONMENT === 'internal' ? 'internal' : 'production';
export async function recordSignup(userId: number, observedPlatform: unknown) {
    const value = platform(observedPlatform);
    await db.query('INSERT IGNORE INTO analytics_user_settings (user_id, signup_platform, environment) VALUES (?, ?, ?)', [userId, value === 'unknown' ? null : value, analyticsEnvironment()]);
}
export async function ingestEvents(userId: number, events: AnalyticsInput[]): Promise<number> {
    const conn = await db.getConnection();
    try {
        await conn.beginTransaction();
        const [settings] = await conn.query<RowDataPacket[]>('SELECT enabled, is_internal FROM analytics_user_settings WHERE user_id = ?', [userId]);
        if (settings[0]?.enabled === 0) {
            await conn.commit();
            return 0;
        }
        const internal = Boolean(settings[0]?.is_internal);
        const environment = analyticsEnvironment();
        let accepted = 0;
        for (const event of events) {
            const [session] = await conn.query<RowDataPacket[]>('SELECT user_id, client_platform FROM analytics_sessions WHERE session_id = ? FOR UPDATE', [event.session_id]);
            if (session[0] && (Number(session[0].user_id) !== userId || session[0].client_platform !== event.client_platform))
                continue;
            const [result] = await conn.query<ResultSetHeader>(`INSERT IGNORE INTO analytics_events (event_id, schema_version, user_id, event_type, session_id, install_id, client_platform, app_version, app_build, source_screen, client_occurred_at, significant, environment, is_internal, metadata_json)
        VALUES (?,1,?,?,?,?,?,?,?,?,?,FALSE,?,?,?)`, [event.event_id, userId, event.event_type, event.session_id, event.install_id ?? null, event.client_platform, event.app_version ?? null, event.app_build ?? null, event.source_screen ?? null, sqlDate(new Date(event.client_occurred_at)), environment, internal, JSON.stringify(event.metadata ?? {})]);
            if (!result.affectedRows)
                continue;
            accepted += 1;
            // Only foreground behavior advances sessions; provider callbacks and background pushes do not.
            if (['session_started', 'app_foregrounded', 'screen_view', 'feature_used', 'onboarding_step_completed', 'paywall_viewed', 'checkout_started'].includes(event.event_type)) {
                const at = sqlDate(new Date(event.client_occurred_at));
                await conn.query(`INSERT INTO analytics_sessions (session_id,user_id,client_platform,started_at,last_seen_at,environment,is_internal) VALUES (?,?,?,?,?,?,?)
          ON DUPLICATE KEY UPDATE started_at=LEAST(started_at,VALUES(started_at)),last_seen_at=GREATEST(last_seen_at,VALUES(last_seen_at))`, [event.session_id, userId, event.client_platform, at, at, environment, internal]);
            }
        }
        await conn.commit();
        return accepted;
    }
    catch (error) {
        await conn.rollback();
        throw error;
    }
    finally {
        conn.release();
    }
}
export async function recordDomainAnalytics(input: {
    eventId?: string;
    userId: number;
    eventType: string;
    platform?: Platform;
    appVersion?: string;
    sourceScreen?: string;
    occurredAt?: Date;
}) {
    if (process.env.ADMIN_ANALYTICS_ENABLED?.toLowerCase() !== 'true')
        return;
    const [rows] = await db.query<RowDataPacket[]>('SELECT enabled, is_internal FROM analytics_user_settings WHERE user_id = ?', [input.userId]);
    if (rows[0]?.enabled === 0)
        return;
    // Callers are trusted domain handlers/outbox workers; never wire this function to a client event name.
    const at = input.occurredAt && Number.isFinite(input.occurredAt.getTime()) ? input.occurredAt : new Date();
    const eventType = input.eventType.replace(/[^a-z0-9_.]/gi, '').slice(0, 64);
    await db.query(`INSERT IGNORE INTO analytics_events (event_id,user_id,event_type,client_platform,app_version,source_screen,client_occurred_at,significant,environment,is_internal,metadata_json)
    VALUES (?,?,?,?,?,?,?,TRUE,?,?,JSON_OBJECT())`, [domainEventIdentity(input.eventId), input.userId, eventType, platform(input.platform), input.appVersion?.slice(0, 32) ?? null, screens.includes(input.sourceScreen as typeof screens[number]) ? input.sourceScreen : null, sqlDate(at), analyticsEnvironment(), Boolean(rows[0]?.is_internal)]);
}
export async function cleanupAnalytics() {
    await db.query('DELETE FROM analytics_events WHERE received_at < UTC_TIMESTAMP() - INTERVAL 400 DAY');
    await db.query('DELETE FROM analytics_sessions WHERE last_seen_at < UTC_TIMESTAMP() - INTERVAL 400 DAY');
    await db.query('DELETE FROM admin_audit WHERE created_at < UTC_TIMESTAMP() - INTERVAL 400 DAY');
}
/** Trusted provider state only. The caller may include this insert in its billing transaction. */
export async function recordBillingAnalytics(input: {
    eventId: string;
    userId: number;
    eventType: 'purchase_verified' | 'subscription_state_changed';
    provider: 'google' | 'apple' | 'stripe' | 'unknown';
    status?: string;
    flowId?: string;
}, connection?: Pick<PoolConnection, 'query'>) {
    if (process.env.ADMIN_ANALYTICS_ENABLED?.toLowerCase() !== 'true')
        return;
    const query = connection ?? db;
    const [rows] = await query.query<RowDataPacket[]>('SELECT enabled, is_internal FROM analytics_user_settings WHERE user_id = ?', [input.userId]);
    if (rows[0]?.enabled === 0)
        return;
    const metadata = { provider: input.provider, ...(input.status ? { status: input.status.slice(0, 32) } : {}), ...(input.flowId && /^[0-9a-f-]{36}$/i.test(input.flowId) ? { flow_id: input.flowId.toLowerCase() } : {}) };
    await query.query(`INSERT IGNORE INTO analytics_events (event_id,user_id,event_type,client_platform,client_occurred_at,significant,environment,is_internal,metadata_json)
    VALUES (?,?,?,'unknown',UTC_TIMESTAMP(3),FALSE,?,?,?)`, [domainEventIdentity(input.eventId), input.userId, input.eventType, analyticsEnvironment(), Boolean(rows[0]?.is_internal), JSON.stringify(metadata)]);
}
