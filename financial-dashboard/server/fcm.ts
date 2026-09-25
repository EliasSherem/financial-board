import { createHash } from 'node:crypto';
import { google, type Auth } from 'googleapis';

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
export type NotificationPayload = { title: string; body: string };
export type FcmOutcome = {
  token: string;
  status: 'accepted' | 'validated' | 'retryable' | 'invalid' | 'rejected' | 'unknown';
  code: string;
  retryAfterMs?: number;
};
type Credentials = { client_email: string; private_key: string };
export type FcmConfiguration = { mode: 'service_account' | 'adc'; projectId: string; credentials?: Credentials };

/** Validation is local only: no metadata or credential endpoint is contacted here. */
export function fcmConfiguration(env: NodeJS.ProcessEnv = process.env): FcmConfiguration | null {
  const raw = env.FCM_SERVICE_ACCOUNT_JSON?.trim();
  const explicitProject = env.FCM_PROJECT_ID?.trim();
  if (raw) {
    try {
      const value = JSON.parse(raw) as Record<string, unknown>;
      if (!value || typeof value !== 'object' || typeof value.client_email !== 'string' || !value.client_email.trim() || typeof value.private_key !== 'string' || !value.private_key.includes('PRIVATE KEY')) return null;
      const projectId = explicitProject || (typeof value.project_id === 'string' ? value.project_id.trim() : '');
      if (!/^[a-z0-9][a-z0-9-]{3,62}$/.test(projectId)) return null;
      return { mode: 'service_account', projectId, credentials: { client_email: value.client_email.trim(), private_key: value.private_key.replace(/\\n/g, '\n') } };
    } catch { return null; }
  }
  const projectId = explicitProject || env.GOOGLE_CLOUD_PROJECT?.trim() || env.GCLOUD_PROJECT?.trim();
  return projectId && /^[a-z0-9][a-z0-9-]{3,62}$/.test(projectId) ? { mode: 'adc', projectId } : null;
}
export function isFcmConfigured(): boolean { return fcmConfiguration() !== null; }

let cachedAuth: { key: string; promise: Promise<Auth.AuthClient> } | null = null;
async function getAccessToken(): Promise<{ token: string; projectId: string }> {
  const config = fcmConfiguration();
  if (!config) throw new Error('FCM_CONFIGURATION');
  const key = createHash('sha256').update(JSON.stringify(config)).digest('hex');
  if (!cachedAuth || cachedAuth.key !== key) {
    const auth = new google.auth.GoogleAuth({ ...(config.credentials ? { credentials: config.credentials } : {}), scopes: [FCM_SCOPE] });
    const entry = { key, promise: auth.getClient() };
    cachedAuth = entry;
    void entry.promise.catch(() => { if (cachedAuth === entry) cachedAuth = null; });
  }
  const client = await cachedAuth.promise;
  const accessToken = await client.getAccessToken();
  const token = typeof accessToken === 'string' ? accessToken : accessToken?.token;
  if (!token) throw new Error('FCM_ACCESS_TOKEN');
  return { token, projectId: config.projectId };
}

