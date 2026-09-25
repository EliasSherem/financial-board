import { db } from './db.js';
import { isFcmConfigured, type NotificationPayload } from './fcm.js';
import { deliverPushEvent } from './notifications/delivery.js';
import { isEmailConfigured, sendResendEmail } from './email.js';

const DAY_MS = 24 * 60 * 60 * 1000;
const PAYMENT_DUE_SOON_DAYS = 3;
const TYPE_PAYMENT_DUE_SOON = 'payment_due_soon';
const TYPE_EMAIL_PAYMENT_DUE_SOON = 'email_payment_due_soon';
const TYPE_PROJECT_OVER_BUDGET = 'project_over_budget';
const TYPE_SUBCATEGORY_OVER_BUDGET = 'subcategory_over_budget';

export type NotificationPorts = {
  query: typeof db.query;
  pushConfigured: () => boolean;
  emailConfigured: () => boolean;
  sendEmail: typeof sendResendEmail;
  deliverPush: typeof deliverPushEvent;
  now: () => Date;
  log: (code: string) => void;
};
const defaults: NotificationPorts = { query: db.query.bind(db), pushConfigured: isFcmConfigured, emailConfigured: isEmailConfigured, sendEmail: sendResendEmail, deliverPush: deliverPushEvent, now: () => new Date(), log: code => console.error('notification_delivery_failed', { code }) };

type PendingEvent = {
  type: string;
  entityId: string;
  eventKey: string;
  note: NotificationPayload;
  data?: Record<string, string>;
};

type PendingEmailEvent = {
  type: string;
  entityId: string;
  eventKey: string;
  subject: string;
  text: string;
  html: string;
};

