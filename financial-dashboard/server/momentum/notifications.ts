import { db } from '../db.js';
import { enabled } from '../platform/http.js';
import { localParts } from '../platform/periods.js';
import { isFcmConfigured } from '../fcm.js';
import { deliverPushEvent, preparePushEvent, type PushEvent } from '../notifications/delivery.js';
import { hash, json, locked, rows, type Row } from './repository.js';

export function quiet(hour: number, start: number, end: number) { return start === end || (start < end ? hour >= start && hour < end : hour >= start || hour < end); }
export type MomentumNotificationPorts = {
  query: typeof db.query;
  enabled: typeof enabled;
  configured: typeof isFcmConfigured;
  locked: typeof locked;
  prepare: typeof preparePushEvent;
  deliver: typeof deliverPushEvent;
  now: () => Date;
  log: (code: string) => void;
};
const defaults: MomentumNotificationPorts = { query: db.query.bind(db), enabled, configured: isFcmConfigured, locked, prepare: preparePushEvent, deliver: deliverPushEvent, now: () => new Date(), log: code => console.error('momentum_push_failed', { code }) };

export async function runMomentumNotifications(overrides: Partial<MomentumNotificationPorts> = {}) {
  const ports = { ...defaults, ...overrides };
  if (!ports.enabled('MOMENTUM_ENABLED') || !ports.enabled('MOMENTUM_PUSH_ENABLED') || !ports.configured()) return;
  const [stored] = await ports.query("SELECT value_json FROM platform_settings WHERE setting_key='momentum_push_cursor'");
  const cursor = Number(json<Record<string, unknown>>((stored as Row[])[0]?.value_json, {}).id ?? 0);
  const [users] = await ports.query(`SELECT m.user_id,m.locale,m.quiet_start,m.quiet_end,p.* FROM user_momentum m JOIN momentum_periods p ON p.user_id=m.user_id
    WHERE m.notifications_enabled=1 AND p.kind='week' AND p.assigned_at IS NOT NULL AND p.ends_at>UTC_TIMESTAMP(3) AND p.starts_at<=UTC_TIMESTAMP(3) AND p.completed_at IS NULL AND m.user_id>? ORDER BY m.user_id LIMIT 500`, [cursor]);
  let last = 0;
  for (const user of users as Row[]) {
    const userId = Number(user.user_id); last = userId;
    try {
      const now = ports.now();
      const hour = localParts(now, String(user.timezone_name), Number(user.offset_min)).hour;
      if (quiet(hour, Number(user.quiet_start), Number(user.quiet_end))) continue;
      const age = now.getTime() - new Date(user.assigned_at as string).getTime(), timeLeft = new Date(user.ends_at as string).getTime() - now.getTime();
      const comeback = ((await ports.query("SELECT target_json FROM user_missions WHERE user_id=? AND period_key=? AND mission_key='comeback_clarity' AND status='active'", [userId, user.period_key]))[0] as Row[])[0];
      const episode = json<string[]>(comeback?.target_json, [])[0];
      const type = episode ? 'momentum_comeback' : age < 48 * 3600000 && !user.presented_at ? 'momentum_week_ready' : timeLeft < 48 * 3600000 && age > 48 * 3600000 ? 'momentum_week_reminder' : null;
      if (!type) continue;
      const eventKey = episode ? `comeback:${hash(episode).slice(0, 32)}` : String(user.period_key);
      const event: PushEvent = { userId, type, entityId: 'momentum', eventKey, expiresAt: new Date(user.ends_at as string) };
      const reservedEventId = await ports.locked(userId, async (conn, state) => {
        if (!state.notifications_enabled) return null;
        const current = (await rows(conn, "SELECT * FROM momentum_periods WHERE id=? AND user_id=? AND starts_at<=UTC_TIMESTAMP(3) AND ends_at>UTC_TIMESTAMP(3) AND completed_at IS NULL FOR UPDATE", [user.id, userId]))[0];
        if (!current) return null;
        const currentHour = localParts(ports.now(), String(current.timezone_name), Number(current.offset_min)).hour;
        if (quiet(currentHour, Number(state.quiet_start), Number(state.quiet_end))) return null;
        if (type === 'momentum_week_ready' && current.presented_at) return null;
        if (type === 'momentum_comeback' && !(await rows(conn, "SELECT 1 FROM user_missions WHERE user_id=? AND period_key=? AND mission_key='comeback_clarity' AND status='active'", [userId, user.period_key])).length) return null;
        // The same durable event can retry its rejected devices; all other events retain the original frequency cap.
        const recent = await rows(conn, "SELECT 1 FROM notification_events WHERE user_id=? AND type LIKE 'momentum_%' AND created_at>DATE_SUB(UTC_TIMESTAMP(),INTERVAL 48 HOUR) AND NOT(type=? AND entity_id='momentum' AND event_key=?) LIMIT 1", [userId, type, eventKey]);
        if (recent.length) return null;
        if (type === 'momentum_comeback' && (await rows(conn, "SELECT 1 FROM notification_events WHERE user_id=? AND type='momentum_comeback' AND created_at>DATE_SUB(UTC_TIMESTAMP(),INTERVAL 14 DAY) AND NOT(entity_id='momentum' AND event_key=?) LIMIT 1", [userId, eventKey])).length) return null;
        const unavailable = await rows(conn, "SELECT 1 FROM user_missions WHERE user_id=? AND period_key=? AND slot IS NOT NULL AND status='unavailable' LIMIT 1", [userId, user.period_key]);
        if (unavailable.length) return null;
        return ports.prepare(conn, event);
      });
      if (!reservedEventId) continue;
      const es = user.locale === 'es';
      await ports.deliver(event, { title: 'FinSight Momentum', body: type === 'momentum_comeback' ? (es ? 'Tu panorama está listo cuando quieras retomarlo.' : 'Your overview is here whenever you want to return.') : es ? (type === 'momentum_week_ready' ? 'Tu semana está lista. Elige un momento para revisarla.' : 'Puedes retomar tu revisión semanal cuando te venga bien.') : (type === 'momentum_week_ready' ? 'Your week is ready. Choose a moment to review it.' : 'You can return to your weekly review when it suits you.') }, { route: '/momentum', type }, reservedEventId);
    } catch { ports.log('EVENT_PROCESSING_FAILED'); }
  }
  await ports.query("INSERT INTO platform_settings(setting_key,value_json) VALUES ('momentum_push_cursor',JSON_OBJECT('id',?)) ON DUPLICATE KEY UPDATE value_json=VALUES(value_json)", [last]);
}
