import { useCallback, useEffect, useMemo, useState } from 'react';
import { Pencil, PlusCircle, RefreshCcw, Trash2 } from 'lucide-react';
import { useI18n } from '../contexts/I18nContext';
import { api } from '../utils/api';
import type { ExpenseCategory, ExpenseSubcategory } from '../types/expense';
import { CATEGORY_ICON_OPTIONS, iconForCategory } from '../utils/categoryIcons';
import { ActionButton, AppCard, EmptyState, LoadingState, PageHeader } from '../components/ui';

const DEFAULT_ICON = 'shopping_cart';

type FormState = {
  name: string;
  icon: string;
};

export default function Categories() {
  const { t } = useI18n();
  const [categories, setCategories] = useState<ExpenseCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<string | null>(null);

  const [categoryModalOpen, setCategoryModalOpen] = useState(false);
  const [categoryForm, setCategoryForm] = useState<FormState>({ name: '', icon: DEFAULT_ICON });
  const [editingCategory, setEditingCategory] = useState<ExpenseCategory | null>(null);

  const [subcategoryModalOpen, setSubcategoryModalOpen] = useState(false);
  const [subcategoryForm, setSubcategoryForm] = useState<FormState>({ name: '', icon: DEFAULT_ICON });
  const [parentCategory, setParentCategory] = useState<ExpenseCategory | null>(null);
  const [editingSubcategory, setEditingSubcategory] = useState<ExpenseSubcategory | null>(null);

  const [saving, setSaving] = useState(false);

  const fetchCategories = useCallback(
    async (initial = false) => {
      try {
        if (initial) setLoading(true);
        else setRefreshing(true);
        const data = await api.getExpenseCategories();
        const normalized = (data ?? []).map((cat: ExpenseCategory) => ({
          ...cat,
          subcategories: [...(cat.subcategories ?? [])].sort((a, b) => a.name.localeCompare(b.name)),
        }));
        normalized.sort((a, b) => a.name.localeCompare(b.name));
        setCategories(normalized);
        setError(null);
      } catch (err) {
        console.error('Failed to load categories', err);
        setError(t('common.failedLoad'));
      } finally {
        if (initial) setLoading(false);
        else setRefreshing(false);
      }
    },
    [t]
  );

  useEffect(() => {
    fetchCategories(true);
  }, [fetchCategories]);

  const openCategoryModal = (category?: ExpenseCategory) => {
    setEditingCategory(category ?? null);
    setCategoryForm({
      name: category?.name ?? '',
      icon: category?.icon ?? DEFAULT_ICON,
    });
    setCategoryModalOpen(true);
    setFeedback(null);
  };

  const closeCategoryModal = () => {
    setCategoryModalOpen(false);
    setEditingCategory(null);
    setCategoryForm({ name: '', icon: DEFAULT_ICON });
    setSaving(false);
  };

  const openSubcategoryModal = (parent: ExpenseCategory, subcategory?: ExpenseSubcategory) => {
    setParentCategory(parent);
    setEditingSubcategory(subcategory ?? null);
    setSubcategoryForm({
      name: subcategory?.name ?? '',
      icon: subcategory?.icon ?? parent.icon ?? DEFAULT_ICON,
    });
    setSubcategoryModalOpen(true);
    setFeedback(null);
  };

  const closeSubcategoryModal = () => {
    setSubcategoryModalOpen(false);
    setParentCategory(null);
    setEditingSubcategory(null);
    setSubcategoryForm({ name: '', icon: DEFAULT_ICON });
    setSaving(false);
  };

  const handleCategorySubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!categoryForm.name.trim()) return;
    setSaving(true);
    try {
      const payload = {
        name: categoryForm.name.trim(),
        icon: categoryForm.icon,
      };
      if (editingCategory) {
        await api.updateExpenseCategory(editingCategory.id, payload);
      } else {
        await api.createExpenseCategory(payload);
      }
      await fetchCategories(false);
      setFeedback(t('categories.feedback.saved'));
      closeCategoryModal();
    } catch (err) {
      console.error('Failed to save category', err);
      setFeedback(t('categories.feedback.error'));
      setSaving(false);
    }
  };

  const handleSubcategorySubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!subcategoryForm.name.trim() || !parentCategory) return;
    setSaving(true);
    try {
      const payload = {
        name: subcategoryForm.name.trim(),
        icon: subcategoryForm.icon,
        category_id: parentCategory.id,
      };
      if (editingSubcategory) {
        await api.updateExpenseSubcategory(editingSubcategory.id, payload);
      } else {
        await api.createExpenseSubcategory(payload);
      }
      await fetchCategories(false);
      setFeedback(t('categories.feedback.saved'));
      closeSubcategoryModal();
    } catch (err) {
      console.error('Failed to save subcategory', err);
      setFeedback(t('categories.feedback.error'));
      setSaving(false);
    }
  };

  const deleteCategory = async (category: ExpenseCategory) => {
    if (!window.confirm(t('categories.deleteCategoryConfirm'))) return;
    try {
      await api.deleteExpenseCategory(category.id);
      await fetchCategories(false);
      setFeedback(t('categories.feedback.deleted'));
    } catch (err) {
      console.error('Failed to delete category', err);
      setFeedback(t('categories.feedback.error'));
    }
  };

  const deleteSubcategory = async (subcategory: ExpenseSubcategory) => {
    if (!window.confirm(t('categories.deleteSubcategoryConfirm'))) return;
    try {
      await api.deleteExpenseSubcategory(subcategory.id);
      await fetchCategories(false);
      setFeedback(t('categories.feedback.deleted'));
    } catch (err) {
      console.error('Failed to delete subcategory', err);
      setFeedback(t('categories.feedback.error'));
    }
  };

  const totalSubcategories = useMemo(
    () => categories.reduce((acc, category) => acc + (category.subcategories?.length ?? 0), 0),
    [categories]
  );

  const fieldClassName = 'w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-blue-400 dark:focus:ring-blue-400/20';

  const renderIconPicker = (selected: string, onSelect: (key: string) => void) => (
    <div className="grid max-h-48 grid-cols-3 gap-2 overflow-y-auto md:grid-cols-4">
      {CATEGORY_ICON_OPTIONS.map((option) => {
        const Icon = option.Icon;
        const isActive = option.key === selected;
        return (
          <button
            key={option.key}
            type="button"
            onClick={() => onSelect(option.key)}
            className={`flex flex-col items-center rounded-xl border px-2 py-3 text-xs transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 ${
              isActive
                ? 'border-blue-500 bg-blue-50 text-blue-600 shadow-sm shadow-blue-500/10 dark:border-blue-400 dark:bg-blue-500/10 dark:text-blue-200'
                : 'border-slate-200 bg-white text-slate-600 hover:border-blue-400 hover:bg-blue-50/40 dark:border-white/10 dark:bg-slate-950 dark:text-slate-200 dark:hover:border-blue-400 dark:hover:bg-blue-500/10'
            }`}
          >
            <Icon className="mb-1 h-5 w-5" aria-hidden="true" />
            <span className="text-center leading-tight">{option.label}</span>
          </button>
        );
      })}
    </div>
  );

  return (
    <div className="space-y-8">
      <PageHeader
        title={t('categories.title')}
        subtitle={
          <>
            <span>{t('categories.subtitle')}</span>
            <span className="mt-2 block text-sm text-slate-500 dark:text-slate-500">
              {t('categories.totalSummary', { categories: categories.length, subcategories: totalSubcategories })}
            </span>
          </>
        }
        actions={
          <>
          <ActionButton
            type="button"
            variant="outline"
            onClick={() => fetchCategories(false)}
            disabled={loading || refreshing}
            iconLeft={<RefreshCcw className={`h-4 w-4 ${refreshing ? 'animate-spin' : ''}`} />}
          >
            {t('categories.refresh')}
          </ActionButton>
          <ActionButton
            type="button"
            onClick={() => openCategoryModal()}
            iconLeft={<PlusCircle className="h-4 w-4" />}
          >
            {t('categories.addCategory')}
          </ActionButton>
          </>
        }
      />

      {feedback && (
        <div className="rounded-2xl border border-blue-200 bg-blue-50 px-4 py-3 text-sm font-medium text-blue-700 dark:border-blue-400/30 dark:bg-blue-500/10 dark:text-blue-200">
          {feedback}
        </div>
      )}

      {error && (
        <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-medium text-red-700 dark:border-red-400/30 dark:bg-red-500/10 dark:text-red-200">
          {error}
        </div>
      )}

      {loading ? (
        <LoadingState className="min-h-56" label={t('common.loading')} />
      ) : categories.length === 0 ? (
        <AppCard variant="subtle">
          <EmptyState
            icon={<PlusCircle className="h-6 w-6" />}
            title={t('categories.emptyState')}
            description={t('categories.emptyStateHint')}
            action={
              <ActionButton
                type="button"
                onClick={() => openCategoryModal()}
                iconLeft={<PlusCircle className="h-4 w-4" />}
              >
                {t('categories.addCategory')}
              </ActionButton>
            }
          />
        </AppCard>
      ) : (
        <div className="space-y-4">
          {categories.map((category) => {
            const Icon = iconForCategory(category.icon);
            const subCount = category.subcategories?.length ?? 0;
            const subLabel =
              subCount === 0
                ? t('categories.subcategory.none')
                : subCount === 1
                ? t('categories.subcategory.single')
                : t('categories.subcategory.plural', { count: subCount });
            return (
              <AppCard
                key={category.id}
                variant="elevated"
              >
                <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                  <div className="flex min-w-0 items-center gap-3">
                    <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-blue-50 text-blue-600 ring-1 ring-blue-100 dark:bg-blue-500/10 dark:text-blue-200 dark:ring-blue-400/20">
                      <Icon className="h-5 w-5" aria-hidden="true" />
                    </div>
                    <div className="min-w-0">
                      <p className="truncate text-lg font-semibold text-slate-950 dark:text-white">
                        {category.name}
                      </p>
                      <p className="text-sm text-slate-500 dark:text-slate-400">{subLabel}</p>
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <ActionButton
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => openSubcategoryModal(category)}
                      iconLeft={<PlusCircle className="h-4 w-4" />}
                    >
                      {t('categories.addSubcategory')}
                    </ActionButton>
                    <ActionButton
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => openCategoryModal(category)}
                      iconLeft={<Pencil className="h-4 w-4" />}
                    >
                      {t('categories.editCategory')}
                    </ActionButton>
                    <ActionButton
                      type="button"
                      variant="danger"
                      size="sm"
                      onClick={() => deleteCategory(category)}
                      iconLeft={<Trash2 className="h-4 w-4" />}
                    >
                      {t('categories.delete')}
                    </ActionButton>
                  </div>
                </div>

                <div className="mt-5 border-t border-slate-200/80 pt-5 dark:border-white/10">
                  {category.subcategories.length === 0 ? (
                    <p className="rounded-2xl border border-dashed border-slate-200 bg-slate-50/70 px-4 py-5 text-sm text-slate-500 dark:border-white/10 dark:bg-white/[0.04] dark:text-slate-400">
                      {t('categories.subcategory.noneLong')}
                    </p>
                  ) : (
                    <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
                      {category.subcategories.map((subcategory) => {
                        const SubIcon = iconForCategory(subcategory.icon ?? category.icon);
                        return (
                          <div
                            key={subcategory.id}
                            className="flex min-w-0 items-center justify-between gap-3 rounded-2xl border border-slate-200/80 bg-slate-50/70 px-3 py-3 transition hover:border-blue-200 hover:bg-white dark:border-white/10 dark:bg-white/[0.04] dark:hover:border-blue-400/30 dark:hover:bg-white/[0.06]"
                          >
                            <div className="flex min-w-0 items-center gap-2">
                              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-white text-slate-600 ring-1 ring-slate-200 dark:bg-slate-950 dark:text-slate-200 dark:ring-white/10">
                                <SubIcon className="h-4 w-4" aria-hidden="true" />
                              </div>
                              <span className="min-w-0 break-words text-sm font-medium text-slate-800 dark:text-slate-100">
                                {subcategory.name}
                              </span>
                            </div>
                            <div className="flex shrink-0 gap-1">
                              <button
                                type="button"
                                onClick={() => openSubcategoryModal(category, subcategory)}
                                className="inline-flex h-8 w-8 items-center justify-center rounded-xl text-slate-500 transition hover:bg-slate-100 hover:text-slate-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 dark:text-slate-300 dark:hover:bg-white/10 dark:hover:text-white"
                                title={t('categories.editSubcategory')}
                              >
                                <Pencil className="h-4 w-4" aria-hidden="true" />
                              </button>
                              <button
                                type="button"
                                onClick={() => deleteSubcategory(subcategory)}
                                className="inline-flex h-8 w-8 items-center justify-center rounded-xl text-red-500 transition hover:bg-red-50 hover:text-red-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-500 dark:text-red-300 dark:hover:bg-red-500/10 dark:hover:text-red-200"
                                title={t('categories.deleteSubcategory')}
                              >
                                <Trash2 className="h-4 w-4" aria-hidden="true" />
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </AppCard>
            );
          })}
        </div>
      )}

      {categoryModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-lg overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-[0_30px_90px_rgba(15,23,42,0.24)] dark:border-white/10 dark:bg-slate-900 dark:shadow-black/40">
            <div className="border-b border-slate-200/80 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">
                {editingCategory ? t('categories.editCategory') : t('categories.modal.createCategory')}
              </h2>
            </div>
            <form onSubmit={handleCategorySubmit} className="max-h-[calc(100vh-11rem)] space-y-4 overflow-y-auto px-5 py-5">
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('categories.form.name')}
                </label>
                <input
                  type="text"
                  value={categoryForm.name}
                  onChange={(event) => setCategoryForm({ ...categoryForm, name: event.target.value })}
                  required
                  autoFocus
                  className={fieldClassName}
                  placeholder={t('categories.form.namePlaceholder')}
                />
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('categories.form.icon')}
                </label>
                {renderIconPicker(categoryForm.icon, (key) => setCategoryForm({ ...categoryForm, icon: key }))}
              </div>
              <div className="flex flex-col-reverse gap-2 border-t border-slate-200/80 pt-4 dark:border-white/10 sm:flex-row sm:justify-end">
                <ActionButton
                  type="button"
                  variant="outline"
                  onClick={closeCategoryModal}
                >
                  {t('common.cancel')}
                </ActionButton>
                <ActionButton
                  type="submit"
                  disabled={saving}
                  loading={saving}
                >
                  {saving ? t('categories.form.saving') : t('categories.form.save')}
                </ActionButton>
              </div>
            </form>
          </div>
        </div>
      )}

      {subcategoryModalOpen && parentCategory && (
        <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-lg overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-[0_30px_90px_rgba(15,23,42,0.24)] dark:border-white/10 dark:bg-slate-900 dark:shadow-black/40">
            <div className="border-b border-slate-200/80 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">
                {editingSubcategory ? t('categories.editSubcategory') : t('categories.modal.createSubcategory')}
              </h2>
              <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
                {t('categories.subcategory.forCategory', { name: parentCategory.name })}
              </p>
            </div>
            <form onSubmit={handleSubcategorySubmit} className="max-h-[calc(100vh-11rem)] space-y-4 overflow-y-auto px-5 py-5">
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('categories.form.name')}
                </label>
                <input
                  type="text"
                  value={subcategoryForm.name}
                  onChange={(event) =>
                    setSubcategoryForm({ ...subcategoryForm, name: event.target.value })
                  }
                  required
                  autoFocus
                  className={fieldClassName}
                  placeholder={t('categories.form.subcategoryPlaceholder')}
                />
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('categories.form.icon')}
                </label>
                {renderIconPicker(subcategoryForm.icon, (key) =>
                  setSubcategoryForm({ ...subcategoryForm, icon: key })
                )}
              </div>
              <div className="flex flex-col-reverse gap-2 border-t border-slate-200/80 pt-4 dark:border-white/10 sm:flex-row sm:justify-end">
                <ActionButton
                  type="button"
                  variant="outline"
                  onClick={closeSubcategoryModal}
                >
                  {t('common.cancel')}
                </ActionButton>
                <ActionButton
                  type="submit"
                  disabled={saving}
                  loading={saving}
                >
                  {saving ? t('categories.form.saving') : t('categories.form.save')}
                </ActionButton>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
