import { useEffect, useMemo, useRef, useState } from 'react';
import { ChevronDown, Search, X } from 'lucide-react';
import type { ExpenseCategory, ExpenseSubcategory, CategorySelectionValue } from '../types/expense';
import { iconForCategory } from '../utils/categoryIcons';

type CategorySelection = CategorySelectionValue | null;

interface CategoryPickerProps {
  categories: ExpenseCategory[];
  value: CategorySelection;
  onChange: (selection: CategorySelection) => void;
  placeholder?: string;
  disabled?: boolean;
  fallbackLabel?: string;
}

interface FilteredCategory {
  category: ExpenseCategory;
  matchesCategory: boolean;
  subcategories: ExpenseSubcategory[];
}

const buttonClasses =
  'w-full flex items-center justify-between gap-2 rounded-xl border border-slate-300 bg-white px-3 py-2 text-left text-slate-950 shadow-sm outline-none transition ' +
  'hover:border-blue-400 hover:bg-blue-50/40 focus:border-blue-400 focus:ring-4 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500 disabled:opacity-60 ' +
  'dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:hover:border-blue-400/40 dark:hover:bg-blue-500/10 dark:focus:border-blue-400 dark:focus:ring-blue-400/20 dark:disabled:bg-slate-900 dark:disabled:text-slate-500';

