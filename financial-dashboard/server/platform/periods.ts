export type PeriodKind = 'week' | 'month';
export type Period = { key: string; kind: PeriodKind; timezone: string; offset: number; start: Date; end: Date };
const DAY = 86_400_000;
export function validZone(zone: unknown): string | null {
  if (typeof zone !== 'string' || zone.length > 64) return null;
  // Abbreviations emitted by old mobile clients are not a preferred IANA zone.
  if (zone !== 'UTC' && !zone.includes('/')) return null;
  try { new Intl.DateTimeFormat('en', { timeZone: zone }).format(); return zone; } catch { return null; }
}
export function localParts(now: Date, timezone: string, offset = 0) {
  if (timezone === 'offset') {
    const d = new Date(now.getTime() + offset * 60_000);
    return { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate(), hour: d.getUTCHours() };
  }
  const fields = Object.fromEntries(new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', hourCycle: 'h23' }).formatToParts(now).map(p => [p.type, p.value]));
  return { year: +fields.year, month: +fields.month, day: +fields.day, hour: +fields.hour };
}
function civilNumber(now: Date, zone: string, offset: number): number {
  const p = localParts(now, zone, offset);
  return Date.UTC(p.year, p.month - 1, p.day);
}
/** Earliest instant of a civil day. Binary search also handles midnight DST transitions. */
export function startOfLocalDay(civil: number, zone: string, offset = 0): Date {
  if (zone === 'offset') return new Date(civil - offset * 60_000);
  let low = civil - 2 * DAY, high = civil + 2 * DAY;
  while (high - low > 1) {
    const middle = Math.floor((low + high) / 2);
    if (civilNumber(new Date(middle), zone, offset) < civil) low = middle; else high = middle;
  }
  return new Date(high);
}
export function periodAt(now: Date, kind: PeriodKind, preferredZone?: unknown, fallbackOffset = 0): Period {
  const zone = validZone(preferredZone) ?? 'offset';
  const offset = Number.isFinite(fallbackOffset) ? Math.max(-720, Math.min(840, Math.trunc(fallbackOffset))) : 0;
  const day = civilNumber(now, zone, offset), date = new Date(day);
  let start: number, end: number, key: string;
  if (kind === 'month') {
    start = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1);
    end = Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 1);
    key = new Date(start).toISOString().slice(0, 7);
  } else {
    start = day - ((date.getUTCDay() + 6) % 7) * DAY;
    end = start + 7 * DAY;
    const thursday = new Date(start + 3 * DAY), year = thursday.getUTCFullYear();
    const week = Math.floor((start - (Date.UTC(year, 0, 4) - ((new Date(Date.UTC(year, 0, 4)).getUTCDay() + 6) % 7) * DAY)) / (7 * DAY)) + 1;
    key = `${year}-W${String(week).padStart(2, '0')}`;
  }
  return { key, kind, timezone: zone, offset, start: startOfLocalDay(start, zone, offset), end: startOfLocalDay(end, zone, offset) };
}
export function withinPeriod(occurred: Date, period: Pick<Period, 'start' | 'end'>, now = new Date()): boolean {
  return now < period.end && occurred >= period.start && occurred < period.end && occurred <= new Date(now.getTime() + 60_000);
}
