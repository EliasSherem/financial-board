import { Router, Request, Response } from 'express';
import { db } from './db.js';
import { isFcmConfigured, sendFcmNotification } from './fcm.js';
import { isEmailConfigured, sendResendEmail } from './email.js';
import { authenticateToken, login, generateToken, verifyPassword } from './auth.js';
import { createCheckoutSession, createPortalSession, syncUserSubscription, cancelUserSubscription } from './stripe.js';
import { google } from 'googleapis';
import crypto from 'crypto';
import OpenAI from 'openai';

const router = Router();
const APPLE_VERIFY_RECEIPT_PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const APPLE_VERIFY_RECEIPT_SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

let openaiClient: OpenAI | null = null;

function getOpenAiClient(): OpenAI | null {
  if (openaiClient) return openaiClient;
  const apiKey = process.env.OPENAI_API_KEY?.trim();
  if (!apiKey) return null;
  openaiClient = new OpenAI({ apiKey });
  return openaiClient;
}

function escapeEmailHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function maskEmail(value: string): string {
  const trimmed = value.trim();
  const atIndex = trimmed.indexOf('@');
  if (atIndex <= 1) return trimmed;
  const local = trimmed.slice(0, atIndex);
  const domain = trimmed.slice(atIndex + 1);
  const head = local.slice(0, 1);
  const tail = local.length > 2 ? local.slice(-1) : '';
  const stars = '*'.repeat(Math.max(1, local.length - 2));
  return `${head}${stars}${tail}@${domain}`;
}

function buildWelcomeEmail(username: string) {
  const greetName = username?.trim() ? username.trim() : 'there';
  const safeGreet = escapeEmailHtml(greetName);
  const subject = 'Welcome to FinSight';
  const text =
    `Hi ${greetName},\n\n` +
    `Welcome to FinSight. Your account is ready to go.\n\n` +
    `Start here:\n` +
    `- Add your first account\n` +
    `- Create categories that match your spending\n` +
    `- Log your first transaction to unlock insights\n\n` +
    `Open FinSight: https://finsight.com.mx\n\n` +
    `If you did not create this account, you can ignore this email.\n\n` +
    `- FinSight`;
  const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>${subject}</title>
  </head>
  <body style="margin:0;background:#f4f5f7;font-family:Arial,Helvetica,sans-serif;color:#111827;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f5f7;padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="560" cellspacing="0" cellpadding="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 24px rgba(17,24,39,0.08);">
            <tr>
              <td style="padding:20px 24px;background:#0f172a;color:#ffffff;">
                <div style="font-size:18px;font-weight:700;letter-spacing:0.3px;">FinSight</div>
              </td>
            </tr>
            <tr>
              <td style="padding:24px;">
                <div style="font-size:20px;font-weight:700;margin-bottom:6px;">Welcome to FinSight</div>
                <div style="color:#374151;font-size:14px;margin-bottom:18px;">Hi ${safeGreet}, your account is ready to go.</div>
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border:1px solid #e5e7eb;border-radius:12px;">
                  <tr>
                    <td style="padding:16px 18px;">
                      <div style="font-size:12px;text-transform:uppercase;color:#6b7280;letter-spacing:0.6px;">Start here</div>
                      <div style="font-size:14px;color:#111827;margin-top:8px;line-height:1.6;">
                        Add your first account<br />
                        Create categories that match your spending<br />
                        Log your first transaction to unlock insights
                      </div>
                    </td>
                  </tr>
                </table>
                <div style="margin-top:18px;font-size:13px;color:#6b7280;">If you did not create this account, you can ignore this email.</div>
                <div style="margin-top:22px;">
                  <a href="https://finsight.com.mx" style="display:inline-block;background:#2563eb;color:#ffffff;text-decoration:none;padding:10px 18px;border-radius:10px;font-size:14px;font-weight:600;">Open FinSight</a>
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 24px;background:#f9fafb;color:#6b7280;font-size:12px;">
                You received this email because a new FinSight account was created with this address.
              </td>
            </tr>
          </table>
          <div style="margin-top:14px;color:#9ca3af;font-size:11px;">FinSight Notifications</div>
        </td>
      </tr>
    </table>
  </body>
</html>`;
  return { subject, text, html };
}

async function sendWelcomeEmail(email: string, username: string) {
  const normalized = email.trim().toLowerCase();
  if (!normalized) {
    console.warn('Welcome email skipped: missing email');
    return;
  }
  if (normalized === 'root@example.com') return;
  const masked = maskEmail(normalized);
  if (!isEmailConfigured()) {
    console.warn('Welcome email skipped: Resend not configured for', masked);
    return;
  }
  console.info('Sending welcome email to', masked);
  const payload = buildWelcomeEmail(username);
  const sent = await sendResendEmail({
    to: email,
    subject: payload.subject,
    text: payload.text,
    html: payload.html
  });
  if (sent) {
    console.info('Welcome email sent to', masked);
  } else {
    console.warn('Welcome email failed for', masked);
  }
}

function invoiceLabel(invoiceId: number, numberValue: string | null | undefined) {
  const raw = String(numberValue || '').trim();
  if (!raw || raw === '#') return `#${invoiceId}`;
  return raw.startsWith('#') ? raw : `#${raw}`;
}

function getAppleSharedSecret() {
  return (
    process.env.APPLE_SHARED_SECRET?.trim() ||
    process.env.APPLE_APP_SHARED_SECRET?.trim() ||
    process.env.APPLE_IAP_SHARED_SECRET?.trim() ||
    ''
  );
}

function getAppleReceiptVerificationMode() {
  const mode = String(
    process.env.APPLE_RECEIPT_VERIFICATION_MODE ||
      process.env.APPLE_VERIFY_RECEIPT_MODE ||
      'auto'
  )
    .trim()
    .toLowerCase();
  return mode === 'sandbox' || mode === 'production' ? mode : 'auto';
}

function parseAppleDateMs(value: unknown): Date | null {
  if (value == null) return null;
  const asNumber = Number(value);
  if (!Number.isFinite(asNumber) || asNumber <= 0) return null;
  return new Date(asNumber);
}

async function verifyReceiptWithApple(
  url: string,
  receiptData: string,
  sharedSecret: string
) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      'receipt-data': receiptData,
      password: sharedSecret,
      'exclude-old-transactions': false,
    }),
  });
  if (!response.ok) {
    throw new Error(`Apple receipt validation failed with HTTP ${response.status}`);
  }
  return response.json() as Promise<any>;
}

async function verifyAppStoreReceipt(receiptData: string) {
  const sharedSecret = getAppleSharedSecret();
  if (!sharedSecret) {
    throw new Error('APPLE_SHARED_SECRET is not configured');
  }

  const mode = getAppleReceiptVerificationMode();
  const primaryUrl =
    mode === 'sandbox'
      ? APPLE_VERIFY_RECEIPT_SANDBOX_URL
      : APPLE_VERIFY_RECEIPT_PRODUCTION_URL;
  const secondaryUrl =
    primaryUrl === APPLE_VERIFY_RECEIPT_PRODUCTION_URL
      ? APPLE_VERIFY_RECEIPT_SANDBOX_URL
      : APPLE_VERIFY_RECEIPT_PRODUCTION_URL;
  const secondaryStatus =
    primaryUrl === APPLE_VERIFY_RECEIPT_PRODUCTION_URL ? 21007 : 21008;

  let payload = await verifyReceiptWithApple(primaryUrl, receiptData, sharedSecret);
  if (mode === 'auto' && payload?.status === secondaryStatus) {
    payload = await verifyReceiptWithApple(
      secondaryUrl,
      receiptData,
      sharedSecret
    );
  }

  return {
    status: Number(payload?.status ?? -1),
    environment:
      typeof payload?.environment === 'string' && payload.environment.trim()
        ? payload.environment.trim()
        : mode === 'sandbox'
          ? 'Sandbox'
          : 'Production',
    latestReceipt: payload?.latest_receipt || receiptData,
    latestReceiptInfo: Array.isArray(payload?.latest_receipt_info)
      ? payload.latest_receipt_info
      : Array.isArray(payload?.receipt?.in_app)
        ? payload.receipt.in_app
        : [],
    pendingRenewalInfo: Array.isArray(payload?.pending_renewal_info)
      ? payload.pending_renewal_info
      : [],
  };
}

function summarizeAppStoreSubscription(
  latestReceiptInfo: any[],
  pendingRenewalInfo: any[],
  preferredProductId?: string
) {
  const matchingEntries = latestReceiptInfo
    .filter((entry) => {
      const productId = String(entry?.product_id || '').trim();
      return preferredProductId ? productId === preferredProductId : !!productId;
    })
    .sort((a, b) => {
      const aExpiry = Number(a?.expires_date_ms || 0);
      const bExpiry = Number(b?.expires_date_ms || 0);
      return bExpiry - aExpiry;
    });

  const latest = matchingEntries[0];
  if (!latest) return null;

  const expiry = parseAppleDateMs(latest.expires_date_ms);
  const isCanceled = Boolean(latest.cancellation_date_ms || latest.cancellation_date);
  const isActive = Boolean(!isCanceled && expiry && expiry.getTime() > Date.now());
  const originalTransactionId = String(
    latest.original_transaction_id || ''
  ).trim();
  const latestTransactionId = String(latest.transaction_id || '').trim();
  const renewalInfo = pendingRenewalInfo.find((item) => {
    const itemOriginal = String(item?.original_transaction_id || '').trim();
    const itemProductId = String(item?.product_id || '').trim();
    return (
      (originalTransactionId && itemOriginal === originalTransactionId) ||
      itemProductId === String(latest.product_id || '').trim()
    );
  });
  const autoRenewStatusRaw = String(renewalInfo?.auto_renew_status || '').trim();
  const autoRenewStatus =
    autoRenewStatusRaw === '1'
      ? true
      : autoRenewStatusRaw === '0'
        ? false
        : null;

  return {
    productId: String(latest.product_id || preferredProductId || '').trim(),
    originalTransactionId: originalTransactionId || latestTransactionId,
    latestTransactionId: latestTransactionId || originalTransactionId || null,
    expiry,
    state: isCanceled ? 'CANCELED' : isActive ? 'ACTIVE' : expiry ? 'EXPIRED' : 'UNKNOWN',
    isActive,
    autoRenewStatus,
  };
}

function formatInvoiceDate(value: unknown) {
  if (!value) return '-';
  const date =
    value instanceof Date ? value : new Date(String(value));
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat('en-GB', { timeZone: 'UTC' }).format(date);
}

function formatInvoiceAmount(value: unknown, currency: string | null | undefined) {
  const amount = Number(value || 0);
  const safeCurrency = String(currency || 'MXN').toUpperCase();
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: safeCurrency,
    }).format(amount);
  } catch (_) {
    return `${safeCurrency} ${amount.toFixed(2)}`;
  }
}

function buildInvoiceShareEmail(args: {
  invoiceId: number;
  invoiceNumber?: string | null;
  customerName: string;
  total: unknown;
  dueDate: unknown;
  currency?: string | null;
}) {
  const label = invoiceLabel(args.invoiceId, args.invoiceNumber);
  const safeCustomerName = escapeEmailHtml(args.customerName.trim() || 'there');
  const totalLabel = formatInvoiceAmount(args.total, args.currency);
  const dueLabel = formatInvoiceDate(args.dueDate);
  const subject = `Invoice ${label} from FinSight`;
  const text =
    `Hi ${args.customerName.trim() || 'there'},\n\n` +
    `Your invoice ${label} is attached as a PDF.\n` +
    `Total: ${totalLabel}\n` +
    `Due date: ${dueLabel}\n\n` +
    `Sent via FinSight.\n\n` +
    `- FinSight`;
  const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>${subject}</title>
  </head>
  <body style="margin:0;background:#f4f5f7;font-family:Arial,Helvetica,sans-serif;color:#111827;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f5f7;padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="560" cellspacing="0" cellpadding="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 24px rgba(17,24,39,0.08);">
            <tr>
              <td style="padding:20px 24px;background:#0f172a;color:#ffffff;">
                <div style="font-size:18px;font-weight:700;letter-spacing:0.3px;">FinSight</div>
              </td>
            </tr>
            <tr>
              <td style="padding:24px;">
                <div style="font-size:20px;font-weight:700;margin-bottom:6px;">Invoice ${escapeEmailHtml(label)}</div>
                <div style="color:#374151;font-size:14px;margin-bottom:18px;">Hi ${safeCustomerName}, your invoice PDF is attached.</div>
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border:1px solid #e5e7eb;border-radius:12px;">
                  <tr>
                    <td style="padding:16px 18px;">
                      <div style="font-size:12px;text-transform:uppercase;color:#6b7280;letter-spacing:0.6px;">Invoice summary</div>
                      <div style="font-size:14px;color:#111827;margin-top:8px;line-height:1.8;">
                        Total: ${escapeEmailHtml(totalLabel)}<br />
                        Due date: ${escapeEmailHtml(dueLabel)}
                      </div>
                    </td>
                  </tr>
                </table>
                <div style="margin-top:18px;font-size:13px;color:#6b7280;">This invoice was sent from FinSight.</div>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 24px;background:#f9fafb;color:#6b7280;font-size:12px;">
                FinSight Notifications
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
  return { subject, text, html };
}

type CategoryResponse = {
  id: number;
  name: string;
  icon: string;
  subcategories: Array<{ id: number; name: string; icon: string; budget: number }>;
};

const TRANSACTION_SELECT_BASE = `
  SELECT
    t.id,
    t.user_id,
    t.account_id,
    t.project_id,
    t.date,
    t.description,
    t.amount,
    t.type,
    COALESCE(sc.name, cat.name, t.category) AS category,
    t.category_id,
    t.subcategory_id,
    t.created_at,
    t.updated_at,
    a.name AS account_name,
    p.name AS project_name,
    cat.name AS category_name,
    cat.icon AS category_icon,
    sc.name AS subcategory_name,
    sc.icon AS subcategory_icon
  FROM transactions t
  LEFT JOIN accounts a ON t.account_id = a.id
  LEFT JOIN projects p ON t.project_id = p.id
  LEFT JOIN expense_categories cat ON t.category_id = cat.id
  LEFT JOIN expense_subcategories sc ON t.subcategory_id = sc.id
`;

async function fetchTransactionWithRelations(userId: number, transactionId: number) {
  const [rows] = await db.query(
    `${TRANSACTION_SELECT_BASE} WHERE t.id = ? AND t.user_id = ?`,
    [transactionId, userId]
  );
  return (rows as any[])[0] ?? null;
}

async function listExpenseCategories(userId: number): Promise<CategoryResponse[]> {
  const [rows] = await db.query(
    `SELECT 
        c.id AS category_id,
        c.name AS category_name,
        c.icon AS category_icon,
        sc.id AS subcategory_id,
        sc.name AS subcategory_name,
        sc.icon AS subcategory_icon,
        sc.budget AS subcategory_budget
     FROM expense_categories c
     LEFT JOIN expense_subcategories sc ON sc.category_id = c.id
     WHERE c.user_id = ?
     ORDER BY c.name ASC, sc.name ASC`,
    [userId]
  );

  const map = new Map<number, CategoryResponse>();
  for (const row of rows as any[]) {
    const catId = row.category_id as number;
    if (!map.has(catId)) {
      map.set(catId, {
        id: catId,
        name: row.category_name,
        icon: row.category_icon,
        subcategories: []
      });
    }
    if (row.subcategory_id) {
      map.get(catId)!.subcategories.push({
        id: row.subcategory_id,
        name: row.subcategory_name,
        icon: row.subcategory_icon,
        budget: Number(row.subcategory_budget ?? 0)
      });
    }
  }

  return Array.from(map.values());
}

const INVESTMENT_TOTAL_CONTRIBUTIONS_SQL = `COALESCE((SELECT SUM(c.amount) FROM investment_contributions c WHERE c.investment_id = i.id), 0)`;

const INVESTMENT_ESTIMATED_VALUE_SQL = `(
    (i.principal * POW(1 + (i.annual_rate/100)/365, GREATEST(DATEDIFF(CURDATE(), i.start_date), 0)))
    + COALESCE(
        (SELECT SUM(c.amount * POW(1 + (i.annual_rate/100)/365, GREATEST(DATEDIFF(CURDATE(), c.date), 0)))
         FROM investment_contributions c WHERE c.investment_id = i.id),
        0
      )
  )`;

async function fetchExpenseCategory(userId: number, categoryId: number): Promise<CategoryResponse | null> {
  const [rows] = await db.query(
    `SELECT 
        c.id AS category_id,
        c.name AS category_name,
        c.icon AS category_icon,
        sc.id AS subcategory_id,
        sc.name AS subcategory_name,
        sc.icon AS subcategory_icon,
        sc.budget AS subcategory_budget
     FROM expense_categories c
     LEFT JOIN expense_subcategories sc ON sc.category_id = c.id
     WHERE c.user_id = ? AND c.id = ?
     ORDER BY sc.name ASC`,
    [userId, categoryId]
  );

  if ((rows as any[]).length === 0) return null;
  const category: CategoryResponse = {
    id: (rows as any[])[0].category_id,
    name: (rows as any[])[0].category_name,
    icon: (rows as any[])[0].category_icon,
    subcategories: []
  };
  for (const row of rows as any[]) {
    if (row.subcategory_id) {
      category.subcategories.push({
        id: row.subcategory_id,
        name: row.subcategory_name,
        icon: row.subcategory_icon,
        budget: Number(row.subcategory_budget ?? 0)
      });
    }
  }
  return category;
}

let investmentAccountSchemaEnsured = false;
let transactionTransferTypeSchemaEnsured = false;

async function ensureTransactionTransferTypeSchema() {
  if (transactionTransferTypeSchemaEnsured) return;
  try {
    await db.query(
      "ALTER TABLE transactions MODIFY COLUMN type ENUM('Income', 'Expense', 'Transfer') NOT NULL"
    );
  } catch (error: any) {
    const message = String(error?.message || '').toLowerCase();
    if (
      error?.code !== 'ER_BAD_FIELD_ERROR' &&
      !message.includes("enum('income','expense','transfer')") &&
      !message.includes("enum('income', 'expense', 'transfer')")
    ) {
      console.warn('Transactions schema warning (type enum):', error?.message || error);
    }
  }
  transactionTransferTypeSchemaEnsured = true;
}

