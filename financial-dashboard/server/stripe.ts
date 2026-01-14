import Stripe from 'stripe';
import type { Request, Response } from 'express';
import { db } from './db.js';

const stripeSecret = process.env.STRIPE_SECRET_KEY || '';
// Safe visibility for debugging in Cloud Run: do NOT log the key, only presence/length
try {
  console.log('[Stripe] Secret present:', Boolean(stripeSecret), 'len:', stripeSecret.length);
} catch {}

export const stripe = new Stripe(stripeSecret, {
  apiVersion: '2024-06-20',
});

function clientBaseUrl() {
  return process.env.CLIENT_URL || 'http://localhost:5173';
}

async function getOrCreateCustomer(userId: number): Promise<string> {
  const [rows] = await db.query('SELECT email, stripe_customer_id FROM users WHERE id = ? LIMIT 1', [userId]);
  const user = (rows as any[])[0];
  if (user?.stripe_customer_id) return user.stripe_customer_id as string;
  const email = user?.email || undefined;
  const customer = await stripe.customers.create({ email, metadata: { user_id: String(userId) } });
  await db.query('UPDATE users SET stripe_customer_id = ? WHERE id = ?', [customer.id, userId]);
  return customer.id;
}

export async function createCheckoutSession(userId: number) {
  const customerId = await getOrCreateCustomer(userId);
  const successUrl = `${clientBaseUrl()}/payments?upgraded=1`;
  const cancelUrl = `${clientBaseUrl()}/payments?canceled=1`;

  // Configure currency/amount via env vars (defaults keep previous behavior)
  const currency = (process.env.STRIPE_CURRENCY || 'usd').toLowerCase();
  const unitAmount = Number.parseInt(process.env.STRIPE_UNIT_AMOUNT || '1000'); // minor units

  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    customer: customerId,
    line_items: [
      {
        price_data: {
          currency,
          product_data: {
            name: 'FinSight Pro',
            description: 'Unlimited accounts, analytics, projects & invoices',
          },
          recurring: { interval: 'month' },
          unit_amount: unitAmount,
        },
        quantity: 1,
      },
    ],
    allow_promotion_codes: true,
    success_url: successUrl,
    cancel_url: cancelUrl,
    metadata: { user_id: String(userId) },
    subscription_data: {
      metadata: { user_id: String(userId) },
    },
  });
  return { url: session.url };
}

export async function createPortalSession(userId: number) {
  const [rows] = await db.query('SELECT stripe_customer_id FROM users WHERE id = ? LIMIT 1', [userId]);
  const user = (rows as any[])[0];
  const customerId = user?.stripe_customer_id || (await getOrCreateCustomer(userId));
  const session = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: `${clientBaseUrl()}/payments`,
  });
  return { url: session.url };
}

export async function syncUserSubscription(userId: number): Promise<{ is_pro: boolean }>
{
  const [rows] = await db.query('SELECT stripe_customer_id FROM users WHERE id = ? LIMIT 1', [userId]);
  const user = (rows as any[])[0];
  const customerId = user?.stripe_customer_id || (await getOrCreateCustomer(userId));
  // Find any active/trialing subscription for this customer
  const subs = await stripe.subscriptions.list({ customer: customerId, status: 'all', limit: 100 });
  const active = subs.data.some(s => s.status === 'active' || s.status === 'trialing');
  // Pick the most recent subscription if available
  const latest = subs.data[0];
  await db.query(
    'UPDATE users SET is_pro = ?, stripe_subscription_id = ?, stripe_subscription_status = ?, stripe_current_period_end = ? WHERE id = ?',
    [active ? 1 : 0, latest?.id || null, latest?.status || null, latest?.current_period_end ? new Date(latest.current_period_end * 1000) : null, userId]
  );
  return { is_pro: active };
}

