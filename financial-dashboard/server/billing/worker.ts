import { db } from '../db.js';
import { verifyGoogle, acknowledgeGoogle, googlePackage, reconcileGoogleOrder } from './google.js';
import { syncAppleContract, verifyApple } from './apple.js';
import { claimWork, contractOwner, finishWork, refreshEntitlement, tokenOwner, unseal } from './repository.js';
import { processStripeEvent, syncUserSubscription } from '../stripe.js';
import { BillingError, safeError } from './types.js';

export async function syncBillingUser(userId:number):Promise<{is_pro:boolean;sync_pending:boolean}> {
  let failed=false;
  const [tokens]:any=await db.query('SELECT provider,secret_encrypted,product_id FROM billing_purchase_tokens WHERE user_id=?',[userId]);
  const googleTokens=new Set<string>();
  for(const token of tokens) if(token.provider==='google')googleTokens.add(unseal<string>(token.secret_encrypted));
  const [legacy]:any=await db.query('SELECT purchase_token FROM play_subscriptions WHERE user_id=?',[userId]);
  for(const row of legacy)googleTokens.add(row.purchase_token);
  for(const token of googleTokens)try {await verifyGoogle(userId,token);}catch{failed=true;}
  const [apple]:any=await db.query(`SELECT contract_key,environment,status FROM billing_contracts WHERE user_id=? AND provider='apple'`,[userId]);
  for(const contract of apple)try {
    if(contract.status==='legacy') {
      const [receipts]:any=await db.query('SELECT product_id,receipt_data FROM app_store_subscriptions WHERE user_id=? AND original_transaction_id=?',[userId,contract.contract_key]);
      if(receipts[0]?.receipt_data)await verifyApple(userId,receipts[0].receipt_data,receipts[0].product_id);
      else await syncAppleContract(userId,contract.contract_key,contract.environment==='test');
    } else await syncAppleContract(userId,contract.contract_key,contract.environment==='test');
  } catch {failed=true;}
  try {await syncUserSubscription(userId);}catch{failed=true;}
  return {is_pro:await refreshEntitlement(userId),sync_pending:failed};
}
export async function processInbox(row:any) {
  const payload=unseal<any>(row.payload_encrypted);
  if(payload.test)return;
  if(row.provider==='stripe'){await processStripeEvent(payload);return;}
  if(row.provider==='apple') {
    const owner=await contractOwner('apple',payload.originalId);
    if(owner===null)throw new BillingError('purchase_owner_not_linked',409);
    await db.query('UPDATE billing_inbox SET user_id=? WHERE id=?',[owner,row.id]);
    await syncAppleContract(owner,payload.originalId,payload.sandbox);return;
  }
  if(payload.packageName!==googlePackage())throw new BillingError('rtdn_package_mismatch');
  const token=payload.subscriptionNotification?.purchaseToken||payload.voidedPurchaseNotification?.purchaseToken;
  if(!token)throw new BillingError('rtdn_purchase_token_missing');
  let owner=await tokenOwner('google',token);
  if(owner===null) {
    // A replacement can arrive before its new token is linked by the client.
    const {google}=await import('googleapis');
    const auth=await google.auth.getClient({scopes:['https://www.googleapis.com/auth/androidpublisher']});
    const {data}=await google.androidpublisher({version:'v3',auth}).purchases.subscriptionsv2.get({packageName:googlePackage(),token},{timeout:15000});
    const oldToken=data.linkedPurchaseToken||(data as any).outOfAppPurchaseContext?.expiredPurchaseToken;
    if(oldToken)owner=await tokenOwner('google',oldToken);
  }
  if(owner===null)throw new BillingError('purchase_owner_not_linked',409);
  await db.query('UPDATE billing_inbox SET user_id=? WHERE id=?',[owner,row.id]);
  const saved=await verifyGoogle(owner,token);
  if(saved.tokenId && payload.voidedPurchaseNotification?.orderId)await db.query("INSERT INTO billing_jobs(user_id,job_key,kind,token_id,order_id) VALUES(?,?,'google_order',?,?) ON DUPLICATE KEY UPDATE status=IF(status='processing',status,'pending'),next_attempt_at=UTC_TIMESTAMP(3)",[owner,`order:${payload.voidedPurchaseNotification.orderId}`,saved.tokenId,payload.voidedPurchaseNotification.orderId]);
}
export async function runBillingBatch(limit=20):Promise<void> {
  for(const table of ['billing_inbox','billing_jobs'] as const)for(let i=0;i<limit;i++) {
    const row=await claimWork(table);if(!row)break;
    try {
      if(table==='billing_inbox')await processInbox(row);
      else if(row.kind==='google_order')await reconcileGoogleOrder(Number(row.token_id),row.order_id);
      else if(row.kind==='ack_google')await acknowledgeGoogle(Number(row.token_id));
      else if(row.kind==='sync_user'){const result=await syncBillingUser(Number(row.user_id));if(result.sync_pending)throw new BillingError('provider_sync_incomplete',503);}
      await finishWork(table,row);
    }catch(error){await finishWork(table,row,error);}
  }
}
export async function scheduleReconciliation():Promise<void> {
  await db.query(`INSERT INTO billing_jobs(user_id,job_key,kind)
    SELECT DISTINCT c.user_id,CONCAT('sync:',c.user_id),'sync_user' FROM billing_contracts c
    WHERE c.replaced_by_id IS NULL AND (c.synced_at IS NULL OR c.synced_at<DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 6 HOUR))
    ON DUPLICATE KEY UPDATE
      next_attempt_at=IF(billing_jobs.status='done',UTC_TIMESTAMP(3),billing_jobs.next_attempt_at),
      attempts=IF(billing_jobs.status='done',0,billing_jobs.attempts),
      last_error_code=IF(billing_jobs.status='done',NULL,billing_jobs.last_error_code),
      status=IF(billing_jobs.status='done','pending',billing_jobs.status)`);
  // Recent known orders are revisited daily for refund updates, including old renewals.
  // Read the old status before changing it; pending retries retain their backoff and processing leases.
  await db.query(`INSERT INTO billing_jobs(user_id,job_key,kind,token_id,order_id)
    SELECT b.user_id,CONCAT('order:',b.provider_charge_id),'google_order',t.id,b.provider_charge_id
    FROM billing_charges b JOIN billing_purchase_tokens t ON t.contract_id=b.contract_id AND t.provider='google'
    WHERE b.provider='google' AND b.kind='charge' AND b.occurred_at>UTC_TIMESTAMP()-INTERVAL 180 DAY
    ON DUPLICATE KEY UPDATE
      next_attempt_at=IF(billing_jobs.status='done' AND billing_jobs.completed_at<UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP(3),billing_jobs.next_attempt_at),
      attempts=IF(billing_jobs.status='done' AND billing_jobs.completed_at<UTC_TIMESTAMP()-INTERVAL 1 DAY,0,billing_jobs.attempts),
      last_error_code=IF(billing_jobs.status='done' AND billing_jobs.completed_at<UTC_TIMESTAMP()-INTERVAL 1 DAY,NULL,billing_jobs.last_error_code),
      status=IF(billing_jobs.status='done' AND billing_jobs.completed_at<UTC_TIMESTAMP()-INTERVAL 1 DAY,'pending',billing_jobs.status)`);
  // Retention removes encrypted webhook data after handling, never contracts/revenue ledgers.
  await db.query(`DELETE FROM billing_inbox WHERE (status='done' AND received_at<DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 30 DAY)) OR received_at<DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 180 DAY)`);
  await db.query(`DELETE FROM billing_jobs WHERE status='done' AND completed_at<DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 30 DAY)`);
}
export function startBillingWorker():()=>void {
  if(process.env.BILLING_WORKER_ENABLED==='false')return ()=>{};
  let busy=false,lastReconcile=0;
  const tick=async()=>{
    if(busy)return;busy=true;
    try {if(Date.now()-lastReconcile>3600000){await scheduleReconciliation();lastReconcile=Date.now();}await runBillingBatch();}
    catch(error){console.error('[billing] worker unavailable',{code:safeError(error)});}
    finally{busy=false;}
  };
  void tick();const interval=setInterval(()=>void tick(),30000);interval.unref();return()=>clearInterval(interval);
}
