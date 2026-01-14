// Mock database for testing when MySQL is not available
interface User {
  id: number;
  username: string;
  email: string;
  password: string;
}

interface Account {
  id: number;
  user_id: number;
  name: string;
  type: string;
  balance: number;
  account_number: string;
  bank_name: string;
  is_active: boolean;
}

interface Transaction {
  id: number;
  user_id: number;
  account_id: number;
  project_id?: number;
  date: string;
  description: string;
  amount: number;
  type: string;
  category: string;
}

// Mock data storage
let users: User[] = [
  {
    id: 1,
    username: 'root',
    email: 'root@example.com',
    password: '$2b$10$example' // This would be a hashed password
  }
];

let accounts: Account[] = [
  {
    id: 1,
    user_id: 1,
    name: 'Debit Account',
    type: 'Checking',
    balance: 0, // This will be updated when transactions are added
    account_number: '****1234',
    bank_name: 'Test Bank',
    is_active: true
  }
];

let transactions: Transaction[] = [
  {
    id: 1,
    user_id: 1,
    account_id: 1,
    date: '2025-09-02',
    description: 'salary',
    amount: 15000,
    type: 'Income',
    category: 'Salary'
  }
];

// Update account balance based on transactions
function updateAccountBalance(accountId: number) {
  const accountTransactions = transactions.filter(t => t.account_id === accountId);
  const total = accountTransactions.reduce((sum, t) => sum + t.amount, 0);
  
  const account = accounts.find(a => a.id === accountId);
  if (account) {
    account.balance = total;
  }
}

// Initialize account balances
updateAccountBalance(1);

export const mockDb = {
  async query(sql: string, params: any[] = []) {
    console.log('Mock DB Query:', sql, params);
    
    // Handle different SQL operations
    if (sql.includes('SELECT * FROM accounts WHERE user_id = ?')) {
      return [accounts.filter(a => a.user_id === params[0])];
    }
    
    if (sql.includes('SELECT * FROM transactions')) {
      return [transactions];
    }
    
    if (sql.includes('INSERT INTO transactions')) {
      const newTransaction: Transaction = {
        id: transactions.length + 1,
        user_id: params[0],
        account_id: params[1],
        project_id: params[2],
        date: params[3],
        description: params[4],
        amount: params[5],
        type: params[6],
        category: params[7]
      };
      transactions.push(newTransaction);
      updateAccountBalance(newTransaction.account_id);
      return [{ insertId: newTransaction.id }];
    }
    
    if (sql.includes('UPDATE accounts SET balance = balance + ? WHERE id = ?')) {
      const account = accounts.find(a => a.id === params[1]);
      if (account) {
        account.balance += params[0];
      }
      return [];
    }
    
    if (sql.includes('SELECT SUM(amount) as total FROM transactions WHERE account_id = ?')) {
      const accountTransactions = transactions.filter(t => t.account_id === params[0]);
      const total = accountTransactions.reduce((sum, t) => sum + t.amount, 0);
      return [{ total }];
    }
    
    // Default response
    return [[]];
  }
};

// Export current data for debugging
export function getMockData() {
  return { users, accounts, transactions };
}

export function resetMockData() {
  users = [
    {
      id: 1,
      username: 'root',
      email: 'root@example.com',
      password: '$2b$10$example'
    }
  ];
  
  accounts = [
    {
      id: 1,
      user_id: 1,
      name: 'Debit Account',
      type: 'Checking',
      balance: 0,
      account_number: '****1234',
      bank_name: 'Test Bank',
      is_active: true
    }
  ];
  
  transactions = [
    {
      id: 1,
      user_id: 1,
      account_id: 1,
      date: '2025-09-02',
      description: 'salary',
      amount: 15000,
      type: 'Income',
      category: 'Salary'
    }
  ];
  
  updateAccountBalance(1);
}
