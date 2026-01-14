import FinSightLogo from './FinSightLogo';
import { Link } from 'react-router-dom';
import React from 'react';

type Props = {
  title: string;
  lastUpdated?: string;
  children: React.ReactNode;
};

export default function LegalPage({ title, lastUpdated, children }: Props) {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-950">
      <div className="max-w-5xl mx-auto px-4 py-10">
        <div className="flex items-center justify-center mb-6">
          <div className="bg-blue-600 rounded-2xl p-2 shadow-md">
            <FinSightLogo />
          </div>
        </div>

        <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-xl ring-1 ring-black/5 dark:ring-white/10 overflow-hidden">
          <div className="border-b border-gray-200 dark:border-gray-700 px-6 sm:px-10 py-6">
            <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">{title}</h1>
            {lastUpdated && (
              <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">Last Updated: {lastUpdated}</p>
            )}
          </div>

          <div className="px-6 sm:px-10 py-8">
            <div className="prose prose-slate dark:prose-invert max-w-none">
              {children}
            </div>

            <div className="mt-10 flex items-center justify-between text-sm">
              <Link to="/" className="text-blue-600 hover:text-blue-700">Back to app</Link>
              <div className="text-gray-500 dark:text-gray-400">FinSight</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

