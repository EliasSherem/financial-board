function currentLocale(): string {
  try {
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    return user?.language === 'es' ? 'es-ES' : 'en-GB';
  } catch {
    return 'en-GB';
  }
}

export function formatDate(value: string | Date | null | undefined, fallback: string = 'No date'):
  string {
  if (!value) return fallback;
  const d = typeof value === 'string' ? new Date(value) : value;
  if (!(d instanceof Date) || Number.isNaN(d.getTime())) return fallback;
  return d.toLocaleDateString(currentLocale()); // locale-specific
}
