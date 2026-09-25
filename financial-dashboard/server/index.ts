import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { initializeDatabase, databaseScope, pooledDb } from './db.js';
import { pathToFileURL } from 'node:url';
import { assertPlatformSchema, reportStartupFailure } from './platform/startup.js';
import recoveryRoutes from './recovery/routes.js';
import { cleanupRecoveryRecords } from './recovery/cleanup.js';
import billingRoutes from './billing/routes.js';
import { startBillingWorker } from './billing/worker.js';
import momentumRoutes from './momentum/routes.js';
import { startMomentumWorker, cleanupMomentum } from './momentum/worker.js';
import { runMomentumNotifications } from './momentum/notifications.js';
import analyticsRoutes from './analytics/routes.js';
import { cleanupAnalytics } from './analytics/repository.js';
import adminRoutes from './admin/routes.js';
import { startNotificationCron } from './notification_cron.js';
import routes from './routes.js';
import { stripeWebhookHandler } from './stripe.js';
import { inboundEmailWebhookHandler } from './email.js';

if (process.env.NODE_ENV !== 'test') dotenv.config();

export const app = express();
app.disable('x-powered-by');
if (process.env.TRUST_PROXY_CIDRS) app.set('trust proxy', process.env.TRUST_PROXY_CIDRS.split(',').map(value=>value.trim()));
const PORT = Number(process.env.PORT || 3001);

// Middleware: CORS
const corsOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

function isAllowedOrigin(origin: string): boolean {
  const allowList = corsOrigins.length
    ? corsOrigins
    : ['http://localhost:3000','http://localhost:5173','http://localhost:5174','http://localhost:5175','http://localhost:5176','http://localhost:8081'];

  if (allowList.includes(origin)) return true;
  if (process.env.NODE_ENV === 'production') return false;

  try {
    const { hostname, protocol } = new URL(origin);
    const isHttp = protocol === 'http:' || protocol === 'https:';
    if (!isHttp) return false;

    const isLocalDevHost =
      hostname === 'localhost' ||
      hostname === '127.0.0.1' ||
      hostname === '0.0.0.0' ||
      hostname === '192' ||
      /^192\.168\.\d{1,3}\.\d{1,3}$/.test(hostname) ||
      /^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(hostname) ||
      /^172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3}$/.test(hostname);

    if (isLocalDevHost) return true;
    if (hostname.endsWith('.a.run.app') || hostname.endsWith('.appspot.com')) return true;
    if (hostname === 'finsight.com.mx' || hostname === 'www.finsight.com.mx') return true;
  } catch {}
  return false;
}

const corsOptions: cors.CorsOptions = {
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    return callback(null, isAllowedOrigin(origin));
  },
  credentials: true,
  methods: ['GET','HEAD','POST','PUT','PATCH','DELETE','OPTIONS'],
  allowedHeaders: ['Content-Type','Authorization','X-Client-Platform','X-App-Version'],
  optionsSuccessStatus: 204,
};

app.use(cors(corsOptions));
// Explicitly handle preflight requests for all routes
app.options('*', cors(corsOptions));

// Stripe webhook must use raw body to validate signature; register before JSON parser
app.post('/webhooks/stripe', express.raw({ type: 'application/json' }), stripeWebhookHandler);
app.post('/api/webhook', express.raw({ type: 'application/json' }), inboundEmailWebhookHandler);

// JSON parser for all other routes
app.use(['/api/appstore/link','/webhooks/app-store'],express.json({limit:'1100kb'}));
app.use(express.json({limit:'128kb'}));
app.use(databaseScope);
app.use(recoveryRoutes);
app.use(billingRoutes);
app.use(momentumRoutes);
app.use(analyticsRoutes);
app.use(adminRoutes);
app.use(routes);

// Fail readiness before listening; never seed users or silently migrate production.
export async function boot() {
  await initializeDatabase();
  await assertPlatformSchema();
  app.listen(PORT, '0.0.0.0', () => console.log(`Server running on port ${PORT}`));
  startNotificationCron();
  startBillingWorker();
  startMomentumWorker();
  let maintenanceRunning=false;
  const maintenance=async()=>{
    if(maintenanceRunning)return;maintenanceRunning=true;
    try {await cleanupRecoveryRecords();await cleanupAnalytics();await cleanupMomentum();await runMomentumNotifications();}
    catch {console.error('platform_maintenance_failed');}
    finally {maintenanceRunning=false;}
  };
  const timer=setInterval(()=>void maintenance(),300000);timer.unref();
}
if(process.argv[1] && pathToFileURL(process.argv[1]).href===import.meta.url) {
  void boot().catch(async error => {
    process.exitCode = 1;
    await reportStartupFailure(error, pooledDb);
  });
}
