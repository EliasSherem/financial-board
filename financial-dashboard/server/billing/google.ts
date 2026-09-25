import { google } from 'googleapis';
import { BillingError, normalizeGoogle, parseProviderTime, type VerifiedContract } from './types.js';
import { obfuscatedAccountId, productIds, tokenHash } from './secrets.js';
import { recordCharge, saveContract, tokenOwner } from './repository.js';
import { db } from '../db.js';
export function googlePackage():string { return process.env.ANDROID_PACKAGE_NAME || 'com.finsight.finsight'; }
async function publisher() {
  const auth=await google.auth.getClient({scopes:['https://www.googleapis.com/auth/androidpublisher']});
  return google.androidpublisher({version:'v3',auth});
}
export function googleContract(payload:any,token:string,productId?:string,now=new Date()):VerifiedContract {
  const allowed=productIds('google');
  const items=Array.isArray(payload?.lineItems)?payload.lineItems:[];
  const selected=items.filter((item:any)=>allowed.includes(item.productId)&&(!productId||item.productId===productId))
    .sort((a:any,b:any)=>(parseProviderTime(b.expiryTime)?.getTime()??0)-(parseProviderTime(a.expiryTime)?.getTime()??0))[0];
  if(!selected)throw new BillingError('purchase_product_not_allowed');
  const environment=payload.testPurchase?'test':'production';
  if(environment==='test' && process.env.BILLING_ALLOW_SANDBOX!=='true')throw new BillingError('sandbox_purchase_not_allowed');
  const accessUntil=parseProviderTime(selected.expiryTime);
  const rawState=String(payload.subscriptionState||'UNKNOWN');
  // v2 does not provide contractual duration for all plans; leave unknown, never infer monthly from SKU.
  const price=selected.autoRenewingPlan?.recurringPrice;
  let recurringAmount:string|null=null;
  if(price?.currencyCode && (price.units!=null||price.nanos!=null))recurringAmount=(Number(price.units||0)+Number(price.nanos||0)/1e9).toFixed(6);
  const isTrial=selected.offerPhase?.freeTrial!=null;
  const status=normalizeGoogle(rawState,accessUntil,now);
  return {provider:'google',contractKey:tokenHash(token),productId:selected.productId,basePlanId:selected.offerDetails?.basePlanId??null,rawState,status:isTrial&&status==='active'?'trial':status,accessUntil,isTrial,autoRenewing:selected.autoRenewingPlan?.autoRenewEnabled??false,currency:price?.currencyCode??null,recurringAmount,periodMonths:null,environment,linkedToken:payload.linkedPurchaseToken??payload.outOfAppPurchaseContext?.expiredPurchaseToken,acknowledged:payload.acknowledgementState==='ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',accountId:payload.externalAccountIdentifiers?.obfuscatedExternalAccountId,orderIds:[selected.latestSuccessfulOrderId||payload.latestOrderId].filter(Boolean)};
}
export interface GoogleVerificationPorts {
  publisher: typeof publisher;
  tokenOwner: typeof tokenOwner;
  saveContract: typeof saveContract;
}
export async function verifyGoogle(userId:number,token:string,productId?:string,ports:GoogleVerificationPorts={publisher,tokenOwner,saveContract},flowId?:string) {
  if(token.length<8||token.length>4096||!token.trim())throw new BillingError('invalid_purchase_token');
  const owner=await ports.tokenOwner('google',token);
  if(owner!==null&&owner!==userId)throw new BillingError('purchase_owned_by_another_account',409);
  const api=await ports.publisher();
  const observedAt=new Date();
  const {data}=await api.purchases.subscriptionsv2.get({packageName:googlePackage(),token},{timeout:15000});
  const contract=googleContract(data,token,productId);
  contract.observedAt=observedAt; contract.flowId=flowId;
  const linkedOwner=owner===null&&contract.linkedToken?await ports.tokenOwner('google',contract.linkedToken):null;
  if(linkedOwner!==null&&linkedOwner!==userId)throw new BillingError('replacement_owned_by_another_account',409);
  if(contract.accountId && contract.accountId!==obfuscatedAccountId(userId))throw new BillingError('purchase_account_mismatch',409);
  if(!contract.accountId && owner===null && linkedOwner===null && process.env.GOOGLE_PLAY_REQUIRE_ACCOUNT_ID!=='false')throw new BillingError('purchase_account_identity_missing',409);
  const saved=await ports.saveContract(userId,contract,{value:token});
  return {success:true,verified:true,state:contract.rawState,expiry:contract.accessUntil,is_pro:saved.isPro,acknowledged:Boolean(contract.acknowledged),ack_owner:'server',...saved};
}
export async function acknowledgeGoogle(tokenId:number,ports:{query:typeof db.query;publisher:typeof publisher}={query:db.query.bind(db),publisher}):Promise<void> {
  const [rows]:any=await ports.query(`SELECT t.*,c.status,c.access_until,c.verified,c.replaced_by_id FROM billing_purchase_tokens t JOIN billing_contracts c ON c.id=t.contract_id WHERE t.id=?`,[tokenId]);
  if(!rows.length)return;
  const row=rows[0];
  const {unseal}=await import('./secrets.js');
  const token=unseal<string>(row.secret_encrypted);
  const api=await ports.publisher();
  const {data}=await api.purchases.subscriptionsv2.get({packageName:googlePackage(),token},{timeout:15000});
  const latest=googleContract(data,token,row.product_id);
  // Revalidate before ACK; a pending/failed payment must never be acknowledged as delivery.
  if(!['active','trial','grace','cancel_at_period_end'].includes(latest.status))throw new BillingError('ack_purchase_not_deliverable',409);
  if(!latest.acknowledged)await api.purchases.subscriptions.acknowledge({packageName:googlePackage(),subscriptionId:latest.productId,token,requestBody:{}},{timeout:15000});
  await ports.query('UPDATE billing_purchase_tokens SET acknowledged=TRUE WHERE id=?',[tokenId]);
}

