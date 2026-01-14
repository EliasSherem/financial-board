import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { useEffect } from 'react';
import { ThemeProvider } from './contexts/ThemeContext';
import { I18nProvider } from './contexts/I18nContext';
import { api } from './utils/api';
import Layout from './components/Layout';
import ProtectedRoute from './components/ProtectedRoute';
import Login from './pages/Login';
import Signup from './pages/Signup';
import Dashboard from './pages/Dashboard';
import Analytics from './pages/Analytics';
import Projects from './pages/Projects';
import Transactions from './pages/Transactions';
import Invoices from './pages/Invoices';
import InvoiceDetail from './pages/InvoiceDetail';
import Payments from './pages/Payments';
import DeleteAccount from './pages/DeleteAccount';
import Accounts from './pages/Accounts';
import Investments from './pages/Investments';
import Terms from './pages/Terms';
import Privacy from './pages/Privacy';
import Landing from './pages/Landing';
import Guide from './pages/Guide';
import Onboarding from './pages/Onboarding';
import Categories from './pages/Categories';
import { AssistantChat } from './components/AssistantChat';

function App() {
  // On mount, refresh current user info so is_pro stays in sync
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return;
    api.getCurrentUser()
      .then(u => { if (u && (u as any).id) localStorage.setItem('user', JSON.stringify(u)); })
      .catch(() => {});
  }, []);
  return (
    <ThemeProvider>
      <I18nProvider>
        <Router>
          <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/signup" element={<Signup />} />
          <Route path="/terms" element={<Terms />} />
          <Route path="/privacy" element={<Privacy />} />
          <Route path="/landing" element={<Landing />} />
          <Route path="/guide" element={<Guide />} />
          <Route path="/delete-account" element={<DeleteAccount />} />
          <Route path="/onboarding" element={<ProtectedRoute><Onboarding /></ProtectedRoute>} />
          <Route path="/" element={
            <ProtectedRoute>
              <Layout />
            </ProtectedRoute>
          }>
            <Route index element={<Dashboard />} />
            <Route path="analytics" element={<Analytics />} />
            <Route path="projects" element={<Projects />} />
            <Route path="transactions" element={<Transactions />} />
            <Route path="invoices" element={<Invoices />} />
            <Route path="invoices/:id" element={<InvoiceDetail />} />
            <Route path="payments" element={<Payments />} />
            <Route path="categories" element={<Categories />} />
            <Route path="accounts" element={<Accounts />} />
            <Route path="investments" element={<Investments />} />
          </Route>
          </Routes>
          <AssistantChat />
        </Router>
      </I18nProvider>
    </ThemeProvider>
  );
}

export default App;
