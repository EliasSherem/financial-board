import { HttpError } from '../platform/http.js';
import { startOfLocalDay, validZone } from '../platform/periods.js';
export type Filters = {
    start: string;
    end: string;
    timezone: string;
    startAt: Date;
    endAt: Date;
    platform: string;
    provider: string;
    plan: string;
    status: string;
    version: string;
    cohort: string;
    environment: string;
    includeInternal: boolean;
    page: number;
    pageSize: number;
    query: string;
};
const DAY = 86400000;
function date(value: unknown, fallback: string): string {
    const v = value === undefined ? fallback : String(value);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(v) || !Number.isFinite(Date.parse(v)) || new Date(v).toISOString().slice(0, 10) !== v)
        throw new HttpError(400, 'INVALID_DATE');
    return v;
}
function choice(value: unknown, values: string[], fallback = 'all') {
    const v = value === undefined ? fallback : String(value);
    if (!values.includes(v))
        throw new HttpError(400, 'INVALID_FILTER');
    return v;
}
export function parseFilters(input: Record<string, unknown>, now = new Date()): Filters {
    const allowed = ['start', 'end', 'timezone', 'platform', 'provider', 'plan', 'status', 'version', 'cohort', 'environment', 'include_internal', 'page', 'page_size', 'q'];
    if (Object.keys(input).some(k => !allowed.includes(k)))
        throw new HttpError(400, 'UNKNOWN_FILTER');
    const timezone = validZone(input.timezone ?? 'UTC');
    if (!timezone)
        throw new HttpError(400, 'INVALID_TIMEZONE');
    const today = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
    const end = date(input.end, today), start = date(input.start, new Date(Date.parse(end) - 29 * DAY).toISOString().slice(0, 10));
    const span = Date.parse(end) - Date.parse(start);
    if (span < 0 || span > 365 * DAY || end > today)
        throw new HttpError(400, 'INVALID_RANGE');
    const integer = (value: unknown, fallback: number, max: number) => { const n = value === undefined ? fallback : Number(value); if (!Number.isInteger(n) || n < 1 || n > max)
        throw new HttpError(400, 'INVALID_PAGINATION'); return n; };
    const version = String(input.version ?? ''), plan = String(input.plan ?? ''), cohort = input.cohort ? date(input.cohort, today) : '', query = String(input.q ?? '').trim();
    if (!/^[A-Za-z0-9._+-]{0,32}$/.test(version) || !/^[A-Za-z0-9._:-]{0,100}$/.test(plan) || query.length > 100 || /[\x00-\x1f]/.test(query))
        throw new HttpError(400, 'INVALID_FILTER');
    if (input.include_internal !== undefined && !['true', 'false'].includes(String(input.include_internal)))
        throw new HttpError(400, 'INVALID_FILTER');
    return { start, end, timezone, startAt: startOfLocalDay(Date.parse(start), timezone), endAt: startOfLocalDay(Date.parse(end) + DAY, timezone), platform: choice(input.platform, ['all', 'web', 'android', 'ios', 'unknown']), provider: choice(input.provider, ['all', 'google', 'apple', 'stripe', 'unknown']), status: choice(input.status, ['all', 'pending', 'trial', 'active', 'cancel_at_period_end', 'grace', 'hold', 'paused', 'expired', 'revoked', 'refunded', 'unknown', 'legacy']), environment: choice(input.environment, ['production', 'test', 'internal', 'unknown', 'all'], 'production'), includeInternal: input.include_internal === 'true', plan, version, cohort, page: integer(input.page, 1, 1000000), pageSize: integer(input.page_size, 25, 100), query };
}
export function publicFilters(f: Filters) { return { start: f.start, end: f.end, timezone: f.timezone, platform: f.platform, provider: f.provider, plan: f.plan, status: f.status, version: f.version, cohort: f.cohort, environment: f.environment, include_internal: f.includeInternal }; }
export function csvCell(value: unknown): string {
    let text = value == null ? '' : String(value);
    if (/^[\s\x00-\x1f]*[=+@-]/.test(text) || /^[\t\r\n]/.test(text))
        text = "'" + text;
    return '"' + text.replace(/"/g, '""') + '"';
}
export function toCsv(rows: Record<string, unknown>[], fields: string[]) { return '\uFEFF' + [fields.map(csvCell).join(','), ...rows.map(row => fields.map(k => csvCell(row[k])).join(','))].join('\r\n'); }