export function CategoryPicker({
  categories,
  value,
  onChange,
  placeholder = 'Select category',
  disabled = false,
  fallbackLabel,
}: CategoryPickerProps) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const containerRef = useRef<HTMLDivElement | null>(null);
  const searchRef = useRef<HTMLInputElement | null>(null);

  const selectedLabel =
    value?.subcategory?.name ??
    value?.category?.name ??
    (fallbackLabel && fallbackLabel.trim().length > 0 ? fallbackLabel : '');
  const selectedIconKey = value?.subcategory?.icon ?? value?.category?.icon;
  const SelectedIcon = iconForCategory(selectedIconKey);

  useEffect(() => {
    if (!open) return;
    const handleClick = (event: MouseEvent) => {
      if (!containerRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    };
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', handleClick);
    document.addEventListener('keydown', handleKey);
    return () => {
      document.removeEventListener('mousedown', handleClick);
      document.removeEventListener('keydown', handleKey);
    };
  }, [open]);

  useEffect(() => {
    if (open) {
      requestAnimationFrame(() => searchRef.current?.focus());
    } else {
      setQuery('');
    }
  }, [open]);

  const filteredCategories = useMemo<FilteredCategory[]>(() => {
    const trimmed = query.trim().toLowerCase();
    return categories
      .map<FilteredCategory | null>((category) => {
        const matchesCategory = trimmed.length === 0 || category.name.toLowerCase().includes(trimmed);
        const filteredSubs =
          trimmed.length === 0
            ? category.subcategories
            : category.subcategories.filter((sub) => sub.name.toLowerCase().includes(trimmed));
        if (matchesCategory || filteredSubs.length > 0) {
          return { category, matchesCategory, subcategories: filteredSubs };
        }
        return null;
      })
      .filter((item): item is FilteredCategory => Boolean(item));
  }, [categories, query]);

  const handleSelect = (category: ExpenseCategory, subcategory?: ExpenseSubcategory | null) => {
    onChange({
      category,
      subcategory: subcategory ?? null,
    });
    setOpen(false);
  };

  const handleClear = () => {
    onChange(null);
    setOpen(false);
  };

  return (
    <div className="relative" ref={containerRef}>
      <button
        type="button"
        className={buttonClasses}
        onClick={() => setOpen((prev) => !prev)}
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={open}
      >
        <span className="flex items-center gap-2 truncate">
          <SelectedIcon className="h-4 w-4 shrink-0 text-slate-500 dark:text-slate-300" />
          <span className="truncate text-sm">
            {selectedLabel || placeholder}
          </span>
        </span>
        <ChevronDown className="h-4 w-4 shrink-0 text-slate-500 dark:text-slate-300" />
      </button>

      {open && (
        <div className="absolute z-40 mt-2 w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-2xl shadow-slate-950/15 dark:border-white/10 dark:bg-slate-900 dark:shadow-black/40">
          <div className="flex items-center gap-2 border-b border-slate-200/80 bg-slate-50/80 p-2.5 dark:border-white/10 dark:bg-slate-950/60">
            <Search className="h-4 w-4 text-slate-500 dark:text-slate-300" />
            <input
              ref={searchRef}
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search..."
              className="min-w-0 flex-1 border-none bg-transparent text-sm text-slate-700 outline-none placeholder:text-slate-400 dark:text-slate-100 dark:placeholder:text-slate-500"
            />
            {(value?.category || value?.subcategory || selectedLabel || fallbackLabel) && (
              <button
                type="button"
                onClick={handleClear}
                className="rounded-lg px-2 py-1 text-xs font-semibold text-blue-600 transition hover:bg-blue-50 hover:text-blue-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 dark:text-blue-300 dark:hover:bg-blue-500/10"
              >
                Clear
              </button>
            )}
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="rounded-lg p-1 text-slate-500 transition hover:bg-slate-100 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 dark:text-slate-300 dark:hover:bg-white/10 dark:hover:text-white"
              aria-label="Close category picker"
            >
              <X className="h-4 w-4" />
            </button>
          </div>

          <div className="max-h-64 overflow-y-auto py-1">
            {filteredCategories.length === 0 ? (
              <div className="px-4 py-6 text-center text-sm text-slate-500 dark:text-slate-300">
                No categories found
              </div>
            ) : (
              filteredCategories.map(({ category, matchesCategory, subcategories }) => {
                const CategoryIcon = iconForCategory(category.icon);
                const isCategorySelected = Boolean(
                  value?.category?.id === category.id && !value?.subcategory
                );

                return (
                  <div key={category.id} className="px-2 py-1">
                    <button
                      type="button"
                      onClick={() => handleSelect(category, null)}
                      className={`flex w-full items-center gap-2 rounded-xl px-2.5 py-2 text-left transition ${
                        isCategorySelected
                          ? 'bg-blue-50 text-blue-700 ring-1 ring-blue-100 dark:bg-blue-500/10 dark:text-blue-200 dark:ring-blue-400/20'
                          : 'text-slate-700 hover:bg-slate-50 dark:text-slate-200 dark:hover:bg-white/[0.06]'
                      }`}
                    >
                      <CategoryIcon className="h-4 w-4 shrink-0 text-slate-500 dark:text-slate-300" />
                      <div className="flex flex-col">
                        <span className="text-sm font-medium">{category.name}</span>
                        <span className="text-xs text-slate-500 dark:text-slate-400">Category</span>
                      </div>
                    </button>

                    {category.subcategories.length > 0 && (
                      <div className="mt-1 space-y-1 pl-6">
                        {(matchesCategory ? category.subcategories : subcategories).map((sub) => {
                          const SubIcon = iconForCategory(sub.icon ?? category.icon);
                          const isSelected = value?.subcategory?.id === sub.id;
                          return (
                            <button
                              key={sub.id}
                              type="button"
                              onClick={() => handleSelect(category, sub)}
                              className={`flex w-full items-center gap-2 rounded-xl px-2.5 py-1.5 text-left text-sm transition ${
                                isSelected
                                  ? 'bg-blue-50 text-blue-700 ring-1 ring-blue-100 dark:bg-blue-500/10 dark:text-blue-200 dark:ring-blue-400/20'
                                  : 'text-slate-700 hover:bg-slate-50 dark:text-slate-200 dark:hover:bg-white/[0.06]'
                              }`}
                            >
                              <SubIcon className="h-4 w-4 shrink-0 text-slate-500 dark:text-slate-300" />
                              <span>{sub.name}</span>
                            </button>
                          );
                        })}
                        {matchesCategory && subcategories.length === 0 && (
                          <div className="px-2 py-1 text-xs text-slate-500 dark:text-slate-400">
                            No subcategories match this search
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}
    </div>
  );
}

export type { CategorySelection };
