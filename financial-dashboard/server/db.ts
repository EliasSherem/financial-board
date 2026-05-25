import mysql from 'mysql2';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config();

// Support MYSQL_URL (e.g. mysql://user:pass@host:port/db) and optional SSL.
let host = process.env.MYSQL_HOST;
let port = parseInt(process.env.MYSQL_PORT || '3306');
let user = process.env.MYSQL_USER;
let password = process.env.MYSQL_PASSWORD;
let database = process.env.MYSQL_DATABASE;

const url = process.env.MYSQL_URL;
if (url) {
  try {
    const u = new URL(url);
    host = u.hostname || host;
    if (u.port) port = parseInt(u.port);
    user = decodeURIComponent(u.username || user || '');
    password = decodeURIComponent(u.password || password || '');
    database = (u.pathname || '').replace(/^\//, '') || database;
  } catch (e) {
    console.warn('Warning: Failed to parse MYSQL_URL, falling back to individual env vars');
  }
}

const useSSL = String(process.env.MYSQL_SSL || '').toLowerCase() === 'true';
const rejectUnauthorized = String(process.env.MYSQL_SSL_REJECT_UNAUTHORIZED || 'false').toLowerCase() === 'true';
const allowPublicKeyRetrieval = String(process.env.MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL || 'false').toLowerCase() === 'true';

const pool = mysql.createPool({
  host,
  port,
  user,
  password,
  database,
  ssl: useSSL ? { rejectUnauthorized } : undefined,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  connectTimeout: 60000,
  idleTimeout: 300000,
  multipleStatements: false,
  // Some providers require this with MySQL 8 when not using SSL
  // Only enabled if explicitly requested
  ...(allowPublicKeyRetrieval ? { enableKeepAlive: true, authPlugins: undefined, } : {})
});

export const db = pool.promise();

export async function initializeDatabase() {
  try {
    console.log('Initializing database...');
    console.log('Database config:', {
      host,
      port,
      user,
      database,
      useSSL
    });
    
    // Test connection first
    console.log('Testing database connection...');
    await db.query('SELECT 1 as test');
    console.log('Database connection successful');
    
    // Read and execute schema (support multiple repo layouts)
    const schemaCandidates = [
      path.join(__dirname, '../../database/schema.sql'), // financial-dashboard/database/schema.sql
      path.join(__dirname, '../../../database/schema.sql'), // project-root/database/schema.sql
      path.resolve(process.cwd(), 'database/schema.sql'),
    ];
    const schemaPath = schemaCandidates.find(p => fs.existsSync(p));
    if (schemaPath) {
      console.log('Reading schema file...');
      const schema = fs.readFileSync(schemaPath, 'utf8');
      const statements = schema.split(';').filter(stmt => stmt.trim());
      
      console.log(`Executing ${statements.length} schema statements...`);
      for (let i = 0; i < statements.length; i++) {
        const statement = statements[i];
        if (statement.trim()) {
          try {
            await db.query(statement);
            console.log(`Schema statement ${i + 1}/${statements.length} executed successfully`);
          } catch (stmtError) {
            console.warn(`Warning: Schema statement ${i + 1} failed:`, stmtError.message);
            // Continue with other statements
          }
        }
      }
      console.log('Database schema processed successfully');
    } else {
      console.log('No schema file found, skipping schema creation');
    }
    
    // Check if root user exists
    console.log('Checking for existing users...');
    const [users] = await db.query('SELECT * FROM users WHERE username = ?', ['root']);
    
    if ((users as any[]).length === 0) {
      console.log('No root user found, inserting seed data...');
      // Read and execute seed data (support multiple repo layouts)
      const seedCandidates = [
        path.join(__dirname, '../../database/seed.sql'),
        path.join(__dirname, '../../../database/seed.sql'),
        path.resolve(process.cwd(), 'database/seed.sql'),
      ];
      const seedPath = seedCandidates.find(p => fs.existsSync(p));
      if (seedPath) {
        const seed = fs.readFileSync(seedPath, 'utf8');
        const statements = seed.split(';').filter(stmt => stmt.trim());
        
        for (let i = 0; i < statements.length; i++) {
          const statement = statements[i];
          if (statement.trim()) {
            try {
              await db.query(statement);
              console.log(`Seed statement ${i + 1}/${statements.length} executed successfully`);
            } catch (stmtError) {
              console.warn(`Warning: Seed statement ${i + 1} failed:`, stmtError.message);
              // Continue with other statements
            }
          }
        }
        console.log('Seed data processed successfully');
      } else {
        console.log('No seed file found, skipping seed data insertion');
      }
    } else {
      console.log('Database already contains data');
    }
    
    console.log('Database initialization completed successfully');
    
  } catch (error) {
    console.error('Error initializing database:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      errno: error.errno,
      sqlState: error.sqlState
    });
    throw error;
  }
}
