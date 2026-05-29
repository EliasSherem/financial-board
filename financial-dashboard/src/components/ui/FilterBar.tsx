import type { HTMLAttributes, ReactNode } from 'react';
import { AppCard } from './AppCard';
import { cn } from './utils';

export interface FilterBarProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
}

export function FilterBar({ children, className, ...props }: FilterBarProps) {
  return (
    <AppCard variant="subtle" padding="sm" className={className} {...props}>
      <div className={cn('flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end')}>
        {children}
      </div>
    </AppCard>
  );
}
