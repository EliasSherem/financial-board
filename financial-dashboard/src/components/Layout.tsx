import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import TopNavbar from './TopNavbar';
import UpdateProfileModal from './UpdateProfileModal';

export default function Layout() {
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      <Sidebar />
      <div className="pl-64 flex min-h-screen flex-col">
        <TopNavbar onUpdateProfile={() => setIsProfileModalOpen(true)} />
        <main className="flex-1 p-8 overflow-auto">
          <Outlet />
        </main>
      </div>
      <UpdateProfileModal 
        isOpen={isProfileModalOpen} 
        onClose={() => setIsProfileModalOpen(false)} 
      />
    </div>
  );
}