async function ensureInvestmentAccountSchema() {
  if (investmentAccountSchemaEnsured) return;
  try {
    await db.query('ALTER TABLE investments ADD COLUMN account_id INT NULL');
  } catch (error: any) {
    if (error?.code !== 'ER_DUP_FIELDNAME') {
      console.warn('Investments schema warning (account_id):', error?.message || error);
    }
  }
  try {
    await db.query(
      'ALTER TABLE investments ADD CONSTRAINT fk_investments_account FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL'
    );
  } catch (error: any) {
    if (error?.code !== 'ER_FK_DUP_NAME' && error?.code !== 'ER_DUP_KEY') {
      console.warn('Investments schema warning (fk account):', error?.message || error);
    }
  }
  try {
    await db.query('ALTER TABLE investments ADD UNIQUE KEY uniq_investment_account (account_id)');
  } catch (error: any) {
    if (error?.code !== 'ER_DUP_KEYNAME') {
      console.warn('Investments schema warning (uniq account):', error?.message || error);
    }
  }
  try {
    await db.query('ALTER TABLE investment_contributions ADD COLUMN transaction_id INT NULL');
  } catch (error: any) {
    if (error?.code !== 'ER_DUP_FIELDNAME') {
      console.warn('Investment contributions schema warning (transaction_id):', error?.message || error);
    }
  }
  try {
    await db.query(
      'ALTER TABLE investment_contributions ADD UNIQUE KEY uniq_investment_contribution_tx (transaction_id)'
    );
  } catch (error: any) {
    if (error?.code !== 'ER_DUP_KEYNAME') {
      console.warn('Investment contributions schema warning (uniq tx):', error?.message || error);
    }
  }

  try {
    const [rows] = await db.query(
      `SELECT i.id, i.user_id, i.name, i.principal,
              COALESCE((SELECT SUM(c.amount) FROM investment_contributions c WHERE c.investment_id = i.id), 0) AS total_contributions
         FROM investments i
        WHERE i.account_id IS NULL`
    );
    for (const row of rows as any[]) {
      const balance = Number(row.principal || 0) + Number(row.total_contributions || 0);
      const [accResult] = await db.query(
        'INSERT INTO accounts (user_id, name, type, balance, account_number, bank_name, is_active) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [row.user_id, row.name, 'Investment', balance, null, null, true]
      );
      const newAccountId = (accResult as any).insertId;
      await db.query('UPDATE investments SET account_id = ? WHERE id = ?', [newAccountId, row.id]);
    }
  } catch (error) {
    console.warn('Failed to backfill investment accounts:', (error as any)?.message || error);
  }

  investmentAccountSchemaEnsured = true;
}

async function findInvestmentIdByAccount(accountId: number, userId: number) {
  const [rows] = await db.query('SELECT id FROM investments WHERE account_id = ? AND user_id = ?', [
    accountId,
    userId
  ]);
  if ((rows as any[]).length === 0) return null;
  return (rows as any[])[0].id as number;
}

async function syncInvestmentContribution(
  userId: number,
  accountId: number | null,
  transactionId: number,
  amount: number,
  date: string | Date
) {
  await ensureInvestmentAccountSchema();
  await db.query('DELETE FROM investment_contributions WHERE transaction_id = ? AND user_id = ?', [
    transactionId,
    userId
  ]);
  if (!accountId) return;
  const investmentId = await findInvestmentIdByAccount(accountId, userId);
  if (!investmentId) return;
  const amountNum = Number(amount);
  if (!Number.isFinite(amountNum) || amountNum === 0) return;
  const dateStr =
    typeof date === 'string'
      ? new Date(date).toISOString().slice(0, 10)
      : new Date(date).toISOString().slice(0, 10);
  await db.query(
    `INSERT INTO investment_contributions (user_id, investment_id, amount, date, transaction_id)
     VALUES (?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE amount = VALUES(amount), date = VALUES(date)`,
    [userId, investmentId, amountNum, dateStr, transactionId]
  );
}

async function deleteInvestmentContributionByTransaction(userId: number, transactionId: number) {
  await ensureInvestmentAccountSchema();
  await db.query('DELETE FROM investment_contributions WHERE transaction_id = ? AND user_id = ?', [
    transactionId,
    userId
  ]);
}

// Access control helpers
const EXEMPT_USER_IDS = new Set([1, 3]);

async function refreshUserProFlag(userId: number): Promise<boolean> {
  if (EXEMPT_USER_IDS.has(userId)) {
    await db.query('UPDATE users SET is_pro = 1 WHERE id = ?', [userId]);
    return true;
  }

  const [userRows] = await db.query(
    'SELECT stripe_subscription_status, stripe_current_period_end FROM users WHERE id = ? LIMIT 1',
    [userId]
  );
  const user = (userRows as any[])[0] || {};
  const stripeStatus = String(user?.stripe_subscription_status || '').trim().toLowerCase();
  const stripePeriodEnd =
    user?.stripe_current_period_end != null ? new Date(user.stripe_current_period_end) : null;
  const stripeActive =
    stripeStatus === 'active' ||
    stripeStatus === 'trialing' ||
    Boolean(stripePeriodEnd && stripePeriodEnd.getTime() > Date.now());

  const [playRows] = await db.query(
    `SELECT 1
       FROM play_subscriptions
      WHERE user_id = ?
        AND (last_state = 'SUBSCRIPTION_STATE_ACTIVE' OR (expiry_time IS NOT NULL AND expiry_time > NOW()))
      LIMIT 1`,
    [userId]
  );
  const [appStoreRows] = await db.query(
    `SELECT 1
       FROM app_store_subscriptions
      WHERE user_id = ?
        AND last_state = 'ACTIVE'
        AND (expiry_time IS NULL OR expiry_time > NOW())
      LIMIT 1`,
    [userId]
  );

  const isPro =
    stripeActive ||
    (playRows as any[]).length > 0 ||
    (appStoreRows as any[]).length > 0;
  await db.query('UPDATE users SET is_pro = ? WHERE id = ?', [isPro ? 1 : 0, userId]);
  return isPro;
}

async function userIsPro(userId: number): Promise<boolean> {
  if (EXEMPT_USER_IDS.has(userId)) return true;
  const [rows] = await db.query('SELECT COALESCE(is_pro, 0) AS is_pro FROM users WHERE id = ? LIMIT 1', [userId]);
  return Boolean((rows as any[])[0]?.is_pro);
}

async function ensureProOrExempt(req: Request, res: Response): Promise<boolean> {
  const uid = req.user?.id!;
  if (await userIsPro(uid)) return true;
  res.status(403).json({ message: 'Feature available on Pro plan. Upgrade to access.' });
  return false;
}

async function enforceFreeAccountLimit(req: Request, res: Response): Promise<boolean> {
  const uid = req.user?.id!;
  if (await userIsPro(uid)) return true;
  const [rows] = await db.query('SELECT COUNT(*) AS cnt FROM accounts WHERE user_id = ?', [uid]);
  const cnt = Number((rows as any[])[0]?.cnt || 0);
  if (cnt >= 3) {
    res.status(403).json({ message: 'Free plan limit reached: max 3 accounts. Upgrade to create more.' });
    return false;
  }
  return true;
}

// Helper function to update balance history for a specific account and month
async function updateBalanceHistory(userId: number, accountId: number, year: number, month: number) {
  try {
    // Compute the inclusive last day of the requested month
    const endDate = new Date(year, month, 0); // month is 1-based here; day 0 = last day of previous month
    const endDateStr = endDate.toISOString().slice(0, 10); // YYYY-MM-DD

    // Baseline = current account balance - sum(all transactions up to now)
    const [accRows] = await db.query(
      'SELECT balance FROM accounts WHERE id = ? AND user_id = ? LIMIT 1',
      [accountId, userId]
    );
    const currentBalance = (accRows as any[])[0]?.balance ?? 0;

    const [totalToNowRows] = await db.query(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions WHERE user_id = ? AND account_id = ?',
      [userId, accountId]
    );
    const sumToNow = Number((totalToNowRows as any[])[0]?.total ?? 0);
    const baseline = Number(currentBalance) - sumToNow;

    // Sum of transactions up to month end
    const [totalToMonthRows] = await db.query(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions WHERE user_id = ? AND account_id = ? AND date <= ?',
      [userId, accountId, endDateStr]
    );
    const sumToMonth = Number((totalToMonthRows as any[])[0]?.total ?? 0);

    const runningBalance = baseline + sumToMonth;

    // Insert or update balance history
    await db.query(
      `INSERT INTO balance_history (user_id, account_id, year, month, balance) 
       VALUES (?, ?, ?, ?, ?) 
       ON DUPLICATE KEY UPDATE balance = VALUES(balance)`,
      [userId, accountId, year, month, runningBalance]
    );
  } catch (error) {
    console.error('Error updating balance history:', error);
  }
}

// ----- Salary automation helpers -----

let salarySchemaEnsured = false;

async function ensureSalaryAutomationSchema() {
  if (salarySchemaEnsured) return;
  try {
    await db.query('ALTER TABLE salary_rules ADD COLUMN next_date DATE NULL');
  } catch (error: any) {
    if (error?.code !== 'ER_DUP_FIELDNAME') {
      console.warn('Salary automation schema warning:', error?.message || error);
    }
  }
  salarySchemaEnsured = true;
}

async function ensureSalaryCategory(userId: number) {
  const name = 'Salary';
  const [existing] = await db.query('SELECT id FROM expense_categories WHERE user_id = ? AND name = ? LIMIT 1', [
    userId,
    name,
  ]);
  if ((existing as any[]).length > 0) {
    return { id: (existing as any[])[0].id as number, name };
  }
  const defaultIcon = 'work';
  const [result] = await db.query(
    'INSERT INTO expense_categories (user_id, name, icon) VALUES (?, ?, ?)',
    [userId, name, defaultIcon]
  );
  return { id: (result as any).insertId as number, name };
}

function startOfDay(d: Date) {
  const copy = new Date(d);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function formatDateOnly(d: Date | null) {
  if (!d) return null;
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function daysInMonth(year: number, monthIndex: number) {
  return new Date(year, monthIndex + 1, 0).getDate();
}

function clampDay(year: number, monthIndex: number, desired: number) {
  const max = daysInMonth(year, monthIndex);
  return Math.max(1, Math.min(desired, max));
}

function computeFirstSalaryDate(rule: any, reference: Date) {
  const today = startOfDay(reference);
  const schedule = rule?.schedule || 'SemiMonthly';

  switch (schedule) {
    case 'Weekly': {
      const rawWeekday = Number(rule?.weekday ?? 1);
      const target = rawWeekday === 7 ? 0 : Math.max(0, Math.min(6, rawWeekday));
      const diff = (target - today.getDay() + 7) % 7;
      const candidate = new Date(today);
      candidate.setDate(candidate.getDate() + diff);
      return candidate;
    }
    case 'Monthly': {
      const desired = clampDay(today.getFullYear(), today.getMonth(), Number(rule?.day ?? 1) || 1);
      let candidate = new Date(today.getFullYear(), today.getMonth(), desired);
      if (candidate < today) {
        const nextMonth = new Date(today.getFullYear(), today.getMonth() + 1, 1);
        const nextDesired = clampDay(nextMonth.getFullYear(), nextMonth.getMonth(), Number(rule?.day ?? 1) || 1);
        candidate = new Date(nextMonth.getFullYear(), nextMonth.getMonth(), nextDesired);
      }
      return candidate;
    }
    case 'SemiMonthly':
    default: {
      const first = new Date(today.getFullYear(), today.getMonth(), 15);
      const second = new Date(
        today.getFullYear(),
        today.getMonth(),
        Math.min(30, daysInMonth(today.getFullYear(), today.getMonth()))
      );
      if (today <= first) return first;
      if (today <= second) return second;
      const nextMonth = new Date(today.getFullYear(), today.getMonth() + 1, 1);
      return new Date(nextMonth.getFullYear(), nextMonth.getMonth(), 15);
    }
  }
}

function computeNextSalaryDate(rule: any, previous: Date) {
  const schedule = rule?.schedule || 'SemiMonthly';
  const base = startOfDay(previous);
  switch (schedule) {
    case 'Weekly': {
      const next = new Date(base);
      next.setDate(next.getDate() + 7);
      return next;
    }
    case 'Monthly': {
      const nextMonth = new Date(base.getFullYear(), base.getMonth() + 1, 1);
      const desired = clampDay(
        nextMonth.getFullYear(),
        nextMonth.getMonth(),
        Number(rule?.day ?? base.getDate()) || 1
      );
      return new Date(nextMonth.getFullYear(), nextMonth.getMonth(), desired);
    }
    case 'SemiMonthly':
    default: {
      const day = base.getDate();
      const year = base.getFullYear();
      const month = base.getMonth();
      if (day <= 15) {
        const secondDay = Math.min(30, daysInMonth(year, month));
        return new Date(year, month, secondDay);
      }
      return new Date(year, month + 1, 15);
    }
  }
}

const SALARY_PROCESS_LIMIT = 48;

async function processDueSalaryRules(userId: number, referenceDate: Date = new Date()): Promise<void> {
  if (!userId) return;
  await ensureSalaryAutomationSchema();
  await ensureInvestmentAccountSchema();
  const today = startOfDay(referenceDate);
  const [rules] = await db.query('SELECT * FROM salary_rules WHERE user_id = ? AND is_active = TRUE', [userId]);

  for (const rule of rules as any[]) {
    if (!rule.account_id || !Number.isFinite(Number(rule.amount))) continue;
    const salaryCategory = await ensureSalaryCategory(userId);
    let nextDate: Date | null = rule.next_date ? startOfDay(new Date(rule.next_date)) : null;
    if (!nextDate || Number.isNaN(nextDate.getTime())) {
      nextDate = computeFirstSalaryDate(rule, today);
    }
    if (!nextDate) continue;

    let iterations = 0;
    let dueDate = startOfDay(nextDate);
    const amount = Math.abs(Number(rule.amount));

    while (dueDate <= today && iterations < SALARY_PROCESS_LIMIT) {
      try {
        const txDate = formatDateOnly(dueDate)!;
        const description = rule.name || 'Salary';

        const [existingRows] = await db.query(
          `SELECT id FROM transactions 
           WHERE user_id = ? 
             AND account_id = ? 
             AND date = ? 
             AND description = ? 
             AND amount = ? 
             AND type = ? 
             AND (category_id <=> ? OR category = ?)
           LIMIT 1`,
          [userId, rule.account_id, txDate, description, amount, 'Income', salaryCategory.id, salaryCategory.name]
        );
        if ((existingRows as any[]).length > 0) {
          dueDate = computeNextSalaryDate(rule, dueDate);
          iterations += 1;
          continue;
        }

        const [insertResult] = await db.query(
          'INSERT INTO transactions (user_id, account_id, date, description, amount, type, category, project_id, category_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [userId, rule.account_id, txDate, description, amount, 'Income', salaryCategory.name, null, salaryCategory.id]
        );

        await db.query(
          'UPDATE accounts SET balance = balance + ? WHERE id = ? AND user_id = ?',
          [amount, rule.account_id, userId]
        );

        await updateBalanceHistory(userId, rule.account_id, dueDate.getFullYear(), dueDate.getMonth() + 1);
        await syncInvestmentContribution(userId, rule.account_id, (insertResult as any).insertId, amount, txDate);

        rule.last_transaction_id = (insertResult as any)?.insertId ?? null;
      } catch (error) {
        console.error('Failed to process salary automation:', error);
        break;
      }

      dueDate = computeNextSalaryDate(rule, dueDate);
      iterations += 1;
    }

    if (!dueDate || dueDate <= today) {
      dueDate = computeNextSalaryDate(rule, today);
    }

    await db.query('UPDATE salary_rules SET next_date = ? WHERE id = ? AND user_id = ?', [
      formatDateOnly(dueDate),
      rule.id,
      userId,
    ]);
  }
}

// Rebuild balance history for the authenticated user (dev/maintenance)
router.post('/api/balance-history/rebuild', authenticateToken, async (req: Request, res: Response) => {
  try {
    // Find accounts for the user
    const [accounts] = await db.query('SELECT id FROM accounts WHERE user_id = ?', [req.user?.id]);
    const accountIds = (accounts as any[]).map(a => a.id);

    // Find min and max dates per account from transactions
    const [dateBounds] = await db.query(
      `SELECT account_id, MIN(date) as min_date, MAX(date) as max_date
       FROM transactions WHERE user_id = ? AND account_id IN (?)
       GROUP BY account_id`,
      [req.user?.id, accountIds.length ? accountIds : [0]]
    );

    const boundsByAccount = new Map<number, { min: Date; max: Date }>();
    for (const row of dateBounds as any[]) {
      boundsByAccount.set(row.account_id, {
        min: new Date(row.min_date),
        max: new Date(row.max_date)
      });
    }

    const now = new Date();
    const currY = now.getFullYear();
    const currM = now.getMonth() + 1; // 1-based

    for (const accId of accountIds) {
      const bounds = boundsByAccount.get(accId);
      if (!bounds) {
        // No transactions for this account: still write current month's balance so analytics include it
        await updateBalanceHistory(req.user!.id, accId, currY, currM);
        continue;
      }

      const min = bounds.min;
      const max = bounds.max;
      // Iterate months from min to max
      for (let y = min.getFullYear(); y <= max.getFullYear(); y++) {
        const startM = y === min.getFullYear() ? min.getMonth() + 1 : 1; // 1-based
        const endM = y === max.getFullYear() ? max.getMonth() + 1 : 12; // 1-based
        for (let m = startM; m <= endM; m++) {
          await updateBalanceHistory(req.user!.id, accId, y, m);
        }
      }
      // Also fill months after last transaction up to current month so totals reflect current balances
      let y = max.getFullYear();
      let m = max.getMonth() + 1;
      while (y < currY || (y === currY && m < currM)) {
        // advance month
        m++;
        if (m > 12) { m = 1; y++; }
        await updateBalanceHistory(req.user!.id, accId, y, m);
      }
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Rebuild balance history error:', error);
    res.status(500).json({ message: 'Failed to rebuild balance history' });
  }
});

// Auth routes
router.post('/api/signup', async (req: Request, res: Response) => {
  const { username, email, password } = req.body;
  
  try {
    // Check if username already exists
    const [existingUsers] = await db.query(
      'SELECT id FROM users WHERE username = ? OR email = ?',
      [username, email]
    );
    
    if ((existingUsers as any[]).length > 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'Username or email already exists' 
      });
    }
    
    // Hash password
    const bcrypt = await import('bcrypt');
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // Create user
    const [result] = await db.query(
      'INSERT INTO users (username, email, password) VALUES (?, ?, ?)',
      [username, email, hashedPassword]
    );
    
    const userId = (result as any).insertId;
    const safeEmail = String(email || '').trim();
    if (safeEmail) {
      void sendWelcomeEmail(safeEmail, String(username || ''));
    }
    
    // Generate token
    const token = generateToken({ id: userId, username });
    
    res.json({
      success: true,
      token,
      user: { id: userId, username, email }
    });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to create account' 
    });
  }
});

