import { useCallback, useEffect, useMemo, useState } from 'react';
import { Pencil, PlusCircle, RefreshCcw, Trash2 } from 'lucide-react';
import { useI18n } from '../contexts/I18nContext';
import { api } from '../utils/api';
import type { ExpenseCategory, ExpenseSubcategory } from '../types/expense';
import { CATEGORY_ICON_OPTIONS, iconForCategory } from '../utils/categoryIcons';

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
            className={`flex flex-col items-center rounded-md border px-2 py-3 text-xs transition ${
              isActive
                ? 'border-blue-500 bg-blue-50 text-blue-600 dark:border-blue-400 dark:bg-blue-950/40 dark:text-blue-200'
                : 'border-gray-200 text-gray-600 hover:border-blue-400 dark:border-gray-700 dark:text-gray-200 dark:hover:border-blue-400'
            }`}
          >
            <Icon className="mb-1 h-5 w-5" />
            <span className="text-center leading-tight">{option.label}</span>
          </button>
        );
      })}
    </div>
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">
            {t('categories.title')}
          </h1>
          <p className="text-gray-600 dark:text-gray-400">
            {t('categories.subtitle')}
          </p>
          <p className="mt-2 text-sm text-gray-500 dark:text-gray-500">
            {t('categories.totalSummary', { categories: categories.length, subcategories: totalSubcategories })}
          </p>
        </div>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => fetchCategories(false)}
            className="flex items-center rounded-md border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 transition hover:bg-gray-100 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-700"
            disabled={loading || refreshing}
          >
            <RefreshCcw className={`mr-2 h-4 w-4 ${refreshing ? 'animate-spin' : ''}`} />
            {t('categories.refresh')}
          </button>
          <button
            type="button"
            onClick={() => openCategoryModal()}
            className="flex items-center rounded-md bg-blue-600 px-3 py-2 text-sm font-medium text-white transition hover:bg-blue-700"
          >
            <PlusCircle className="mr-2 h-4 w-4" />
            {t('categories.addCategory')}
          </button>
        </div>
      </div>

      {feedback && (
        <div className="rounded-md border border-blue-200 bg-blue-50 px-4 py-2 text-sm text-blue-700 dark:border-blue-400/40 dark:bg-blue-950/40 dark:text-blue-200">
          {feedback}
        </div>
      )}

      {error && (
        <div className="rounded-md border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-700 dark:border-red-400/40 dark:bg-red-950/40 dark:text-red-200">
          {error}
        </div>
      )}

      {loading ? (
        <div className="flex h-48 items-center justify-center rounded-lg border border-dashed border-gray-300 dark:border-gray-700">
          <span className="text-sm text-gray-500 dark:text-gray-400">{t('common.loading')}</span>
        </div>
      ) : categories.length === 0 ? (
        <div className="rounded-lg border-2 border-dashed border-gray-300 p-8 text-center dark:border-gray-700">
          <p className="text-lg font-semibold text-gray-700 dark:text-gray-200">
            {t('categories.emptyState')}
          </p>
          <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
            {t('categories.emptyStateHint')}
          </p>
          <button
            type="button"
            onClick={() => openCategoryModal()}
            className="mt-4 inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
          >
            <PlusCircle className="mr-2 h-4 w-4" />
            {t('categories.addCategory')}
          </button>
        </div>
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
              <div
                key={category.id}
                className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800"
              >
                <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 items-center justify-center rounded-md bg-blue-50 text-blue-600 dark:bg-blue-900/40 dark:text-blue-200">
                      <Icon className="h-5 w-5" />
                    </div>
                    <div>
                      <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                        {category.name}
                      </p>
                      <p className="text-sm text-gray-500 dark:text-gray-400">{subLabel}</p>
                    </div>
                  </div>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => openSubcategoryModal(category)}
                      className="inline-flex items-center rounded-md border border-gray-300 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
                    >
                      <PlusCircle className="mr-2 h-4 w-4" />
                      {t('categories.addSubcategory')}
                    </button>
                    <button
                      type="button"
                      onClick={() => openCategoryModal(category)}
                      className="inline-flex items-center rounded-md border border-gray-300 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
                    >
                      <Pencil className="mr-2 h-4 w-4" />
                      {t('categories.editCategory')}
                    </button>
                    <button
                      type="button"
                      onClick={() => deleteCategory(category)}
                      className="inline-flex items-center rounded-md border border-red-200 px-3 py-2 text-sm text-red-600 hover:bg-red-50 dark:border-red-400/30 dark:text-red-300 dark:hover:bg-red-900/40"
                    >
                      <Trash2 className="mr-2 h-4 w-4" />
                      {t('categories.delete')}
                    </button>
                  </div>
                </div>

                <div className="mt-4 border-t border-gray-200 pt-4 dark:border-gray-700">
                  {category.subcategories.length === 0 ? (
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      {t('categories.subcategory.noneLong')}
                    </p>
                  ) : (
                    <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
                      {category.subcategories.map((subcategory) => {
                        const SubIcon = iconForCategory(subcategory.icon ?? category.icon);
                        return (
                          <div
                            key={subcategory.id}
                            className="flex items-center justify-between rounded-md border border-gray-200 px-3 py-2 dark:border-gray-700"
                          >
                            <div className="flex items-center gap-2">
                              <div className="flex h-8 w-8 items-center justify-center rounded-md bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-100">
                                <SubIcon className="h-4 w-4" />
                              </div>
                              <span className="text-sm font-medium text-gray-800 dark:text-gray-100">
                                {subcategory.name}
                              </span>
                            </div>
                            <div className="flex gap-1">
                              <button
                                type="button"
                                onClick={() => openSubcategoryModal(category, subcategory)}
                                className="rounded-md p-1 text-gray-500 hover:bg-gray-100 hover:text-gray-800 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:text-gray-100"
                                title={t('categories.editSubcategory')}
                              >
                                <Pencil className="h-4 w-4" />
                              </button>
                              <button
                                type="button"
                                onClick={() => deleteSubcategory(subcategory)}
                                className="rounded-md p-1 text-red-500 hover:bg-red-50 hover:text-red-700 dark:text-red-300 dark:hover:bg-red-900/40"
                                title={t('categories.deleteSubcategory')}
                              >
                                <Trash2 className="h-4 w-4" />
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {categoryModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4 py-6">
          <div className="w-full max-w-lg rounded-lg bg-white p-6 shadow-xl dark:bg-gray-900">
            <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">
              {editingCategory ? t('categories.editCategory') : t('categories.modal.createCategory')}
            </h2>
            <form onSubmit={handleCategorySubmit} className="mt-4 space-y-4">
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  {t('categories.form.name')}
                </label>
                <input
                  type="text"
                  value={categoryForm.name}
                  onChange={(event) => setCategoryForm({ ...categoryForm, name: event.target.value })}
                  required
                  autoFocus
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100"
                  placeholder={t('categories.form.namePlaceholder')}
                />
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  {t('categories.form.icon')}
                </label>
                {renderIconPicker(categoryForm.icon, (key) => setCategoryForm({ ...categoryForm, icon: key }))}
              </div>
              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={closeCategoryModal}
                  className="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800"
                >
                  {t('common.cancel')}
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-60"
                >
                  {saving ? t('categories.form.saving') : t('categories.form.save')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {subcategoryModalOpen && parentCategory && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4 py-6">
          <div className="w-full max-w-lg rounded-lg bg-white p-6 shadow-xl dark:bg-gray-900">
            <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">
              {editingSubcategory ? t('categories.editSubcategory') : t('categories.modal.createSubcategory')}
            </h2>
            <p className="text-sm text-gray-500 dark:text-gray-400">
              {t('categories.subcategory.forCategory', { name: parentCategory.name })}
            </p>
            <form onSubmit={handleSubcategorySubmit} className="mt-4 space-y-4">
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
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
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100"
                  placeholder={t('categories.form.subcategoryPlaceholder')}
                />
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  {t('categories.form.icon')}
                </label>
                {renderIconPicker(subcategoryForm.icon, (key) =>
                  setSubcategoryForm({ ...subcategoryForm, icon: key })
                )}
              </div>
              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={closeSubcategoryModal}
                  className="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800"
                >
                  {t('common.cancel')}
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-60"
                >
                  {saving ? t('categories.form.saving') : t('categories.form.save')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
