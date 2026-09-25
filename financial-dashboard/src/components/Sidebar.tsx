import { NavLink } from 'react-router-dom';
import { useEffect, useState } from 'react';
import {
  Home,
  BarChart3,
  FolderOpen,
  ArrowUpDown,
  Receipt,
  CreditCard,
  Wallet,
  TrendingUp,
  Tags,
  Crown,
  Award,
  Shield,
  X
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import FinSightLogo from './FinSightLogo';
import ProUpgradeMini from './ProUpgradeMini';
import { useI18n } from '../contexts/I18nContext';
import { cn } from './ui';
import { platformRequest } from '../momentum/service';

type NavigationItem = {
  key: string;
  href: string;
  icon: LucideIcon;
  proRequired?: boolean;
};

const navigation: NavigationItem[] = [
  { key: 'sidebar.dashboard', href: '/', icon: Home },
  // Mark Pro-required sections so we can show a badge for free users
  { key: 'sidebar.analytics', href: '/analytics', icon: BarChart3, proRequired: true },
  { key: 'sidebar.projects', href: '/projects', icon: FolderOpen, proRequired: true },
  { key: 'sidebar.transactions', href: '/transactions', icon: ArrowUpDown },
  { key: 'sidebar.invoices', href: '/invoices', icon: Receipt, proRequired: true },
  { key: 'sidebar.payments', href: '/payments', icon: CreditCard },
  { key: 'sidebar.categories', href: '/categories', icon: Tags },
  { key: 'sidebar.accounts', href: '/accounts', icon: Wallet },
  { key: 'sidebar.investments', href: '/investments', icon: TrendingUp, proRequired: true },
  { key: 'sidebar.momentum', href: '/momentum', icon: Award },
];

interface SidebarProps {
  mobileOpen?: boolean;
  onMobileClose?: () => void;
}

export default function Sidebar({ mobileOpen = false, onMobileClose }: SidebarProps) {
  const [showUpgrade, setShowUpgrade] = useState(false);
  const [owner,setOwner] = useState(false);
  useEffect(()=>{let active=true;platformRequest<{allowed:boolean}>('/admin/access').then(value=>{if(active)setOwner(value.allowed);}).catch(()=>{});return()=>{active=false;};},[]);
  const { t } = useI18n();
  const user = (() => {
    try { return JSON.parse(localStorage.getItem('user') || '{}'); } catch { return {}; }
  })();
  const isProOrExempt = Boolean(user?.is_pro) || user?.id === 1 || user?.id === 3;

  useEffect(() => {
    if (!mobileOpen) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onMobileClose?.();
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [mobileOpen, onMobileClose]);

  const renderPanel = (isMobile = false) => (
    <div className="relative flex h-full w-72 max-w-[86vw] flex-col overflow-hidden border-r border-white/10 bg-slate-950 text-white shadow-2xl shadow-slate-950/30">
      <div
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(37,99,235,0.24),transparent_34%),linear-gradient(180deg,rgba(15,23,42,0.98),rgba(2,6,23,1))]"
        aria-hidden="true"
      />
      <div className="relative flex min-h-0 flex-1 flex-col p-4">
        <div className="mb-6 flex items-center justify-between px-1 pt-1">
          <div className="flex min-w-0 items-center">
            <FinSightLogo />
          </div>
          {isMobile && (
            <button
              type="button"
              onClick={onMobileClose}
              className="inline-flex h-10 w-10 items-center justify-center rounded-xl text-slate-300 transition hover:bg-white/10 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-400"
              aria-label="Close navigation"
            >
              <X className="h-5 w-5" aria-hidden="true" />
            </button>
          )}
        </div>
        
        <nav className="min-h-0 flex-1 space-y-1.5 overflow-y-auto pr-1" aria-label="Main navigation">
          {[...navigation,...(owner?[{key:'sidebar.admin',href:'/admin',icon:Shield}]:[])].map((item) => (
            <NavLink
              key={item.key}
              to={item.href}
              onClick={() => {
                if (isMobile) onMobileClose?.();
              }}
              className={({ isActive }) =>
                cn(
                  'group flex items-center gap-3 rounded-2xl px-3 py-2.5 text-sm font-medium transition duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-400',
                  isActive
                    ? 'bg-blue-500/15 text-white shadow-[0_14px_35px_rgba(37,99,235,0.22)] ring-1 ring-blue-400/30'
                    : 'text-slate-300 hover:bg-white/[0.07] hover:text-white'
                )
              }
            >
              {({ isActive }) => (
                <>
                  <span
                    className={cn(
                      'flex h-9 w-9 shrink-0 items-center justify-center rounded-xl transition',
                      isActive
                        ? 'bg-blue-500 text-white shadow-lg shadow-blue-500/25'
                        : 'bg-white/[0.06] text-slate-300 group-hover:bg-white/[0.10] group-hover:text-white'
                    )}
                  >
                    <item.icon className="h-5 w-5" aria-hidden="true" />
                  </span>
                  <span className="flex min-w-0 flex-1 items-center gap-2">
                    <span className="truncate">{t(item.key)}</span>
                    {!isProOrExempt && item.proRequired && (
                      <span
                        className="inline-flex shrink-0 items-center rounded-full border border-amber-300/30 bg-amber-300/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-200"
                        aria-label="Pro feature"
                      >
                        {t('common.pro')}
                      </span>
                    )}
                  </span>
                </>
              )}
            </NavLink>
          ))}
        </nav>

        {!isProOrExempt && (
          <div className="mt-5 rounded-2xl border border-amber-300/20 bg-amber-300/[0.08] p-4 shadow-inner shadow-amber-950/20">
            <div className="mb-3 flex items-center justify-center text-amber-100">
              <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-amber-300/15 text-amber-200">
                <Crown className="h-4 w-4" aria-hidden="true" />
              </span>
            </div>
            <a
              href="#"
              onClick={async (e) => {
                e.preventDefault();
                setShowUpgrade((v) => !v);
              }}
              className="block w-full rounded-xl bg-amber-400 px-3 py-2 text-center text-sm font-semibold text-slate-950 shadow-sm shadow-amber-400/20 transition hover:-translate-y-0.5 hover:bg-amber-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-200"
            >
              Upgrade to Pro
            </a>
            <p className="mt-3 text-xs leading-5 text-slate-300">Unlock analytics, projects & invoices — MX$200/mo</p>
            <ProUpgradeMini open={showUpgrade} onClose={() => setShowUpgrade(false)} />
          </div>
        )}
      </div>
    </div>
  );

  return (
    <>
      <aside className="fixed inset-y-0 left-0 z-30 hidden lg:block">
        {renderPanel()}
      </aside>

      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden" role="dialog" aria-modal="true">
          <div
            className="absolute inset-0 bg-slate-950/60 backdrop-blur-sm"
            onClick={onMobileClose}
            aria-hidden="true"
          />
          <aside className="relative h-full">{renderPanel(true)}</aside>
        </div>
      )}
    </>
  );
}
