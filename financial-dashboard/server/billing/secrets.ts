import { createCipheriv, createDecipheriv, createHash, createHmac, randomBytes } from 'node:crypto';
import { BillingError } from './types.js';
export function tokenHash(token: string): string { return createHash('sha256').update(token).digest('hex'); }
function key(): Buffer {
  const encoded = process.env.BILLING_ENCRYPTION_KEY || '';
  const value = Buffer.from(encoded, 'base64');
  if (value.length !== 32) throw new BillingError('billing_encryption_not_configured',503);
  return value;
}
export function seal(value: unknown): string {
  const iv = randomBytes(12); const cipher = createCipheriv('aes-256-gcm',key(),iv);
  const body = Buffer.concat([cipher.update(JSON.stringify(value),'utf8'),cipher.final()]);
  return ['v1',iv.toString('base64'),cipher.getAuthTag().toString('base64'),body.toString('base64')].join('.');
}
export function unseal<T = any>(encoded: string): T {
  const [version,iv,tag,body] = encoded.split('.');
  if(version!=='v1'||!iv||!tag||!body)throw new BillingError('billing_secret_invalid',503);
  const decipher = createDecipheriv('aes-256-gcm',key(),Buffer.from(iv,'base64'));
  decipher.setAuthTag(Buffer.from(tag,'base64'));
  return JSON.parse(Buffer.concat([decipher.update(Buffer.from(body,'base64')),decipher.final()]).toString('utf8')) as T;
}
export function obfuscatedAccountId(userId: number): string {
  const secret = process.env.BILLING_ACCOUNT_ID_SECRET;
  if (!secret || secret.length < 32) throw new BillingError('billing_account_identity_not_configured',503);
  return createHmac('sha256',secret).update(`finsight:${userId}`).digest('hex');
}
export function appleAccountToken(userId:number):string {
  const hash=obfuscatedAccountId(userId);
  // A UUID-shaped opaque identifier is required by StoreKit2's appAccountToken.
  return `${hash.slice(0,8)}-${hash.slice(8,12)}-4${hash.slice(13,16)}-a${hash.slice(17,20)}-${hash.slice(20,32)}`;
}
export function productIds(provider: 'google'|'apple'): string[] {
  // Existing shipped aliases are preserved. Console availability is never inferred.
  const observed = provider==='google' ? 'finsight_monthly,finsight_pro_monthly' : '7T8M8X5R46,finsight_pro_monthly,finsight_monthly';
  return (process.env[provider==='google'?'GOOGLE_PLAY_PRODUCT_IDS':'APPLE_PRODUCT_IDS'] || observed).split(',').map(x=>x.trim()).filter(Boolean);
}