router.post('/api/login', async (req: Request, res: Response) => {
  const { username, password } = req.body;
  const result = await login(username, password);
  
  if (result.success) {
    res.json(result);
  } else {
    res.status(401).json(result);
  }
});

// Public account deletion: delete by username + password (no JWT required)
router.post('/api/account/delete-public', async (req: Request, res: Response) => {
  try {
    const { username, password } = req.body || {};
    if (!username || !password) {
      return res.status(400).json({ message: 'Username and password are required' });
    }

    // Load user and verify password
    const [rows] = await db.query(
      'SELECT id, password, stripe_subscription_id FROM users WHERE username = ? LIMIT 1',
      [username]
    );
    const user = (rows as any[])[0];
    if (!user) return res.status(401).json({ message: 'Invalid credentials' });

    const ok = await verifyPassword(password, user.password);
    if (!ok) return res.status(401).json({ message: 'Invalid credentials' });

    // Protect built-in/demo accounts from deletion
    if (EXEMPT_USER_IDS.has(Number(user.id))) {
      return res.status(403).json({ message: 'This account is not allowed to be deleted.' });
    }

    // Try to cancel subscription first (non-fatal on failure)
    try {
      if (user.stripe_subscription_id) {
        await cancelUserSubscription(Number(user.id));
      }
    } catch (e) {
      console.warn('Warning: failed to cancel subscription before public deletion:', (e as any)?.message || e);
    }

    // Delete user -> cascades to all owned rows
    const conn = await (db as any).getConnection();
    try {
      await conn.beginTransaction();
      await conn.query('DELETE FROM users WHERE id = ?', [user.id]);
      await conn.commit();
    } catch (e) {
      try { await conn.rollback(); } catch {}
      throw e;
    } finally {
      try { conn.release(); } catch {}
    }

    res.json({ success: true });
  } catch (e) {
    console.error('Public delete account error:', e);
    res.status(500).json({ message: 'Failed to delete account' });
  }
});

// Delete current user's account (cascades via FK constraints)
// Requires username + password confirmation
router.post('/api/account/delete', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { username, password } = req.body || {};
    if (!username || !password) {
      return res.status(400).json({ message: 'Username and password are required' });
    }

    // Ensure the request matches the logged-in user
    if (String(username) !== String(req.user?.username)) {
      return res.status(400).json({ message: 'Username does not match logged-in user' });
    }

    // Load user + password hash
    const [rows] = await db.query(
      'SELECT id, password, stripe_subscription_id FROM users WHERE id = ? AND username = ? LIMIT 1',
      [req.user?.id, username]
    );
    const user = (rows as any[])[0];
    if (!user) return res.status(404).json({ message: 'User not found' });

    const ok = await verifyPassword(password, user.password);
    if (!ok) return res.status(401).json({ message: 'Invalid credentials' });

    // Best-effort: cancel Stripe sub first (non-fatal if fails)
    try {
      if (user.stripe_subscription_id) {
        await cancelUserSubscription(req.user!.id);
      }
    } catch (e) {
      console.warn('Warning: failed to cancel subscription before deletion:', (e as any)?.message || e);
    }

    // Delete user -> cascades to all owned rows per schema (ON DELETE CASCADE)
    const conn = await (db as any).getConnection();
    try {
      await conn.beginTransaction();
      await conn.query('DELETE FROM users WHERE id = ?', [req.user?.id]);
      await conn.commit();
    } catch (e) {
      try { await conn.rollback(); } catch {}
      throw e;
    } finally {
      try { conn.release(); } catch {}
    }

    res.json({ success: true });
  } catch (e) {
    console.error('Delete account error:', e);
    res.status(500).json({ message: 'Failed to delete account' });
  }
});

// Google Sign-In (OAuth ID token) login endpoint
// Expects a JSON body: { id_token: string }
router.post('/api/login/google', async (req: Request, res: Response) => {
  try {
    const idToken = String(req.body?.id_token || '');
    if (!idToken) return res.status(400).json({ success: false, message: 'id_token is required' });

    // Verify with Google tokeninfo endpoint
    const resp = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`);
    if (!resp.ok) {
      const t = await resp.text().catch(() => '');
      return res.status(401).json({ success: false, message: 'Invalid Google token', detail: t });
    }
    const info = await resp.json() as any;
    const clientId = process.env.GOOGLE_CLIENT_ID || '';
    if (clientId && info.aud !== clientId) {
      return res.status(401).json({ success: false, message: 'Token audience mismatch' });
    }

    const email = info.email as string | undefined;
    const emailVerified = String(info.email_verified || 'false') === 'true';
    const sub = info.sub as string; // Google user id
    const name = (info.name as string) || (email ? email.split('@')[0] : `g_${sub.slice(0,6)}`);
    if (!email || !emailVerified) {
      return res.status(400).json({ success: false, message: 'Google email not available or not verified' });
    }

    // Find or create local user
    const [existing] = await db.query('SELECT id, username, email, COALESCE(is_pro,0) AS is_pro FROM users WHERE email = ? LIMIT 1', [email]);
    let userId: number;
    let username: string;
    let is_pro = false;
    if ((existing as any[]).length > 0) {
      const u = (existing as any[])[0];
      userId = u.id;
      username = u.username;
      is_pro = Boolean(u.is_pro);
    } else {
      // Create new user with random password
      username = name.toLowerCase().replace(/[^a-z0-9_]+/g, '').slice(0, 20) || 'user';
      // ensure username uniqueness (best-effort)
      let candidate = username;
      let suffix = 1;
      while (true) {
        const [rows] = await db.query('SELECT id FROM users WHERE username = ? LIMIT 1', [candidate]);
        if ((rows as any[]).length === 0) break;
        candidate = `${username}${suffix++}`;
      }
      username = candidate;
      const randomPass = crypto.randomBytes(18).toString('base64url');
      const bcrypt = await import('bcrypt');
      const hashed = await bcrypt.hash(randomPass, 10);
      const [ins] = await db.query('INSERT INTO users (username, email, password) VALUES (?, ?, ?)', [username, email, hashed]);
      userId = (ins as any).insertId;
      void sendWelcomeEmail(email, username);
    }

    const token = generateToken({ id: userId, username, is_pro });
    res.json({ success: true, token, user: { id: userId, username, email, is_pro } });
  } catch (e) {
    console.error('Google login failed:', e);
    res.status(500).json({ success: false, message: 'Google login failed' });
  }
});

// Account routes
router.get('/api/accounts', authenticateToken, async (req: Request, res: Response) => {
  try {
    await processDueSalaryRules(req.user!.id);
    await ensureInvestmentAccountSchema();
    const [accounts] = await db.query(
      `SELECT
         a.id,
         a.user_id,
         a.name,
         a.type,
         a.account_number,
         a.bank_name,
         a.is_active,
         a.balance AS raw_balance,
         CASE
           WHEN i.id IS NULL THEN a.balance
           ELSE ${INVESTMENT_ESTIMATED_VALUE_SQL}
         END AS balance,
         i.id AS investment_id,
         i.principal AS investment_principal,
         i.annual_rate AS investment_annual_rate,
         ${INVESTMENT_TOTAL_CONTRIBUTIONS_SQL} AS investment_total_contributions,
         CASE
           WHEN i.id IS NULL THEN NULL
           ELSE ${INVESTMENT_ESTIMATED_VALUE_SQL}
         END AS investment_estimated_value,
         i.start_date AS investment_start_date
       FROM accounts a
       LEFT JOIN investments i ON i.account_id = a.id AND i.user_id = a.user_id
       WHERE a.user_id = ?
       ORDER BY a.id DESC`,
      [req.user?.id]
    );
    res.json(accounts);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch accounts' });
  }
});

router.post('/api/accounts', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await enforceFreeAccountLimit(req, res))) return;
    const { name, type, balance, account_number, bank_name, is_active } = req.body;
    const safeAccountNumber = account_number ? String(account_number) : null;
    const safeBankName = bank_name ? String(bank_name) : null;
    const [result] = await db.query(
      'INSERT INTO accounts (user_id, name, type, balance, account_number, bank_name, is_active) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [req.user?.id, name, type, balance, safeAccountNumber, safeBankName, is_active]
    );
    
    const insertId = (result as any).insertId;
    const [newAccount] = await db.query('SELECT * FROM accounts WHERE id = ?', [insertId]);
    // Seed current month's balance history so analytics reflect initial balance
    try {
      const now = new Date();
      const y = now.getFullYear();
      const m = now.getMonth() + 1;
      await updateBalanceHistory(req.user?.id!, insertId, y, m);
    } catch (e) {
      console.warn('Seed balance history failed:', e);
    }
    res.json((newAccount as any[])[0]);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create account' });
  }
});

router.put('/api/accounts/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { name, type, balance, account_number, bank_name, is_active } = req.body;
    const safeAccountNumber = account_number ? String(account_number) : null;
    const safeBankName = bank_name ? String(bank_name) : null;
    await db.query(
      'UPDATE accounts SET name = ?, type = ?, balance = ?, account_number = ?, bank_name = ?, is_active = ? WHERE id = ? AND user_id = ?',
      [name, type, balance, safeAccountNumber, safeBankName, is_active, req.params.id, req.user?.id]
    );
    
    const [updated] = await db.query('SELECT * FROM accounts WHERE id = ? AND user_id = ?', [req.params.id, req.user?.id]);
    // Update current month's balance history to reflect changes
    try {
      const now = new Date();
      const y = now.getFullYear();
      const m = now.getMonth() + 1;
      await updateBalanceHistory(req.user?.id!, Number(req.params.id), y, m);
    } catch (e) {
      console.warn('Update balance history after account update failed:', e);
    }
    res.json((updated as any[])[0]);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update account' });
  }
});

router.delete('/api/accounts/:id', authenticateToken, async (req: Request, res: Response) => {
  const accId = Number(req.params.id);
  const userId = req.user?.id;
  try {
    await db.query('START TRANSACTION');

    // Proactively remove invoice payments tied to this account to avoid FK blocks
    // Only payments owned by this user (via invoices.user_id)
    await db.query(
      `DELETE ip FROM invoice_payments ip
       JOIN invoices i ON i.id = ip.invoice_id
       WHERE i.user_id = ? AND ip.account_id = ?`,
      [userId, accId]
    );

    // Delete the account; transactions, payments, balance_history etc. are set to cascade in schema
    await db.query('DELETE FROM accounts WHERE id = ? AND user_id = ?', [accId, userId]);

    await db.query('COMMIT');
    res.json({ success: true });
  } catch (error) {
    await db.query('ROLLBACK');
    console.error('Account delete error:', error);
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

// Expense category routes
router.get('/api/expense-categories', authenticateToken, async (req: Request, res: Response) => {
  try {
    const categories = await listExpenseCategories(req.user!.id);
    res.json(categories);
  } catch (error) {
    console.error('Expense categories fetch error:', error);
    res.status(500).json({ message: 'Failed to fetch categories' });
  }
});

router.post('/api/expense-categories', authenticateToken, async (req: Request, res: Response) => {
  const uid = req.user!.id;
  const name = (req.body?.name ?? '').toString().trim();
  const icon = (req.body?.icon ?? 'category').toString().trim() || 'category';

  if (!name) {
    return res.status(400).json({ message: 'Name is required' });
  }

  try {
    const [result] = await db.query(
      'INSERT INTO expense_categories (user_id, name, icon) VALUES (?, ?, ?)',
      [uid, name, icon]
    );
    const id = (result as any).insertId;
    const category = await fetchExpenseCategory(uid, id);
    res.status(201).json(category);
  } catch (error: any) {
    if (error?.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'Category name already exists' });
    }
    console.error('Expense category create error:', error);
    res.status(500).json({ message: 'Failed to create category' });
  }
});

router.put('/api/expense-categories/:id', authenticateToken, async (req: Request, res: Response) => {
  const uid = req.user!.id;
  const categoryId = Number(req.params.id);
  if (!Number.isFinite(categoryId)) {
    return res.status(400).json({ message: 'Invalid category id' });
  }

  const name = (req.body?.name ?? '').toString().trim();
  const icon = (req.body?.icon ?? 'category').toString().trim() || 'category';
  if (!name) {
    return res.status(400).json({ message: 'Name is required' });
  }

  try {
    const [result] = await db.query(
      'UPDATE expense_categories SET name = ?, icon = ? WHERE id = ? AND user_id = ?',
      [name, icon, categoryId, uid]
    );
    if ((result as any).affectedRows === 0) {
      return res.status(404).json({ message: 'Category not found' });
    }
    const category = await fetchExpenseCategory(uid, categoryId);
    res.json(category);
  } catch (error: any) {
    if (error?.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'Category name already exists' });
    }
    console.error('Expense category update error:', error);
    res.status(500).json({ message: 'Failed to update category' });
  }
});

router.delete('/api/expense-categories/:id', authenticateToken, async (req: Request, res: Response) => {
  const uid = req.user!.id;
  const categoryId = Number(req.params.id);
  if (!Number.isFinite(categoryId)) {
    return res.status(400).json({ message: 'Invalid category id' });
  }

  try {
    const [result] = await db.query(
      'DELETE FROM expense_categories WHERE id = ? AND user_id = ?',
      [categoryId, uid]
    );
    if ((result as any).affectedRows === 0) {
      return res.status(404).json({ message: 'Category not found' });
    }
    res.json({ success: true });
  } catch (error) {
    console.error('Expense category delete error:', error);
    res.status(500).json({ message: 'Failed to delete category' });
  }
});

router.post('/api/expense-subcategories', authenticateToken, async (req: Request, res: Response) => {
  const uid = req.user!.id;
  const categoryId = Number(req.body?.category_id);
  const name = (req.body?.name ?? '').toString().trim();
  const icon = (req.body?.icon ?? 'subcategory').toString().trim() || 'subcategory';
  const budgetNum = Number(req.body?.budget ?? 0);

  if (!Number.isFinite(categoryId)) {
    return res.status(400).json({ message: 'category_id is required' });
  }
  if (!name) {
    return res.status(400).json({ message: 'Name is required' });
  }
  if (!Number.isFinite(budgetNum) || budgetNum < 0) {
    return res.status(400).json({ message: 'Invalid budget' });
  }
  if (budgetNum > 0 && !(await ensureProOrExempt(req, res))) {
    return;
  }

  const [categoryRows] = await db.query(
    'SELECT id FROM expense_categories WHERE id = ? AND user_id = ?',
    [categoryId, uid]
  );
  if ((categoryRows as any[]).length === 0) {
    return res.status(404).json({ message: 'Category not found' });
  }

  try {
    await db.query(
      'INSERT INTO expense_subcategories (user_id, category_id, name, icon, budget) VALUES (?, ?, ?, ?, ?)',
      [uid, categoryId, name, icon, budgetNum]
    );
    const category = await fetchExpenseCategory(uid, categoryId);
    res.status(201).json(category);
  } catch (error: any) {
    if (error?.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'Subcategory name already exists in this category' });
    }
    console.error('Expense subcategory create error:', error);
    res.status(500).json({ message: 'Failed to create subcategory' });
  }
});

router.put('/api/expense-subcategories/:id', authenticateToken, async (req: Request, res: Response) => {
  const uid = req.user!.id;
  const subcategoryId = Number(req.params.id);
  if (!Number.isFinite(subcategoryId)) {
    return res.status(400).json({ message: 'Invalid subcategory id' });
  }

  const name = (req.body?.name ?? '').toString().trim();
  const icon = (req.body?.icon ?? 'subcategory').toString().trim() || 'subcategory';
  const maybeCategoryId = req.body?.category_id;
  const budgetRaw = req.body?.budget;
  let budgetNum: number | null = null;

  if (!name) {
    return res.status(400).json({ message: 'Name is required' });
  }
  if (budgetRaw !== undefined) {
    budgetNum = Number(budgetRaw);
    if (!Number.isFinite(budgetNum) || budgetNum < 0) {
      return res.status(400).json({ message: 'Invalid budget' });
    }
    if (budgetNum > 0 && !(await ensureProOrExempt(req, res))) {
      return;
    }
  }

  const [rows] = await db.query(
    'SELECT category_id, budget FROM expense_subcategories WHERE id = ? AND user_id = ?',
    [subcategoryId, uid]
  );
  if ((rows as any[]).length === 0) {
    return res.status(404).json({ message: 'Subcategory not found' });
  }
  let categoryId = Number((rows as any[])[0].category_id);
  const currentBudget = Number((rows as any[])[0].budget ?? 0);
  const budgetToSave = budgetNum ?? currentBudget;

  if (maybeCategoryId !== undefined && maybeCategoryId !== null) {
    const newCategoryId = Number(maybeCategoryId);
    if (!Number.isFinite(newCategoryId)) {
      return res.status(400).json({ message: 'Invalid category_id' });
    }
    const [catRows] = await db.query(
      'SELECT id FROM expense_categories WHERE id = ? AND user_id = ?',
      [newCategoryId, uid]
    );
    if ((catRows as any[]).length === 0) {
      return res.status(404).json({ message: 'Category not found' });
    }
    categoryId = newCategoryId;
  }

  try {
    await db.query(
      'UPDATE expense_subcategories SET name = ?, icon = ?, category_id = ?, budget = ? WHERE id = ? AND user_id = ?',
      [name, icon, categoryId, budgetToSave, subcategoryId, uid]
    );
    const category = await fetchExpenseCategory(uid, categoryId);
    res.json(category);
  } catch (error: any) {
    if (error?.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'Subcategory name already exists in this category' });
    }
    console.error('Expense subcategory update error:', error);
    res.status(500).json({ message: 'Failed to update subcategory' });
  }
});

router.delete('/api/expense-subcategories/:id', authenticateToken, async (req: Request, res: Response) => {
  const uid = req.user!.id;
  const subcategoryId = Number(req.params.id);
  if (!Number.isFinite(subcategoryId)) {
    return res.status(400).json({ message: 'Invalid subcategory id' });
  }

  const [rows] = await db.query(
    'SELECT category_id FROM expense_subcategories WHERE id = ? AND user_id = ?',
    [subcategoryId, uid]
  );
  if ((rows as any[]).length === 0) {
    return res.status(404).json({ message: 'Subcategory not found' });
  }
  const categoryId = Number((rows as any[])[0].category_id);

  try {
    await db.query(
      'DELETE FROM expense_subcategories WHERE id = ? AND user_id = ?',
      [subcategoryId, uid]
    );
    const category = await fetchExpenseCategory(uid, categoryId);
    res.json(category);
  } catch (error) {
    console.error('Expense subcategory delete error:', error);
    res.status(500).json({ message: 'Failed to delete subcategory' });
  }
});

// Transaction routes
router.get('/api/transactions', authenticateToken, async (req: Request, res: Response) => {
  try {
    await processDueSalaryRules(req.user!.id);
    const [transactions] = await db.query(
      `${TRANSACTION_SELECT_BASE} WHERE t.user_id = ? ORDER BY t.date DESC, t.id DESC`,
      [req.user!.id]
    );
    res.json(transactions);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

router.post('/api/transactions/repair-transfers', authenticateToken, async (req: Request, res: Response) => {
  const uid = req.user!.id;
  const transferLabels = ['transfer', 'fund transfer'];

  try {
    await ensureTransactionTransferTypeSchema();
    await db.query('START TRANSACTION');

    try {
      const [projectRows] = await db.query(
        `SELECT project_id, type, amount
         FROM transactions
         WHERE user_id = ?
           AND project_id IS NOT NULL
           AND LOWER(TRIM(COALESCE(category, ''))) IN (?, ?)
           AND type IN ('Income', 'Expense')`,
        [uid, ...transferLabels]
      );

      const projectAdjustments = new Map<number, number>();
      for (const row of projectRows as any[]) {
        const projectId = Number(row.project_id);
        if (!Number.isFinite(projectId)) continue;
        const amount = Math.abs(Number(row.amount || 0));
        const priorSpentEffect = row.type === 'Expense' ? amount : -amount;
        projectAdjustments.set(
          projectId,
          (projectAdjustments.get(projectId) ?? 0) - priorSpentEffect
        );
      }

      for (const [projectId, delta] of projectAdjustments.entries()) {
        if (delta === 0) continue;
        await db.query(
          'UPDATE projects SET spent = spent + ? WHERE id = ? AND user_id = ?',
          [delta, projectId, uid]
        );
      }

      const [result] = await db.query(
        `UPDATE transactions
         SET type = 'Transfer',
             category = 'Fund transfer',
             category_id = NULL,
             subcategory_id = NULL
         WHERE user_id = ?
           AND LOWER(TRIM(COALESCE(category, ''))) IN (?, ?)
           AND type IN ('Income', 'Expense', 'Transfer')`,
        [uid, ...transferLabels]
      );

      await db.query('COMMIT');
      res.json({
        success: true,
        updated: (result as any).affectedRows ?? 0,
        repaired_projects: projectAdjustments.size,
      });
    } catch (error) {
      await db.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error('Transfer repair error:', error);
    res.status(500).json({ message: 'Failed to repair past transfers' });
  }
});

router.post('/api/transactions', authenticateToken, async (req: Request, res: Response) => {
  try {
    const uid = req.user!.id;
    await ensureInvestmentAccountSchema();
    await ensureTransactionTransferTypeSchema();
    const {
      account_id,
      project_id,
      date,
      description,
      amount,
      type,
      category,
      category_id,
      subcategory_id,
    } = req.body;

    let categoryId: number | null = category_id !== undefined && category_id !== null ? Number(category_id) : null;
    let subcategoryId: number | null = subcategory_id !== undefined && subcategory_id !== null ? Number(subcategory_id) : null;
    if (subcategoryId !== null && !Number.isFinite(subcategoryId)) {
      return res.status(400).json({ message: 'Invalid subcategory_id' });
    }
    if (categoryId !== null && !Number.isFinite(categoryId)) {
      return res.status(400).json({ message: 'Invalid category_id' });
    }

    let categoryLabel = (category ?? '').toString().trim() || null;

    if (subcategoryId !== null) {
      const [subRows] = await db.query(
        'SELECT id, category_id, name FROM expense_subcategories WHERE id = ? AND user_id = ?',
        [subcategoryId, uid]
      );
      if ((subRows as any[]).length === 0) {
        return res.status(400).json({ message: 'Subcategory not found' });
      }
      const sub = (subRows as any[])[0];
      if (categoryId !== null && categoryId !== Number(sub.category_id)) {
        return res.status(400).json({ message: 'Subcategory does not belong to the specified category' });
      }
      categoryId = Number(sub.category_id);
      categoryLabel = sub.name;
    }

    if (categoryId !== null) {
      const [catRows] = await db.query(
        'SELECT id, name FROM expense_categories WHERE id = ? AND user_id = ?',
        [categoryId, uid]
      );
      if ((catRows as any[]).length === 0) {
        return res.status(400).json({ message: 'Category not found' });
      }
      if (!categoryLabel) {
        categoryLabel = (catRows as any[])[0].name;
      }
    }

    if (categoryLabel && categoryLabel.length > 50) {
      categoryLabel = categoryLabel.slice(0, 50);
    }

    await db.query('START TRANSACTION');

    try {
      const [result] = await db.query(
        `INSERT INTO transactions (user_id, account_id, project_id, date, description, amount, type, category, category_id, subcategory_id)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [uid, account_id, project_id || null, date, description, amount, type, categoryLabel, categoryId, subcategoryId]
      );

      await db.query(
        'UPDATE accounts SET balance = balance + ? WHERE id = ? AND user_id = ?',
        [amount, account_id, uid]
      );

      if (project_id) {
        const spentAmount =
          type === 'Expense'
            ? Math.abs(amount)
            : type === 'Income'
            ? -Math.abs(amount)
            : 0;
        if (spentAmount !== 0) {
          await db.query(
            'UPDATE projects SET spent = spent + ? WHERE id = ? AND user_id = ?',
            [spentAmount, project_id, uid]
          );
        }
      }

      const transactionDate = new Date(date);
      const year = transactionDate.getFullYear();
      const month = transactionDate.getMonth() + 1;
      await updateBalanceHistory(uid, account_id, year, month);

      const currentDate = new Date();
      const currentYear = currentDate.getFullYear();
      const currentMonth = currentDate.getMonth() + 1;
      for (let y = year; y <= currentYear; y++) {
        const startMonth = y === year ? month : 1;
        const endMonth = y === currentYear ? currentMonth : 12;
        for (let m = startMonth; m <= endMonth; m++) {
          await updateBalanceHistory(uid, account_id, y, m);
        }
      }

      await syncInvestmentContribution(uid, account_id, (result as any).insertId, amount, date);
      await db.query('COMMIT');

      const inserted = await fetchTransactionWithRelations(uid, (result as any).insertId);
      res.json(inserted);
    } catch (error) {
      await db.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error('Transaction creation error:', error);
    res.status(500).json({ error: 'Failed to create transaction' });
  }
});

