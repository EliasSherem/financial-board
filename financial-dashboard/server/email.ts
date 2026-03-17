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

function getResendConfig() {
  const apiKey = process.env.RESEND_API_KEY?.trim();
  const from = process.env.RESEND_FROM?.trim();
  return { apiKey, from };
}

export function isEmailConfigured(): boolean {
  const { apiKey, from } = getResendConfig();
  return Boolean(apiKey && from);
}

export async function sendResendEmail(payload: EmailPayload): Promise<boolean> {
  const { apiKey, from } = getResendConfig();
  if (!apiKey || !from) return false;

  try {
    const res = await fetch(RESEND_API_URL, {
      method: 'POST',
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
      const body = await res.text();
      console.error('Resend email failed:', res.status, body);
      return false;
    }
    return true;
  } catch (error) {
    console.error('Resend email error:', error);
    return false;
  }
}
