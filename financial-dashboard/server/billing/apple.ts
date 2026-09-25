import { readFileSync } from 'node:fs';
import { AppStoreServerAPIClient, Environment, SignedDataVerifier } from '@apple/app-store-server-library';
import { BillingError, parseProviderTime, type VerifiedContract } from './types.js';
import { appleAccountToken, productIds } from './secrets.js';
import { contractOwner, saveContract, storeInbox } from './repository.js';

function environment(sandbox=false) { return sandbox?Environment.SANDBOX:Environment.PRODUCTION; }
function verifier(sandbox=false):SignedDataVerifier {
  const roots=(process.env.APPLE_ROOT_CA_PATHS||'').split(',').map(s=>s.trim()).filter(Boolean);
  const bundle=process.env.APPLE_BUNDLE_ID;
  const appId=Number(process.env.APPLE_APP_ID);
  if(!roots.length||!bundle||(!sandbox&&!Number.isSafeInteger(appId)))throw new BillingError('apple_verification_not_configured',503);
  return new SignedDataVerifier(roots.map(p=>readFileSync(p)),true,environment(sandbox),bundle,sandbox?undefined:appId);
}
function serverClient(sandbox=false):AppStoreServerAPIClient {
  const file=process.env.APPLE_PRIVATE_KEY_PATH, keyId=process.env.APPLE_KEY_ID, issuer=process.env.APPLE_ISSUER_ID,bundle=process.env.APPLE_BUNDLE_ID;
  if(!file||!keyId||!issuer||!bundle)throw new BillingError('apple_server_api_not_configured',503);
  return new AppStoreServerAPIClient(readFileSync(file,'utf8'),keyId,issuer,bundle,environment(sandbox));
}
async function verifySigned<T>(method:'verifyAndDecodeTransaction'|'verifyAndDecodeNotification',value:string):Promise<{payload:T;sandbox:boolean}> {
  try {return {payload:await verifier(false)[method](value) as T,sandbox:false};}
  catch(error) {
    if(process.env.BILLING_ALLOW_SANDBOX==='true')return {payload:await verifier(true)[method](value) as T,sandbox:true};
    if(error instanceof BillingError)throw error;
    throw new BillingError('invalid_apple_signature');
  }
}
export function appleContract(transaction:any,renewal:any={},state?:number,sandbox=false,now=new Date()):VerifiedContract {
  if(!productIds('apple').includes(transaction.productId))throw new BillingError('purchase_product_not_allowed');
  if(!transaction.originalTransactionId)throw new BillingError('apple_original_transaction_missing');
  const expiry=parseProviderTime(transaction.expiresDate);
  const grace=parseProviderTime(renewal.gracePeriodExpiresDate);
  const raw=String(state??(transaction.revocationDate?5:expiry&&expiry>now?1:2));
  const status=transaction.revocationDate||state===5?'revoked':state===4&&grace&&grace>now?'grace':state===3?'hold':!expiry||expiry<=now||state===2?'expired':renewal.autoRenewStatus===0?'cancel_at_period_end':'active';
  const isTrial=transaction.offerDiscountType==='FREE_TRIAL';
  return {provider:'apple',contractKey:String(transaction.originalTransactionId),productId:transaction.productId,rawState:raw,status:isTrial&&status==='active'?'trial':status,accessUntil:status==='grace'?grace:expiry,isTrial,autoRenewing:renewal.autoRenewStatus==null?null:renewal.autoRenewStatus===1,environment:sandbox?'test':'production',currency:transaction.currency??null,recurringAmount:null,periodMonths:null,acknowledged:true,charges:transaction.price!=null&&transaction.currency&&transaction.transactionId&&transaction.purchaseDate?[{id:String(transaction.transactionId),kind:'charge',amount:(Number(transaction.price)/1000).toFixed(6),currency:transaction.currency,occurredAt:new Date(transaction.purchaseDate)}]:[]};
}
export async function syncAppleContract(userId:number,originalId:string,sandbox=false,flowId?:string):Promise<any> {
  if(sandbox&&process.env.BILLING_ALLOW_SANDBOX!=='true')throw new BillingError('sandbox_purchase_not_allowed');
  const api=serverClient(sandbox), verify=verifier(sandbox);
  const observedAt=new Date();
  const data=await api.getAllSubscriptionStatuses(originalId);
  const subscriptions=(data.data||[]).flatMap(group=>group.lastTransactions||[]).filter(t=>t.originalTransactionId===originalId);
  if(!subscriptions.length)throw new BillingError('apple_subscription_not_found',404);
  let newest:{contract:VerifiedContract;receipt:string}|null=null;
  for(const sub of subscriptions) {
    if(!sub.signedTransactionInfo)continue;
    const transaction=await verify.verifyAndDecodeTransaction(sub.signedTransactionInfo);
    const renewal=sub.signedRenewalInfo?await verify.verifyAndDecodeRenewalInfo(sub.signedRenewalInfo):{};
    const contract=appleContract(transaction,renewal,sub.status,sandbox);
    if(!newest||(contract.accessUntil?.getTime()??0)>(newest.contract.accessUntil?.getTime()??0))newest={contract,receipt:sub.signedTransactionInfo};
  }
  if(!newest)throw new BillingError('apple_subscription_not_found',404);
  newest.contract.observedAt=observedAt; newest.contract.flowId=flowId;
  const saved=await saveContract(userId,newest.contract,{value:newest.receipt,identity:originalId});
  return {success:true,verified:true,state:newest.contract.rawState,expiry:newest.contract.accessUntil,environment:sandbox?'Sandbox':'Production',is_pro:saved.isPro,acknowledged:true,...saved};
}
async function verifyLegacy(receipt:string,productId:string):Promise<{contract:VerifiedContract;receipt:string}> {
  const secret=process.env.APPLE_SHARED_SECRET||process.env.APPLE_APP_SHARED_SECRET||process.env.APPLE_IAP_SHARED_SECRET;
  if(!secret||!process.env.APPLE_BUNDLE_ID)throw new BillingError('apple_legacy_verification_not_configured',503);
  async function request(sandbox:boolean) {
    const response=await fetch(sandbox?'https://sandbox.itunes.apple.com/verifyReceipt':'https://buy.itunes.apple.com/verifyReceipt',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({'receipt-data':receipt,password:secret,'exclude-old-transactions':false}),signal:AbortSignal.timeout(15000)});
    if(!response.ok)throw new BillingError('apple_temporarily_unavailable',503);
    return await response.json() as any;
  }
  let payload=await request(false), sandbox=false;
  if(payload.status===21007&&process.env.BILLING_ALLOW_SANDBOX==='true'){payload=await request(true);sandbox=true;}
  if(payload.status!==0||payload.receipt?.bundle_id!==process.env.APPLE_BUNDLE_ID)throw new BillingError('invalid_apple_receipt');
  const entry=(payload.latest_receipt_info||payload.receipt?.in_app||[]).filter((r:any)=>r.product_id===productId).sort((a:any,b:any)=>Number(b.expires_date_ms)-Number(a.expires_date_ms))[0];
  if(!entry)throw new BillingError('apple_subscription_not_found',404);
  const renewal=(payload.pending_renewal_info||[]).find((r:any)=>r.original_transaction_id===entry.original_transaction_id)||{};
  const contract=appleContract({productId:entry.product_id,originalTransactionId:entry.original_transaction_id,expiresDate:Number(entry.expires_date_ms),revocationDate:entry.cancellation_date_ms?Number(entry.cancellation_date_ms):null,offerDiscountType:entry.is_trial_period==='true'?'FREE_TRIAL':null},{autoRenewStatus:renewal.auto_renew_status==null?undefined:Number(renewal.auto_renew_status),gracePeriodExpiresDate:Number(renewal.grace_period_expires_date_ms)||undefined},entry.cancellation_date_ms?5:renewal.grace_period_expires_date_ms?4:undefined,sandbox);
  return {contract,receipt:payload.latest_receipt||receipt};
}
export async function verifyApple(userId:number,receipt:string,productId:string,flowId?:string):Promise<any> {
  if(!productIds('apple').includes(productId)||!receipt||receipt.length>1024*1024)throw new BillingError('invalid_apple_purchase');
  if(receipt.split('.').length===3) {
    const {payload,sandbox}=await verifySigned<any>('verifyAndDecodeTransaction',receipt);
    if(payload.productId!==productId)throw new BillingError('purchase_product_mismatch');
    if(payload.appAccountToken && String(payload.appAccountToken).toLowerCase()!==appleAccountToken(userId))throw new BillingError('purchase_account_mismatch',409);
    const owner=await contractOwner('apple',String(payload.originalTransactionId));
    if(owner!==null&&owner!==userId)throw new BillingError('purchase_owned_by_another_account',409);
    if(!payload.appAccountToken && owner===null && process.env.APPLE_REQUIRE_ACCOUNT_TOKEN!=='false')throw new BillingError('purchase_account_identity_missing',409);
    // Signed historical transactions alone cannot detect a later revocation/renewal.
    return syncAppleContract(userId,String(payload.originalTransactionId),sandbox,flowId);
  }
  const verified=await verifyLegacy(receipt,productId);
  if(await contractOwner('apple',verified.contract.contractKey)===null && process.env.APPLE_REQUIRE_ACCOUNT_TOKEN!=='false')throw new BillingError('purchase_account_identity_missing',409);
  verified.contract.flowId=flowId;
  const saved=await saveContract(userId,verified.contract,{value:verified.receipt,identity:verified.contract.contractKey});
  return {success:true,verified:true,state:verified.contract.rawState,expiry:verified.contract.accessUntil,is_pro:saved.isPro,acknowledged:true,...saved};
}
export async function receiveAppleNotification(signedPayload:string):Promise<void> {
  if(!signedPayload||signedPayload.length>1024*1024)throw new BillingError('invalid_apple_notification');
  const {payload,sandbox}=await verifySigned<any>('verifyAndDecodeNotification',signedPayload);
  if(!payload.notificationUUID)throw new BillingError('apple_notification_id_missing');
  if(payload.notificationType==='TEST') {await storeInbox('apple',payload.notificationUUID,{test:true});return;}
  const signed=payload.data?.signedTransactionInfo;
  if(!signed)throw new BillingError('apple_notification_transaction_missing');
  const transaction=await verifier(sandbox).verifyAndDecodeTransaction(signed);
  const originalId=String(transaction.originalTransactionId||'');
  const owner=await contractOwner('apple',originalId);
  await storeInbox('apple',payload.notificationUUID,{originalId,sandbox},owner);
}
