export interface Account {
  id: number;
  name: string;
  type: 'Checking' | 'Savings' | 'Business' | 'Investment' | 'Credit';
  balance: number;
  accountNumber: string;
  bankName: string;
  isActive: boolean;
}

export interface Transaction {
  id: number;
  date: string;
  description: string;
  amount: number;
  type: 'Income' | 'Expense';
  category: string;
  accountId: number;
  accountName: string;
  projectId?: number;
  projectName?: string;
}

export interface Project {
  id: number;
  name: string;
  description: string;
  budget: number;
  spent: number;
  status: 'Active' | 'Completed' | 'On Hold';
  startDate: string;
  endDate: string;
}

export interface Payment {
  id: number;
  name: string;
  description: string;
  amount: number;
  frequency: 'Weekly' | 'Monthly' | 'Quarterly' | 'Yearly';
  nextDate: string;
  accountId: number;
  accountName: string;
  isActive: boolean;
  category: string;
}

const STORAGE_KEYS = {
  ACCOUNTS: 'financial_dashboard_accounts',
  TRANSACTIONS: 'financial_dashboard_transactions',
  PROJECTS: 'financial_dashboard_projects',
  PAYMENTS: 'financial_dashboard_payments',
  INITIALIZED: 'financial_dashboard_initialized'
};

// Generic storage functions
export const getFromStorage = <T>(key: string, defaultValue: T): T => {
  try {
    const item = localStorage.getItem(key);
    return item ? JSON.parse(item) : defaultValue;
  } catch (error) {
    console.error(`Error reading from localStorage key "${key}":`, error);
    return defaultValue;
  }
};

export const saveToStorage = <T>(key: string, data: T): void => {
  try {
    localStorage.setItem(key, JSON.stringify(data));
  } catch (error) {
    console.error(`Error saving to localStorage key "${key}":`, error);
  }
};

// Specific data functions
export const getAccounts = (): Account[] => {
  return getFromStorage(STORAGE_KEYS.ACCOUNTS, []);
};

export const saveAccounts = (accounts: Account[]): void => {
  saveToStorage(STORAGE_KEYS.ACCOUNTS, accounts);
};

export const getTransactions = (): Transaction[] => {
  return getFromStorage(STORAGE_KEYS.TRANSACTIONS, []);
};

export const saveTransactions = (transactions: Transaction[]): void => {
  saveToStorage(STORAGE_KEYS.TRANSACTIONS, transactions);
};

export const getProjects = (): Project[] => {
  return getFromStorage(STORAGE_KEYS.PROJECTS, []);
};

export const saveProjects = (projects: Project[]): void => {
  saveToStorage(STORAGE_KEYS.PROJECTS, projects);
};

export const getPayments = (): Payment[] => {
  return getFromStorage(STORAGE_KEYS.PAYMENTS, []);
};

export const savePayments = (payments: Payment[]): void => {
  saveToStorage(STORAGE_KEYS.PAYMENTS, payments);
};

export const isInitialized = (): boolean => {
  return getFromStorage(STORAGE_KEYS.INITIALIZED, false);
};

export const setInitialized = (): void => {
  saveToStorage(STORAGE_KEYS.INITIALIZED, true);
};

