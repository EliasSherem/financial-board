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

  const [rows] = await conn.query('DESCRIBE projects');
  const projCol = rows.find(r => r.Field === 'project_id');
  if (!projCol) {
    console.log('projects.project_id does not exist — nothing to do.');
    await conn.end();
    return;
  }

  if (projCol.Null === 'NO' || projCol.Default !== null) {
    console.log('Altering projects.project_id to be NULL DEFAULT NULL...');
    await conn.query('ALTER TABLE projects MODIFY COLUMN project_id INT NULL DEFAULT NULL');
  } else {
    console.log('projects.project_id already NULL DEFAULT NULL.');
  }

  const [after] = await conn.query('DESCRIBE projects');
  console.log(after);
  await conn.end();
}

main().catch(err => { console.error(err); process.exit(1); });

