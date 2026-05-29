import { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { User, LogOut, Settings, Sun, Moon, ChevronDown, Trash2, PanelLeft } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';
import { useI18n } from '../contexts/I18nContext';
import { ActionButton, cn } from './ui';

interface TopNavbarProps {
  onUpdateProfile: () => void;
  onOpenSidebar?: () => void;
}

export default function TopNavbar({ onUpdateProfile, onOpenSidebar }: TopNavbarProps) {
  const navigate = useNavigate();
  const { theme, toggleTheme } = useTheme();
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const { t } = useI18n();
  
  const user = JSON.parse(localStorage.getItem('user') || '{}');

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsDropdownOpen(false);
      }
    }

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    navigate('/login');
  };

  const username = user.username || 'User';
  const userInitial = username.charAt(0).toUpperCase();

  return (
    <header className="sticky top-0 z-20 border-b border-slate-200/80 bg-white/85 px-4 py-3 shadow-sm shadow-slate-200/40 backdrop-blur-xl dark:border-white/10 dark:bg-slate-950/80 dark:shadow-black/20 sm:px-6 lg:px-8 xl:px-10">
      <div className="mx-auto flex max-w-[1600px] items-center justify-between gap-4">
        <div className="flex min-w-0 flex-1 items-center gap-3">
          <ActionButton
            type="button"
            variant="ghost"
            size="icon"
            onClick={onOpenSidebar}
            className="lg:hidden"
            aria-label="Open navigation"
          >
            <PanelLeft className="h-5 w-5" aria-hidden="true" />
          </ActionButton>
        </div>

        <div className="flex items-center gap-2 sm:gap-3">
          <ActionButton
            type="button"
            variant="outline"
            size="icon"
            onClick={toggleTheme}
            title={t('nav.switchTo', { mode: t(theme === 'light' ? 'nav.mode.dark' : 'nav.mode.light') })}
            aria-label={t('nav.switchTo', { mode: t(theme === 'light' ? 'nav.mode.dark' : 'nav.mode.light') })}
          >
            {theme === 'light' ? (
              <Moon className="h-5 w-5" aria-hidden="true" />
            ) : (
              <Sun className="h-5 w-5" aria-hidden="true" />
            )}
          </ActionButton>

          <div className="relative" ref={dropdownRef}>
            <button
              type="button"
              onClick={() => setIsDropdownOpen(!isDropdownOpen)}
              className="flex h-11 items-center gap-2 rounded-2xl border border-slate-200/80 bg-white px-2.5 pr-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:border-blue-200 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:border-white/10 dark:bg-slate-900 dark:hover:border-blue-400/30 dark:focus-visible:ring-offset-slate-950"
              aria-haspopup="menu"
              aria-expanded={isDropdownOpen}
            >
              <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-blue-600 text-sm font-bold text-white shadow-sm shadow-blue-600/25">
                {userInitial || <User className="h-5 w-5" aria-hidden="true" />}
              </div>
              <span className="hidden max-w-36 truncate text-sm font-semibold text-slate-700 dark:text-slate-100 sm:inline">
                {username}
              </span>
              <ChevronDown
                className={cn(
                  'h-4 w-4 text-slate-400 transition-transform',
                  isDropdownOpen && 'rotate-180'
                )}
                aria-hidden="true"
              />
            </button>

            {isDropdownOpen && (
              <div
                className="absolute right-0 z-50 mt-3 w-64 overflow-hidden rounded-2xl border border-slate-200/80 bg-white/95 py-2 shadow-[0_24px_70px_rgba(15,23,42,0.16)] backdrop-blur-xl dark:border-white/10 dark:bg-slate-900/95 dark:shadow-black/30"
                role="menu"
              >
                <div className="mx-2 mb-2 rounded-xl bg-slate-50 px-3 py-3 dark:bg-white/[0.04]">
                  <p className="truncate text-sm font-semibold text-slate-950 dark:text-white">
                    {username}
                  </p>
                  <p className="mt-0.5 truncate text-xs text-slate-500 dark:text-slate-400">
                    {user.email || 'user@example.com'}
                  </p>
                </div>
                
                <button
                  type="button"
                  onClick={() => {
                    setIsDropdownOpen(false);
                    onUpdateProfile();
                  }}
                  className="flex w-full items-center gap-3 px-4 py-2.5 text-sm font-medium text-slate-700 transition hover:bg-slate-100 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-blue-500 dark:text-slate-200 dark:hover:bg-white/10 dark:hover:text-white"
                  role="menuitem"
                >
                  <Settings className="h-4 w-4" />
                  {t('nav.updateProfile')}
                </button>
                
                <button
                  type="button"
                  onClick={handleLogout}
                  className="flex w-full items-center gap-3 px-4 py-2.5 text-sm font-medium text-red-600 transition hover:bg-red-50 hover:text-red-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-red-500 dark:text-red-300 dark:hover:bg-red-500/10 dark:hover:text-red-200"
                  role="menuitem"
                >
                  <LogOut className="h-4 w-4" />
                  {t('nav.logout')}
                </button>
                <button
                  type="button"
                  onClick={() => { setIsDropdownOpen(false); navigate('/delete-account'); }}
                  className="flex w-full items-center gap-3 px-4 py-2.5 text-sm font-medium text-red-700 transition hover:bg-red-50 hover:text-red-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-red-500 dark:text-red-300 dark:hover:bg-red-500/10 dark:hover:text-red-200"
                  role="menuitem"
                >
                  <Trash2 className="h-4 w-4" />
                  Delete Account
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}
