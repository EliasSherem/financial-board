export class PlatformError extends Error {
    readonly status: number;
    constructor(code: string, status: number) { super(code); this.status = status; }
}
type Options = {
    token: () => string | null;
    base: () => string;
    unauthorized: () => void;
    fetch: typeof globalThis.fetch;
    timeoutMs?: number;
};
/** Fence every response to the token actually sent, including late 401s. */
export function createPlatformRequest(options: Options) {
    return async function request<T>(path: string, payload?: unknown, signal?: AbortSignal): Promise<T> {
        const token = options.token();
        const controller = new AbortController();
        const abort = () => controller.abort(signal?.reason);
        if (signal?.aborted) abort();
        else signal?.addEventListener('abort', abort, { once: true });
        const timeout = setTimeout(() => controller.abort(new Error('REQUEST_TIMEOUT')), options.timeoutMs ?? (/^\/engagement\/(me|review)(\?|\/|$)/.test(path) ? 90_000 : 30_000));
        try {
            const response = await options.fetch(`${options.base()}${path}`, {
                method: payload === undefined ? 'GET' : 'POST', cache: 'no-store', referrerPolicy: 'no-referrer', signal: controller.signal,
                headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
                ...(payload === undefined ? {} : { body: JSON.stringify(payload) }),
            });
            const data = await response.json().catch(() => ({}));
            controller.signal.throwIfAborted();
            if (options.token() !== token) throw new PlatformError('SESSION_CHANGED', 409);
            if (response.status === 401 && token) options.unauthorized();
            if (!response.ok) throw new PlatformError(data.code || 'REQUEST_FAILED', response.status);
            return data as T;
        } finally {
            clearTimeout(timeout);
            signal?.removeEventListener('abort', abort);
        }
    };
}