// Initialize with sample data for first-time users
export const initializeDefaultData = (): void => {
  if (isInitialized()) return;

  const defaultAccounts: Account[] = [
    {
      id: 1,
      name: 'Main Checking',
      type: 'Checking',
      balance: 5420.00,
      accountNumber: '****1234',
      bankName: 'First National Bank',
      isActive: true
    },
    {
      id: 2,
      name: 'Savings Account',
      type: 'Savings',
      balance: 12300.50,
      accountNumber: '****5678',
      bankName: 'First National Bank',
      isActive: true
    },
    {
      id: 3,
      name: 'Business Account',
      type: 'Business',
      balance: 8750.25,
      accountNumber: '****9012',
      bankName: 'Business Bank',
      isActive: true
    }
  ];

  const defaultTransactions: Transaction[] = [
    {
      id: 1,
      date: '2025-08-30',
      description: 'Grocery Store',
      amount: -85.42,
      type: 'Expense',
      category: 'Food & Dining',
      accountId: 1,
      accountName: 'Main Checking'
    },
    {
      id: 2,
      date: '2025-08-29',
      description: 'Salary Deposit',
      amount: 3500.00,
      type: 'Income',
      category: 'Salary',
      accountId: 1,
      accountName: 'Main Checking'
    },
    {
      id: 3,
      date: '2025-08-28',
      description: 'Electric Bill',
      amount: -120.30,
      type: 'Expense',
      category: 'Bills & Utilities',
      accountId: 1,
      accountName: 'Main Checking'
    },
    {
      id: 4,
      date: '2025-08-27',
      description: 'Client Payment',
      amount: 1200.00,
      type: 'Income',
      category: 'Freelance',
      accountId: 3,
      accountName: 'Business Account'
    },
    {
      id: 5,
      date: '2025-09-01',
      description: 'September Salary',
      amount: 3500.00,
      type: 'Income',
      category: 'Salary',
      accountId: 1,
      accountName: 'Main Checking'
    },
    {
      id: 6,
      date: '2025-09-05',
      description: 'September Groceries',
      amount: -95.50,
      type: 'Expense',
      category: 'Food & Dining',
      accountId: 1,
      accountName: 'Main Checking'
    },
    {
      id: 7,
      date: '2025-09-10',
      description: 'September Client Work',
      amount: 1500.00,
      type: 'Income',
      category: 'Freelance',
      accountId: 3,
      accountName: 'Business Account'
    },
    {
      id: 8,
      date: '2025-09-15',
      description: 'September Rent',
      amount: -1200.00,
      type: 'Expense',
      category: 'Rent/Mortgage',
      accountId: 1,
      accountName: 'Main Checking'
    }
  ];

  const defaultProjects: Project[] = [
    {
      id: 1,
      name: 'Website Redesign',
      description: 'Complete overhaul of company website',
      budget: 15000,
      spent: 8500,
      status: 'Active',
      startDate: '2025-07-01',
      endDate: '2025-09-30'
    },
    {
      id: 2,
      name: 'Mobile App Development',
      description: 'Native iOS and Android app',
      budget: 25000,
      spent: 25000,
      status: 'Completed',
      startDate: '2025-01-15',
      endDate: '2025-06-30'
    },
    {
      id: 3,
      name: 'Marketing Campaign',
      description: 'Q3 digital marketing initiative',
      budget: 8000,
      spent: 3200,
      status: 'On Hold',
      startDate: '2025-08-01',
      endDate: '2025-10-31'
    }
  ];

  const defaultPayments: Payment[] = [
    {
      id: 1,
      name: 'Rent Payment',
      description: 'Monthly apartment rent',
      amount: 1200,
      frequency: 'Monthly',
      nextDate: '2025-09-01',
      accountId: 1,
      accountName: 'Main Checking',
      isActive: true,
      category: 'Rent/Mortgage'
    },
    {
      id: 2,
      name: 'Netflix Subscription',
      description: 'Monthly streaming service',
      amount: 15.99,
      frequency: 'Monthly',
      nextDate: '2025-09-05',
      accountId: 1,
      accountName: 'Main Checking',
      isActive: true,
      category: 'Subscriptions'
    },
    {
      id: 3,
      name: 'Car Insurance',
      description: 'Quarterly car insurance premium',
      amount: 450,
      frequency: 'Quarterly',
      nextDate: '2025-10-15',
      accountId: 1,
      accountName: 'Main Checking',
      isActive: false,
      category: 'Insurance'
    }
  ];

  saveAccounts(defaultAccounts);
  saveTransactions(defaultTransactions);
  saveProjects(defaultProjects);
  savePayments(defaultPayments);
  setInitialized();
};

// Helper function to get the next ID for new records
export const getNextId = (items: { id: number }[]): number => {
  return items.length > 0 ? Math.max(...items.map(item => item.id)) + 1 : 1;
};