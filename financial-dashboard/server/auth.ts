import type { Request, Response, NextFunction } from 'express';
import type { PoolConnection, RowDataPacket } from 'mysql2/promise';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { db } from './db.js';

export interface UserPayload {
  id: number;
  username: string;
  is_pro?: boolean;
  token_version?: number;
}

declare global {
  namespace Express {
    interface Request {
      user?: UserPayload;
    }
  }
}

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 10);
}

export async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

export function generateToken(user: UserPayload): string {
  return jwt.sign({ ...user, token_version: user.token_version ?? 0 }, process.env.JWT_SECRET || 'secret', { expiresIn: '24h' });
}

export function verifyToken(token: string): UserPayload | null {
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET || 'secret', { algorithms: ['HS256'] }) as UserPayload;
    return Number.isSafeInteger(payload.id) && payload.id > 0 && typeof payload.username === 'string' ? payload : null;
  } catch {
    return null;
  }
}

export async function authenticateToken(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  const user = verifyToken(token);
  if (!user) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
  try {
    const [rows] = await db.query<RowDataPacket[]>('SELECT token_version FROM users WHERE id = ?', [user.id]);
    // Legacy JWTs contain no version and remain compatible until the first revocation.
    if (!rows[0] || !Number.isSafeInteger(user.token_version ?? 0) || Number(rows[0].token_version) !== (user.token_version ?? 0)) {
      return res.status(401).json({ error: 'Session revoked. Please sign in again.' });
    }
    req.user = user;
    next();
  } catch {
    // Missing migration or database outage must never bypass session revocation.
    return res.status(503).json({ error: 'Authentication temporarily unavailable' });
  }
}

export async function login(username: string, password: string) {
  if (typeof username !== 'string' || typeof password !== 'string' || password.length === 0 || Buffer.byteLength(password, 'utf8') > 1024) {
    return { success: false, message: 'Invalid username or password' };
  }
  let conn: PoolConnection | undefined;
  try {
    conn = await db.getConnection();
    await conn.beginTransaction();
    const [users] = await conn.query<RowDataPacket[]>(
      'SELECT id, username, email, password, credential_kind, token_version, COALESCE(is_pro, 0) AS is_pro FROM users WHERE username = ? FOR UPDATE',
      [username]
    );

    const user = users[0];
    if (!user) {
      await conn.rollback();
      return { success: false, message: 'Invalid username or password' };
    }

    const validPassword = await verifyPassword(password, user.password);
    if (!validPassword || user.credential_kind === 'google') {
      await conn.rollback();
      return { success: false, message: 'Invalid username or password' };
    }

    // A successful password challenge is evidence of a legacy local credential.
    if (user.credential_kind === 'unknown') await conn.query("UPDATE users SET credential_kind = 'local' WHERE id = ?", [user.id]);
    const token = generateToken({ id: user.id, username: user.username, is_pro: Boolean(user.is_pro), token_version: Number(user.token_version) });
    await conn.commit();
    return {
      success: true,
      token,
      user: { id: user.id, username: user.username, email: user.email, is_pro: Boolean(user.is_pro) }
    };
  } catch {
    await conn?.rollback();
    console.error('Login failed: authentication storage unavailable');
    return { success: false, message: 'An error occurred during login' };
  } finally { conn?.release(); }
}
