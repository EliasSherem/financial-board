import dotenv from 'dotenv';
import mysql from 'mysql2/promise';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.join(__dirname, '../.env') });

async function main() {
  const conn = await mysql.createConnection({
    host: process.env.MYSQL_HOST,
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
  });

  // Make fields nullable and without default
  const sql = `ALTER TABLE accounts
    MODIFY COLUMN bank_name VARCHAR(100) NULL DEFAULT NULL,
    MODIFY COLUMN account_number VARCHAR(20) NULL DEFAULT NULL`;
  try {
    await conn.query(sql);
    console.log('Accounts columns updated to be NULLable.');
  } catch (e) {
    console.error('Failed to alter accounts table:', e);
  } finally {
    await conn.end();
  }
}

main().catch(err => { console.error(err); process.exit(1); });

