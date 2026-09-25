import type { Request, Response } from 'express';
import { Webhook } from 'svix';

import { db } from './db.js';

type EmailPayload = {
  to: string;
  subject: string;
  text: string;
  html?: string;
  attachments?: Array<{
    filename: string;
    content: string;
    contentType?: string;
  }>;
};

const RESEND_API_URL = 'https://api.resend.com/emails';
const RESEND_RECEIVING_API_URL = 'https://api.resend.com/emails/receiving';

function getResendConfig() {
  const apiKey = process.env.RESEND_API_KEY?.trim();
  const from = process.env.RESEND_FROM?.trim();
  const webhookSecret = process.env.RESEND_WEBHOOK_SECRET?.trim();
  return { apiKey, from, webhookSecret };
}

export function isEmailConfigured(): boolean {
  const { apiKey, from } = getResendConfig();
  return Boolean(apiKey && from);
}

type ResendWebhookEvent = {
  type: string;
  created_at?: string;
  data?: {
    email_id?: string;
    created_at?: string;
    from?: string;
    to?: string[];
    cc?: string[];
    bcc?: string[];
    message_id?: string;
    subject?: string;
    attachments?: Array<Record<string, unknown>>;
  };
};

type ResendReceivedEmail = {
  id: string;
  to?: string[];
  from?: string;
  created_at?: string;
  subject?: string;
  html?: string | null;
  text?: string | null;
  headers?: Record<string, unknown> | null;
  bcc?: string[];
  cc?: string[];
  reply_to?: string[];
  message_id?: string;
  raw?: {
    download_url?: string;
    expires_at?: string;
  } | null;
  attachments?: Array<Record<string, unknown>>;
};

function parseWebhookTimestamp(value?: string) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function verifyResendWebhookPayload(req: Request, payload: string): ResendWebhookEvent {
  const { webhookSecret } = getResendConfig();
  if (!webhookSecret) {
    return JSON.parse(payload) as ResendWebhookEvent;
  }

  const svixId = req.header('svix-id');
  const svixTimestamp = req.header('svix-timestamp');
  const svixSignature = req.header('svix-signature');
  if (!svixId || !svixTimestamp || !svixSignature) {
    throw new Error('Missing Resend webhook signature headers');
  }

  const webhook = new Webhook(webhookSecret);
  const verified = webhook.verify(payload, {
    'svix-id': svixId,
    'svix-timestamp': svixTimestamp,
    'svix-signature': svixSignature,
  });
  return verified as ResendWebhookEvent;
}

async function fetchResendReceivedEmail(emailId: string): Promise<ResendReceivedEmail | null> {
  const { apiKey } = getResendConfig();
  if (!apiKey) {
    throw new Error('RESEND_API_KEY is not configured');
  }

  const res = await fetch(`${RESEND_RECEIVING_API_URL}/${emailId}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Failed to retrieve received email ${emailId}: ${res.status} ${body}`);
  }

  const json = (await res.json()) as { data?: ResendReceivedEmail } | ResendReceivedEmail;
  if ('data' in json && json.data) return json.data;
  return json as ResendReceivedEmail;
}

async function persistInboundEmail(
  event: ResendWebhookEvent,
  email: ResendReceivedEmail | null,
  rawPayload: string
) {
  const providerEmailId = String(
    email?.id || event.data?.email_id || ''
  ).trim() || null;
  const sender = String(email?.from || event.data?.from || '').trim() || null;
  const subject = String(email?.subject || event.data?.subject || '').trim() || null;
  const messageId = String(
    email?.message_id || event.data?.message_id || ''
  ).trim() || null;
  const toAddresses = email?.to || event.data?.to || [];
  const ccAddresses = email?.cc || event.data?.cc || [];
  const bccAddresses = email?.bcc || event.data?.bcc || [];
  const attachments = email?.attachments || event.data?.attachments || [];
  const providerCreatedAt =
    parseWebhookTimestamp(email?.created_at) ||
    parseWebhookTimestamp(event.data?.created_at) ||
    parseWebhookTimestamp(event.created_at);

  await db.query(
    `INSERT INTO inbound_emails (
       provider,
       event_type,
       provider_email_id,
       sender,
       subject,
       message_id,
       to_addresses,
       cc_addresses,
       bcc_addresses,
       html,
       text,
       headers_json,
       attachments_json,
       raw_download_url,
       payload_json,
       provider_created_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       event_type = VALUES(event_type),
       sender = VALUES(sender),
       subject = VALUES(subject),
       message_id = VALUES(message_id),
       to_addresses = VALUES(to_addresses),
       cc_addresses = VALUES(cc_addresses),
       bcc_addresses = VALUES(bcc_addresses),
       html = VALUES(html),
       text = VALUES(text),
       headers_json = VALUES(headers_json),
       attachments_json = VALUES(attachments_json),
       raw_download_url = VALUES(raw_download_url),
       payload_json = VALUES(payload_json),
       provider_created_at = VALUES(provider_created_at)`,
    [
      'resend',
      event.type,
      providerEmailId,
      sender,
      subject,
      messageId,
      JSON.stringify(toAddresses),
      JSON.stringify(ccAddresses),
      JSON.stringify(bccAddresses),
      email?.html || null,
      email?.text || null,
      email?.headers ? JSON.stringify(email.headers) : null,
      JSON.stringify(attachments),
      email?.raw?.download_url || null,
      rawPayload,
      providerCreatedAt,
    ]
  );
}

export async function inboundEmailWebhookHandler(req: Request, res: Response) {
  try {
    const rawBody = Buffer.isBuffer(req.body)
      ? req.body.toString('utf8')
      : typeof req.body === 'string'
        ? req.body
        : JSON.stringify(req.body || {});
    const event = verifyResendWebhookPayload(req, rawBody);

    if (event.type !== 'email.received') {
      return res.status(200).json({ ok: true, ignored: true, type: event.type });
    }

    const emailId = String(event.data?.email_id || '').trim();
    const email = emailId ? await fetchResendReceivedEmail(emailId) : null;
    await persistInboundEmail(event, email, rawBody);

    console.info(
      'Inbound email received',
      JSON.stringify({
        emailId,
        from: email?.from || event.data?.from || null,
        subject: email?.subject || event.data?.subject || null,
      })
    );

    return res.status(200).json({ ok: true, type: event.type, email_id: emailId || null });
  } catch (error) {
    console.error('Inbound email webhook error:', error);
    return res.status(500).json({ ok: false, message: 'Failed to process webhook' });
  }
}

export async function sendResendEmail(payload: EmailPayload): Promise<boolean> {
  const { apiKey, from } = getResendConfig();
  if (!apiKey || !from) return false;

  try {
    const res = await fetch(RESEND_API_URL, {
      method: 'POST',
      signal: AbortSignal.timeout(10000),
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: payload.to,
        subject: payload.subject,
        text: payload.text,
        ...(payload.html ? { html: payload.html } : {}),
        ...(payload.attachments && payload.attachments.length > 0
          ? {
              attachments: payload.attachments.map((attachment) => ({
                filename: attachment.filename,
                content: attachment.content,
                ...(attachment.contentType
                  ? { content_type: attachment.contentType }
                  : {}),
              })),
            }
          : {}),
      }),
    });

    if (!res.ok) {
      // Provider errors can echo recipient addresses and recovery links. Log status only.
      console.error('Resend email failed:', res.status);
      return false;
    }
    return true;
  } catch {
    console.error('Resend email delivery failed or timed out');
    return false;
  }
}
