import test from 'node:test';
import assert from 'node:assert/strict';
import { effectiveAccess, normalizeGoogle, normalizeStripe, parseProviderTime, retryDelay } from './types.js';
import { appleAccountToken, obfuscatedAccountId, seal, tokenHash, unseal } from './secrets.js';
import { googleContract, verifyGoogle } from './google.js';
import { appleContract, verifyApple } from './apple.js';
import { saveContract } from './repository.js';
import { minorAmount, stripeContract, stripeWebhookHandler } from '../stripe.js';
import { SignedDataVerifier, Environment } from '@apple/app-store-server-library';

const now=new Date('2026-09-24T12:00:00Z'),future=new Date('2026-10-24T12:00:00Z');
const base={lineItems:[{productId:'finsight_monthly',expiryTime:future.toISOString(),autoRenewingPlan:{autoRenewEnabled:true},offerDetails:{basePlanId:'monthly'}}],subscriptionState:'SUBSCRIPTION_STATE_ACTIVE',acknowledgementState:'ACKNOWLEDGEMENT_STATE_PENDING'};
process.env.BILLING_ACCOUNT_ID_SECRET='test-only-account-binding-key-at-least-32-bytes';
process.env.BILLING_ENCRYPTION_KEY=Buffer.alloc(32,42).toString('base64');

