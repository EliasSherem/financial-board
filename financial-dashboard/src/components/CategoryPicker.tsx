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
  'w-full flex items-center justify-between gap-2 border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 text-left shadow-sm transition ' +
  'hover:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:cursor-not-allowed disabled:opacity-60 ' +
  'dark:bg-gray-700 dark:text-gray-100';

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
          <SelectedIcon className="h-4 w-4 text-gray-500 dark:text-gray-300 shrink-0" />
          <span className="truncate text-sm">
            {selectedLabel || placeholder}
          </span>
        </span>
        <ChevronDown className="h-4 w-4 text-gray-500 dark:text-gray-300 shrink-0" />
      </button>

      {open && (
        <div className="absolute z-40 mt-2 w-full rounded-md border border-gray-200 bg-white shadow-lg dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center gap-2 border-b border-gray-200 p-2 dark:border-gray-700">
            <Search className="h-4 w-4 text-gray-500 dark:text-gray-300" />
            <input
              ref={searchRef}
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search..."
              className="flex-1 border-none bg-transparent text-sm text-gray-700 outline-none dark:text-gray-100"
            />
            {(value?.category || value?.subcategory || selectedLabel || fallbackLabel) && (
              <button
                type="button"
                onClick={handleClear}
                className="text-xs text-blue-600 hover:text-blue-500 dark:text-blue-400"
              >
                Clear
              </button>
            )}
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="rounded p-1 hover:bg-gray-100 dark:hover:bg-gray-700"
              aria-label="Close category picker"
            >
              <X className="h-4 w-4 text-gray-500 dark:text-gray-300" />
            </button>
          </div>

          <div className="max-h-64 overflow-y-auto py-1">
            {filteredCategories.length === 0 ? (
              <div className="px-4 py-6 text-center text-sm text-gray-500 dark:text-gray-300">
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
                      className={`flex w-full items-center gap-2 rounded-md px-2 py-2 text-left transition ${
                        isCategorySelected
                          ? 'bg-blue-50 text-blue-600 dark:bg-blue-900/40 dark:text-blue-200'
                          : 'hover:bg-gray-100 dark:hover:bg-gray-700'
                      }`}
                    >
                      <CategoryIcon className="h-4 w-4 text-gray-500 dark:text-gray-300" />
                      <div className="flex flex-col">
                        <span className="text-sm font-medium">{category.name}</span>
                        <span className="text-xs text-gray-500">Category</span>
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
                              className={`flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm transition ${
                                isSelected
                                  ? 'bg-blue-50 text-blue-600 dark:bg-blue-900/40 dark:text-blue-200'
                                  : 'hover:bg-gray-100 dark:hover:bg-gray-700'
                              }`}
                            >
                              <SubIcon className="h-4 w-4 text-gray-500 dark:text-gray-300" />
                              <span>{sub.name}</span>
                            </button>
                          );
                        })}
                        {matchesCategory && subcategories.length === 0 && (
                          <div className="px-2 py-1 text-xs text-gray-500 dark:text-gray-400">
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