router.put('/api/transactions/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    const uid = req.user!.id;
    await ensureInvestmentAccountSchema();
    await ensureTransactionTransferTypeSchema();
    const transactionId = Number(req.params.id);
    const {
      account_id,
      project_id,
      date,
      description,
      amount,
      type,
      category,
      category_id,
      subcategory_id,
    } = req.body;

    const [oldRows] = await db.query(
      'SELECT account_id, project_id, amount, type FROM transactions WHERE id = ? AND user_id = ?',
      [transactionId, uid]
    );
    if ((oldRows as any[]).length === 0) {
      return res.status(404).json({ message: 'Transaction not found' });
    }
    const oldTrans = (oldRows as any[])[0];

    let categoryId: number | null = category_id !== undefined && category_id !== null ? Number(category_id) : null;
    let subcategoryId: number | null = subcategory_id !== undefined && subcategory_id !== null ? Number(subcategory_id) : null;
    if (subcategoryId !== null && !Number.isFinite(subcategoryId)) {
      return res.status(400).json({ message: 'Invalid subcategory_id' });
    }
    if (categoryId !== null && !Number.isFinite(categoryId)) {
      return res.status(400).json({ message: 'Invalid category_id' });
    }

    let categoryLabel = (category ?? '').toString().trim() || null;

    if (subcategoryId !== null) {
      const [subRows] = await db.query(
        'SELECT id, category_id, name FROM expense_subcategories WHERE id = ? AND user_id = ?',
        [subcategoryId, uid]
      );
      if ((subRows as any[]).length === 0) {
        return res.status(400).json({ message: 'Subcategory not found' });
      }
      const sub = (subRows as any[])[0];
      if (categoryId !== null && categoryId !== Number(sub.category_id)) {
        return res.status(400).json({ message: 'Subcategory does not belong to the specified category' });
      }
      categoryId = Number(sub.category_id);
      categoryLabel = sub.name;
    }

    if (categoryId !== null) {
      const [catRows] = await db.query(
        'SELECT id, name FROM expense_categories WHERE id = ? AND user_id = ?',
        [categoryId, uid]
      );
      if ((catRows as any[]).length === 0) {
        return res.status(400).json({ message: 'Category not found' });
      }
      if (!categoryLabel) {
        categoryLabel = (catRows as any[])[0].name;
      }
    }

    if (categoryLabel && categoryLabel.length > 50) {
      categoryLabel = categoryLabel.slice(0, 50);
    }

    await db.query('START TRANSACTION');

    try {
      await db.query(
        `UPDATE transactions
         SET account_id = ?, project_id = ?, date = ?, description = ?, amount = ?, type = ?, category = ?, category_id = ?, subcategory_id = ?
         WHERE id = ? AND user_id = ?`,
        [account_id, project_id || null, date, description, amount, type, categoryLabel, categoryId, subcategoryId, transactionId, uid]
      );

      if (oldTrans.account_id !== account_id) {
        await db.query(
          'UPDATE accounts SET balance = balance - ? WHERE id = ? AND user_id = ?',
          [oldTrans.amount, oldTrans.account_id, uid]
        );
        await db.query(
          'UPDATE accounts SET balance = balance + ? WHERE id = ? AND user_id = ?',
          [amount, account_id, uid]
        );
      } else {
        const difference = amount - oldTrans.amount;
        await db.query(
          'UPDATE accounts SET balance = balance + ? WHERE id = ? AND user_id = ?',
          [difference, account_id, uid]
        );
      }

      if (oldTrans.project_id) {
        const oldSpentAmount =
          oldTrans.type === 'Expense'
            ? Math.abs(oldTrans.amount)
            : oldTrans.type === 'Income'
            ? -Math.abs(oldTrans.amount)
            : 0;
        if (oldSpentAmount !== 0) {
          await db.query(
            'UPDATE projects SET spent = spent - ? WHERE id = ? AND user_id = ?',
            [oldSpentAmount, oldTrans.project_id, uid]
          );
        }
      }

      if (project_id) {
        const newSpentAmount =
          type === 'Expense'
            ? Math.abs(amount)
            : type === 'Income'
            ? -Math.abs(amount)
            : 0;
        if (newSpentAmount !== 0) {
          await db.query(
            'UPDATE projects SET spent = spent + ? WHERE id = ? AND user_id = ?',
            [newSpentAmount, project_id, uid]
          );
        }
      }

      await syncInvestmentContribution(uid, account_id, transactionId, amount, date);
      await db.query('COMMIT');

      const updated = await fetchTransactionWithRelations(uid, transactionId);
      res.json(updated);
    } catch (error) {
      await db.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error('Transaction update error:', error);
    res.status(500).json({ error: 'Failed to update transaction' });
  }
});

router.delete('/api/transactions/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    await ensureInvestmentAccountSchema();
    // Start a transaction to ensure both operations succeed or fail together
    await db.query('START TRANSACTION');
    
    try {
      // Get the transaction to reverse its effect on account balance and project spent
      const [transaction] = await db.query(
        'SELECT account_id, project_id, amount, type FROM transactions WHERE id = ? AND user_id = ?',
        [req.params.id, req.user?.id]
      );
      
      if ((transaction as any[]).length === 0) {
        throw new Error('Transaction not found');
      }
      
      const trans = (transaction as any[])[0];
      
      // Reverse the transaction effect on account balance
      await db.query(
        'UPDATE accounts SET balance = balance - ? WHERE id = ? AND user_id = ?',
        [trans.amount, trans.account_id, req.user?.id]
      );
      
      // Reverse the transaction effect on project spent amount if it was linked to a project
      if (trans.project_id) {
        const spentAmount =
          trans.type === 'Expense'
            ? Math.abs(trans.amount)
            : trans.type === 'Income'
            ? -Math.abs(trans.amount)
            : 0;
        if (spentAmount !== 0) {
          await db.query(
            'UPDATE projects SET spent = spent - ? WHERE id = ? AND user_id = ?',
            [spentAmount, trans.project_id, req.user?.id]
          );
        }
      }
      
      // Delete the transaction
      await db.query('DELETE FROM transactions WHERE id = ? AND user_id = ?', [req.params.id, req.user?.id]);
      await deleteInvestmentContributionByTransaction(req.user!.id, Number(req.params.id));
      
      // Commit the transaction
      await db.query('COMMIT');
      
      res.json({ success: true });
    } catch (error) {
      // Rollback on error
      await db.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error('Transaction deletion error:', error);
    res.status(500).json({ error: 'Failed to delete transaction' });
  }
});

// Balance history routes
router.get('/api/balance-history', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;

    // Ensure we have rows up to the current month for every account.
    const now = new Date();
    const currY = now.getFullYear();
    const currM = now.getMonth() + 1; // 1-based

    // Fetch user accounts
    const [accounts] = await db.query('SELECT id FROM accounts WHERE user_id = ?', [req.user?.id]);
    const accIds = (accounts as any[]).map((r: any) => r.id) as number[];

    // For each account, find last recorded month and backfill through current month
    for (const accId of accIds) {
      const [lastRows] = await db.query(
        `SELECT year, month FROM balance_history 
         WHERE user_id = ? AND account_id = ? 
         ORDER BY year DESC, month DESC LIMIT 1`,
        [req.user?.id, accId]
      );
      if ((lastRows as any[]).length === 0) {
        await updateBalanceHistory(req.user!.id, accId, currY, currM);
        continue;
      }
      const last = (lastRows as any[])[0] as { year: number; month: number };
      let y = last.year;
      let m = last.month;
      while (y < currY || (y === currY && m < currM)) {
        m++;
        if (m > 12) { m = 1; y++; }
        await updateBalanceHistory(req.user!.id, accId, y, m);
      }
    }

    // Return ordered history
    const [balanceHistory] = await db.query(
      `SELECT bh.*, a.name as account_name 
       FROM balance_history bh 
       JOIN accounts a ON bh.account_id = a.id 
       WHERE bh.user_id = ? 
       ORDER BY bh.year DESC, bh.month DESC, a.name ASC`,
      [req.user?.id]
    );
    res.json(balanceHistory);
  } catch (error) {
    console.error('Balance history fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch balance history' });
  }
});

// Project routes
router.get('/api/projects', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const [projects] = await db.query(
      'SELECT * FROM projects WHERE user_id = ? ORDER BY id DESC',
      [req.user?.id]
    );
    res.json(projects);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch projects' });
  }
});

router.post('/api/projects', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const { name, description, budget, spent, status, start_date, end_date } = req.body;

    // Basic validation and coercion
    const allowedStatuses = ['Active', 'On Hold', 'Completed'];
    const budgetNum = Number(budget);
    const spentNum = Number(spent ?? 0);

    if (!name || typeof name !== 'string') {
      return res.status(400).json({ message: 'Project name is required' });
    }
    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }
    if (Number.isNaN(budgetNum)) {
      return res.status(400).json({ message: 'Budget must be a number' });
    }
    if (Number.isNaN(spentNum)) {
      return res.status(400).json({ message: 'Spent must be a number' });
    }
    // Expect YYYY-MM-DD
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(start_date) || !dateRegex.test(end_date)) {
      return res.status(400).json({ message: 'Dates must be in YYYY-MM-DD format' });
    }

    // Debug payload (development only)
    if (process.env.NODE_ENV !== 'production') {
      console.log('Create project payload:', {
        user_id: req.user?.id,
        name,
        description,
        budget,
        budgetNum,
        spent,
        spentNum,
        status,
        start_date,
        end_date
      });
    }

    const desc = description ?? '';
    const [result] = await db.query(
      'INSERT INTO projects (user_id, name, description, budget, spent, status, start_date, end_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [req.user?.id, name, desc, budgetNum, spentNum, status, start_date, end_date]
    );
    
    const insertId = (result as any).insertId;
    const [newProject] = await db.query('SELECT * FROM projects WHERE id = ?', [insertId]);
    res.json((newProject as any[])[0]);
  } catch (error: any) {
    const code = error?.code;
    const detail = error?.sqlMessage || error?.message;
    console.error('Project create error:', code, detail);
    if (code === 'ER_NO_DEFAULT_FOR_FIELD' || code === 'ER_BAD_NULL_ERROR' || code === 'ER_TRUNCATED_WRONG_VALUE') {
      return res.status(400).json({ message: detail || 'Invalid data', code });
    }
    res.status(500).json({ message: 'Failed to create project', code });
  }
});

