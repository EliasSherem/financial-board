import type { HTMLAttributes, ReactNode } from 'react';
import { cn } from './utils';

export type AppCardVariant = 'default' | 'elevated' | 'interactive' | 'subtle';
export type AppCardPadding = 'none' | 'sm' | 'md' | 'lg';

export interface AppCardProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  variant?: AppCardVariant;
  padding?: AppCardPadding;
}

const variantClasses: Record<AppCardVariant, string> = {
  default:
    'border-slate-200/80 bg-white shadow-sm dark:border-white/10 dark:bg-slate-900',
  elevated:
    'border-slate-200/80 bg-white shadow-[0_18px_45px_rgba(15,23,42,0.08)] dark:border-white/10 dark:bg-slate-900 dark:shadow-black/20',
  interactive:
    'border-slate-200/80 bg-white shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-blue-200 hover:shadow-[0_18px_45px_rgba(15,23,42,0.10)] dark:border-white/10 dark:bg-slate-900 dark:hover:border-blue-400/30 dark:hover:shadow-black/30',
  subtle:
    'border-slate-200/70 bg-slate-50/80 shadow-none dark:border-white/10 dark:bg-slate-900/70',
};

const paddingClasses: Record<AppCardPadding, string> = {
  none: 'p-0',
  sm: 'p-4',
  md: 'p-5 sm:p-6',
  lg: 'p-6 sm:p-8',
};

export function AppCard({
  children,
  className,
  variant = 'default',
  padding = 'md',
  ...props
}: AppCardProps) {
  return (
    <div
      className={cn(
        'rounded-2xl border',
        variantClasses[variant],
        paddingClasses[padding],
        className,
      )}
      {...props}
    >
      {children}
    </div>
  );
}