function formatUtcYmd(date: Date): string {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  const d = String(date.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function getLocalDateBaseUtc(now: Date, offsetMin: number): number {
  const adjusted = new Date(now.getTime() + offsetMin * 60000);
  return Date.UTC(
    adjusted.getUTCFullYear(),
    adjusted.getUTCMonth(),
    adjusted.getUTCDate()
  );
}

function getLocalDateRange(now: Date, offsetMin: number, days: number) {
  const baseUtcMs = getLocalDateBaseUtc(now, offsetMin);
  const start = formatUtcYmd(new Date(baseUtcMs));
  const end = formatUtcYmd(new Date(baseUtcMs + (days - 1) * DAY_MS));
  return { start, end, baseUtcMs };
}

function getLocalMonthRange(now: Date, offsetMin: number) {
  const adjusted = new Date(now.getTime() + offsetMin * 60000);
  const year = adjusted.getUTCFullYear();
  const month = adjusted.getUTCMonth(); // 0-based
  const start = formatUtcYmd(new Date(Date.UTC(year, month, 1)));
  const end = formatUtcYmd(new Date(Date.UTC(year, month + 1, 0)));
  const key = `${year}-${String(month + 1).padStart(2, '0')}`;
  return { start, end, key };
}

function ymdToUtcMs(ymd: string): number {
  const [y, m, d] = ymd.split('-').map((v) => Number(v));
  return Date.UTC(y, m - 1, d);
}

function diffDays(baseUtcMs: number, ymd: string): number {
  return Math.round((ymdToUtcMs(ymd) - baseUtcMs) / DAY_MS);
}

function formatMoney(value: number): string {
  const amount = Number(value) || 0;
  return `$${amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function buildPaymentDueEmail(input: {
  greetName: string;
  paymentName: string;
  amount: string;
  when: string;
  eventKey: string;
}) {
  const safeName = escapeHtml(input.paymentName);
  const safeGreet = escapeHtml(input.greetName);
  const safeAmount = escapeHtml(input.amount);
  const safeWhen = escapeHtml(input.when);
  const safeDate = escapeHtml(input.eventKey);
  const subject = `Payment due ${input.when}`;
  const text =
    `Hi ${input.greetName},\n\n` +
    `Payment due ${input.when} (${input.eventKey}).\n` +
    `Payment: ${input.paymentName}\n` +
    `Amount: ${input.amount}\n\n` +
    `Open FinSight: https://finsight.com.mx\n\n` +
    `- FinSight`;
  const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>${subject}</title>
  </head>
  <body style="margin:0;background:#f4f5f7;font-family:Arial,Helvetica,sans-serif;color:#111827;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f5f7;padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="560" cellspacing="0" cellpadding="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 24px rgba(17,24,39,0.08);">
            <tr>
              <td style="padding:20px 24px;background:#0f172a;color:#ffffff;">
                <div style="font-size:18px;font-weight:700;letter-spacing:0.3px;">FinSight</div>
              </td>
            </tr>
            <tr>
              <td style="padding:24px;">
                <div style="font-size:20px;font-weight:700;margin-bottom:6px;">Payment due ${safeWhen}</div>
                <div style="color:#6b7280;font-size:13px;margin-bottom:20px;">Due date: ${safeDate}</div>
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border:1px solid #e5e7eb;border-radius:12px;">
                  <tr>
                    <td style="padding:16px 18px;">
                      <div style="font-size:12px;text-transform:uppercase;color:#6b7280;letter-spacing:0.6px;">Payment</div>
                      <div style="font-size:16px;font-weight:600;margin-top:4px;">${safeName}</div>
                    </td>
                    <td align="right" style="padding:16px 18px;">
                      <div style="font-size:12px;text-transform:uppercase;color:#6b7280;letter-spacing:0.6px;">Amount</div>
                      <div style="font-size:18px;font-weight:700;margin-top:4px;color:#111827;">${safeAmount}</div>
                    </td>
                  </tr>
                </table>
                <div style="margin-top:20px;font-size:14px;color:#374151;">Hi ${safeGreet}, your payment is due ${safeWhen}. Make sure you have enough funds to avoid late fees.</div>
                <div style="margin-top:22px;">
                  <a href="https://finsight.com.mx" style="display:inline-block;background:#2563eb;color:#ffffff;text-decoration:none;padding:10px 18px;border-radius:10px;font-size:14px;font-weight:600;">Open FinSight</a>
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 24px;background:#f9fafb;color:#6b7280;font-size:12px;">
                You received this email because you have payment reminders enabled.
              </td>
            </tr>
          </table>
          <div style="margin-top:14px;color:#9ca3af;font-size:11px;">FinSight • Notifications</div>
        </td>
      </tr>
    </table>
  </body>
</html>`;
  return { subject, text, html };
}

async function resolveOverBudgetEvents(ports: NotificationPorts, userId: number, activeProjectIds: string[]) {
  if (activeProjectIds.length === 0) {
    await ports.query(
      'UPDATE notification_events SET resolved_at = NOW() WHERE user_id = ? AND type = ? AND resolved_at IS NULL',
      [userId, TYPE_PROJECT_OVER_BUDGET]
    );
    return;
  }
  await ports.query(
    'UPDATE notification_events SET resolved_at = NOW() WHERE user_id = ? AND type = ? AND resolved_at IS NULL AND entity_id NOT IN (?)',
    [userId, TYPE_PROJECT_OVER_BUDGET, activeProjectIds]
  );
}

async function resolveSubcategoryBudgetEvents(ports: NotificationPorts, userId: number, overBudgetIds: string[], monthKey: string) {
  if (overBudgetIds.length === 0) {
    await ports.query(
      'UPDATE notification_events SET resolved_at = NOW() WHERE user_id = ? AND type = ? AND resolved_at IS NULL AND event_key = ?',
      [userId, TYPE_SUBCATEGORY_OVER_BUDGET, monthKey]
    );
    await ports.query(
      'UPDATE notification_events SET resolved_at = NOW() WHERE user_id = ? AND type = ? AND resolved_at IS NULL AND event_key <> ?',
      [userId, TYPE_SUBCATEGORY_OVER_BUDGET, monthKey]
    );
    return;
  }
  await ports.query(
    'UPDATE notification_events SET resolved_at = NOW() WHERE user_id = ? AND type = ? AND resolved_at IS NULL AND (event_key <> ? OR entity_id NOT IN (?))',
    [userId, TYPE_SUBCATEGORY_OVER_BUDGET, monthKey, overBudgetIds]
  );
}

async function claimNotificationEvent(
  ports: NotificationPorts,
  userId: number,
  type: string,
  entityId: string,
  eventKey: string
): Promise<boolean> {
  const [result] = await ports.query(
    'INSERT IGNORE INTO notification_events (user_id, type, entity_id, event_key) VALUES (?, ?, ?, ?)',
    [userId, type, entityId, eventKey]
  );
  return Number((result as any).affectedRows || 0) > 0;
}

async function releaseNotificationEvent(
  ports: NotificationPorts,
  userId: number,
  type: string,
  entityId: string,
  eventKey: string
) {
  await ports.query(
    'DELETE FROM notification_events WHERE user_id = ? AND type = ? AND entity_id = ? AND event_key = ?',
    [userId, type, entityId, eventKey]
  );
}

async function processUser(
  ports: NotificationPorts,
  userId: number,
  email: string | null,
  username: string | null,
  offsetMin: number,
  pushEnabled: boolean,
  emailEnabled: boolean
) {
  const now = ports.now();
  const { start, end, baseUtcMs } = getLocalDateRange(now, offsetMin, PAYMENT_DUE_SOON_DAYS);
  const monthRange = getLocalMonthRange(now, offsetMin);

  const pendingEvents: PendingEvent[] = [];
  const pendingEmailEvents: PendingEmailEvent[] = [];

  const [pRows] = await ports.query(
    `SELECT p.id, p.name, DATE_FORMAT(p.next_date, '%Y-%m-%d') AS next_date, p.amount, a.name AS account_name
     FROM payments p
     LEFT JOIN accounts a ON a.id = p.account_id AND a.user_id = p.user_id
     WHERE p.user_id = ? AND p.is_active = TRUE AND DATE(p.next_date) BETWEEN ? AND ?`,
    [userId, start, end]
  );
  const payments = pRows as Array<{
    id: number;
    name: string;
    next_date: string;
    amount: number;
    account_name: string | null;
  }>;
  if (payments.length > 0 && pushEnabled) {
    for (const p of payments) {
      const eventKey = p.next_date;

      const daysUntil = diffDays(baseUtcMs, eventKey);
      const when =
        daysUntil <= 0 ? 'today' : daysUntil === 1 ? 'tomorrow' : `in ${daysUntil} days`;
      const name = p.account_name ? `${p.name} (${p.account_name})` : p.name;
      pendingEvents.push({
        type: TYPE_PAYMENT_DUE_SOON,
        entityId: String(p.id),
        eventKey,
        note: {
          title: 'Payment due soon',
          body: `${name} is due ${when}`,
        },
        data: {
          target_type: 'payment',
          target_id: String(p.id),
          notification_type: TYPE_PAYMENT_DUE_SOON,
        },
      });
    }
  }

  if (payments.length > 0 && emailEnabled && email) {
    try {
    const ids = payments.map((p) => String(p.id));
    const keys = payments.map((p) => p.next_date);
    const [eventRows] = await ports.query(
      'SELECT entity_id, event_key FROM notification_events WHERE user_id = ? AND type = ? AND entity_id IN (?) AND event_key IN (?)',
      [userId, TYPE_EMAIL_PAYMENT_DUE_SOON, ids, keys]
    );
    const existing = new Set(
      (eventRows as any[]).map((r) => `${r.entity_id}|${r.event_key}`)
    );
    for (const p of payments) {
      const eventKey = p.next_date;
      const signature = `${p.id}|${eventKey}`;
      if (existing.has(signature)) continue;
      const daysUntil = diffDays(baseUtcMs, eventKey);
      const when =
        daysUntil <= 0 ? 'today' : daysUntil === 1 ? 'tomorrow' : `in ${daysUntil} days`;
      const name = p.account_name ? `${p.name} (${p.account_name})` : p.name;
      const greetName = username && username.trim().length > 0 ? username.trim() : 'there';
      const amount = formatMoney(p.amount);
      const emailPayload = buildPaymentDueEmail({
        greetName,
        paymentName: name,
        amount,
        when,
        eventKey,
      });
      pendingEmailEvents.push({
        type: TYPE_EMAIL_PAYMENT_DUE_SOON,
        entityId: String(p.id),
        eventKey,
        subject: emailPayload.subject,
        text: emailPayload.text,
        html: emailPayload.html,
      });
    }
    } catch { ports.log('EMAIL_EVIDENCE_FAILED'); }
  }

  if (pushEnabled) {
    try {
    const [projRows] = await ports.query(
      `SELECT id, name, budget, spent
       FROM projects
       WHERE user_id = ? AND status = 'Active' AND budget > 0 AND spent > budget`,
      [userId]
    );
    const projects = projRows as Array<{
      id: number;
      name: string;
      budget: number;
      spent: number;
    }>;
    const activeProjectIds = projects.map((p) => String(p.id));
    const [activeRows] = await ports.query(
      'SELECT entity_id,event_key FROM notification_events WHERE user_id = ? AND type = ? AND resolved_at IS NULL ORDER BY id DESC',
      [userId, TYPE_PROJECT_OVER_BUDGET]
    );
    const activeKeys = new Map<string,string>();
    for (const row of activeRows as any[]) if (!activeKeys.has(String(row.entity_id))) activeKeys.set(String(row.entity_id), String(row.event_key));
    for (const p of projects) {
      const overBy = Number(p.spent) - Number(p.budget);
      pendingEvents.push({
        type: TYPE_PROJECT_OVER_BUDGET,
        entityId: String(p.id),
        eventKey: activeKeys.get(String(p.id)) ?? start,
        note: {
          title: 'Project over budget',
          body: `${p.name} is over budget by ${overBy.toFixed(2)}`,
        },
        data: {
          target_type: 'project',
          target_id: String(p.id),
          notification_type: TYPE_PROJECT_OVER_BUDGET,
        },
      });
    }
    await resolveOverBudgetEvents(ports, userId, activeProjectIds);

    const [subRows] = await ports.query(
      `SELECT sc.id, sc.name, sc.budget, c.name AS category_name,
              COALESCE(SUM(ABS(t.amount)), 0) AS spent
         FROM expense_subcategories sc
         JOIN expense_categories c ON c.id = sc.category_id AND c.user_id = sc.user_id
         LEFT JOIN transactions t
           ON t.subcategory_id = sc.id
          AND t.user_id = sc.user_id
          AND t.type = 'Expense'
          AND t.date BETWEEN ? AND ?
        WHERE sc.user_id = ? AND sc.budget > 0
        GROUP BY sc.id`,
      [monthRange.start, monthRange.end, userId]
    );

    const overBudget = (subRows as any[]).filter((row) => Number(row.spent) > Number(row.budget));
    const overBudgetIds = overBudget.map((row) => String(row.id));

    for (const row of overBudget) {
      const overBy = Number(row.spent) - Number(row.budget);
      const label = row.category_name ? `${row.category_name} / ${row.name}` : row.name;
      pendingEvents.push({
        type: TYPE_SUBCATEGORY_OVER_BUDGET,
        entityId: String(row.id),
        eventKey: monthRange.key,
        note: {
          title: 'Subcategory over budget',
          body: `${label} is over budget by ${overBy.toFixed(2)}`,
        },
        data: {
          target_type: 'subcategory',
          target_id: String(row.id),
          notification_type: TYPE_SUBCATEGORY_OVER_BUDGET,
        },
      });
    }
    await resolveSubcategoryBudgetEvents(ports, userId, overBudgetIds, monthRange.key);
    } catch { ports.log('PUSH_EVIDENCE_FAILED'); }
  }

  if (emailEnabled && email && email.trim().toLowerCase() !== 'root@example.com' && pendingEmailEvents.length > 0) {
    for (const event of pendingEmailEvents) {
      try {
      const claimed = await claimNotificationEvent(
        ports, userId,
        event.type,
        event.entityId,
        event.eventKey
      );
      if (!claimed) continue;
      let sent = false;
      try { sent = await ports.sendEmail({
        to: email,
        subject: event.subject,
        text: event.text,
        html: event.html,
      }); } catch { ports.log('EMAIL_SEND_FAILED'); }
      if (!sent) {
        await releaseNotificationEvent(
          ports, userId,
          event.type,
          event.entityId,
          event.eventKey
        );
      }
      } catch { ports.log('EMAIL_EVENT_FAILED'); }
    }
  }

  if (pushEnabled && pendingEvents.length > 0) {
    for (const event of pendingEvents) {
      const expiresAt = event.type === TYPE_PAYMENT_DUE_SOON
        ? new Date(ymdToUtcMs(event.eventKey) + DAY_MS - offsetMin * 60000)
        : new Date(now.getTime() + DAY_MS);
      try {
        await ports.deliverPush({ userId, type: event.type, entityId: event.entityId, eventKey: event.eventKey, expiresAt }, event.note, event.data);
      } catch { ports.log('PUSH_EVENT_FAILED'); }
    }
  }
}

export async function runNotificationCron(overrides: Partial<NotificationPorts> = {}) {
  const ports = { ...defaults, ...overrides };
  const pushEnabled = ports.pushConfigured();
  const emailEnabled = ports.emailConfigured();
  if (!pushEnabled && !emailEnabled) {
    console.warn('Notification cron skipped: no delivery channels configured');
    return;
  }
  const [users] = await ports.query(
    'SELECT id, username, email, COALESCE(timezone_offset_min, 0) AS timezone_offset_min FROM users'
  );
  for (const u of users as any[]) {
    const offset = Number(u.timezone_offset_min) || 0;
    try { await processUser(
      ports, Number(u.id),
      u.email ?? null,
      u.username ?? null,
      offset,
      pushEnabled,
      emailEnabled
    ); } catch { ports.log('USER_PROCESSING_FAILED'); }
  }
}

export function startNotificationCron() {
  const enabled = String(process.env.NOTIFICATION_CRON_ENABLED || 'true').toLowerCase() !== 'false';
  if (!enabled) return;
  const intervalMinutes = Math.max(
    1,
    Number.parseInt(process.env.NOTIFICATION_CRON_INTERVAL_MINUTES || '5', 10)
  );
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      await runNotificationCron();
    } catch {
      console.error('Notification cron error', { code: 'CRON_FAILED' });
    } finally {
      running = false;
    }
  };
  tick();
  setInterval(tick, intervalMinutes * 60 * 1000);
}