router.put('/api/projects/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const { name, description, budget, spent, status, start_date, end_date } = req.body;

    const allowedStatuses = ['Active', 'On Hold', 'Completed'];
    const budgetNum = Number(budget);
    const spentNum = Number(spent ?? 0);
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;

    if (!name || typeof name !== 'string') {
      return res.status(400).json({ message: 'Project name is required' });
    }
    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }
    if (Number.isNaN(budgetNum) || Number.isNaN(spentNum)) {
      return res.status(400).json({ message: 'Budget/Spent must be numbers' });
    }
    if (!dateRegex.test(start_date) || !dateRegex.test(end_date)) {
      return res.status(400).json({ message: 'Dates must be in YYYY-MM-DD format' });
    }

    const desc = description ?? '';
    await db.query(
      'UPDATE projects SET name = ?, description = ?, budget = ?, spent = ?, status = ?, start_date = ?, end_date = ? WHERE id = ? AND user_id = ?',
      [name, desc, budgetNum, spentNum, status, start_date, end_date, req.params.id, req.user?.id]
    );
    
    const [updated] = await db.query('SELECT * FROM projects WHERE id = ? AND user_id = ?', [req.params.id, req.user?.id]);
    res.json((updated as any[])[0]);
  } catch (error: any) {
    const code = error?.code;
    const detail = error?.sqlMessage || error?.message;
    console.error('Project update error:', code, detail);
    if (code === 'ER_NO_DEFAULT_FOR_FIELD' || code === 'ER_BAD_NULL_ERROR' || code === 'ER_TRUNCATED_WRONG_VALUE') {
      return res.status(400).json({ message: detail || 'Invalid data', code });
    }
    res.status(500).json({ message: 'Failed to update project', code });
  }
});

router.delete('/api/projects/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    await db.query('DELETE FROM projects WHERE id = ? AND user_id = ?', [req.params.id, req.user?.id]);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete project' });
  }
});

// Payment routes
router.get('/api/payments', authenticateToken, async (req: Request, res: Response) => {
  try {
    // First, let's check what projects exist for this user
    const [userProjects] = await db.query(
      'SELECT * FROM projects WHERE user_id = ?',
      [req.user?.id]
    );
    console.log('User projects:', userProjects);
    
    const [payments] = await db.query(
      `SELECT p.*, a.name as account_name, pr.name as project_name
       FROM payments p 
       LEFT JOIN accounts a ON p.account_id = a.id 
       LEFT JOIN projects pr ON p.project_id = pr.id AND pr.user_id = p.user_id
       WHERE p.user_id = ? 
       ORDER BY p.next_date ASC`,
      [req.user?.id]
    );
    console.log('Fetched payments:', payments);
    res.json(payments);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch payments' });
  }
});

router.post('/api/payments', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { account_id, name, description, amount, frequency, next_date, is_active, category, project_id } = req.body;
    console.log('Creating payment with project_id:', project_id);
    const actualProjectId = project_id && project_id !== 0 ? project_id : null;
    console.log('Actual project_id to save:', actualProjectId);
    const [result] = await db.query(
      'INSERT INTO payments (user_id, account_id, name, description, amount, frequency, next_date, is_active, category, project_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [req.user?.id, account_id, name, description, amount, frequency, next_date, is_active, category, actualProjectId]
    );
    
    const insertId = (result as any).insertId;
    const [newPayment] = await db.query(
      `SELECT p.*, a.name as account_name, pr.name as project_name
       FROM payments p 
       LEFT JOIN accounts a ON p.account_id = a.id 
       LEFT JOIN projects pr ON p.project_id = pr.id AND pr.user_id = p.user_id
       WHERE p.id = ?`,
      [insertId]
    );
    
    console.log('New payment created:', (newPayment as any[])[0]);
    console.log('Project lookup - project_id:', (newPayment as any[])[0].project_id);
    
    // Let's also check if the project exists
    if ((newPayment as any[])[0].project_id) {
      const [projectCheck] = await db.query(
        'SELECT * FROM projects WHERE id = ? AND user_id = ?',
        [(newPayment as any[])[0].project_id, req.user?.id]
      );
      console.log('Project exists:', projectCheck);
    }
    
    res.json((newPayment as any[])[0]);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create payment' });
  }
});

// Create a credit card installment plan (finite monthly payments)
router.post('/api/credit/installments', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { account_id, project_id, name, description, total_amount, months, first_due_date, category } = req.body;

    // Validate inputs
    const total = Number(total_amount);
    const monthsInt = Number(months);
    if (!account_id) return res.status(400).json({ message: 'account_id is required' });
    if (!name || typeof name !== 'string') return res.status(400).json({ message: 'name is required' });
    if (!first_due_date) return res.status(400).json({ message: 'first_due_date is required' });
    if (!monthsInt || monthsInt < 1) return res.status(400).json({ message: 'months must be >= 1' });
    if (Number.isNaN(total) || total <= 0) return res.status(400).json({ message: 'total_amount must be > 0' });

    // Ensure account is a Credit account owned by user
    const [acctRows] = await db.query('SELECT id, type FROM accounts WHERE id = ? AND user_id = ?', [account_id, req.user?.id]);
    const acct = (acctRows as any[])[0];
    if (!acct) return res.status(404).json({ message: 'Account not found' });
    if (acct.type !== 'Credit') return res.status(400).json({ message: 'Installments allowed only on Credit accounts' });

    // Compute monthly amount (2 decimals), remainder handled in processor on last payment
    const monthly = Math.round((total / monthsInt) * 100) / 100;

    const [result] = await db.query(
      `INSERT INTO payments (
        user_id, account_id, project_id, name, description, amount, frequency, next_date, is_active, category,
        installments_total, installments_remaining, installment_total_amount
      ) VALUES (?, ?, ?, ?, ?, ?, 'Monthly', ?, TRUE, ?, ?, ?, ?)`,
      [
        req.user?.id,
        account_id,
        project_id || null,
        name,
        description ?? '',
        monthly,
        first_due_date,
        category ?? 'Subscriptions',
        monthsInt,
        monthsInt,
        total,
      ]
    );

    const insertId = (result as any).insertId;
    const [newPayment] = await db.query(
      `SELECT p.*, a.name as account_name, pr.name as project_name
       FROM payments p 
       LEFT JOIN accounts a ON p.account_id = a.id 
       LEFT JOIN projects pr ON p.project_id = pr.id AND pr.user_id = p.user_id
       WHERE p.id = ?`,
      [insertId]
    );
    res.json((newPayment as any[])[0]);
  } catch (error: any) {
    console.error('Create installments error:', error?.code || error?.message || error);
    res.status(500).json({ message: 'Failed to create installment plan' });
  }
});

router.put('/api/payments/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { account_id, name, description, amount, frequency, next_date, is_active, category, project_id } = req.body;
    const actualProjectId = project_id && project_id !== 0 ? project_id : null;
    await db.query(
      'UPDATE payments SET account_id = ?, name = ?, description = ?, amount = ?, frequency = ?, next_date = ?, is_active = ?, category = ?, project_id = ? WHERE id = ? AND user_id = ?',
      [account_id, name, description, amount, frequency, next_date, is_active, category, actualProjectId, req.params.id, req.user?.id]
    );
    
    const [updated] = await db.query(
      `SELECT p.*, a.name as account_name, pr.name as project_name
       FROM payments p 
       LEFT JOIN accounts a ON p.account_id = a.id 
       LEFT JOIN projects pr ON p.project_id = pr.id AND pr.user_id = p.user_id
       WHERE p.id = ? AND p.user_id = ?`,
      [req.params.id, req.user?.id]
    );
    res.json((updated as any[])[0]);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update payment' });
  }
});

router.delete('/api/payments/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    await db.query('DELETE FROM payments WHERE id = ? AND user_id = ?', [req.params.id, req.user?.id]);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete payment' });
  }
});

// Register device token for push notifications
router.post('/api/device-tokens', authenticateToken, async (req: Request, res: Response) => {
  try {
    const uid = req.user!.id;
    const token = (req.body?.token ?? '').toString().trim();
    if (!token) {
      return res.status(400).json({ message: 'token is required' });
    }
    const platform =
      req.body?.platform != null
        ? String(req.body.platform).trim().slice(0, 32)
        : null;
    const tzOffsetRaw = req.body?.timezone_offset_min;
    const tzNameRaw = req.body?.timezone_name;
    const tzOffset =
      tzOffsetRaw === undefined || tzOffsetRaw === null
        ? null
        : Number(tzOffsetRaw);
    if (tzOffset != null && !Number.isFinite(tzOffset)) {
      return res.status(400).json({ message: 'timezone_offset_min invalid' });
    }
    const tzName =
      tzNameRaw == null
        ? null
        : String(tzNameRaw).trim().slice(0, 64) || null;

    await db.query(
      `INSERT INTO device_tokens (user_id, token, platform)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE platform = VALUES(platform)`,
      [uid, token.slice(0, 255), platform]
    );

    if (tzOffset != null || tzName != null) {
      const fields: string[] = [];
      const values: any[] = [];
      if (tzOffset != null) {
        fields.push('timezone_offset_min = ?');
        values.push(tzOffset);
      }
      if (tzName != null) {
        fields.push('timezone_name = ?');
        values.push(tzName);
      }
      values.push(uid);
      await db.query(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, values);
    }

    res.json({ success: true });
  } catch (e) {
    console.error('Device token register error:', e);
    res.status(500).json({ message: 'Failed to register device token' });
  }
});

// Notifications endpoint: payments due tomorrow and invoices due tomorrow (not paid/void)
router.get('/api/notifications', authenticateToken, async (req: Request, res: Response) => {
  try {
    const maxDays = 30;
    const rawDays = Number.parseInt(String(req.query.days ?? '7'), 10);
    const days = Math.min(maxDays, Math.max(1, Number.isNaN(rawDays) ? 7 : rawDays));
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(endDate.getDate() - (days - 1));
    const formatYmd = (date: Date) => {
      const y = date.getFullYear();
      const m = (date.getMonth() + 1).toString().padStart(2, '0');
      const d = date.getDate().toString().padStart(2, '0');
      return `${y}-${m}-${d}`;
    };
    const startYmd = formatYmd(startDate);
    const endYmd = formatYmd(endDate);

    const [pRows] = await db.query(
      `SELECT p.id, p.name, p.next_date, p.amount, a.name as account_name
       FROM payments p
       LEFT JOIN accounts a ON a.id = p.account_id
       WHERE p.user_id = ? AND p.is_active = TRUE AND DATE(p.next_date) BETWEEN ? AND ?`,
      [req.user?.id, startYmd, endYmd]
    );

    const [iRows] = await db.query(
      `SELECT i.id, i.number, i.due_date, i.total, i.amount_due, c.name AS customer_name
       FROM invoices i JOIN customers c ON c.id = i.customer_id
       WHERE i.user_id = ? AND i.status NOT IN ('paid','void') AND DATE(i.due_date) BETWEEN ? AND ?`,
      [req.user?.id, startYmd, endYmd]
    );

    const notifications: any[] = [];
    for (const p of pRows as any[]) {
      const name = p.account_name ? `${p.name} (${p.account_name})` : p.name;
      notifications.push({
        type: 'payment_due',
        title: 'Payment due',
        message: `${name} - Due ${p.next_date}`,
        date: p.next_date,
      });
    }
    for (const inv of iRows as any[]) {
      const label = `${inv.number || '#' + inv.id} - ${inv.customer_name}`;
      notifications.push({
        type: 'invoice_due',
        title: 'Invoice due',
        message: `${label} - Due ${inv.due_date}`,
        date: inv.due_date,
      });
    }
    notifications.sort((a, b) => (a.date > b.date ? -1 : 1));
    res.json(notifications);
  } catch (e) {
    console.error('Notifications error:', e);
    res.status(500).json({ message: 'Failed to load notifications' });
  }
});

router.post('/api/notifications/push-now', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!isFcmConfigured()) {
      return res.status(400).json({ message: 'FCM_SERVICE_ACCOUNT_JSON not configured' });
    }

    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const y = tomorrow.getFullYear();
    const m = (tomorrow.getMonth() + 1).toString().padStart(2, '0');
    const d = tomorrow.getDate().toString().padStart(2, '0');
    const ymd = `${y}-${m}-${d}`;

    const [pRows] = await db.query(
      `SELECT p.id, p.name, p.next_date, p.amount, a.name as account_name
       FROM payments p
       LEFT JOIN accounts a ON a.id = p.account_id
       WHERE p.user_id = ? AND p.is_active = TRUE AND DATE(p.next_date) = ?`,
      [req.user?.id, ymd]
    );
    const [iRows] = await db.query(
      `SELECT i.id, i.number, i.due_date, i.total, i.amount_due, c.name AS customer_name
       FROM invoices i JOIN customers c ON c.id = i.customer_id
       WHERE i.user_id = ? AND i.status NOT IN ('paid','void') AND DATE(i.due_date) = ?`,
      [req.user?.id, ymd]
    );
    const notifications: { title: string; body: string; data?: Record<string, string> }[] = [];
    for (const p of pRows as any[]) {
      notifications.push({
        title: 'Payment due tomorrow',
        body: `${p.name} (${p.account_name})`,
        data: {
          target_type: 'payment',
          target_id: String(p.id),
          notification_type: 'payment_due_tomorrow',
        },
      });
    }
    for (const inv of iRows as any[]) {
      notifications.push({
        title: 'Invoice due tomorrow',
        body: `${inv.number || '#' + inv.id} - ${inv.customer_name}`,
        data: {
          target_type: 'invoice',
          target_id: String(inv.id),
          notification_type: 'invoice_due_tomorrow',
        },
      });
    }

    const [tokensRows] = await db.query('SELECT token FROM device_tokens WHERE user_id = ?', [req.user?.id]);
    const tokens = (tokensRows as any[]).map(r => r.token).filter(Boolean);
    if (tokens.length === 0 || notifications.length === 0) {
      return res.json({ success: true, sent: 0, tokens: tokens.length, notifications: notifications.length });
    }

    let sent = 0;
    for (const note of notifications) {
      const delivered = await sendFcmNotification(tokens, note, note.data);
      if (delivered > 0) sent += 1;
    }
    res.json({ success: true, sent, tokens: tokens.length, notifications: notifications.length });
  } catch (e) {
    console.error('Push now error:', e);
    res.status(500).json({ message: 'Failed to push notifications' });
  }
});
// Process overdue recurring payments
router.post('/api/payments/process-overdue', authenticateToken, async (req: Request, res: Response) => {
  try {
    await ensureInvestmentAccountSchema();
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD format
    
    // Get all overdue active payments for the user
    const [overduePayments] = await db.query(
      'SELECT * FROM payments WHERE user_id = ? AND is_active = TRUE AND next_date <= ?',
      [req.user?.id, today]
    );
    
    const processedPayments: any[] = [];
    
    for (const payment of overduePayments as any[]) {
      // Start a transaction to ensure all operations succeed or fail together
      await db.query('START TRANSACTION');
      
      try {
        // Determine charge amount (handle installments' last payment rounding)
        let amountToCharge = Math.abs(payment.amount);
        const installmentsTotal = payment.installments_total as number | null;
        const installmentsRemaining = payment.installments_remaining as number | null;
        const installmentTotal = payment.installment_total_amount as number | null;

        if (installmentsTotal && installmentsRemaining) {
          if (installmentsRemaining === 1 && installmentTotal) {
            const alreadyPlanned = Math.round((amountToCharge * (installmentsTotal - 1)) * 100) / 100;
            const last = Math.round((installmentTotal - alreadyPlanned) * 100) / 100;
            amountToCharge = Math.abs(last);
          }
        }

        // Create a transaction record for this payment
        const [transactionResult] = await db.query(
          'INSERT INTO transactions (user_id, account_id, date, description, amount, type, category, project_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            req.user?.id,
            payment.account_id,
            payment.next_date,
            payment.name,
            -Math.abs(amountToCharge),
            'Expense',
            payment.category,
            payment.project_id || null,
          ]
        );
        
        // Update account balance
        await db.query(
          'UPDATE accounts SET balance = balance - ? WHERE id = ? AND user_id = ?',
          [Math.abs(amountToCharge), payment.account_id, req.user?.id]
        );
        
        // Update project spent amount if payment is linked to a project
        if (payment.project_id) {
          await db.query(
            'UPDATE projects SET spent = spent + ? WHERE id = ? AND user_id = ?',
            [Math.abs(amountToCharge), payment.project_id, req.user?.id]
          );
        }
        
        // Calculate next due date based on frequency
        let nextDate = new Date(payment.next_date);
        switch (payment.frequency) {
          case 'Weekly':
            nextDate.setDate(nextDate.getDate() + 7);
            break;
          case 'Monthly':
            nextDate.setMonth(nextDate.getMonth() + 1);
            break;
          case 'Quarterly':
            nextDate.setMonth(nextDate.getMonth() + 3);
            break;
          case 'Yearly':
            nextDate.setFullYear(nextDate.getFullYear() + 1);
            break;
        }
        
        // Update installments counters if applicable
        if (installmentsTotal && installmentsRemaining) {
          const newRemaining = installmentsRemaining - 1;
          if (newRemaining <= 0) {
            // Completed plan: deactivate payment and do not advance date further
            await db.query('UPDATE payments SET is_active = FALSE, installments_remaining = 0 WHERE id = ?', [payment.id]);
          } else {
            // Advance date for next installment and decrement counter
            await db.query(
              'UPDATE payments SET next_date = ?, installments_remaining = ? WHERE id = ?',
              [nextDate.toISOString().split('T')[0], newRemaining, payment.id]
            );
          }
        } else {
          // Regular recurring payment: just update next_date
          await db.query(
            'UPDATE payments SET next_date = ? WHERE id = ?',
            [nextDate.toISOString().split('T')[0], payment.id]
          );
        }
        
        // Update balance history for this month
        const transactionDate = new Date(payment.next_date);
        const year = transactionDate.getFullYear();
        const month = transactionDate.getMonth() + 1;
        await updateBalanceHistory(req.user?.id!, payment.account_id, year, month);
        await syncInvestmentContribution(
          req.user!.id,
          payment.account_id,
          (transactionResult as any).insertId,
          -Math.abs(amountToCharge),
          payment.next_date
        );
        
        // Commit the transaction
        await db.query('COMMIT');
        
        processedPayments.push({
          payment_id: payment.id,
          payment_name: payment.name,
          amount: payment.amount,
          next_date: nextDate.toISOString().split('T')[0],
          transaction_id: (transactionResult as any).insertId
        });
        
      } catch (error) {
        // Rollback on error
        await db.query('ROLLBACK');
        throw error;
      }
    }
    
    res.json({
      success: true,
      processed_count: processedPayments.length,
      processed_payments: processedPayments
    });
    
  } catch (error) {
    console.error('Error processing overdue payments:', error);
    res.status(500).json({ error: 'Failed to process overdue payments' });
  }
});

