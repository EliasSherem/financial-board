/** Salary schedules use calendar dates, independently of the SQL driver's UTC Date objects. */
export function parseSalaryDate(value: string | Date | null | undefined): Date | null {
  if (!value) return null;
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return null;
    return new Date(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate());
  }
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  if (!match) return null;
  return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
}

export function startOfDay(d: Date) {
  const copy = new Date(d);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

export function formatDateOnly(d: Date | null) {
  if (!d) return null;
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function daysInMonth(year: number, monthIndex: number) {
  return new Date(year, monthIndex + 1, 0).getDate();
}

export function clampDay(year: number, monthIndex: number, desired: number) {
  const max = daysInMonth(year, monthIndex);
  return Math.max(1, Math.min(desired, max));
}

export function computeFirstSalaryDate(rule: any, reference: Date) {
  const today = startOfDay(reference);
  const schedule = rule?.schedule || 'SemiMonthly';

  switch (schedule) {
    case 'Weekly': {
      const rawWeekday = Number(rule?.weekday ?? 1);
      const target = rawWeekday === 7 ? 0 : Math.max(0, Math.min(6, rawWeekday));
      const diff = (target - today.getDay() + 7) % 7;
      const candidate = new Date(today);
      candidate.setDate(candidate.getDate() + diff);
      return candidate;
    }
    case 'Monthly': {
      const desired = clampDay(today.getFullYear(), today.getMonth(), Number(rule?.day ?? 1) || 1);
      let candidate = new Date(today.getFullYear(), today.getMonth(), desired);
      if (candidate < today) {
        const nextMonth = new Date(today.getFullYear(), today.getMonth() + 1, 1);
        const nextDesired = clampDay(nextMonth.getFullYear(), nextMonth.getMonth(), Number(rule?.day ?? 1) || 1);
        candidate = new Date(nextMonth.getFullYear(), nextMonth.getMonth(), nextDesired);
      }
      return candidate;
    }
    case 'SemiMonthly':
    default: {
      const first = new Date(today.getFullYear(), today.getMonth(), 15);
      const second = new Date(
        today.getFullYear(),
        today.getMonth(),
        Math.min(30, daysInMonth(today.getFullYear(), today.getMonth()))
      );
      if (today <= first) return first;
      if (today <= second) return second;
      const nextMonth = new Date(today.getFullYear(), today.getMonth() + 1, 1);
      return new Date(nextMonth.getFullYear(), nextMonth.getMonth(), 15);
    }
  }
}

export function computeNextSalaryDate(rule: any, previous: Date) {
  const schedule = rule?.schedule || 'SemiMonthly';
  const base = startOfDay(previous);
  switch (schedule) {
    case 'Weekly': {
      const next = new Date(base);
      next.setDate(next.getDate() + 7);
      return next;
    }
    case 'Monthly': {
      const nextMonth = new Date(base.getFullYear(), base.getMonth() + 1, 1);
      const desired = clampDay(
        nextMonth.getFullYear(),
        nextMonth.getMonth(),
        Number(rule?.day ?? base.getDate()) || 1
      );
      return new Date(nextMonth.getFullYear(), nextMonth.getMonth(), desired);
    }
    case 'SemiMonthly':
    default: {
      const day = base.getDate();
      const year = base.getFullYear();
      const month = base.getMonth();
      if (day <= 15) {
        const secondDay = Math.min(30, daysInMonth(year, month));
        return new Date(year, month, secondDay);
      }
      return new Date(year, month + 1, 15);
    }
  }
}

/** Editing/pausing must never rewind the first unpaid occurrence. */
export function salaryScheduleReference(cursor: string | Date | null, today: Date): Date {
  const previous = parseSalaryDate(cursor);
  const reference = startOfDay(today);
  return previous && previous > reference ? previous : reference;
}
