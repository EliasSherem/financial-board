import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { initializeDatabase } from './db.js';
import { startNotificationCron } from './notification_cron.js';
import routes from './routes.js';
import { stripeWebhookHandler } from './stripe.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware: CORS
const corsOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

const corsOptions: cors.CorsOptions = {
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    const allowList = corsOrigins.length
      ? corsOrigins
      : ['http://localhost:3000','http://localhost:5173','http://localhost:5174','http://localhost:5175','http://localhost:5176','http://localhost:8081'];
    let ok = allowList.includes(origin);
    try {
      const h = new URL(origin).hostname;
      if (h.endsWith('.a.run.app') || h.endsWith('.appspot.com') || h === 'finsight.com.mx' || h === 'www.finsight.com.mx') ok = true;
    } catch {}
    return callback(null, ok);
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