test('RFC3339 and Google states preserve canceled access until expiry, never pending/hold/paused',()=>{
  assert.equal(parseProviderTime(base.lineItems[0].expiryTime)?.toISOString(),future.toISOString());
  const cases=[['ACTIVE','active',true],['IN_GRACE_PERIOD','grace',true],['CANCELED','cancel_at_period_end',true],['ON_HOLD','hold',false],['PAUSED','paused',false],['EXPIRED','expired',false],['PENDING','pending',false],['PENDING_PURCHASE_CANCELED','expired',false]] as const;
  for(const [raw,status,access]of cases){const normalized=normalizeGoogle(`SUBSCRIPTION_STATE_${raw}`,future,now);assert.equal(normalized,status);assert.equal(effectiveAccess({status:normalized,accessUntil:future},now),access);}
  assert.equal(normalizeGoogle('SUBSCRIPTION_STATE_ACTIVE',now,now),'expired');
  assert.equal(normalizeGoogle('SUBSCRIPTION_STATE_ACTIVE',null,now),'expired');
});
test('OR preserves independent provider access; unverified/replaced/legacy cannot be counted paid',()=>{
  assert.equal([{status:'revoked',accessUntil:future},{status:'active',accessUntil:future}].some(c=>effectiveAccess(c,now)),true);
  for(const c of [{status:'legacy'},{status:'unknown'},{status:'active',verified:false},{status:'active',replaced_by_id:2}])assert.equal(effectiveAccess({...c,accessUntil:future},now),false);
});
test('Google validates products/environment, derives identity, does not guess periodicity',()=>{
  const verified=googleContract(base,'opaque-token','finsight_monthly',now);
  assert.equal(verified.contractKey,tokenHash('opaque-token'));assert.equal(verified.periodMonths,null);
  assert.throws(()=>googleContract({...base,lineItems:[{...base.lineItems[0],productId:'not-pro'}]},'token',undefined,now),/purchase_product_not_allowed/);
  process.env.BILLING_ALLOW_SANDBOX='false';assert.throws(()=>googleContract({...base,testPurchase:{}},'token',undefined,now),/sandbox_purchase_not_allowed/);
});
test('Other user token rejected before provider request',async()=>{
  let called=false;
  await assert.rejects(verifyGoogle(4,'opaque-existing-token',undefined,{tokenOwner:async()=>8,publisher:async()=>{called=true;throw Error('unreachable');},saveContract:async()=>{throw Error('unreachable');}}),/purchase_owned_by_another_account/);
  assert.equal(called,false);
});
test('Network failure never grants; verified pending is persisted without access/ACK',async()=>{
  let saved=false;
  const ports:any={tokenOwner:async()=>null,publisher:async()=>({purchases:{subscriptionsv2:{get:async()=>{throw Error('network');}}}}),saveContract:async()=>{saved=true;return {contractId:1,tokenId:1,isPro:false};}};
  await assert.rejects(verifyGoogle(4,'valid-looking-token','finsight_monthly',ports),/network/);assert.equal(saved,false);
  ports.publisher=async()=>({purchases:{subscriptionsv2:{get:async()=>({data:{...base,subscriptionState:'SUBSCRIPTION_STATE_PENDING',externalAccountIdentifiers:{obfuscatedExternalAccountId:obfuscatedAccountId(4)}}})}}});
  ports.saveContract=async(_user:any,c:any)=>{assert.equal(c.status,'pending');assert.equal(effectiveAccess(c,now),false);return {contractId:1,tokenId:1,isPro:false};};
  assert.equal((await verifyGoogle(4,'valid-looking-token','finsight_monthly',ports)).is_pro,false);
});
test('Obfuscated account mismatch prevents persisting valid store token',async()=>{
  const ports:any={tokenOwner:async()=>null,publisher:async()=>({purchases:{subscriptionsv2:{get:async()=>({data:{...base,externalAccountIdentifiers:{obfuscatedExternalAccountId:obfuscatedAccountId(8)}}})}}}),saveContract:async()=>{throw Error('unreachable');}};
  await assert.rejects(verifyGoogle(4,'valid-looking-token','finsight_monthly',ports),/purchase_account_mismatch/);
});
test('Ownership is checked again under DB transaction before any write',async()=>{
  let mutated=false;
  const connection={query:async(sql:string)=>{if(sql.startsWith('SELECT id FROM users'))return [[{id:4}]];if(sql.startsWith('SELECT user_id FROM billing_purchase_tokens'))return [[{user_id:8}]];mutated=true;throw Error('unreachable');}};
  await assert.rejects(saveContract(4,googleContract(base,'opaque-token',undefined,now),{value:'opaque-token'},(async(fn:any)=>fn(connection)) as any),/purchase_owned_by_another_account/);
  assert.equal(mutated,false);
});
test('Apple grace/hold/revoked/cancel-at-end preserve their distinct meaning',()=>{
  const p={productId:'finsight_monthly',originalTransactionId:'original',expiresDate:future.getTime()};
  assert.equal(appleContract(p,{autoRenewStatus:0},1,false,now).status,'cancel_at_period_end');
  assert.equal(appleContract(p,{gracePeriodExpiresDate:future.getTime()},4,false,now).status,'grace');
  assert.equal(appleContract(p,{},3,false,now).status,'hold');
  assert.equal(appleContract({...p,revocationDate:now.getTime()},{},1,false,now).status,'revoked');
});
test('Forged StoreKit2 payload rejected by official verifier; missing config fails closed',async()=>{
  const forged=`${Buffer.from('{"alg":"none"}').toString('base64url')}.${Buffer.from(JSON.stringify({productId:'finsight_monthly',bundleId:'com.finsight.finsight',originalTransactionId:'forged',expiresDate:future.getTime()})).toString('base64url')}.signature`;
  await assert.rejects(new SignedDataVerifier([],false,Environment.PRODUCTION,'com.finsight.finsight',123456).verifyAndDecodeTransaction(forged));
  const roots=process.env.APPLE_ROOT_CA_PATHS;delete process.env.APPLE_ROOT_CA_PATHS;
  await assert.rejects(verifyApple(4,forged,'finsight_monthly'));
  if(roots!==undefined)process.env.APPLE_ROOT_CA_PATHS=roots;
});
test('Encrypted secrets randomized/authenticated, opaque binding not an email',()=>{
  const one=seal({token:'never-log-this'}),two=seal({token:'never-log-this'});
  assert.notEqual(one,two);assert.equal(one.includes('never-log'),false);assert.deepEqual(unseal(one),{token:'never-log-this'});
  const parts=one.split('.');parts[2]=Buffer.alloc(16).toString('base64');assert.throws(()=>unseal(parts.join('.')));
  assert.notEqual(obfuscatedAccountId(4),obfuscatedAccountId(8));assert.match(appleAccountToken(4),/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-a[a-f0-9]{3}-[a-f0-9]{12}$/);
});
test('Stripe annual /12, unknown discounts, distinct currencies and trial/cancel states',()=>{
  assert.equal(normalizeStripe('active',true),'cancel_at_period_end');assert.equal(normalizeStripe('past_due',false),'hold');assert.equal(normalizeStripe('trialing',false),'trial');
  const sub:any={id:'sub1',status:'active',cancel_at_period_end:false,current_period_end:future.getTime()/1000,livemode:true,items:{data:[{quantity:1,price:{id:'annual',product:'pro',currency:'usd',unit_amount:12000,recurring:{interval:'year',interval_count:1}}}]}};
  const contract=stripeContract(sub);assert.equal(contract.recurringAmount,'120.00');assert.equal(contract.periodMonths,12);assert.equal(stripeContract({...sub,discount:{id:'discount'}}).recurringAmount,null);
  assert.equal(minorAmount(500,'UGX'),'5.00');assert.equal(minorAmount(1200,'JPY'),'1200');assert.equal(minorAmount(1200,'USD'),'12.00');assert.equal(minorAmount(1200,'KWD'),'1.200');
});
test('Stripe missing signature secret cannot accept JSON as an authenticated event',async()=>{
  const existing=process.env.STRIPE_WEBHOOK_SECRET;delete process.env.STRIPE_WEBHOOK_SECRET;let status=0;
  const response:any={status(code:number){status=code;return this;},json(){return this;}};
  await stripeWebhookHandler({body:{type:'checkout.session.completed'}} as any,response);assert.equal(status,503);
  if(existing!==undefined)process.env.STRIPE_WEBHOOK_SECRET=existing;
});
test('Backoff is exponential with six-hour bound',()=>{assert.equal(retryDelay(1),60);assert.equal(retryDelay(12),21600);});

