export class AuthRequestError extends Error {
  readonly code: string;
  readonly reason?: string;
  constructor(code: string, reason?: string) { super(code); this.code = code; this.reason = reason; }
}

// Recovery credentials never follow the legacy ?api= override stored by the financial client.
export function authApiBase(): string {
  const configured = import.meta.env.VITE_API_URL as string | undefined;
  const base = configured?.trim() || (import.meta.env.DEV ? 'http://localhost:3001/api' : '/api');
  const parsed = new URL(base, window.location.origin);
  const local = import.meta.env.DEV && ['localhost', '127.0.0.1'].includes(parsed.hostname);
  if (parsed.username || parsed.password || parsed.search || parsed.hash || (parsed.protocol !== 'https:' && !local && parsed.origin !== window.location.origin)) throw new AuthRequestError('RECOVERY_UNAVAILABLE');
  return parsed.toString().replace(/\/$/, '');
}

export async function authRequest<T>(path: string, payload: Record<string, unknown>, authenticated = false): Promise<T> {
  const token = authenticated ? localStorage.getItem('token') : null;
  const response = await fetch(`${authApiBase()}/auth/${path}`, {
    method: 'POST', cache: 'no-store', referrerPolicy: 'no-referrer',
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(payload),
  });
  const data = await response.json().catch(() => ({})) as { code?: string; reason?: string };
  if (!response.ok) throw new AuthRequestError(data.code || 'RECOVERY_UNAVAILABLE', data.reason);
  return data as T;
}

export function clearSession() {
  try { sessionStorage.removeItem('finsight:momentum:v1'); } catch { /* Optional cache cannot prevent logout. */ }
  localStorage.removeItem('token');
  localStorage.removeItem('user');
  for (let i=localStorage.length-1;i>=0;i--) { const key=localStorage.key(i);if(key?.startsWith('finsight:telemetry:'))localStorage.removeItem(key); }
  for (let i=sessionStorage.length-1;i>=0;i--) { const key=sessionStorage.key(i);if(key?.startsWith('finsight:checkout:'))sessionStorage.removeItem(key); }
  window.dispatchEvent(new Event('finsight:session-changed'));
}

export function passwordIsValid(password: string): boolean {
  return password.length >= 6 && new TextEncoder().encode(password).length <= 72;
}
