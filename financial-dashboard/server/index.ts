import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { initializeDatabase } from './db.js';
import { startNotificationCron } from './notification_cron.js';
import routes from './routes.js';
import { stripeWebhookHandler } from './stripe.js';
import { inboundEmailWebhookHandler } from './email.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

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
  allowedHeaders: ['Content-Type','Authorization'],
  optionsSuccessStatus: 204,
};

app.use(cors(corsOptions));
// Explicitly handle preflight requests for all routes
app.options('*', cors(corsOptions));

// Stripe webhook must use raw body to validate signature; register before JSON parser
app.post('/webhooks/stripe', express.raw({ type: 'application/json' }), stripeWebhookHandler);
app.post('/api/webhook', express.raw({ type: 'application/json' }), inboundEmailWebhookHandler);

// JSON parser for all other routes
app.use(express.json());

// Start server immediately; initialize DB in background to avoid startup failures
async function boot() {
  // Routes
  app.use(routes);

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
  });

  try {
    await initializeDatabase();
    startNotificationCron();
  } catch (error) {
    console.error('Database initialization failed (server still running):', error);
  }
}

boot();
