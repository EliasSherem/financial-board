import { useState, useEffect } from 'react';
import { Plus, Edit2, Trash2 } from 'lucide-react';
import { api } from '../utils/api';
import ProUpgradeBanner from '../components/ProUpgradeBanner';
import { formatDate } from '../utils/date';
import { useI18n } from '../contexts/I18nContext';
import {
  ActionButton,
  DataTableShell,
  EmptyState,
  LoadingState,
  PageHeader,
  StatusBadge,
} from '../components/ui';

interface Project {
  id: number;
  name: string;
  description: string;
  budget: number;
  spent: number;
  status: 'Active' | 'On Hold' | 'Completed';
  start_date: string;
  end_date: string;
}

export default function Projects() {
  const { t, locale } = useI18n();
  const user = (() => { try { return JSON.parse(localStorage.getItem('user') || '{}'); } catch { return {}; } })();
  const isProOrExempt = Boolean(user?.is_pro) || user?.id === 1 || user?.id === 3;
  if (!isProOrExempt) {
    return <ProUpgradeBanner featureLabel="Projects" variant="page" />;
  }
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadProjects();
  }, []);

  const loadProjects = async () => {
    try {
      setLoading(true);
      const data = await api.getProjects();
      setProjects(data);
    } catch (error) {
      console.error('Failed to load projects:', error);
    } finally {
      setLoading(false);
    }
  };
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingProject, setEditingProject] = useState<Project | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    budget: 0,
    spent: 0,
    status: 'Active' as Project['status'],
    start_date: '',
    end_date: ''
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      if (editingProject) {
        await api.updateProject(editingProject.id, formData);
      } else {
        await api.createProject(formData);
      }
      await loadProjects();
      closeModal();
    } catch (error) {
      console.error('Failed to save project:', error);
    }
  };

  const openModal = (project?: Project) => {
    if (project) {
      setEditingProject(project);
      setFormData(project);
    } else {
      setEditingProject(null);
      setFormData({
        name: '',
        description: '',
        budget: 0,
        spent: 0,
        status: 'Active',
        start_date: '',
        end_date: ''
      });
    }
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setEditingProject(null);
  };

  const deleteProject = async (id: number) => {
    try {
      await api.deleteProject(id);
      await loadProjects();
    } catch (error) {
      console.error('Failed to delete project:', error);
    }
  };

  const getStatusVariant = (status: Project['status']) => {
    switch (status) {
      case 'Active': return 'active';
      case 'Completed': return 'completed';
      case 'On Hold': return 'warning';
    }
  };

  const fieldClassName = 'w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-slate-950 shadow-sm outline-none transition focus:border-blue-400 focus:ring-4 focus:ring-blue-100 dark:border-slate-700 dark:bg-slate-950 dark:text-white dark:focus:border-blue-400 dark:focus:ring-blue-400/20';

  if (loading && projects.length === 0) {
    return (
      <LoadingState
        className="min-h-[60vh]"
        label={`${t('common.loading')} ${t('projects.title').toLowerCase()}...`}
      />
    );
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title={t('projects.title')}
        subtitle={t('projects.subtitle')}
        actions={
          <ActionButton
            type="button"
            onClick={() => openModal()}
            iconLeft={<Plus className="h-4 w-4" />}
          >
            {t('projects.add')}
          </ActionButton>
        }
      />

      <DataTableShell>
        {projects.length === 0 ? (
          <EmptyState
            icon={<Plus className="h-6 w-6" />}
            title={t('projects.subtitle')}
            action={
              <ActionButton
                type="button"
                onClick={() => openModal()}
                iconLeft={<Plus className="h-4 w-4" />}
              >
                {t('projects.add')}
              </ActionButton>
            }
          />
        ) : (
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-slate-50 dark:bg-slate-950">
              <tr>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('projects.table.project')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('projects.table.budget')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('projects.table.spent')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('projects.table.status')}
                </th>
                <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('projects.table.period')}
                </th>
                <th className="px-6 py-4 text-right text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                  {t('projects.table.actions')}
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 bg-white dark:divide-white/10 dark:bg-slate-900">
              {projects.map((project) => (
                <tr key={project.id} className="transition hover:bg-blue-50/40 dark:hover:bg-blue-500/10">
                  <td className="px-6 py-5">
                    <div className="min-w-56">
                      <div className="font-semibold text-slate-950 dark:text-white">{project.name}</div>
                      <div className="mt-1 max-w-md text-sm text-slate-500 dark:text-slate-400">{project.description}</div>
                    </div>
                  </td>
                  <td className="whitespace-nowrap px-6 py-5 text-sm font-semibold text-slate-950 dark:text-white">
                    ${project.budget.toLocaleString(locale)}
                  </td>
                  <td className="whitespace-nowrap px-6 py-5 text-sm text-slate-950 dark:text-white">
                    <div className="min-w-36">
                      <div className="font-semibold">${project.spent.toLocaleString(locale)}</div>
                      <div className="mt-2 h-2 w-full rounded-full bg-slate-200 dark:bg-slate-800">
                        <div 
                          className="h-2 rounded-full bg-blue-600" 
                          style={{ width: `${Math.min((project.spent / project.budget) * 100, 100)}%` }}
                        />
                      </div>
                    </div>
                  </td>
                  <td className="whitespace-nowrap px-6 py-5">
                    <StatusBadge variant={getStatusVariant(project.status)}>
                      {project.status}
                    </StatusBadge>
                  </td>
                  <td className="whitespace-nowrap px-6 py-5 text-sm text-slate-500 dark:text-slate-400">
                    {formatDate(project.start_date)} {t('projects.to')} {formatDate(project.end_date)}
                  </td>
                  <td className="whitespace-nowrap px-6 py-5 text-right text-sm font-medium">
                    <div className="flex justify-end gap-2">
                      <button
                        type="button"
                        onClick={() => openModal(project)}
                        className="inline-flex h-9 w-9 items-center justify-center rounded-xl text-blue-600 transition hover:bg-blue-50 hover:text-blue-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 dark:text-blue-300 dark:hover:bg-blue-500/10 dark:hover:text-blue-200"
                        aria-label={t('projects.modal.edit')}
                      >
                        <Edit2 className="h-4 w-4" aria-hidden="true" />
                      </button>
                      <button
                        type="button"
                        onClick={() => deleteProject(project.id)}
                        className="inline-flex h-9 w-9 items-center justify-center rounded-xl text-red-600 transition hover:bg-red-50 hover:text-red-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-500 dark:text-red-300 dark:hover:bg-red-500/10 dark:hover:text-red-200"
                        aria-label={t('common.delete')}
                      >
                        <Trash2 className="h-4 w-4" aria-hidden="true" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </DataTableShell>

      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-slate-950/55 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-2xl border border-slate-200/80 bg-white shadow-[0_30px_90px_rgba(15,23,42,0.24)] dark:border-white/10 dark:bg-slate-900 dark:shadow-black/40">
            <div className="border-b border-slate-200/80 px-5 py-4 dark:border-white/10">
              <h2 className="text-lg font-semibold text-slate-950 dark:text-white">
                {editingProject ? t('projects.modal.edit') : t('projects.modal.new')}
              </h2>
            </div>
            
            <form onSubmit={handleSubmit} className="max-h-[calc(100vh-11rem)] space-y-4 overflow-y-auto px-5 py-5">
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('projects.form.name')}
                </label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({...formData, name: e.target.value})}
                  className={fieldClassName}
                />
              </div>
              
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('projects.form.description')}
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({...formData, description: e.target.value})}
                  className={fieldClassName}
                  rows={3}
                />
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                    {t('projects.form.budget')}
                  </label>
                  <input
                    type="number"
                    required
                    value={formData.budget}
                    onChange={(e) => setFormData({...formData, budget: Number(e.target.value)})}
                    className={fieldClassName}
                  />
                </div>
                
                <div>
                  <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                    {t('projects.form.spent')}
                  </label>
                  <input
                    type="number"
                    value={formData.spent}
                    onChange={(e) => setFormData({...formData, spent: Number(e.target.value)})}
                    className={fieldClassName}
                  />
                </div>
              </div>
              
              <div>
                <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                  {t('projects.form.status')}
                </label>
                <select
                  value={formData.status}
                  onChange={(e) => setFormData({...formData, status: e.target.value as Project['status']})}
                  className={fieldClassName}
                >
                  <option value="Active">Active</option>
                  <option value="On Hold">On Hold</option>
                  <option value="Completed">Completed</option>
                </select>
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                    {t('projects.form.startDate')}
                  </label>
                  <input
                    type="date"
                    required
                    value={formData.start_date}
                    onChange={(e) => setFormData({...formData, start_date: e.target.value})}
                    className={fieldClassName}
                  />
                </div>
                
                <div>
                  <label className="mb-1.5 block text-sm font-medium text-slate-700 dark:text-slate-300">
                    {t('projects.form.endDate')}
                  </label>
                  <input
                    type="date"
                    required
                    value={formData.end_date}
                    onChange={(e) => setFormData({...formData, end_date: e.target.value})}
                    className={fieldClassName}
                  />
                </div>
              </div>
              
              <div className="flex flex-col-reverse gap-2 border-t border-slate-200/80 pt-4 dark:border-white/10 sm:flex-row sm:justify-end">
                <ActionButton
                  type="button"
                  variant="outline"
                  onClick={closeModal}
                >
                  {t('common.cancel')}
                </ActionButton>
                <ActionButton
                  type="submit"
                >
                  {editingProject ? t('projects.form.update') : t('projects.form.create')} {t('projects.title')}
                </ActionButton>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
