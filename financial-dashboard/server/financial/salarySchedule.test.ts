import test from 'node:test';
import assert from 'node:assert/strict';
import { computeFirstSalaryDate, computeNextSalaryDate, formatDateOnly, parseSalaryDate, salaryScheduleReference } from './salarySchedule.js';

test('salary cursor retains its SQL calendar date west of UTC', () => {
  const previous = process.env.TZ;
  try {
    process.env.TZ = 'America/Los_Angeles';
    assert.equal(formatDateOnly(parseSalaryDate(new Date('2026-03-01T00:00:00Z'))), '2026-03-01');
    assert.equal(formatDateOnly(parseSalaryDate('2026-03-01')), '2026-03-01');
    assert.equal(formatDateOnly(computeNextSalaryDate({ schedule: 'Weekly' }, parseSalaryDate('2026-03-01')!)), '2026-03-08');
  } finally {
    if (previous === undefined) delete process.env.TZ; else process.env.TZ = previous;
  }
});

test('monthly and semimonthly salary dates retain month-end and leap-year rules', () => {
  assert.equal(formatDateOnly(computeNextSalaryDate({ schedule: 'Monthly', day: 31 }, new Date(2024, 0, 31))), '2024-02-29');
  assert.equal(formatDateOnly(computeNextSalaryDate({ schedule: 'Monthly', day: 31 }, new Date(2024, 1, 29))), '2024-03-31');
  assert.equal(formatDateOnly(computeNextSalaryDate({ schedule: 'SemiMonthly' }, new Date(2025, 1, 15))), '2025-02-28');
  assert.equal(formatDateOnly(computeNextSalaryDate({ schedule: 'SemiMonthly' }, new Date(2025, 1, 28))), '2025-03-15');
});

test('reactivation or rescheduling cannot rewind an already advanced cursor', () => {
  const reference = salaryScheduleReference('2026-09-30', new Date(2026, 8, 25));
  assert.equal(formatDateOnly(computeFirstSalaryDate({ schedule: 'Weekly', weekday: 5 }, reference)), '2026-10-02');
  assert.equal(formatDateOnly(salaryScheduleReference('2026-09-01', new Date(2026, 8, 25))), '2026-09-25');
  assert.equal(formatDateOnly(salaryScheduleReference(null, new Date(2026, 8, 25))), '2026-09-25');
});
