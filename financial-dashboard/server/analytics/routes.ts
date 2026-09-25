import { Router } from 'express';
import type { RowDataPacket } from 'mysql2/promise';
import { db } from '../db.js';
import { authenticateToken } from '../auth.js';
import { enabled, endpoint, HttpError, limit } from '../platform/http.js';
import { AnalyticsValidationError, validateEvent } from './validation.js';
import { ingestEvents } from './repository.js';
const router = Router();
router.use('/api/analytics', authenticateToken);
router.post('/api/analytics/events', endpoint(async (req, res) => {
    if (!enabled('ADMIN_ANALYTICS_ENABLED'))
        return res.json({ accepted: 0 });
    await limit(`analytics:${req.user!.id}`, 60);
    if (!req.body || Object.keys(req.body).some(key => key !== 'events') || !Array.isArray(req.body.events) || req.body.events.length > 20 || req.body.events.length < 1)
        throw new HttpError(400, 'INVALID_EVENT_BATCH');
    try {
        const events = req.body.events.map((event: unknown) => validateEvent(event));
        return res.json({ accepted: await ingestEvents(req.user!.id, events) });
    }
    catch (error) {
        if (error instanceof AnalyticsValidationError)
            throw new HttpError(400, error.message);
        throw error;
    }
}));
router.get('/api/analytics/preferences', endpoint(async (req, res) => {
    const [rows] = await db.query<RowDataPacket[]>('SELECT enabled FROM analytics_user_settings WHERE user_id = ?', [req.user!.id]);
    return res.json({ enabled: rows[0]?.enabled !== 0, available: enabled('ADMIN_ANALYTICS_ENABLED') });
}));
router.post('/api/analytics/preferences', endpoint(async (req, res) => {
    if (!req.body || typeof req.body.enabled !== 'boolean' || Object.keys(req.body).some(key => key !== 'enabled'))
        throw new HttpError(400, 'INVALID_PREFERENCES');
    await db.query('INSERT INTO analytics_user_settings (user_id,enabled) VALUES (?,?) ON DUPLICATE KEY UPDATE enabled=VALUES(enabled)', [req.user!.id, req.body.enabled]);
    return res.json({ enabled: req.body.enabled });
}));
export default router;