export function googleOrderCharges(order:any):NonNullable<VerifiedContract['charges']> {
  const money=(value:any):string|null=>value?.currencyCode && Number.isFinite(Number(value.units??0)) && Number.isFinite(Number(value.nanos??0))?(Number(value.units??0)+Number(value.nanos??0)/1e9).toFixed(6):null;
  const result:NonNullable<VerifiedContract['charges']>=[];
  const append=(id:string,kind:'charge'|'refund',amount:any,time:any)=>{
    const value=money(amount),at=parseProviderTime(time);
    if(value!==null&&at&&Number(value)>=0)result.push({id,kind,amount:value,currency:amount.currencyCode,occurredAt:at});
  };
  const history=order.orderHistory??{};
  if(history.processedEvent)append(order.orderId,'charge',order.total,history.processedEvent.eventTime);
  if(history.refundEvent)append(`${order.orderId}:refund`,'refund',history.refundEvent.refundDetails?.total,history.refundEvent.eventTime);
  for(const event of history.partialRefundEvents??[])if(event.state==='PROCESSED_SUCCESSFULLY')append(`${order.orderId}:${event.createTime}`,'refund',event.refundDetails?.total,event.processTime);
  return result;
}
/** Order totals are real collections, never inferred from a subscription catalogue price. */
export async function reconcileGoogleOrder(tokenId:number,orderId:string):Promise<void> {
  const [rows]:any=await db.query('SELECT t.user_id,t.contract_id,t.token_hash,c.environment FROM billing_purchase_tokens t JOIN billing_contracts c ON c.id=t.contract_id WHERE t.id=?',[tokenId]);
  if(!rows.length)return;
  const auth=await google.auth.getClient({scopes:['https://www.googleapis.com/auth/androidpublisher']});
  const {data}=await auth.request<any>({url:`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(googlePackage())}/orders/${encodeURIComponent(orderId)}`,timeout:15000});
  if(data.orderId!==orderId)throw new BillingError('google_order_mismatch');
  if(typeof data.purchaseToken!=='string'||tokenHash(data.purchaseToken)!==rows[0].token_hash)throw new BillingError('google_order_owner_mismatch');
  for(const charge of googleOrderCharges(data))await recordCharge({userId:Number(rows[0].user_id),contractId:Number(rows[0].contract_id),provider:'google',environment:rows[0].environment,...charge});
}
