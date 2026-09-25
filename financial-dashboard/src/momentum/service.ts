import { authApiBase, clearSession } from '../utils/authApi';
import { createPlatformRequest } from './request';
export { PlatformError } from './request';
export const platformRequest = createPlatformRequest({
    token: () => localStorage.getItem('token'),
    base: authApiBase,
    fetch: (...args) => fetch(...args),
    unauthorized: () => { clearSession(); window.location.assign('/login'); },
});
export const eventPayload = (type: string) => ({ event_id: crypto.randomUUID(), type, occurred_at: new Date().toISOString() });
