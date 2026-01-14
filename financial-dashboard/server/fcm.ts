import { google } from 'googleapis';

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

type ServiceAccount = {
  project_id?: string;
  client_email?: string;
  private_key?: string;
};

export type NotificationPayload = {
  title: string;
  body: string;
};

let cachedServiceAccount: ServiceAccount | null | undefined;
let authClientPromise: Promise<google.auth.AuthClient> | null = null;

function loadServiceAccount(): ServiceAccount | null {
  if (cachedServiceAccount !== undefined) return cachedServiceAccount;
  const raw = process.env.FCM_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    cachedServiceAccount = null;
    return cachedServiceAccount;
  }
  try {
    cachedServiceAccount = JSON.parse(raw) as ServiceAccount;
  } catch {
    console.error('Invalid FCM_SERVICE_ACCOUNT_JSON');
    cachedServiceAccount = null;
  }
  return cachedServiceAccount;
}

export function isFcmConfigured(): boolean {
  return loadServiceAccount() !== null;
}

async function getAccessToken(): Promise<{ token: string; projectId: string }> {
  const serviceAccount = loadServiceAccount();
  if (!serviceAccount) {
    throw new Error('FCM service account not configured');
  }
  const projectId = serviceAccount.project_id || process.env.FCM_PROJECT_ID;
  if (!projectId) {
    throw new Error('FCM project id not configured');
  }
  if (!authClientPromise) {
    if (!serviceAccount.client_email || !serviceAccount.private_key) {
      throw new Error('FCM service account missing credentials');
    }
    const auth = new google.auth.GoogleAuth({
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: serviceAccount.private_key,
      },
      scopes: [FCM_SCOPE],
    });
    authClientPromise = auth.getClient();
  }
  const client = await authClientPromise;
  const accessToken = await client.getAccessToken();
  const token = typeof accessToken === 'string' ? accessToken : accessToken?.token;
  if (!token) {
    throw new Error('Failed to obtain FCM access token');
  }
  return { token, projectId };
}

export async function sendFcmNotification(
  tokens: string[],
  note: NotificationPayload,
  data?: Record<string, string>
): Promise<number> {
  if (tokens.length === 0) return 0;
  const { token, projectId } = await getAccessToken();
  const payloadData =
    data && Object.keys(data).length > 0 ? data : undefined;
  let sent = 0;
  for (const deviceToken of tokens) {
    const payload = {
      message: {
        token: deviceToken,
        notification: { title: note.title, body: note.body },
        data: payloadData,
        android: {
          notification: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
      },
    };
    const resp = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(payload),
      }
    );
    if (!resp.ok) {
      const text = await resp.text().catch(() => '');
      console.error('FCM send failed:', resp.status, text);
      continue;
    }
    sent += 1;
  }
  return sent;
}
