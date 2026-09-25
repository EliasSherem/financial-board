import { db } from '../server/db.js';
import { fcmConfiguration, sendFcmDetailed } from '../server/fcm.js';

// Operator diagnostics only. This command always uses FCM validate_only and does
// not enqueue events, change registrations, or deliver messages to phones.
async function main() {
  const config = fcmConfiguration();
  if (!config) throw new Error('FCM_CONFIGURATION');
  const [counts] = await db.query(`SELECT platform,COUNT(*) AS registrations FROM device_tokens GROUP BY platform`);
  const [rows] = await db.query(`SELECT d.token,d.platform FROM device_tokens d
    WHERE NOT EXISTS (SELECT 1 FROM device_tokens other WHERE other.token=d.token AND other.user_id<>d.user_id)
    ORDER BY d.id DESC LIMIT 10`);
  const devices = rows as { token: string; platform: string | null }[];
  const results = await sendFcmDetailed(devices.map(device => device.token),
    { title: 'FinSight configuration check', body: 'Validation only; this message is never delivered.' },
    undefined, undefined, true);
  const outcomes: Record<string, number> = {};
  for (const result of results) outcomes[result.code] = (outcomes[result.code] ?? 0) + 1;
  const validated = results.filter(result => result.status === 'validated').length;
  console.log(JSON.stringify({ diagnostic: 'push_validation', validate_only: true, project: config.projectId,
    authentication: config.mode, registrations: counts, checked: devices.length, validated, outcomes }));
  if (!devices.length || !validated) process.exitCode = 2;
}
try { await main(); }
catch { console.error('push_validation_failed'); process.exitCode = 1; }
finally { await db.end(); }
