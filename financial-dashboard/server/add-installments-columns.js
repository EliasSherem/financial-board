import dotenv from 'dotenv';
import mysql from 'mysql2/promise';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.join(__dirname, '../.env') });

async function columnExists(conn, table, column) {
  const [rows] = await conn.query('SHOW COLUMNS FROM `' + table + '` LIKE ?', [column]);
  return Array.isArray(rows) && rows.length > 0;
}

async function main() {
  const conn = await mysql.createConnection({
    host: process.env.MYSQL_HOST,
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
  });

  const adds = [];
  if (!(await columnExists(conn, 'payments', 'installments_total'))) {
    adds.push('ADD COLUMN installments_total INT NULL');
  }
  if (!(await columnExists(conn, 'payments', 'installments_remaining'))) {
    adds.push('ADD COLUMN installments_remaining INT NULL');
  }
  if (!(await columnExists(conn, 'payments', 'installment_total_amount'))) {
    adds.push('ADD COLUMN installment_total_amount DECIMAL(15,2) NULL');
  }

  if (adds.length) {
    const sql = `ALTER TABLE payments ${adds.join(', ')}`;
    console.log('Altering payments:', sql);
    await conn.query(sql);
  } else {
    console.log('Installment columns already present.');
  }

  await conn.end();
}

main().catch(err => { console.error(err); process.exit(1); });

