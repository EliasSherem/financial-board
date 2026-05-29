import type { ReactNode } from 'react';
import { AppCard } from './AppCard';
import { cn } from './utils';

export interface DataTableShellProps {
  children: ReactNode;
  className?: string;
  title?: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
}

export function DataTableShell({
  children,
  className,
  title,
  description,
  actions,
}: DataTableShellProps) {
  const hasHeader = title || description || actions;

  return (
    <AppCard padding="none" className={cn('overflow-hidden', className)}>
      {hasHeader && (
        <div className="flex flex-col gap-3 border-b border-slate-200/80 px-5 py-4 dark:border-white/10 sm:flex-row sm:items-center sm:justify-between">
          <div className="min-w-0">
            {title && (
              <h2 className="text-base font-semibold text-slate-950 dark:text-white">{title}</h2>
            )}
            {description && (
              <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">{description}</p>
            )}
          </div>
          {actions && <div className="flex shrink-0 flex-wrap items-center gap-2">{actions}</div>}
        </div>
      )}
      <div className="w-full overflow-x-auto">{children}</div>
    </AppCard>
  );
}