type SenderOptions = {
  accessToken: () => Promise<{ token: string; projectId: string }>;
  fetch: typeof globalThis.fetch;
  now?: () => number;
  authTimeoutMs?: number;
  log?: (code: string, status?: number) => void;
};
function retryAfter(value: string | null, now: number) {
  if (!value) return undefined;
  const delay = /^\d+$/.test(value.trim()) ? Number(value) * 1000 : Date.parse(value) - now;
  return Number.isFinite(delay) ? Math.max(60_000, delay) : undefined;
}
/** Per-device outcomes never confuse provider acceptance with phone delivery. */
export function createFcmSender(options: SenderOptions) {
  return async (tokens: string[], note: NotificationPayload, data?: Record<string, string>, deliveryId?: string, validateOnly = false): Promise<FcmOutcome[]> => {
    const devices = [...new Set(tokens.map(token => token.trim()).filter(Boolean))];
    if (!devices.length) return [];
    let auth: { token: string; projectId: string };
    let authTimeout: ReturnType<typeof setTimeout>;
    try { auth = await Promise.race([options.accessToken(), new Promise<never>((_resolve, reject) => { authTimeout = setTimeout(() => reject(new Error('AUTH_TIMEOUT')), options.authTimeoutMs ?? 15_000); })]); }
    catch {
      options.log?.('AUTH_UNAVAILABLE');
      return devices.map(token => ({ token, status: 'retryable', code: 'AUTH_UNAVAILABLE', retryAfterMs: 60_000 }));
    } finally { clearTimeout(authTimeout!); }
    const collapseId = deliveryId ? createHash('sha256').update(deliveryId).digest('hex') : undefined;
    const results: FcmOutcome[] = [];
    for (const token of devices) {
      try {
        const response = await options.fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(auth.projectId)}/messages:send`, {
          method: 'POST', signal: AbortSignal.timeout(15_000),
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${auth.token}` },
          body: JSON.stringify({ ...(validateOnly ? { validate_only: true } : {}), message: {
            token, notification: { title: note.title, body: note.body }, ...(data && Object.keys(data).length ? { data } : {}),
            android: { priority: 'high', notification: { channel_id: 'finsight_default', click_action: 'FLUTTER_NOTIFICATION_CLICK', ...(collapseId ? { tag: collapseId } : {}) } },
            apns: { headers: { 'apns-push-type': 'alert', 'apns-priority': '10', ...(collapseId ? { 'apns-collapse-id': collapseId } : {}) }, payload: { aps: { sound: 'default' } } },
          } }),
        });
        const payload = await response.json().catch(() => ({})) as { name?: unknown; error?: { details?: { '@type'?: string; errorCode?: string }[] } };
        if (response.ok) {
          if (validateOnly) { results.push({ token, status: 'validated', code: 'VALIDATED' }); continue; }
          const accepted = typeof payload.name === 'string' && payload.name.startsWith('projects/');
          results.push({ token, status: accepted ? 'accepted' : 'unknown', code: accepted ? 'ACCEPTED' : 'INVALID_SUCCESS_RESPONSE' });
          continue;
        }
        const fcmCode = Array.isArray(payload.error?.details) ? payload.error.details.find(detail => detail['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError')?.errorCode : undefined;
        // Generic 400 and project/permission errors do not prove a device token expired.
        const status: FcmOutcome['status'] = fcmCode === 'UNREGISTERED' ? 'invalid' : [401, 429, 500, 502, 503, 504].includes(response.status) ? 'retryable' : 'rejected';
        const code = fcmCode === 'UNREGISTERED' ? 'UNREGISTERED' : fcmCode === 'SENDER_ID_MISMATCH' ? 'SENDER_ID_MISMATCH' : fcmCode === 'THIRD_PARTY_AUTH_ERROR' ? 'THIRD_PARTY_AUTH_ERROR' : `HTTP_${response.status}`;
        options.log?.(code, response.status);
        results.push({ token, status, code, ...(status === 'retryable' ? { retryAfterMs: retryAfter(response.headers.get('retry-after'), options.now?.() ?? Date.now()) ?? 60_000 } : {}) });
      } catch (error) {
        const code = (error as { cause?: { code?: string } })?.cause?.code;
        const notSent = code === 'ENOTFOUND' || code === 'ECONNREFUSED';
        options.log?.(notSent ? 'CONNECTION_UNAVAILABLE' : 'DELIVERY_UNCONFIRMED');
        results.push({ token, status: notSent ? 'retryable' : 'unknown', code: notSent ? 'CONNECTION_UNAVAILABLE' : 'DELIVERY_UNCONFIRMED', ...(notSent ? { retryAfterMs: 60_000 } : {}) });
      }
    }
    return results;
  };
}

export const sendFcmDetailed = createFcmSender({ accessToken: getAccessToken, fetch: (input, init) => fetch(input, init), log: (code, status) => console.error('fcm_delivery_failed', { code, status }) });
/** Compatibility for explicit push-now; this counts FCM acceptance, never device receipt. */
export async function sendFcmNotification(tokens: string[], note: NotificationPayload, data?: Record<string, string>): Promise<number> {
  return (await sendFcmDetailed(tokens, note, data)).filter(result => result.status === 'accepted').length;
}