// Process a single recurring payment if due (today or past) and active
router.post('/api/payments/:id/process', authenticateToken, async (req: Request, res: Response) => {
  try {
    await ensureInvestmentAccountSchema();
    const uid = req.user?.id!;
    const id = Number(req.params.id);
    if (!id || Number.isNaN(id)) return res.status(400).json({ message: 'Invalid payment id' });

    const today = new Date().toISOString().split('T')[0];
    const [rows] = await db.query('SELECT * FROM payments WHERE id = ? AND user_id = ? LIMIT 1', [id, uid]);
    if ((rows as any[]).length === 0) return res.status(404).json({ message: 'Payment not found' });
    const payment: any = (rows as any[])[0];
    if (!payment.is_active) return res.status(400).json({ message: 'Payment is inactive' });
    if (payment.next_date > today) return res.status(400).json({ message: 'Payment is not due yet' });

    await db.query('START TRANSACTION');
    try {
      let amountToCharge = Math.abs(payment.amount);
      const installmentsTotal = payment.installments_total as number | null;
      const installmentsRemaining = payment.installments_remaining as number | null;
      const installmentTotal = payment.installment_total_amount as number | null;

      if (installmentsTotal && installmentsRemaining) {
        if (installmentsRemaining === 1 && installmentTotal) {
          const alreadyPlanned = Math.round((amountToCharge * (installmentsTotal - 1)) * 100) / 100;
          const last = Math.round((installmentTotal - alreadyPlanned) * 100) / 100;
          amountToCharge = Math.abs(last);
        }
      }

      const [txRes] = await db.query(
        'INSERT INTO transactions (user_id, account_id, date, description, amount, type, category, project_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [uid, payment.account_id, payment.next_date, payment.name, -Math.abs(amountToCharge), 'Expense', payment.category, payment.project_id || null]
      );

      await db.query('UPDATE accounts SET balance = balance - ? WHERE id = ? AND user_id = ?', [Math.abs(amountToCharge), payment.account_id, uid]);
      if (payment.project_id) {
        await db.query('UPDATE projects SET spent = spent + ? WHERE id = ? AND user_id = ?', [Math.abs(amountToCharge), payment.project_id, uid]);
      }

      // advance next_date
      let nextDate = new Date(payment.next_date);
      switch (payment.frequency) {
        case 'Weekly':
          nextDate.setDate(nextDate.getDate() + 7); break;
        case 'Monthly':
          nextDate.setMonth(nextDate.getMonth() + 1); break;
        case 'Quarterly':
          nextDate.setMonth(nextDate.getMonth() + 3); break;
        case 'Yearly':
          nextDate.setFullYear(nextDate.getFullYear() + 1); break;
      }

      if (installmentsTotal && installmentsRemaining) {
        const newRemaining = installmentsRemaining - 1;
        if (newRemaining <= 0) {
          await db.query('UPDATE payments SET is_active = FALSE, installments_remaining = 0 WHERE id = ?', [payment.id]);
        } else {
          await db.query('UPDATE payments SET next_date = ?, installments_remaining = ? WHERE id = ?', [nextDate.toISOString().split('T')[0], newRemaining, payment.id]);
        }
      } else {
        await db.query('UPDATE payments SET next_date = ? WHERE id = ?', [nextDate.toISOString().split('T')[0], payment.id]);
      }

      const transactionDate = new Date(payment.next_date);
      const year = transactionDate.getFullYear();
      const month = transactionDate.getMonth() + 1;
      await updateBalanceHistory(uid, payment.account_id, year, month);
      await syncInvestmentContribution(
        uid,
        payment.account_id,
        (txRes as any).insertId,
        -Math.abs(amountToCharge),
        payment.next_date
      );

      await db.query('COMMIT');
      return res.json({ success: true, payment_id: payment.id, transaction_id: (txRes as any).insertId, next_date: nextDate.toISOString().split('T')[0] });
    } catch (e) {
      await db.query('ROLLBACK');
      throw e;
    }
  } catch (e) {
    console.error('Error processing single payment:', e);
    res.status(500).json({ error: 'Failed to process payment' });
  }
});

// ===== Investments =====
// List investments with contributions-aware totals
router.get('/api/investments', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    await ensureInvestmentAccountSchema();
    const uid = req.user?.id;
    // Return base fields plus totals, and an estimated value that includes contributions compounded from their dates
    const [rows] = await db.query(
      `SELECT i.id, i.name, i.principal, i.annual_rate, i.start_date, i.account_id,
              COALESCE((SELECT SUM(c.amount) FROM investment_contributions c WHERE c.investment_id = i.id), 0) AS total_contributions,
              (i.principal * POW(1 + (i.annual_rate/100)/365, GREATEST(DATEDIFF(CURDATE(), i.start_date), 0))) 
                + COALESCE((SELECT SUM(c.amount * POW(1 + (i.annual_rate/100)/365, GREATEST(DATEDIFF(CURDATE(), c.date), 0))) FROM investment_contributions c WHERE c.investment_id = i.id), 0)
                AS estimated_value
       FROM investments i
       WHERE i.user_id = ?
       ORDER BY i.created_at DESC`,
      [uid]
    );
    res.json(rows);
  } catch (e) {
    console.error('Failed to fetch investments:', e);
    res.status(500).json({ message: 'Failed to fetch investments' });
  }
});

  router.post('/api/investments', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    await ensureInvestmentAccountSchema();
    const { name, principal, annual_rate, start_date } = req.body;
    if (!name || principal == null || annual_rate == null || !start_date) {
      return res.status(400).json({ message: 'Missing required fields' });
    }
    const p = Number(principal);
    const r = Number(annual_rate);
    if (!Number.isFinite(p) || p < 0) {
      return res.status(400).json({ message: 'Invalid principal' });
    }
    if (!Number.isFinite(r) || r < 0 || r > 100000) {
      return res.status(400).json({ message: 'Invalid annual rate (0-100000%)' });
    }
    const dateStr = new Date(start_date).toISOString().slice(0, 10);
    await db.query('START TRANSACTION');
    try {
      const [accountResult] = await db.query(
        'INSERT INTO accounts (user_id, name, type, balance, account_number, bank_name, is_active) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [req.user?.id, name, 'Investment', p, null, null, true]
      );
      const accountId = (accountResult as any).insertId;
      const [result] = await db.query(
        'INSERT INTO investments (user_id, name, principal, annual_rate, start_date, account_id) VALUES (?, ?, ?, ?, ?, ?)',
        [req.user?.id, name, p, r, dateStr, accountId]
      );
      await db.query('COMMIT');
      const id = (result as any).insertId;
      const [row] = await db.query('SELECT * FROM investments WHERE id = ?', [id]);
      res.json((row as any[])[0]);
    } catch (err) {
      await db.query('ROLLBACK');
      throw err;
    }
  } catch (e) {
    console.error('Create investment error:', e);
    res.status(500).json({ message: 'Failed to create investment' });
  }
  });


  router.put('/api/investments/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    await ensureInvestmentAccountSchema();
    const { name, principal, annual_rate, start_date } = req.body;
    const p = Number(principal);
    const r = Number(annual_rate);
    if (!Number.isFinite(p) || p < 0) {
      return res.status(400).json({ message: 'Invalid principal' });
    }
    if (!Number.isFinite(r) || r < 0 || r > 100000) {
      return res.status(400).json({ message: 'Invalid annual rate (0-100000%)' });
    }
    const dateStr = new Date(start_date).toISOString().slice(0, 10);

    const [existing] = await db.query('SELECT account_id FROM investments WHERE id = ? AND user_id = ?', [
      req.params.id,
      req.user?.id
    ]);
    if ((existing as any[]).length === 0) {
      return res.status(404).json({ message: 'Investment not found' });
    }
    let accountId = (existing as any[])[0].account_id as number | null;
    if (!accountId) {
      const [accResult] = await db.query(
        'INSERT INTO accounts (user_id, name, type, balance, account_number, bank_name, is_active) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [req.user?.id, name, 'Investment', p, null, null, true]
      );
      accountId = (accResult as any).insertId as number;
    }

    await db.query(
      'UPDATE investments SET name = ?, principal = ?, annual_rate = ?, start_date = ?, account_id = ? WHERE id = ? AND user_id = ?',
      [name, p, r, dateStr, accountId, req.params.id, req.user?.id]
    );

    if (accountId) {
      const [sumRow] = await db.query(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM investment_contributions WHERE investment_id = ?',
        [req.params.id]
      );
      const totalContrib = Number((sumRow as any[])[0]?.total ?? 0);
      const balance = p + totalContrib;
      await db.query('UPDATE accounts SET name = ?, balance = ? WHERE id = ? AND user_id = ?', [
        name,
        balance,
        accountId,
        req.user?.id
      ]);
    }

    const [row] = await db.query('SELECT * FROM investments WHERE id = ? AND user_id = ?', [req.params.id, req.user?.id]);
    res.json((row as any[])[0]);
  } catch (e) {
    console.error('Update investment error:', e);
    res.status(500).json({ message: 'Failed to update investment' });
  }
  });

  router.delete('/api/investments/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    await ensureInvestmentAccountSchema();
    await db.query('START TRANSACTION');
    try {
      const [rows] = await db.query('SELECT account_id FROM investments WHERE id = ? AND user_id = ?', [
        req.params.id,
        req.user?.id
      ]);
      if ((rows as any[]).length === 0) {
        await db.query('ROLLBACK');
        return res.status(404).json({ message: 'Investment not found' });
      }
      const accountId = (rows as any[])[0].account_id as number | null;
      await db.query('DELETE FROM investment_contributions WHERE investment_id = ?', [req.params.id]);
      await db.query('DELETE FROM investments WHERE id = ? AND user_id = ?', [req.params.id, req.user?.id]);
      if (accountId) {
        await db.query('DELETE FROM accounts WHERE id = ? AND user_id = ?', [accountId, req.user?.id]);
      }
      await db.query('COMMIT');
      res.json({ success: true });
    } catch (err) {
      await db.query('ROLLBACK');
      throw err;
    }
  } catch (e) {
    res.status(500).json({ message: 'Failed to delete investment' });
  }
  });

// Investment detail + contributions
router.get('/api/investments/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    await ensureInvestmentAccountSchema();
    const uid = req.user?.id;
    const invId = Number(req.params.id);
    if (!Number.isFinite(invId)) return res.status(400).json({ message: 'Invalid investment id' });
    const [[investmentRows], [contribRows]]: any = await Promise.all([
      db.query('SELECT * FROM investments WHERE id = ? AND user_id = ?', [invId, uid]),
      db.query('SELECT id, amount, date, created_at FROM investment_contributions WHERE investment_id = ? ORDER BY date ASC, id ASC', [invId])
    ]);
    const investment = (investmentRows as any[])[0];
    if (!investment) return res.status(404).json({ message: 'Not found' });
    res.json({ investment, contributions: contribRows });
  } catch (e) {
    console.error('Failed to fetch investment detail:', e);
    res.status(500).json({ message: 'Failed to fetch investment detail' });
  }
});

// Add a contribution
router.post('/api/investments/:id/contributions', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    await ensureInvestmentAccountSchema();
    const uid = req.user?.id;
    const invId = Number(req.params.id);
    const amount = Number(req.body?.amount);
    const dateStr = new Date(req.body?.date).toISOString().slice(0, 10);
    if (!Number.isFinite(invId) || !Number.isFinite(amount) || amount === 0 || !dateStr) {
      return res.status(400).json({ message: 'Invalid payload' });
    }
    // Validate ownership
    const [invRows] = await db.query('SELECT id, account_id FROM investments WHERE id = ? AND user_id = ?', [invId, uid]);
    if ((invRows as any[]).length === 0) return res.status(404).json({ message: 'Investment not found' });
    const [result] = await db.query(
      'INSERT INTO investment_contributions (user_id, investment_id, amount, date) VALUES (?, ?, ?, ?)',
      [uid, invId, amount, dateStr]
    );
    const accountId = (invRows as any[])[0].account_id as number | null;
    if (accountId) {
      await db.query('UPDATE accounts SET balance = balance + ? WHERE id = ? AND user_id = ?', [amount, accountId, uid]);
      const d = new Date(dateStr);
      await updateBalanceHistory(uid, accountId, d.getFullYear(), d.getMonth() + 1);
    }
    res.json({ id: (result as any).insertId, investment_id: invId, amount, date: dateStr });
  } catch (e) {
    console.error('Failed to add contribution:', e);
    res.status(500).json({ message: 'Failed to add contribution' });
  }
});

// ===== Salary Rules (Automated Income) =====
router.get('/api/salaries', authenticateToken, async (req: Request, res: Response) => {
  try {
    await ensureSalaryAutomationSchema();
    await processDueSalaryRules(req.user!.id);
    const [rows] = await db.query(
      `SELECT s.id, s.name, s.amount, s.schedule, s.weekday, s.day, s.account_id, s.is_active, s.next_date,
              s.created_at, s.updated_at, a.name AS account_name
       FROM salary_rules s
       LEFT JOIN accounts a ON a.id = s.account_id AND a.user_id = s.user_id
       WHERE s.user_id = ?
       ORDER BY s.created_at DESC`,
      [req.user?.id]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ message: 'Failed to fetch salary rules' });
  }
});

router.post('/api/salaries', authenticateToken, async (req: Request, res: Response) => {
  try {
    await ensureSalaryAutomationSchema();
    const { name, amount, schedule, weekday, day, account_id, is_active } = req.body || {};
    if (!name) return res.status(400).json({ message: 'name is required' });
    const amt = Number(amount);
    if (!Number.isFinite(amt)) return res.status(400).json({ message: 'amount invalid' });
    const sch = schedule || 'SemiMonthly';
    if (!['Weekly', 'Monthly', 'SemiMonthly'].includes(sch)) return res.status(400).json({ message: 'schedule invalid' });
    const weekdayNum = weekday == null || weekday === '' ? null : Number(weekday);
    const dayNum = day == null || day === '' ? null : Number(day);
    const accountIdNum = account_id == null || account_id === '' ? null : Number(account_id);
    if (weekdayNum != null && !Number.isFinite(weekdayNum)) return res.status(400).json({ message: 'weekday invalid' });
    if (dayNum != null && !Number.isFinite(dayNum)) return res.status(400).json({ message: 'day invalid' });
    if (accountIdNum != null && !Number.isFinite(accountIdNum)) return res.status(400).json({ message: 'account invalid' });
    const active = is_active ?? true;
    const today = startOfDay(new Date());
    const initialNextDate =
      active && accountIdNum
        ? computeFirstSalaryDate({ schedule: sch, weekday: weekdayNum, day: dayNum }, today)
        : null;
    const nextDateStr = formatDateOnly(initialNextDate);
    const [result] = await db.query(
      'INSERT INTO salary_rules (user_id, name, amount, schedule, weekday, day, account_id, is_active, next_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [req.user?.id, name, amt, sch, weekdayNum, dayNum, accountIdNum, active, nextDateStr]
    );
    const id = (result as any).insertId;
    const [row] = await db.query(
      `SELECT s.id, s.name, s.amount, s.schedule, s.weekday, s.day, s.account_id, s.is_active, s.next_date,
              s.created_at, s.updated_at, a.name AS account_name
       FROM salary_rules s LEFT JOIN accounts a ON a.id = s.account_id AND a.user_id = s.user_id
       WHERE s.id = ?`,
      [id]
    );
    await processDueSalaryRules(req.user!.id);
    res.json((row as any[])[0]);
  } catch (e) {
    res.status(500).json({ message: 'Failed to create salary rule' });
  }
});

router.put('/api/salaries/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    await ensureSalaryAutomationSchema();
    const { name, amount, schedule, weekday, day, account_id, is_active } = req.body || {};

    const [existingRows] = await db.query(
      'SELECT * FROM salary_rules WHERE id = ? AND user_id = ?',
      [req.params.id, req.user?.id]
    );
    if ((existingRows as any[]).length === 0) {
      return res.status(404).json({ message: 'Salary rule not found' });
    }
    const current = (existingRows as any[])[0];

    const updatedName = name ?? current.name;
    const updatedAmount =
      amount === undefined || amount === null ? Number(current.amount) : Number(amount);
    if (!Number.isFinite(updatedAmount)) {
      return res.status(400).json({ message: 'amount invalid' });
    }

    const updatedSchedule = schedule ?? current.schedule;
    if (!['Weekly', 'Monthly', 'SemiMonthly'].includes(updatedSchedule)) {
      return res.status(400).json({ message: 'schedule invalid' });
    }

    const weekdaySupplied = weekday !== undefined;
    const daySupplied = day !== undefined;
    const accountSupplied = account_id !== undefined;

    const updatedWeekday = weekdaySupplied
      ? weekday == null || weekday === ''
        ? null
        : Number(weekday)
      : current.weekday;
    if (weekdaySupplied && updatedWeekday != null && !Number.isFinite(updatedWeekday)) {
      return res.status(400).json({ message: 'weekday invalid' });
    }

    const updatedDay = daySupplied
      ? day == null || day === ''
        ? null
        : Number(day)
      : current.day;
    if (daySupplied && updatedDay != null && !Number.isFinite(updatedDay)) {
      return res.status(400).json({ message: 'day invalid' });
    }

    const updatedAccountId = accountSupplied
      ? account_id == null || account_id === ''
        ? null
        : Number(account_id)
      : current.account_id;
    if (accountSupplied && updatedAccountId != null && !Number.isFinite(updatedAccountId)) {
      return res.status(400).json({ message: 'account invalid' });
    }

    const currentActive = Boolean(current.is_active);
    const updatedIsActive =
      is_active === undefined || is_active === null ? currentActive : Boolean(is_active);

    let nextDateStr: string | null = current.next_date || null;
    const scheduleChanged = schedule !== undefined && schedule !== current.schedule;
    const weekdayChanged =
      weekdaySupplied && updatedWeekday !== (current.weekday ?? null);
    const dayChanged = daySupplied && updatedDay !== (current.day ?? null);
    const accountChanged =
      accountSupplied && updatedAccountId !== (current.account_id ?? null);
    const reactivated = !currentActive && updatedIsActive;
    const shouldResetDate = scheduleChanged || weekdayChanged || dayChanged || accountChanged || reactivated || !nextDateStr;

    if (!updatedIsActive) {
      nextDateStr = null;
    } else if (shouldResetDate) {
      if (updatedAccountId) {
        const nextDate = computeFirstSalaryDate(
          { schedule: updatedSchedule, weekday: updatedWeekday, day: updatedDay },
          startOfDay(new Date())
        );
        nextDateStr = formatDateOnly(nextDate);
      } else {
        nextDateStr = null;
      }
    }

    await db.query(
      'UPDATE salary_rules SET name = ?, amount = ?, schedule = ?, weekday = ?, day = ?, account_id = ?, is_active = ?, next_date = ? WHERE id = ? AND user_id = ?',
      [
        updatedName,
        updatedAmount,
        updatedSchedule,
        updatedWeekday,
        updatedDay,
        updatedAccountId,
        updatedIsActive ? 1 : 0,
        nextDateStr,
        req.params.id,
        req.user?.id,
      ]
    );

    await processDueSalaryRules(req.user!.id);

    const [row] = await db.query(
      `SELECT s.id, s.name, s.amount, s.schedule, s.weekday, s.day, s.account_id, s.is_active, s.next_date,
              s.created_at, s.updated_at, a.name AS account_name
       FROM salary_rules s LEFT JOIN accounts a ON a.id = s.account_id AND a.user_id = s.user_id
       WHERE s.id = ? AND s.user_id = ?`,
      [req.params.id, req.user?.id]
    );
    res.json((row as any[])[0]);
  } catch (e) {
    res.status(500).json({ message: 'Failed to update salary rule' });
  }
});

