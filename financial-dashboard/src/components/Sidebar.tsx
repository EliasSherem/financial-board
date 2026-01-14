import { NavLink } from 'react-router-dom';
import { useState } from 'react';
import {
  Home,
  BarChart3,
  FolderOpen,
  ArrowUpDown,
  Receipt,
  CreditCard,
  Wallet,
  TrendingUp,
  Tags
} from 'lucide-react';
import FinSightLogo from './FinSightLogo';
import ProUpgradeMini from './ProUpgradeMini';
import { useI18n } from '../contexts/I18nContext';

const navigation = [
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
] as const;

export default function Sidebar() {
  const [showUpgrade, setShowUpgrade] = useState(false);
  const { t } = useI18n();
  const user = (() => {
    try { return JSON.parse(localStorage.getItem('user') || '{}'); } catch { return {}; }
  })();
  const isProOrExempt = Boolean(user?.is_pro) || user?.id === 1 || user?.id === 3;
  return (
    <div className="fixed inset-y-0 left-0 z-30 bg-gray-900 dark:bg-gray-950 text-white w-64 p-4 flex flex-col overflow-y-auto">
      <div className="mb-8">
        <div className="flex items-center justify-center">
          <FinSightLogo />
        </div>
      </div>
      
      <nav className="space-y-2 flex-1">
        {navigation.map((item) => (
          <NavLink
            key={(item as any).key}
            to={item.href}
            className={({ isActive }) =>
              `flex items-center px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-blue-600 text-white'
                  : 'text-gray-300 hover:bg-gray-800 dark:hover:bg-gray-700 hover:text-white'
              }`
            }
          >
            <item.icon className="mr-3 h-5 w-5" />
            <span className="flex items-center gap-2">
              {t((item as any).key)}
              {!isProOrExempt && (item as any).proRequired && (
                <span
                  className="text-[10px] uppercase tracking-wide px-1.5 py-0.5 rounded-md bg-amber-500/20 text-amber-300 border border-amber-400/30"
                  aria-label="Pro feature"
                >
                  {t('common.pro')}
                </span>
              )}
            </span>
          </NavLink>
        ))}
      </nav>
      {!isProOrExempt && (
        <div className="mt-4">
          <a
            href="#"
            onClick={async (e) => {
              e.preventDefault();
              setShowUpgrade((v) => !v);
            }}
            className="block w-full text-center bg-amber-500 hover:bg-amber-600 text-white font-semibold py-2 rounded-lg"
          >
            Upgrade to Pro
          </a>
          <p className="text-xs text-gray-400 mt-2">Unlock analytics, projects & invoices — MX$200/mo</p>
          <ProUpgradeMini open={showUpgrade} onClose={() => setShowUpgrade(false)} />
        </div>
      )}
    </div>
  );
}
