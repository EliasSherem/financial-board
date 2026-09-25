import { Router } from 'express';
import { authenticateToken } from '../auth.js';
import { db } from '../db.js';
import { enabled, endpoint, HttpError, limit } from '../platform/http.js';
import { ownerMiddleware } from './access.js';
import { parseFilters, publicFilters, toCsv, type Filters } from './filters.js';
import { getAdminReport, getAdminUser, exportRows } from './service.js';
const router = Router();
router.use('/api/admin', authenticateToken, ownerMiddleware, (req, res, next) => { res.setHeader('Cache-Control', 'no-store'); res.setHeader('Referrer-Policy', 'no-referrer'); next(); });
async function audit(user: number, action: string, filters?: Filters) { await db.query('INSERT INTO admin_audit (user_id,action,filters_json) VALUES (?,?,?)', [user, action, JSON.stringify(filters ? { ...publicFilters(filters), has_query: Boolean(filters.query) } : {})]); }
router.get('/api/admin/access', endpoint(async (req, res) => { await audit(req.user!.id, 'access'); return res.json({ allowed: true, analytics_enabled: enabled('ADMIN_ANALYTICS_ENABLED') }); }));
router.get('/api/admin/export/:section', endpoint(async (req, res) => {
    const section = String(req.params.section);
    if (section !== 'users' && section !== 'subscriptions')
        throw new HttpError(404, 'NOT_FOUND');
    await limit(`admin-export:${req.user!.id}`, 5, 3600);
    const f = parseFilters(req.query);
    await audit(req.user!.id, `export_${section}`, f);
    const data = await exportRows(section, f);
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="finsight-${section}-${f.end}.csv"`);
    return res.send(toCsv(data.rows, data.fields));
}));
router.get('/api/admin/users/:id', endpoint(async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isSafeInteger(id) || id < 1)
        throw new HttpError(400, 'INVALID_USER_ID');
    await limit(`admin:${req.user!.id}`, 60);
    const f = parseFilters(req.query);
    await audit(req.user!.id, 'user_detail', f);
    return res.json(await getAdminUser(id, f));
}));
router.get('/api/admin/:section', endpoint(async (req, res) => {
    const section = String(req.params.section);
    if (!['overview', 'usage', 'users', 'subscriptions', 'momentum', 'data-health'].includes(section))
        throw new HttpError(404, 'NOT_FOUND');
    await limit(`admin:${req.user!.id}`, 60);
    const f = parseFilters(req.query);
    await audit(req.user!.id, `view_${section}`, f);
    return res.json(await getAdminReport(section as 'overview' | 'usage' | 'users' | 'subscriptions' | 'momentum' | 'data-health', f));
}));
export default router;
