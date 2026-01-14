// Simple script to fix the account balance for existing transactions
import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
dotenv.config();

async function fixAccountBalance() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'financial_dashboard'
  });

  try {
    console.log('Checking existing transactions...');
    
    // Get all transactions
    const [transactions] = await connection.execute(
      'SELECT * FROM transactions ORDER BY id DESC'
    );
    
    console.log(`Found ${transactions.length} transactions`);
    
    // Get all accounts
    const [accounts] = await connection.execute(
      'SELECT * FROM accounts'
    );
    
    console.log(`Found ${accounts.length} accounts`);
    
    // Calculate correct balance for each account
    for (const account of accounts) {
      const [accountTransactions] = await connection.execute(
        'SELECT SUM(amount) as total FROM transactions WHERE account_id = ?',
        [account.id]
      );
      
      const correctBalance = accountTransactions[0].total || 0;
      
      console.log(`Account "${account.name}" (ID: ${account.id}):`);
      console.log(`  Current balance: $${account.balance}`);
      console.log(`  Correct balance: $${correctBalance}`);
      
      if (account.balance !== correctBalance) {
        await connection.execute(
          'UPDATE accounts SET balance = ? WHERE id = ?',
          [correctBalance, account.id]
        );
        console.log(`  ✅ Updated balance to $${correctBalance}`);
      } else {
        console.log(`  ✅ Balance is already correct`);
      }
    }
    
    console.log('\nAccount balance fix completed!');
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await connection.end();
  }
}

fixAccountBalance();