test('New purchases require account binding by default; known legacy ownership can restore',async()=>{
 const ports:any={tokenOwner:async()=>null,publisher:async()=>({purchases:{subscriptionsv2:{get:async()=>({data:base})}}}),saveContract:async()=>({contractId:1,tokenId:1,isPro:true})};
 await assert.rejects(verifyGoogle(4,'valid-looking-token',undefined,ports),/purchase_account_identity_missing/);ports.tokenOwner=async()=>4;assert.equal((await verifyGoogle(4,'valid-looking-token',undefined,ports)).is_pro,true);
});
test('RTDN rejects missing/wrong JWT identity/package and never acknowledges failed durable write',async()=>{
 const {acceptGoogleRtdn}=await import('./rtdn.js');process.env.GOOGLE_RTDN_AUDIENCE='https://example.invalid/webhooks/google-play';process.env.GOOGLE_RTDN_SERVICE_ACCOUNT='push@example.invalid';
 const audience=process.env.GOOGLE_RTDN_AUDIENCE;let stored=0;
 const message={messageId:'id-123',data:Buffer.from(JSON.stringify({packageName:'com.finsight.finsight',subscriptionNotification:{purchaseToken:'opaque-valid-token'},unneededPrivateField:'omit'})).toString('base64')};
 const ports:any={verify:async(_token:string,aud:string)=>{assert.equal(aud,audience);return{iss:'https://accounts.google.com',email:'push@example.invalid',email_verified:true,aud:audience};},storeInbox:async(_provider:string,_id:string,payload:any)=>{assert.equal(payload.unneededPrivateField,undefined);stored++;}};
 await assert.rejects(acceptGoogleRtdn(undefined,message,ports),/rtdn_auth_required/);assert.equal(stored,0);
 await acceptGoogleRtdn('Bearer signed-jwt',message,ports);assert.equal(stored,1);
 const wrong={...ports,verify:async()=>({iss:'https://accounts.google.com',email:'intruder@example.invalid',email_verified:true,aud:audience})};await assert.rejects(acceptGoogleRtdn('Bearer signed-jwt',message,wrong),/invalid_rtdn_identity/);
 const wrongPackage={...message,data:Buffer.from(JSON.stringify({packageName:'not.finsight',testNotification:{}})).toString('base64')};await assert.rejects(acceptGoogleRtdn('Bearer signed-jwt',wrongPackage,ports),/rtdn_package_mismatch/);
 await assert.rejects(acceptGoogleRtdn('Bearer signed-jwt',message,{...ports,storeInbox:async()=>{throw Error('disk unavailable');}}),/disk unavailable/);
});
test('Google ACK retries failed network, revalidates pending and never consumes',async()=>{
 const {acknowledgeGoogle}=await import('./google.js');let updated=false,acks=0,pending=false;
 const ports:any={query:async(sql:string)=>{if(sql.startsWith('SELECT'))return [[{secret_encrypted:seal('opaque-token'),product_id:'finsight_monthly'}]];updated=true;return [{}];},publisher:async()=>({purchases:{subscriptionsv2:{get:async()=>({data:{...base,subscriptionState:pending?'SUBSCRIPTION_STATE_PENDING':'SUBSCRIPTION_STATE_ACTIVE'}})},subscriptions:{acknowledge:async()=>{acks++;if(acks===1)throw Error('network');}}}})};
 await assert.rejects(acknowledgeGoogle(1,ports),/network/);assert.equal(updated,false);await acknowledgeGoogle(1,ports);assert.equal(updated,true);assert.equal(acks,2);pending=true;updated=false;await assert.rejects(acknowledgeGoogle(1,ports),/ack_purchase_not_deliverable/);assert.equal(updated,false);assert.equal(acks,2);
});
test('Google order amounts use actual charge/refund events and distinct currencies, not catalogue estimates',async()=>{
 const {googleOrderCharges}=await import('./google.js');const order={orderId:'GPA.synthetic',total:{currencyCode:'MXN',units:'199',nanos:500000000},orderHistory:{processedEvent:{eventTime:now.toISOString()},partialRefundEvents:[{createTime:now.toISOString(),processTime:future.toISOString(),state:'PROCESSED_SUCCESSFULLY',refundDetails:{total:{currencyCode:'MXN',units:'20'}}}]}};
 const entries=googleOrderCharges(order);assert.equal(entries.length,2);assert.equal(entries[0].amount,'199.500000');assert.equal(entries[1].kind,'refund');assert.equal(entries[1].amount,'20.000000');assert.equal(entries[1].occurredAt.toISOString(),future.toISOString());assert.equal(googleOrderCharges({orderId:'pending',total:order.total}).length,0);
});

test('Verified out-of-app/replacement chain preserves legacy owner without reopening arbitrary claims',async()=>{
 const ports:any={tokenOwner:async(_p:string,t:string)=>t==='known-old-token'?4:null,publisher:async()=>({purchases:{subscriptionsv2:{get:async()=>({data:{...base,outOfAppPurchaseContext:{expiredPurchaseToken:'known-old-token'}}})}}}),saveContract:async()=>({contractId:1,tokenId:1,isPro:true})};
 assert.equal((await verifyGoogle(4,'new-opaque-token',undefined,ports)).is_pro,true);await assert.rejects(verifyGoogle(8,'new-opaque-token',undefined,ports),/replacement_owned_by_another_account/);
});