router.delete('/api/salaries/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    await db.query('DELETE FROM salary_rules WHERE id = ? AND user_id = ?', [req.params.id, req.user?.id]);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ message: 'Failed to delete salary rule' });
  }
});

type AiChatMessage = { role: 'user' | 'assistant'; content: string };

function normalizeAiMessages(raw: any): AiChatMessage[] {
  if (!Array.isArray(raw)) return [];
  const safe: AiChatMessage[] = [];
  for (const msg of raw) {
    const role = msg?.role;
    if (role !== 'user' && role !== 'assistant') continue;
    const content = typeof msg?.content === 'string' ? msg.content.trim() : '';
    if (!content) continue;
    safe.push({ role, content: content.slice(0, 2000) });
  }
  return safe.slice(-20);
}

function dateToYmd(value: any): string | null {
  if (!value) return null;
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  const raw = String(value);
  return raw.length >= 10 ? raw.slice(0, 10) : raw;
}

async function handleAiChat(req: Request, res: Response) {
  try {
    const client = getOpenAiClient();
    if (!client) {
      console.warn('AI chat unavailable: missing OPENAI_API_KEY');
      return res.status(503).json({ message: 'Assistant unavailable' });
    }
    if (!(await ensureProOrExempt(req, res))) return;

    const messages = normalizeAiMessages(req.body?.messages);
    if (messages.length === 0) {
      return res.status(400).json({ message: 'messages must be a non-empty array' });
    }

    const uid = req.user!.id;
    console.log('AI chat request:', uid, `messages=${messages.length}`);
    const [accountRows] = await db.query(
      'SELECT id, name, type, balance, is_active FROM accounts WHERE user_id = ? ORDER BY id DESC',
      [uid]
    );
    const [projectRows] = await db.query(
      'SELECT id, name, budget, spent, status, start_date, end_date FROM projects WHERE user_id = ? ORDER BY id DESC',
      [uid]
    );
    const [paymentRows] = await db.query(
      `SELECT p.id, p.name, p.amount, p.frequency, p.next_date, p.is_active, p.category,
              a.name AS account_name, pr.name AS project_name
         FROM payments p
         LEFT JOIN accounts a ON p.account_id = a.id
         LEFT JOIN projects pr ON p.project_id = pr.id AND pr.user_id = p.user_id
        WHERE p.user_id = ?
        ORDER BY p.next_date ASC`,
      [uid]
    );
    const [investmentRows] = await db.query(
      'SELECT id, name, principal, annual_rate, start_date, account_id FROM investments WHERE user_id = ? ORDER BY id DESC',
      [uid]
    );
    const [txRows] = await db.query(
      `${TRANSACTION_SELECT_BASE} WHERE t.user_id = ? ORDER BY t.date DESC, t.id DESC LIMIT 200`,
      [uid]
    );
    const categories = await listExpenseCategories(uid);

    const transactions = (txRows as any[]).map((t) => ({
      id: t.id,
      date: dateToYmd(t.date),
      description: t.description,
      amount: Number(t.amount ?? 0),
      type: t.type,
      category: t.category,
      category_id: t.category_id,
      subcategory_id: t.subcategory_id,
      category_name: t.category_name,
      subcategory_name: t.subcategory_name,
      account_name: t.account_name,
      project_name: t.project_name,
    }));

    const monthKey = new Date().toISOString().slice(0, 7);
    let incomeTotal = 0;
    let expenseTotal = 0;
    const categorySpend = new Map<string, number>();
    const subcategorySpend = new Map<number, { name: string; category: string; spent: number }>();

    for (const t of transactions) {
      if (!t.date || !t.date.startsWith(monthKey)) continue;
      const amount = Number(t.amount ?? 0);
      if (amount >= 0) {
        incomeTotal += amount;
        continue;
      }
      const expense = Math.abs(amount);
      expenseTotal += expense;
      const categoryName = t.category_name || t.category || 'Uncategorized';
      categorySpend.set(categoryName, (categorySpend.get(categoryName) ?? 0) + expense);
      if (t.subcategory_id != null) {
        const subId = Number(t.subcategory_id);
        const existing = subcategorySpend.get(subId);
        const subName = t.subcategory_name || categoryName;
        const catName = t.category_name || t.category || 'Uncategorized';
        if (existing) {
          existing.spent += expense;
        } else {
          subcategorySpend.set(subId, { name: subName, category: catName, spent: expense });
        }
      }
    }

    const topCategories = Array.from(categorySpend.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([name, spent]) => ({ name, spent }));

    const subcategoryBudgets = categories
      .flatMap((cat) =>
        cat.subcategories.map((sub) => ({
          id: sub.id,
          name: sub.name,
          category: cat.name,
          budget: sub.budget,
          spent: subcategorySpend.get(sub.id)?.spent ?? 0,
        }))
      )
      .sort((a, b) => b.spent - a.spent)
      .slice(0, 8);

    const context = {
      generated_at: new Date().toISOString(),
      month: monthKey,
      totals: {
        income: Math.round(incomeTotal * 100) / 100,
        expenses: Math.round(expenseTotal * 100) / 100,
        net: Math.round((incomeTotal - expenseTotal) * 100) / 100,
      },
      top_expense_categories: topCategories,
      subcategory_budgets: subcategoryBudgets,
      accounts: (accountRows as any[]),
      projects: (projectRows as any[]),
      payments: (paymentRows as any[]),
      investments: (investmentRows as any[]),
      categories,
      recent_transactions: transactions.slice(0, 120),
    };

    const systemPrompt = [
      'You are FinSight AI, a concise financial consultant for the user.',
      'Use the provided user data context to answer questions and give actionable, realistic guidance.',
      'If the user asks for data not in context, ask a brief clarifying question.',
      'Do not invent transactions or balances. Keep responses short and practical.',
      'User has consented to share their financial data.',
      `Context (JSON): ${JSON.stringify(context)}`,
    ].join('\n');

    const timeoutMs = Math.max(5000, Number(process.env.OPENAI_TIMEOUT_MS || 20000));
    const completion = (await Promise.race([
      client.chat.completions.create({
        model: 'gpt-4o-mini',
        temperature: 0.3,
        max_tokens: 700,
        messages: [{ role: 'system', content: systemPrompt }, ...messages],
      }),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('OpenAI timeout')), timeoutMs)
      ),
    ])) as any;

    const reply = completion.choices?.[0]?.message?.content?.trim() ?? '';
    console.log('AI chat response:', uid, `chars=${reply.length}`);
    res.json({ reply });
  } catch (error) {
    const msg = (error as any)?.message || '';
    console.error('AI chat error:', error);
    if (msg.includes('OpenAI timeout')) {
      return res.status(504).json({ message: 'AI request timed out' });
    }
    res.status(500).json({ message: 'Assistant failed to respond' });
  }
}

router.post('/api/ai-chat', authenticateToken, handleAiChat);
router.post('/api/assistant/chat', authenticateToken, handleAiChat);
export default router;

// ============ Invoices and Customers ============

// Helper to compute invoice totals
function computeInvoiceTotals(items: Array<{ quantity: number; unit_price: number }>, discount: number = 0, tax: number = 0) {
  const subtotal = items.reduce((sum, it) => sum + Number(it.quantity || 0) * Number(it.unit_price || 0), 0);
  const subMinusDiscount = Math.max(subtotal - Number(discount || 0), 0);
  const taxAmount = Number(tax || 0);
  const total = subMinusDiscount + taxAmount;
  return {
    subtotal: Math.round(subtotal * 100) / 100,
    discount: Math.round(Number(discount || 0) * 100) / 100,
    tax: Math.round(taxAmount * 100) / 100,
    total: Math.round(total * 100) / 100,
  };
}

// Customers
router.get('/api/customers', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const [rows] = await db.query('SELECT * FROM customers WHERE user_id = ? ORDER BY name ASC', [req.user?.id]);
    res.json(rows);
  } catch (e) {
    res.status(500).json({ message: 'Failed to fetch customers' });
  }
});

router.post('/api/customers', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const { name, email, company, tax_id, address } = req.body;
    if (!name) return res.status(400).json({ message: 'Name is required' });
    const [result] = await db.query(
      'INSERT INTO customers (user_id, name, email, company, tax_id, address) VALUES (?, ?, ?, ?, ?, ?)',
      [req.user?.id, name, email || null, company || null, tax_id || null, address || null]
    );
    const id = (result as any).insertId;
    const [row] = await db.query('SELECT * FROM customers WHERE id = ?', [id]);
    res.json((row as any[])[0]);
  } catch (e) {
    res.status(500).json({ message: 'Failed to create customer' });
  }
});

router.put('/api/customers/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const { name, email, company, tax_id, address } = req.body;
    await db.query(
      'UPDATE customers SET name = ?, email = ?, company = ?, tax_id = ?, address = ? WHERE id = ? AND user_id = ?',
      [name, email || null, company || null, tax_id || null, address || null, req.params.id, req.user?.id]
    );
    const [row] = await db.query('SELECT * FROM customers WHERE id = ? AND user_id = ?', [req.params.id, req.user?.id]);
    res.json((row as any[])[0]);
  } catch (e) {
    res.status(500).json({ message: 'Failed to update customer' });
  }
});

router.delete('/api/customers/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    await db.query('DELETE FROM customers WHERE id = ? AND user_id = ?', [req.params.id, req.user?.id]);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ message: 'Failed to delete customer' });
  }
});

// Invoices
router.get('/api/invoices', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const [rows] = await db.query(
      `SELECT i.*, c.name AS customer_name, c.email AS customer_email
       FROM invoices i
       JOIN customers c ON i.customer_id = c.id
       WHERE i.user_id = ?
       ORDER BY i.issue_date DESC, i.id DESC`,
      [req.user?.id]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ message: 'Failed to fetch invoices' });
  }
});

router.get('/api/invoices/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const [invRows] = await db.query(
      `SELECT i.*, c.name AS customer_name, c.email AS customer_email,
              c.company AS customer_company, c.tax_id AS customer_tax_id,
              c.address AS customer_address
       FROM invoices i JOIN customers c ON i.customer_id = c.id
       WHERE i.id = ? AND i.user_id = ?`,
      [req.params.id, req.user?.id]
    );
    if ((invRows as any[]).length === 0) return res.status(404).json({ message: 'Invoice not found' });
    const invoice = (invRows as any[])[0];
    const [items] = await db.query('SELECT * FROM invoice_items WHERE invoice_id = ? ORDER BY id ASC', [req.params.id]);
    const [payments] = await db.query(
      `SELECT p.*, a.name AS account_name
       FROM invoice_payments p
       LEFT JOIN accounts a ON a.id = p.account_id
       WHERE p.invoice_id = ?
       ORDER BY p.date DESC, p.id DESC`,
      [req.params.id]
    );
    // Try to associate created transactions with each payment (by description/date/amount/account)
    const [txs] = await db.query(
      `SELECT id, date, description, amount, account_id
       FROM transactions
       WHERE user_id = ? AND description LIKE ?
       ORDER BY date DESC, id DESC`,
      [req.user?.id, `Invoice #${req.params.id}%`]
    );
    const usedTx = new Set<number>();
    const paymentsWithTx = (payments as any[]).map(p => {
      const pDate = new Date(p.date).toISOString().slice(0,10);
      const targetAmt = Math.abs(Number(p.amount));
      const match = (txs as any[]).find((t: any) => !usedTx.has(t.id)
        && t.account_id === p.account_id
        && new Date(t.date).toISOString().slice(0,10) === pDate
        && Number(t.amount) === targetAmt);
      if (match) usedTx.add(match.id);
      return { ...p, transaction: match || null };
    });
    res.json({ invoice, items, payments: paymentsWithTx });
  } catch (e) {
    res.status(500).json({ message: 'Failed to fetch invoice' });
  }
});

router.post('/api/invoices', authenticateToken, async (req: Request, res: Response) => {
  const conn = db;
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const { customer_id, project_id, account_id, number, issue_date, due_date, currency, notes, discount, tax, items } = req.body;
    if (!customer_id || !issue_date || !due_date || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'Missing required fields' });
    }
    const totals = computeInvoiceTotals(items, Number(discount || 0), Number(tax || 0));
    const amount_due = totals.total; // initially unpaid
    // Create as 'sent' to remove the explicit send step
    const [result] = await conn.query(
      `INSERT INTO invoices (user_id, customer_id, project_id, account_id, number, issue_date, due_date, status, currency, notes, subtotal, tax, discount, total, amount_due)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'sent', ?, ?, ?, ?, ?, ?, ?)`,
      [req.user?.id, customer_id, project_id || null, account_id || null, number || null, issue_date, due_date, currency || 'MXN', notes || null, totals.subtotal, totals.tax, totals.discount, totals.total, amount_due]
    );
    const invoiceId = (result as any).insertId;
    for (const it of items) {
      const qty = Number(it.quantity || 0);
      const price = Number(it.unit_price || 0);
      const amount = Math.round(qty * price * 100) / 100;
      await conn.query(
        'INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, amount) VALUES (?, ?, ?, ?, ?)',
        [invoiceId, it.description || 'Item', qty, price, amount]
      );
    }
    const [row] = await conn.query('SELECT * FROM invoices WHERE id = ?', [invoiceId]);
    res.json((row as any[])[0]);
  } catch (e) {
    console.error('Create invoice error:', e);
    res.status(500).json({ message: 'Failed to create invoice' });
  }
});

router.put('/api/invoices/:id', authenticateToken, async (req: Request, res: Response) => {
  const conn = db;
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const id = Number(req.params.id);
    const [check] = await conn.query('SELECT status FROM invoices WHERE id = ? AND user_id = ?', [id, req.user?.id]);
    if ((check as any[]).length === 0) return res.status(404).json({ message: 'Invoice not found' });
    const status = (check as any[])[0].status as string;
    if (status === 'paid' || status === 'void') return res.status(400).json({ message: 'Cannot edit paid/void invoice' });

    const { customer_id, project_id, account_id, number, issue_date, due_date, currency, notes, discount, tax, items } = req.body;

    const totals = Array.isArray(items) && items.length > 0 ? computeInvoiceTotals(items, Number(discount || 0), Number(tax || 0)) : null;

    if (totals) {
      await conn.query(
        `UPDATE invoices SET customer_id = ?, project_id = ?, account_id = ?, number = ?, issue_date = ?, due_date = ?, currency = ?, notes = ?,
          subtotal = ?, tax = ?, discount = ?, total = ?,
          amount_due = GREATEST(total - (SELECT COALESCE(SUM(amount),0) FROM invoice_payments WHERE invoice_id = invoices.id), 0),
          status = (
            CASE
              WHEN (SELECT COALESCE(SUM(amount),0) FROM invoice_payments WHERE invoice_id = invoices.id) = 0 THEN status
              WHEN total - (SELECT COALESCE(SUM(amount),0) FROM invoice_payments WHERE invoice_id = invoices.id) <= 0 THEN 'paid'
              ELSE 'partial'
            END
          )
         WHERE id = ? AND user_id = ?`,
        [customer_id, project_id || null, account_id || null, number || null, issue_date, due_date, currency || 'MXN', notes || null, totals.subtotal, totals.tax, totals.discount, totals.total, id, req.user?.id]
      );
    } else {
      await conn.query(
        `UPDATE invoices SET customer_id = ?, project_id = ?, account_id = ?, number = ?, issue_date = ?, due_date = ?, currency = ?, notes = ?
         WHERE id = ? AND user_id = ?`,
        [customer_id, project_id || null, account_id || null, number || null, issue_date, due_date, currency || 'MXN', notes || null, id, req.user?.id]
      );
    }

    if (Array.isArray(items)) {
      // Replace items
      await conn.query('DELETE FROM invoice_items WHERE invoice_id = ?', [id]);
      for (const it of items) {
        const qty = Number(it.quantity || 0);
        const price = Number(it.unit_price || 0);
        const amount = Math.round(qty * price * 100) / 100;
        await conn.query('INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, amount) VALUES (?, ?, ?, ?, ?)', [id, it.description || 'Item', qty, price, amount]);
      }
    }
    const [row] = await conn.query('SELECT * FROM invoices WHERE id = ?', [id]);
    res.json((row as any[])[0]);
  } catch (e) {
    console.error('Update invoice error:', e);
    res.status(500).json({ message: 'Failed to update invoice' });
  }
});

