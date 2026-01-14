import { db } from './db.js';
import bcrypt from 'bcrypt';

async function updateRootPassword() {
  try {
    const password = 'admin';
    const hash = await bcrypt.hash(password, 10);
    
    console.log('Updating root password...');
    await db.query(
      'UPDATE users SET password = ? WHERE username = ?',
      [hash, 'root']
    );
    
    console.log('Password updated successfully');
    
    // Verify the update
    const [users] = await db.query(
      'SELECT * FROM users WHERE username = ?',
      ['root']
    );
    
    const user = (users as any[])[0];
    if (user) {
      const isValid = await bcrypt.compare(password, user.password);
      console.log('Verification test:', isValid);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error updating password:', error);
    process.exit(1);
  }
}

updateRootPassword();