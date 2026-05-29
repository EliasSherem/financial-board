import type { ReactNode } from 'react';
import { AppCard } from './AppCard';
import { cn } from './utils';

export type StatCardTrendVariant = 'positive' | 'negative' | 'neutral';
export type StatCardAccent = 'blue' | 'green' | 'red' | 'amber' | 'purple' | 'neutral';

export interface StatCardProps {
  title: ReactNode;
  value: ReactNode;
  subtitle?: ReactNode;
  icon?: ReactNode;
  trend?: ReactNode;
  trendVariant?: StatCardTrendVariant;
  accent?: StatCardAccent;
  className?: string;
}

const accentClasses: Record<StatCardAccent, string> = {
  blue: 'bg-blue-50 text-blue-600 ring-blue-100 dark:bg-blue-500/10 dark:text-blue-300 dark:ring-blue-400/20',
  green:
    'bg-emerald-50 text-emerald-600 ring-emerald-100 dark:bg-emerald-500/10 dark:text-emerald-300 dark:ring-emerald-400/20',
  red: 'bg-red-50 text-red-600 ring-red-100 dark:bg-red-500/10 dark:text-red-300 dark:ring-red-400/20',
  amber:
    'bg-amber-50 text-amber-600 ring-amber-100 dark:bg-amber-500/10 dark:text-amber-300 dark:ring-amber-400/20',
  purple:
    'bg-violet-50 text-violet-600 ring-violet-100 dark:bg-violet-500/10 dark:text-violet-300 dark:ring-violet-400/20',
  neutral:
    'bg-slate-100 text-slate-600 ring-slate-200 dark:bg-white/10 dark:text-slate-300 dark:ring-white/10',
};

const trendClasses: Record<StatCardTrendVariant, string> = {
  positive: 'text-emerald-600 dark:text-emerald-300',
  negative: 'text-red-600 dark:text-red-300',
  neutral: 'text-slate-500 dark:text-slate-400',
};

export function StatCard({
  title,
  value,
  subtitle,
  icon,
  trend,
  trendVariant = 'neutral',
  accent = 'blue',
  className,
}: StatCardProps) {
  return (
    <AppCard variant="elevated" className={className}>
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <p className="max-w-full text-sm font-medium leading-5 text-slate-500 dark:text-slate-400">
            {title}
          </p>
        </div>
        {icon && (
          <div
            className={cn(
              'flex h-11 w-11 flex-none items-center justify-center rounded-xl ring-1',
              accentClasses[accent],
            )}
            aria-hidden="true"
          >
            {icon}
          </div>
        )}
      </div>
      <div className="mt-4 min-w-0">
        <div className="max-w-full overflow-hidden text-ellipsis whitespace-nowrap text-2xl font-bold leading-tight tracking-tight text-slate-950 dark:text-white xl:text-3xl">
          {value}
        </div>
      </div>
      {(subtitle || trend) && (
        <div className="mt-3 flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1 text-sm">
          {trend && (
            <span className={cn('min-w-0 break-words font-semibold', trendClasses[trendVariant])}>
              {trend}
            </span>
          )}
          {subtitle && (
            <span className="min-w-0 break-words text-slate-500 dark:text-slate-400">
              {subtitle}
            </span>
          )}
        </div>
      )}
    </AppCard>
  );
}