router.delete('/api/invoices/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const id = Number(req.params.id);
    // Ensure invoice exists and belongs to user
    const [inv] = await db.query('SELECT id, project_id FROM invoices WHERE id = ? AND user_id = ?', [id, req.user?.id]);
    if ((inv as any[]).length === 0) return res.status(404).json({ message: 'Invoice not found' });
    const projectId = (inv as any[])[0].project_id as number | null;

    // Start transaction to reverse side effects
    await db.query('START TRANSACTION');
    try {
      // Find transactions created for this invoice's payments
      const [txs] = await db.query(
        `SELECT id, amount, account_id, date, project_id
         FROM transactions
         WHERE user_id = ? AND description LIKE ?`,
        [req.user?.id, `Invoice #${id}%`]
      );

      for (const tx of txs as any[]) {
        const amt = Number(tx.amount) || 0;
        const accId = tx.account_id as number;
        const d = new Date(tx.date);

        // Reverse account balance (income had increased balance)
        await db.query('UPDATE accounts SET balance = balance - ? WHERE id = ? AND user_id = ?', [Math.abs(amt), accId, req.user?.id]);

        // Reverse project spent reduction if applicable
        if (tx.project_id) {
          await db.query('UPDATE projects SET spent = spent + ? WHERE id = ? AND user_id = ?', [Math.abs(amt), tx.project_id, req.user?.id]);
        }

        // Delete transaction
        await db.query('DELETE FROM transactions WHERE id = ? AND user_id = ?', [tx.id, req.user?.id]);

        // Update balance history for that month
        await updateBalanceHistory(req.user?.id!, accId, d.getFullYear(), d.getMonth() + 1);
      }

      // Delete the invoice (will cascade delete invoice_items and invoice_payments)
      await db.query('DELETE FROM invoices WHERE id = ? AND user_id = ?', [id, req.user?.id]);

      await db.query('COMMIT');
      res.json({ success: true });
    } catch (err) {
      await db.query('ROLLBACK');
      throw err;
    }
  } catch (e) {
    console.error('Delete invoice error:', e);
    res.status(500).json({ message: 'Failed to delete invoice' });
  }
});

router.post('/api/invoices/:id/email', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    if (!isEmailConfigured()) {
      return res.status(503).json({ message: 'Email delivery is not configured' });
    }

    const invoiceId = Number(req.params.id);
    if (!Number.isFinite(invoiceId)) {
      return res.status(400).json({ message: 'Invalid invoice id' });
    }

    const rawBase64 = String(req.body?.pdf_base64 || '').trim();
    if (!rawBase64) {
      return res.status(400).json({ message: 'pdf_base64 is required' });
    }

    const normalizedBase64 = rawBase64.replace(/\s+/g, '');
    const pdfBuffer = Buffer.from(normalizedBase64, 'base64');
    if (pdfBuffer.length === 0 || pdfBuffer.subarray(0, 4).toString() !== '%PDF') {
      return res.status(400).json({ message: 'Invalid PDF attachment' });
    }

    const requestedFileName = String(req.body?.filename || '').trim();
    const safeFileNameBase =
      requestedFileName.replace(/[^A-Za-z0-9._-]/g, '_').replace(/_+/g, '_') ||
      `invoice-${invoiceId}.pdf`;
    const filename = safeFileNameBase.toLowerCase().endsWith('.pdf')
      ? safeFileNameBase
      : `${safeFileNameBase}.pdf`;

    const [rows] = await db.query(
      `SELECT i.id, i.number, i.status, i.total, i.due_date, i.currency,
              c.name AS customer_name, c.email AS customer_email
       FROM invoices i
       JOIN customers c ON c.id = i.customer_id
       WHERE i.id = ? AND i.user_id = ?
       LIMIT 1`,
      [invoiceId, req.user?.id]
    );
    const invoice = (rows as any[])[0];
    if (!invoice) {
      return res.status(404).json({ message: 'Invoice not found' });
    }

    const customerEmail = String(invoice.customer_email || '').trim();
    if (!customerEmail) {
      return res.status(400).json({ message: 'Customer email is required' });
    }

    const emailPayload = buildInvoiceShareEmail({
      invoiceId: invoice.id,
      invoiceNumber: invoice.number,
      customerName: String(invoice.customer_name || '').trim(),
      total: invoice.total,
      dueDate: invoice.due_date,
      currency: invoice.currency,
    });

    const sent = await sendResendEmail({
      to: customerEmail,
      subject: emailPayload.subject,
      text: emailPayload.text,
      html: emailPayload.html,
      attachments: [
        {
          filename,
          content: normalizedBase64,
          contentType: 'application/pdf',
        },
      ],
    });

    if (!sent) {
      return res.status(502).json({ message: 'Failed to send invoice email' });
    }

    await db.query(
      `UPDATE invoices
       SET status = CASE WHEN status = 'draft' THEN 'sent' ELSE status END
       WHERE id = ? AND user_id = ?`,
      [invoiceId, req.user?.id]
    );

    res.json({ success: true, emailed_to: customerEmail, filename });
  } catch (e) {
    console.error('Invoice email error:', e);
    res.status(500).json({ message: 'Failed to email invoice' });
  }
});

router.post('/api/invoices/:id/send', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    await db.query('UPDATE invoices SET status = ? WHERE id = ? AND user_id = ?', ['sent', req.params.id, req.user?.id]);
    const [row] = await db.query('SELECT * FROM invoices WHERE id = ?', [req.params.id]);
    res.json((row as any[])[0]);
  } catch (e) {
    res.status(500).json({ message: 'Failed to mark invoice as sent' });
  }
});

router.post('/api/invoices/:id/void', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    const [pay] = await db.query('SELECT COUNT(*) as cnt FROM invoice_payments WHERE invoice_id = ?', [req.params.id]);
    if ((pay as any[])[0]?.cnt > 0) return res.status(400).json({ message: 'Cannot void an invoice with payments' });
    await db.query('UPDATE invoices SET status = ? WHERE id = ? AND user_id = ?', ['void', req.params.id, req.user?.id]);
    const [row] = await db.query('SELECT * FROM invoices WHERE id = ?', [req.params.id]);
    res.json((row as any[])[0]);
  } catch (e) {
    res.status(500).json({ message: 'Failed to void invoice' });
  }
});

router.post('/api/invoices/:id/payments', authenticateToken, async (req: Request, res: Response) => {
  try {
    if (!(await ensureProOrExempt(req, res))) return;
    await ensureInvestmentAccountSchema();
    const id = Number(req.params.id);
    const { date, amount, account_id, method, reference } = req.body;
    if (!date || !amount || !account_id) return res.status(400).json({ message: 'date, amount and account_id are required' });

    // Start transaction
    await db.query('START TRANSACTION');
    try {
      // Insert invoice payment
      await db.query('INSERT INTO invoice_payments (invoice_id, date, amount, account_id, method, reference) VALUES (?, ?, ?, ?, ?, ?)', [id, date, amount, account_id, method || null, reference || null]);

      // Create income transaction
      const [invRows] = await db.query('SELECT project_id, user_id FROM invoices WHERE id = ? AND user_id = ?', [id, req.user?.id]);
      if ((invRows as any[]).length === 0) throw new Error('Invoice not found');
      const inv = (invRows as any[])[0];

      const [txResult] = await db.query(
        'INSERT INTO transactions (user_id, account_id, project_id, date, description, amount, type, category) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [req.user?.id, account_id, inv.project_id || null, date, `Invoice #${id} payment`, Math.abs(amount), 'Income', 'Invoice']
      );

      // Update account balance
      await db.query('UPDATE accounts SET balance = balance + ? WHERE id = ? AND user_id = ?', [Math.abs(amount), account_id, req.user?.id]);

      // Update project spent (income -> negative)
      if (inv.project_id) {
        await db.query('UPDATE projects SET spent = spent - ? WHERE id = ? AND user_id = ?', [Math.abs(amount), inv.project_id, req.user?.id]);
      }

      // Recalculate invoice amount_due and status
      const [sumPay] = await db.query('SELECT COALESCE(SUM(amount),0) as paid FROM invoice_payments WHERE invoice_id = ?', [id]);
      const paid = Number((sumPay as any[])[0]?.paid || 0);
      await db.query('UPDATE invoices SET amount_due = GREATEST(total - ?, 0), status = (CASE WHEN total - ? <= 0 THEN "paid" ELSE "partial" END) WHERE id = ?', [paid, paid, id]);

      // Update balance history
      const d = new Date(date);
      await updateBalanceHistory(req.user?.id!, account_id, d.getFullYear(), d.getMonth() + 1);
      await syncInvestmentContribution(req.user!.id, account_id, (txResult as any).insertId, Math.abs(amount), date);

      await db.query('COMMIT');
      const [row] = await db.query('SELECT * FROM invoices WHERE id = ?', [id]);
      res.json((row as any[])[0]);
    } catch (err) {
      await db.query('ROLLBACK');
      throw err;
    }
  } catch (e) {
    console.error('Invoice payment error:', e);
    res.status(500).json({ message: 'Failed to record invoice payment' });
  }
});
// Current user profile
router.get('/api/me', authenticateToken, async (req: Request, res: Response) => {
  try {
    const [rows] = await db.query('SELECT id, username, email, COALESCE(is_pro,0) AS is_pro FROM users WHERE id = ? LIMIT 1', [req.user?.id]);
    if ((rows as any[]).length === 0) return res.status(404).json({ message: 'User not found' });
    res.json((rows as any[])[0]);
  } catch (e) {
    res.status(500).json({ message: 'Failed to load user' });
  }
});

// Stripe Billing
router.post('/api/stripe/checkout', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { url } = await createCheckoutSession(req.user?.id!);
    res.json({ url });
  } catch (e: any) {
    console.error('Create checkout session error:', e?.message || e);
    res.status(500).json({ message: 'Failed to create checkout session' });
  }
});

router.post('/api/stripe/portal', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { url } = await createPortalSession(req.user?.id!);
    res.json({ url });
  } catch (e: any) {
    console.error('Create portal session error:', e?.message || e);
    res.status(500).json({ message: 'Failed to create portal session' });
  }
});

router.post('/api/stripe/sync', authenticateToken, async (req: Request, res: Response) => {
  try {
    const result = await syncUserSubscription(req.user?.id!);
    res.json(result);
  } catch (e: any) {
    console.error('Stripe sync error:', e?.message || e);
    res.status(500).json({ message: 'Failed to sync subscription' });
  }
});

router.post('/api/stripe/cancel', authenticateToken, async (req: Request, res: Response) => {
  try {
    const result = await cancelUserSubscription(req.user?.id!);
    res.json(result);
  } catch (e: any) {
    console.error('Stripe cancel error:', e?.message || e);
    const message = e?.message || 'Failed to cancel subscription';
    const status =
      message === 'No active subscription to cancel' || message === 'Unable to locate subscription in Stripe'
        ? 400
        : 500;
    res.status(status).json({ message });
  }
});



// Basic health endpoint to help mobile/web diagnose connectivity
router.get('/api/health', (_req: Request, res: Response) => {
  res.json({ ok: true, time: new Date().toISOString() });
});

// Activate Pro for current user after app store purchase (Play Billing)
router.post('/api/pro/activate', authenticateToken, async (req: Request, res: Response) => {
  try {
    await db.query('UPDATE users SET is_pro = 1 WHERE id = ?', [req.user?.id]);
    res.json({ success: true, is_pro: true });
  } catch (e) {
    console.error('Activate Pro error:', e);
    res.status(500).json({ message: 'Failed to activate Pro' });
  }
});

// Helper: verify subscription state using Google Play Developer API (best-effort)
async function verifyPlaySub(purchaseToken: string) {
  try {
    const packageName = process.env.ANDROID_PACKAGE_NAME || 'com.finsight.finsight';
    const auth = await google.auth.getClient({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
    const androidpublisher = google.androidpublisher({ version: 'v3', auth });
    // Subscriptions v2
    const resp = await androidpublisher.purchases.subscriptionsv2.get({ packageName, token: purchaseToken });
    const sub: any = resp.data;
    // subscriptionState: SUBSCRIPTION_STATE_ACTIVE | CANCELED | IN_GRACE_PERIOD | ON_HOLD | PAUSED | EXPIRED
    const state: string = sub?.subscriptionState || '';
    let expiry: Date | null = null;
    try {
      const li = (sub?.lineItems || [])[0];
      const ms = li?.expiryTime ? Number(li.expiryTime) : undefined;
      if (ms && !Number.isNaN(ms)) expiry = new Date(ms);
    } catch {}
    return { ok: true, state, expiry };
  } catch (e) {
    console.warn('Play verify failed:', (e as any)?.message || e);
    return { ok: false };
  }
}

// Link a Play Billing purchase token to the current user
router.post('/api/play/link', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { productId, purchaseToken } = req.body || {};
    if (!productId || !purchaseToken) {
      return res.status(400).json({ message: 'productId and purchaseToken are required' });
    }

    let state = 'UNKNOWN';
    let expiry: Date | null = null;
    const ver = await verifyPlaySub(purchaseToken);
    if (ver.ok) {
      state = ver.state || 'UNKNOWN';
      expiry = ver.expiry || null;
    }

    // Upsert mapping
    await db.query(
      `INSERT INTO play_subscriptions (user_id, product_id, purchase_token, auto_renewing, expiry_time, last_state)
       VALUES (?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE product_id = VALUES(product_id), expiry_time = VALUES(expiry_time), last_state = VALUES(last_state)`,
      [req.user?.id, productId, purchaseToken, null, expiry, state]
    );

    const isPro = await refreshUserProFlag(req.user!.id);
    res.json({ success: true, state, expiry, is_pro: isPro });
  } catch (e) {
    console.error('play/link error:', e);
    res.status(500).json({ message: 'Failed to link purchase' });
  }
});

// Sync subscription status for current user (best-effort)
router.post('/api/play/sync', authenticateToken, async (req: Request, res: Response) => {
  try {
    const [rows] = await db.query('SELECT purchase_token FROM play_subscriptions WHERE user_id = ?', [req.user?.id]);
    const tokens = (rows as any[]).map(r => r.purchase_token as string);
    if (tokens.length === 0) {
      const isPro = await refreshUserProFlag(req.user!.id);
      return res.json({ success: true, tokens: 0, is_pro: isPro });
    }
    for (const t of tokens) {
      const ver = await verifyPlaySub(t);
      if (ver.ok) {
        await db.query('UPDATE play_subscriptions SET expiry_time = ?, last_state = ? WHERE purchase_token = ?', [ver.expiry ?? null, ver.state ?? null, t]);
      }
    }
    const isPro = await refreshUserProFlag(req.user!.id);
    res.json({ success: true, tokens: tokens.length, is_pro: isPro });
  } catch (e) {
    console.error('play/sync error:', e);
    res.status(500).json({ message: 'Failed to sync subscription' });
  }
});

router.post('/api/appstore/link', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { productId, receiptData } = req.body || {};
    if (!productId || !receiptData) {
      return res.status(400).json({ message: 'productId and receiptData are required' });
    }

    const verification = await verifyAppStoreReceipt(String(receiptData));
    if (verification.status !== 0) {
      return res.status(400).json({
        message: 'Receipt validation failed',
        status: verification.status,
      });
    }

    const summary = summarizeAppStoreSubscription(
      verification.latestReceiptInfo,
      verification.pendingRenewalInfo,
      String(productId)
    );
    if (!summary?.originalTransactionId || !summary.productId) {
      return res.status(400).json({
        message: 'No matching App Store subscription found in receipt',
      });
    }

    await db.query(
      `INSERT INTO app_store_subscriptions (
         user_id,
         product_id,
         original_transaction_id,
         latest_transaction_id,
         auto_renew_status,
         expiry_time,
         last_state,
         environment,
         receipt_data
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         user_id = VALUES(user_id),
         product_id = VALUES(product_id),
         latest_transaction_id = VALUES(latest_transaction_id),
         auto_renew_status = VALUES(auto_renew_status),
         expiry_time = VALUES(expiry_time),
         last_state = VALUES(last_state),
         environment = VALUES(environment),
         receipt_data = VALUES(receipt_data)`,
      [
        req.user?.id,
        summary.productId,
        summary.originalTransactionId,
        summary.latestTransactionId,
        summary.autoRenewStatus,
        summary.expiry,
        summary.state,
        verification.environment,
        verification.latestReceipt,
      ]
    );

    const isPro = await refreshUserProFlag(req.user!.id);
    res.json({
      success: true,
      state: summary.state,
      expiry: summary.expiry,
      environment: verification.environment,
      is_pro: isPro,
    });
  } catch (e) {
    console.error('appstore/link error:', e);
    res.status(500).json({ message: 'Failed to link App Store purchase' });
  }
});

router.post('/api/appstore/sync', authenticateToken, async (req: Request, res: Response) => {
  try {
    const [rows] = await db.query(
      `SELECT product_id, receipt_data
         FROM app_store_subscriptions
        WHERE user_id = ?
          AND receipt_data IS NOT NULL
          AND receipt_data != ''`,
      [req.user?.id]
    );
    const subscriptions = rows as any[];
    if (subscriptions.length === 0) {
      const isPro = await refreshUserProFlag(req.user!.id);
      return res.json({ success: true, receipts: 0, is_pro: isPro });
    }

    for (const subscription of subscriptions) {
      const verification = await verifyAppStoreReceipt(
        String(subscription.receipt_data)
      );
      if (verification.status !== 0) continue;

      const summary = summarizeAppStoreSubscription(
        verification.latestReceiptInfo,
        verification.pendingRenewalInfo,
        String(subscription.product_id || '')
      );
      if (!summary?.originalTransactionId || !summary.productId) continue;

      await db.query(
        `INSERT INTO app_store_subscriptions (
           user_id,
           product_id,
           original_transaction_id,
           latest_transaction_id,
           auto_renew_status,
           expiry_time,
           last_state,
           environment,
           receipt_data
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           user_id = VALUES(user_id),
           product_id = VALUES(product_id),
           latest_transaction_id = VALUES(latest_transaction_id),
           auto_renew_status = VALUES(auto_renew_status),
           expiry_time = VALUES(expiry_time),
           last_state = VALUES(last_state),
           environment = VALUES(environment),
           receipt_data = VALUES(receipt_data)`,
        [
          req.user?.id,
          summary.productId,
          summary.originalTransactionId,
          summary.latestTransactionId,
          summary.autoRenewStatus,
          summary.expiry,
          summary.state,
          verification.environment,
          verification.latestReceipt,
        ]
      );
    }

    const isPro = await refreshUserProFlag(req.user!.id);
    res.json({ success: true, receipts: subscriptions.length, is_pro: isPro });
  } catch (e) {
    console.error('appstore/sync error:', e);
    res.status(500).json({ message: 'Failed to sync App Store subscription' });
  }
});
