import bcrypt from 'bcrypt';

async function hashPassword() {
  const password = 'admin';
  const hash = await bcrypt.hash(password, 10);
  console.log('Password:', password);
  console.log('Hash:', hash);
  
  // Test verification
  const isValid = await bcrypt.compare(password, hash);
  console.log('Verification test:', isValid);
}

hashPassword();