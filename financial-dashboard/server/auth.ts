import { Request, Response, NextFunction } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { db } from './db.js';

interface UserPayload {
  id: number;
  username: string;
  is_pro?: boolean;
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
  return jwt.sign(user, process.env.JWT_SECRET || 'secret', { expiresIn: '24h' });
}

export function verifyToken(token: string): UserPayload | null {
  try {
    return jwt.verify(token, process.env.JWT_SECRET || 'secret') as UserPayload;
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
    return res.status(403).json({ error: 'Invalid or expired token' });
  }

  req.user = user;
  next();
}

export async function login(username: string, password: string) {
  try {
    const [users] = await db.query(
      'SELECT id, username, password, COALESCE(is_pro, 0) AS is_pro FROM users WHERE username = ?',
      [username]
    );

    const user = (users as any[])[0];
    if (!user) {
      return { success: false, message: 'Invalid username or password' };
    }

    const validPassword = await verifyPassword(password, user.password);
    if (!validPassword) {
      return { success: false, message: 'Invalid username or password' };
    }

    const token = generateToken({ id: user.id, username: user.username, is_pro: Boolean(user.is_pro) });
    return { 
      success: true, 
      token, 
      user: { id: user.id, username: user.username, is_pro: Boolean(user.is_pro) } 
    };
  } catch (error) {
    console.error('Login error:', error);
    return { success: false, message: 'An error occurred during login' };
  }
}
