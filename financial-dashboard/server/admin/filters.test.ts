import assert from 'node:assert/strict';
import test from 'node:test';
import { csvCell, parseFilters, toCsv } from './filters.js';
test('strict dates, ranges, filters and pagination reject injection/unknown values', () => {
    const now = new Date('2026-09-24T12:00:00Z');
    assert.equal(parseFilters({}, now).environment, 'production');
    for (const input of [{ start: '2026-02-30' }, { end: '2026-12-01' }, { start: '2020-01-01' }, { provider: "stripe' OR 1=1" }, { page: '1;DROP' }, { timezone: 'EST' }, { include_internal: 'yes' }, { role: 'owner' }])
        assert.throws(() => parseFilters(input, now));
});
test('report calendar boundaries respect DST and closed dates', () => {
    const f = parseFilters({ start: '2026-03-08', end: '2026-03-08', timezone: 'America/New_York' }, new Date('2026-09-24'));
    assert.equal(f.startAt.toISOString(), '2026-03-08T05:00:00.000Z');
    assert.equal(f.endAt.getTime() - f.startAt.getTime(), 23 * 3600000);
});
test('CSV quotes fields and prevents formula injection', () => {
    assert.equal(csvCell(' =HYPERLINK("bad")'), '"\' =HYPERLINK(""bad"")"');
    for (const v of ['+CMD', '-2+3', '@SUM(A1)', '\t=2'])
        assert.ok(csvCell(v).startsWith('"\''));
    assert.equal(toCsv([{ id: 1, email: 'a"b' }], ['id', 'email']), '\uFEFF"id","email"\r\n"1","a""b"');
});
