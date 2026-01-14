function normalizeApiCandidate(input: unknown): string | undefined {
  if (typeof input !== 'string') return undefined;
  const candidate = input.trim();
  if (!candidate) return undefined;

  if (/PASTE\s+CLOUD\s+RUN/i.test(candidate) || candidate.startsWith('<')) return undefined;
  if (/\s/.test(candidate)) return undefined;

  if (/^https?:\/\//i.test(candidate)) return candidate;
  if (candidate.startsWith('/')) return candidate;

  return 'https://' + candidate;
}

(function bootstrapApiBase() {
  try {
    const u = new URL(window.location.href);
    const api = u.searchParams.get('api');
    if (api) {
      const normalized = normalizeApiCandidate(api);
      if (normalized) {
        localStorage.setItem('api_base', normalized);
      } else {
        localStorage.removeItem('api_base');
      }
      u.searchParams.delete('api');
      window.history.replaceState({}, '', u.toString());
    }
  } catch {}
})();

export function resolveApi(): string {
  // Priority: explicit env > stored override (via ?api=...) > production same-origin '/api' > localhost
  const envUrl = normalizeApiCandidate((import.meta as any)?.env?.VITE_API_URL);
  if (envUrl) return envUrl;
  try {
    const stored = normalizeApiCandidate(localStorage.getItem('api_base'));
    if (stored) return stored;
    const host = window.location.hostname;
    if (host === 'finsight.com.mx' || host === 'www.finsight.com.mx') return '/api';
  } catch {}
  return 'http://localhost:3001/api';
}

export const API_URL: string = resolveApi();

class ApiService {
  private getToken(): string | null {
    return localStorage.getItem('token');
  }

  private getHeaders(): HeadersInit {
    const token = this.getToken();
    return {
      'Content-Type': 'application/json',
      ...(token && { 'Authorization': `Bearer ${token}` })
    };
  }

  private async request<T>(url: string, options?: RequestInit): Promise<T> {
    const response = await fetch(`${API_URL}${url}`, {
      ...options,
      headers: this.getHeaders()
    });

    if (response.status === 401) {
      // Token expired or invalid
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
      throw new Error('Unauthorized');
    }

    if (!response.ok) {
      let message = 'Request failed';
      try {
        const error = await response.json();
        message = error.message || error.error || message;
      } catch {
        try {
          const text = await response.text();
          if (text) message = text;
        } catch {}
      }
      throw new Error(message);
    }

    return response.json();
  }

  // Auth
  async login(username: string, password: string) {
    const response = await fetch(`${API_URL}/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    
    const data = await response.json();
    if (!response.ok) throw new Error(data.message);
    return data;
  }

  async getCurrentUser() {
    return this.request<any>('/me');
  }


  // Accounts
  async getAccounts() {
    return this.request<any[]>('/accounts');
  }

  async createAccount(account: any) {
    return this.request<any>('/accounts', {
      method: 'POST',
      body: JSON.stringify(account)
    });
  }

  async updateAccount(id: number, account: any) {
    return this.request<any>(`/accounts/${id}`, {
      method: 'PUT',
      body: JSON.stringify(account)
    });
  }

  async deleteAccount(id: number) {
    return this.request<any>(`/accounts/${id}`, {
      method: 'DELETE'
    });
  }

  // Transactions
  async getTransactions() {
    return this.request<any[]>('/transactions');
  }

  async createTransaction(transaction: any) {
    return this.request<any>('/transactions', {
      method: 'POST',
      body: JSON.stringify(transaction)
    });
  }

  async updateTransaction(id: number, transaction: any) {
    return this.request<any>(`/transactions/${id}`, {
      method: 'PUT',
      body: JSON.stringify(transaction)
    });
  }

  async deleteTransaction(id: number) {
    return this.request<any>(`/transactions/${id}`, {
      method: 'DELETE'
    });
  }

  // Balance History
  async getBalanceHistory() {
    return this.request<any[]>('/balance-history');
  }

  // Projects
  async getProjects() {
    return this.request<any[]>('/projects');
  }

  async createProject(project: any) {
    return this.request<any>('/projects', {
      method: 'POST',
      body: JSON.stringify(project)
    });
  }

  async updateProject(id: number, project: any) {
    return this.request<any>(`/projects/${id}`, {
      method: 'PUT',
      body: JSON.stringify(project)
    });
  }

  async deleteProject(id: number) {
    return this.request<any>(`/projects/${id}`, {
      method: 'DELETE'
    });
  }

  // Payments
  async getPayments() {
    return this.request<any[]>('/payments');
  }

  async createPayment(payment: any) {
    return this.request<any>('/payments', {
      method: 'POST',
      body: JSON.stringify(payment)
    });
  }

  async updatePayment(id: number, payment: any) {
    return this.request<any>(`/payments/${id}`, {
      method: 'PUT',
      body: JSON.stringify(payment)
    });
  }

  async deletePayment(id: number) {
    return this.request<any>(`/payments/${id}`, {
      method: 'DELETE'
    });
  }

  async processOverduePayments() {
    return this.request<any>('/payments/process-overdue', {
      method: 'POST'
    });
  }

  // Credit installments
  async createInstallmentPlan(payload: {
    account_id: number;
    project_id?: number | null;
    name: string;
    description?: string;
    total_amount: number;
    months: number;
    first_due_date: string; // YYYY-MM-DD
    category?: string;
    category_id?: number | null;
    subcategory_id?: number | null;
  }) {
    return this.request<any>('/credit/installments', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  // Balance history maintenance
  async rebuildBalanceHistory() {
    return this.request<{ success: boolean }>('/balance-history/rebuild', {
      method: 'POST'
    });
  }

  // Customers
  async getCustomers() {
    return this.request<any[]>('/customers');
  }
  async createCustomer(customer: any) {
    return this.request<any>('/customers', { method: 'POST', body: JSON.stringify(customer) });
  }
  async updateCustomer(id: number, customer: any) {
    return this.request<any>(`/customers/${id}`, { method: 'PUT', body: JSON.stringify(customer) });
  }
  async deleteCustomer(id: number) {
    return this.request<any>(`/customers/${id}`, { method: 'DELETE' });
  }

  // Invoices
  async getInvoices() {
    return this.request<any[]>('/invoices');
  }
  async getInvoice(id: number) {
    return this.request<any>(`/invoices/${id}`);
  }
  async createInvoice(invoice: any) {
    return this.request<any>('/invoices', { method: 'POST', body: JSON.stringify(invoice) });
    }
  async updateInvoice(id: number, invoice: any) {
    return this.request<any>(`/invoices/${id}`, { method: 'PUT', body: JSON.stringify(invoice) });
  }
  async sendInvoice(id: number) {
    return this.request<any>(`/invoices/${id}/send`, { method: 'POST' });
  }
  async voidInvoice(id: number) {
    return this.request<any>(`/invoices/${id}/void`, { method: 'POST' });
  }
  async recordInvoicePayment(id: number, payment: any) {
    return this.request<any>(`/invoices/${id}/payments`, { method: 'POST', body: JSON.stringify(payment) });
  }
  async deleteInvoice(id: number) {
    return this.request<any>(`/invoices/${id}`, { method: 'DELETE' });
  }

  // Billing
  async createCheckoutSession() {
    return this.request<{ url: string }>(`/stripe/checkout`, { method: 'POST' });
  }
  async createPortalSession() {
    return this.request<{ url: string }>(`/stripe/portal`, { method: 'POST' });
  }

  async cancelSubscription() {
    return this.request<{ status: string; canceledAt: number | null; alreadyCanceled?: boolean }>('/stripe/cancel', { method: 'POST' });
  }

  // Investments
  async getInvestments() {
    return this.request<any[]>('/investments');
  }
  async getInvestment(id: number) {
    return this.request<any>(`/investments/${id}`);
  }
  async createInvestment(payload: { name: string; principal: number; annual_rate: number; start_date: string }) {
    return this.request<any>('/investments', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }
  async addInvestmentContribution(investmentId: number, amount: number, date: string) {
    return this.request<any>(`/investments/${investmentId}/contributions`, {
      method: 'POST',
      body: JSON.stringify({ amount, date })
    });
  }
  async deleteInvestment(id: number) {
    return this.request<{ success: boolean }>(`/investments/${id}`, { method: 'DELETE' });
  }

  // Account deletion (requires username + password)
  async deleteMyAccount(username: string, password: string) {
    return this.request<{ success: boolean }>('/account/delete', {
      method: 'POST',
      body: JSON.stringify({ username, password })
    });
  }

  // Public account deletion (no auth token)
  async deleteMyAccountPublic(username: string, password: string) {
    return this.request<{ success: boolean }>('/account/delete-public', {
      method: 'POST',
      body: JSON.stringify({ username, password })
    });
  }

  // Expense categories
  async getExpenseCategories() {
    return this.request<any[]>('/expense-categories');
  }

  async createExpenseCategory(payload: { name: string; icon: string }) {
    return this.request<any>('/expense-categories', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  async updateExpenseCategory(id: number, payload: { name: string; icon: string }) {
    return this.request<any>(`/expense-categories/${id}`, {
      method: 'PUT',
      body: JSON.stringify(payload)
    });
  }

  async deleteExpenseCategory(id: number) {
    return this.request<{ success: boolean } | null>(`/expense-categories/${id}`, {
      method: 'DELETE'
    });
  }

  async createExpenseSubcategory(payload: { category_id: number; name: string; icon: string }) {
    return this.request<any>('/expense-subcategories', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  async updateExpenseSubcategory(id: number, payload: { name: string; icon: string; category_id?: number }) {
    return this.request<any>(`/expense-subcategories/${id}`, {
      method: 'PUT',
      body: JSON.stringify(payload)
    });
  }

  async deleteExpenseSubcategory(id: number) {
    return this.request<any>(`/expense-subcategories/${id}`, {
      method: 'DELETE'
    });
  }
}

export const api = new ApiService();




