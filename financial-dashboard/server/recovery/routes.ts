import { Router } from 'express';
import { randomInt } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import { db } from '../db.js';
import { authenticateToken, hashPassword } from '../auth.js';
import { isEmailConfigured, sendResendEmail } from '../email.js';
import { RecoveryService, recoveryUrl, type RecoveryConfig } from './core.js';
import { MysqlRecoveryRepository } from './repository.js';
const router = Router();
const neutralResponse = { success: true, message: 'If this address has a password account, recovery instructions will arrive shortly. If you use Google, continue with Google.', retry_after_seconds: 60 };
function service(): RecoveryService {
    const ttl = Number(process.env.RECOVERY_TOKEN_TTL_MINUTES || 30);
    const config: RecoveryConfig = {
        origin: process.env.RECOVERY_ORIGIN || '',
        allowedOrigins: (process.env.RECOVERY_ALLOWED_ORIGINS || '').split(',').map(value => value.trim()).filter(Boolean),
        ttlMinutes: Number.isInteger(ttl) && ttl >= 5 && ttl <= 60 ? ttl : 30,
        rateSecret: process.env.RECOVERY_RATE_SECRET || '',
    };
    recoveryUrl(config, 'validation');
    if (config.rateSecret.length < 32)
        throw new Error('Recovery rate secret missing');
    return new RecoveryService({ repository: new MysqlRecoveryRepository(db), config, hashPassword, send: sendResendEmail });
}
router.use('/api/auth', (_req, res, next) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Referrer-Policy', 'no-referrer');
    next();
});
router.post('/api/auth/forgot-password', async (req, res) => {
    const started = Date.now();
    const responseFloor = 700 + randomInt(0, 201);
    try {
        if (!isEmailConfigured())
            throw new Error('Recovery email configuration missing');
        await service().forgot(req.body?.email, req.ip || req.socket.remoteAddress || 'unknown', req.body?.language === 'es' ? 'es' : 'en');
    }
    catch {
        // Never log a request body, address, URL, token, or provider payload.
        console.warn('Recovery request could not be processed; check configuration/database health');
    }
    await delay(Math.max(0, responseFloor - (Date.now() - started)));
    return res.status(200).json(neutralResponse);
});
router.post('/api/auth/reset-password', async (req, res) => {
    try {
        const result = await service().reset({ token: req.body?.token, password: req.body?.password, confirmation: req.body?.confirm_password, ip: req.ip || req.socket.remoteAddress || 'unknown', language: req.body?.language === 'es' ? 'es' : 'en' });
        if (result.ok === true)
            return res.json({ success: true });
        if (result.reason === 'rate_limit')
            return res.status(429).json({ success: false, code: 'RATE_LIMITED', retry_after_seconds: 3600 });
        if (result.reason === 'password')
            return res.status(400).json({ success: false, code: 'PASSWORD_INVALID' });
        return res.status(400).json({ success: false, code: 'INVALID_OR_EXPIRED_LINK', reason: result.reason });
    }
    catch {
        console.warn('Recovery reset unavailable');
        return res.status(503).json({ success: false, code: 'RECOVERY_UNAVAILABLE' });
    }
});
router.post('/api/auth/change-password', authenticateToken, async (req, res) => {
    try {
        const changed = await service().change(req.user!.id, { current: req.body?.current_password, password: req.body?.password, confirmation: req.body?.confirm_password, language: req.body?.language === 'es' ? 'es' : 'en' });
        if (!changed)
            return res.status(400).json({ success: false, code: 'PASSWORD_CHANGE_REJECTED' });
        return res.json({ success: true });
    }
    catch {
        console.warn('Authenticated password change unavailable');
        return res.status(503).json({ success: false, code: 'RECOVERY_UNAVAILABLE' });
    }
});
export default router;
