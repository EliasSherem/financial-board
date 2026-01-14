import { db } from './db.js';

/**
 * Utility function to reconcile account balances with their transactions
 * This should be run if there are existing transactions that weren't properly reflected in account balances
 */
export async function reconcileAccountBalances() {
  try {
    console.log('Starting account balance reconciliation...');
    
    // Get all accounts
    const [accounts] = await db.query('SELECT id, name, balance FROM accounts');
    
    for (const account of accounts as any[]) {
      // Calculate the correct balance from transactions
      const [transactions] = await db.query(
        'SELECT SUM(amount) as total FROM transactions WHERE account_id = ?',
        [account.id]
      );
      
      const transactionTotal = (transactions as any[])[0]?.total || 0;
      
      // Update the account balance to match the transaction total
      await db.query(
        'UPDATE accounts SET balance = ? WHERE id = ?',
        [transactionTotal, account.id]
      );
      
      console.log(`Reconciled account "${account.name}" (ID: ${account.id}): ${account.balance} -> ${transactionTotal}`);
    }
    
    console.log('Account balance reconciliation completed successfully!');
  } catch (error) {
    console.error('Error during account balance reconciliation:', error);
    throw error;
  }
}

// Run reconciliation if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  reconcileAccountBalances()
    .then(() => {
      console.log('Reconciliation completed');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Reconciliation failed:', error);
      process.exit(1);
    });
}
