import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import TopNavbar from './TopNavbar';
import UpdateProfileModal from './UpdateProfileModal';
import { ContextualMission } from '../momentum/ui';

export default function Layout() {
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);

  return (
    <div className="relative min-h-screen overflow-x-hidden bg-slate-100 text-slate-950 dark:bg-slate-950 dark:text-slate-100">
      <div
        className="pointer-events-none fixed inset-0 bg-[radial-gradient(circle_at_top_right,rgba(37,99,235,0.10),transparent_32%),linear-gradient(180deg,rgba(248,250,252,0.95),rgba(241,245,249,0.92))] dark:bg-[radial-gradient(circle_at_top_right,rgba(59,130,246,0.14),transparent_30%),linear-gradient(180deg,rgba(2,6,23,0.98),rgba(15,23,42,0.96))]"
        aria-hidden="true"
      />
      <Sidebar mobileOpen={isSidebarOpen} onMobileClose={() => setIsSidebarOpen(false)} />
      <div className="relative flex min-h-screen flex-col lg:pl-72">
        <TopNavbar
          onOpenSidebar={() => setIsSidebarOpen(true)}
          onUpdateProfile={() => setIsProfileModalOpen(true)}
        />
        <main className="flex-1 overflow-x-hidden px-4 py-6 sm:px-6 lg:px-8 xl:px-10">
          <div className="mx-auto w-full max-w-[1600px]">
            <ContextualMission />
            <Outlet />
          </div>
        </main>
      </div>
      <UpdateProfileModal 
        isOpen={isProfileModalOpen} 
        onClose={() => setIsProfileModalOpen(false)} 
      />
    </div>
  );
}