async function setPro(userId: number, active: boolean, args?: { subId?: string; status?: string; periodEnd?: number }) {
  const { subId, status, periodEnd } = args || {};
  await db.query(
    'UPDATE users SET is_pro = ?, stripe_subscription_id = COALESCE(?, stripe_subscription_id), stripe_subscription_status = COALESCE(?, stripe_subscription_status), stripe_current_period_end = COALESCE(?, stripe_current_period_end) WHERE id = ?',
    [active ? 1 : 0, subId || null, status || null, periodEnd ? new Date(periodEnd * 1000) : null, userId]
  );
}
export async function cancelUserSubscription(userId: number) {
  const [rows] = await db.query(
    'SELECT stripe_subscription_id FROM users WHERE id = ? LIMIT 1',
    [userId]
  );
  const user = (rows as any[])[0];
  const subscriptionId = user?.stripe_subscription_id as string | undefined;
  if (!subscriptionId) {
    throw new Error('No active subscription to cancel');
  }

  let subscription: Stripe.Subscription;
  try {
    subscription = await stripe.subscriptions.retrieve(subscriptionId);
  } catch (err: any) {
    console.error('Failed to retrieve subscription before cancellation', err?.message || err);
    throw new Error('Unable to locate subscription in Stripe');
  }

  if (subscription.status === 'canceled') {
    await setPro(userId, false, {
      subId: subscription.id,
      status: subscription.status,
      periodEnd: subscription.current_period_end || undefined,
    });
    return { status: subscription.status, alreadyCanceled: true };
  }

  const canceled = await stripe.subscriptions.cancel(subscriptionId);
  await setPro(userId, false, {
    subId: canceled.id,
    status: canceled.status,
    periodEnd: canceled.current_period_end || undefined,
  });

  return {
    status: canceled.status,
    canceledAt: canceled.ended_at || canceled.current_period_end || null,
  };
}

export async function stripeWebhookHandler(req: Request, res: Response) {
  let event: Stripe.Event;
  const whSecret = process.env.STRIPE_WEBHOOK_SECRET;
  try {
    if (whSecret) {
      const sig = req.headers['stripe-signature'] as string;
      event = stripe.webhooks.constructEvent((req as any).body, sig, whSecret);
    } else {
      // req.body is a Buffer when using express.raw; parse JSON for local testing
      const raw = (req as any).body;
      const payload = typeof raw === 'string' ? raw : Buffer.isBuffer(raw) ? raw.toString('utf8') : JSON.stringify(raw || {});
      event = JSON.parse(payload) as any; // not verified; ok for local testing
    }
  } catch (err: any) {
    console.error('Stripe webhook signature verification failed', err?.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        const subscriptionId = session.subscription as string | undefined;
        const customerId = session.customer as string | undefined;
        const userId = Number(session.metadata?.user_id || session.subscription_details?.metadata?.user_id || 0);
        if (userId) {
          if (customerId) await db.query('UPDATE users SET stripe_customer_id = ? WHERE id = ?', [customerId, userId]);
          if (subscriptionId) await setPro(userId, true, { subId: subscriptionId, status: 'active' });
        }
        break;
      }
      case 'customer.subscription.updated':
      case 'customer.subscription.created': {
        const sub = event.data.object as Stripe.Subscription;
        const userId = Number(sub.metadata?.user_id || 0);
        if (userId) {
          const status = sub.status;
          const active = status === 'active' || status === 'trialing';
          await setPro(userId, active, { subId: sub.id, status, periodEnd: sub.current_period_end || undefined });
        }
        break;
      }
      case 'customer.subscription.deleted': {
        const sub = event.data.object as Stripe.Subscription;
        const userId = Number(sub.metadata?.user_id || 0);
        if (userId) await setPro(userId, false, { subId: sub.id, status: sub.status });
        break;
      }
      default:
        // no-op
        break;
    }
  } catch (e) {
    console.error('Stripe webhook handling error:', e);
    return res.status(500).send('Webhook handler failed');
  }

  res.json({ received: true });
}


