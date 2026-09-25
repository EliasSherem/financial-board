import type { RequestHandler } from 'express';
import type { RowDataPacket } from 'mysql2/promise';
import { db } from '../db.js';
export const ownerMiddleware: RequestHandler = (req, res, next) => {
    void (async () => {
        if (!req.user) {
            res.status(401).json({ code: 'UNAUTHORIZED' });
            return;
        }
        const [rows] = await db.query<RowDataPacket[]>('SELECT role FROM admin_roles WHERE user_id = ?', [req.user.id]);
        if (rows[0]?.role !== 'owner') {
            res.status(403).json({ code: 'FORBIDDEN' });
            return;
        }
        next();
    })().catch(() => res.status(503).json({ code: 'ADMIN_UNAVAILABLE' }));
};
