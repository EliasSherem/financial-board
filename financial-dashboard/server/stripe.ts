import Stripe from 'stripe';
import { randomUUID } from 'node:crypto';
import type { Request, Response } from 'express';
import { db } from './db.js';
import { BillingError, normalizeStripe, safeError, type VerifiedContract } from './billing/types.js';
import { recordCharge, refreshEntitlement, saveContract, storeInbox } from './billing/repository.js';

let client: Stripe | undefined;
export function getStripe(): Stripe {
  if (!process.env.STRIPE_SECRET_KEY) throw new BillingError('stripe_not_configured',503);
  return client ??= new Stripe(process.env.STRIPE_SECRET_KEY,{apiVersion:'2024-06-20',timeout:15000,maxNetworkRetries:2});
}
function clientBaseUrl() { return process.env.CLIENT_URL || 'http://localhost:5173'; }
async function getOrCreateCustomer(userId:number):Promise<string> {
  const [rows]:any=await db.query('SELECT email,stripe_customer_id FROM users WHERE id=?',[userId]);
  if(!rows.length)throw new BillingError('user_not_found',404);
  if(rows[0].stripe_customer_id)return rows[0].stripe_customer_id;
  const customer=await getStripe().customers.create({email:rows[0].email||undefined,metadata:{user_id:String(userId)}},{idempotencyKey:`finsight-customer-${userId}`});
  await db.query('UPDATE users SET stripe_customer_id=? WHERE id=? AND stripe_customer_id IS NULL',[customer.id,userId]);
  return customer.id;
}
export async function createCheckoutSession(userId:number,flowId?:string) {
  if(process.env.BILLING_CHECKOUT_ENABLED==='false')throw new BillingError('checkout_temporarily_unavailable',503);
  const customerId=await getOrCreateCustomer(userId);
  const session=await getStripe().checkout.sessions.create({mode:'subscription',customer:customerId,
    line_items:[{price_data:{currency:(process.env.STRIPE_CURRENCY||'usd').toLowerCase(),product_data:{name:'FinSight Pro',description:'Unlimited accounts, analytics, projects & invoices'},recurring:{interval:'month'},unit_amount:Number.parseInt(process.env.STRIPE_UNIT_AMOUNT||'1000',10)},quantity:1}],
    allow_promotion_codes:true,success_url:`${clientBaseUrl()}/payments?upgraded=1`,cancel_url:`${clientBaseUrl()}/payments?canceled=1`,metadata:{user_id:String(userId),...(flowId?{flow_id:flowId}:{})},subscription_data:{metadata:{user_id:String(userId),...(flowId?{flow_id:flowId}:{})}}},{idempotencyKey:`checkout-${userId}-${randomUUID()}`});
  return {url:session.url};
}
export async function createPortalSession(userId:number) {
  const session=await getStripe().billingPortal.sessions.create({customer:await getOrCreateCustomer(userId),return_url:`${clientBaseUrl()}/payments`});
  return {url:session.url};
}
export function minorAmount(amount:number,currency:string):string {
  const zero=new Set(['BIF','CLP','DJF','GNF','JPY','KMF','KRW','MGA','PYG','RWF','VND','VUV','XAF','XOF','XPF']);
  // Stripe API encodes its three-decimal currencies in the smallest unit too.
  const decimals=zero.has(currency.toUpperCase())?0:['BHD','JOD','KWD','OMR','TND'].includes(currency.toUpperCase())?3:2;
  return (amount/10**decimals).toFixed(decimals);
}
export function stripeContract(sub:Stripe.Subscription):VerifiedContract {
  const items=sub.items.data;
  const first=items[0];
  const price=first?.price;
  const interval=price?.recurring;
  const months=interval?.interval==='year'?12*interval.interval_count:interval?.interval==='month'?interval.interval_count:null;
  // Mixed items/discounts lack a reliable simple recurring amount; report N/D instead of guessed MRR.
  const amount=items.length===1 && !sub.discount && price?.unit_amount!=null ? minorAmount(price.unit_amount*(first.quantity??1),price.currency):null;
  return {provider:'stripe',contractKey:sub.id,productId:typeof price?.product==='string'?price.product:price?.product?.id||'unknown',basePlanId:price?.id??null,rawState:sub.status,status:normalizeStripe(sub.status,sub.cancel_at_period_end),accessUntil:sub.current_period_end?new Date(sub.current_period_end*1000):null,isTrial:sub.status==='trialing',autoRenewing:!sub.cancel_at_period_end,currency:price?.currency?.toUpperCase()??null,recurringAmount:amount,periodMonths:months,environment:sub.livemode?'production':'test',flowId:sub.metadata?.flow_id};
}
export async function ingestStripeSubscription(sub:Stripe.Subscription,expectedUser?:number,observedAt=new Date()) {
  const userId=Number(sub.metadata.user_id||expectedUser||0);
  if(!Number.isSafeInteger(userId)||userId<=0)throw new BillingError('stripe_account_mapping_missing',409);
  if(expectedUser&&userId!==expectedUser)throw new BillingError('stripe_account_mismatch',409);
  const customer=typeof sub.customer==='string'?sub.customer:sub.customer.id;
  const [rows]:any=await db.query('SELECT stripe_customer_id FROM users WHERE id=?',[userId]);
  if(!rows.length||rows[0].stripe_customer_id!==customer)throw new BillingError('stripe_customer_mismatch',409);
  const saved=await saveContract(userId,{...stripeContract(sub),observedAt});
  // Keep distributed client columns, but never write is_pro independently of all sources.
  await db.query('UPDATE users SET stripe_subscription_id=?,stripe_subscription_status=?,stripe_current_period_end=? WHERE id=?',[sub.id,sub.status,new Date(sub.current_period_end*1000),userId]);
  return {...saved,userId};
}
export async function syncUserSubscription(userId:number):Promise<{is_pro:boolean}> {
  const [rows]:any=await db.query('SELECT stripe_customer_id FROM users WHERE id=?',[userId]);
  if(rows[0]?.stripe_customer_id) {
    const observedAt=new Date();
    for await(const sub of getStripe().subscriptions.list({customer:rows[0].stripe_customer_id,status:'all',limit:100}))await ingestStripeSubscription(sub,userId,observedAt);
  }
  return {is_pro:await refreshEntitlement(userId)};
}
export async function cancelUserSubscription(userId:number) {
  const [rows]:any=await db.query('SELECT stripe_subscription_id FROM users WHERE id=?',[userId]);
  if(!rows[0]?.stripe_subscription_id)throw new BillingError('no_active_subscription_to_cancel',400);
  const stripe=getStripe();
  const sub=await stripe.subscriptions.retrieve(rows[0].stripe_subscription_id);
  const canceled=sub.status==='canceled'?sub:await stripe.subscriptions.cancel(sub.id);
  await ingestStripeSubscription(canceled,userId);
  return {status:canceled.status,alreadyCanceled:sub.status==='canceled',canceledAt:canceled.ended_at||canceled.current_period_end||null};
}
export async function stripeWebhookHandler(req:Request,res:Response) {
  if(!process.env.STRIPE_WEBHOOK_SECRET)return res.status(503).json({message:'Webhook verification is not configured'});
  try {
    const signature=req.headers['stripe-signature'];
    if(typeof signature!=='string'||!Buffer.isBuffer(req.body))throw new BillingError('invalid_stripe_signature');
    const event=getStripe().webhooks.constructEvent(req.body,signature,process.env.STRIPE_WEBHOOK_SECRET);
    const allowed=new Set(['checkout.session.completed','checkout.session.async_payment_succeeded','customer.subscription.created','customer.subscription.updated','customer.subscription.deleted','invoice.paid','charge.refunded','refund.created','refund.updated']);
    if(allowed.has(event.type)) {
      const object=event.data.object as {id:string};
      // Fetch fresh provider state in worker. No raw payload, email, card details or receipts persisted.
      await storeInbox('stripe',event.id,{type:event.type,objectId:object.id});
    }
    return res.json({received:true});
  } catch(error) {
    const code=safeError(error);
    return res.status(error instanceof BillingError?error.httpStatus:error instanceof Stripe.errors.StripeSignatureVerificationError?400:503).json({message:code==='provider_or_storage_unavailable'?'Unable to accept webhook':code});
  }
}
async function retrieveAndIngest(id:string) {const observedAt=new Date();return ingestStripeSubscription(await getStripe().subscriptions.retrieve(id),undefined,observedAt);}
async function invoiceContract(invoice:Stripe.Invoice) {
  const subId=typeof invoice.subscription==='string'?invoice.subscription:invoice.subscription?.id;
  if(!subId)return null;
  return retrieveAndIngest(subId);
}
export async function processStripeEvent(payload:{type:string;objectId:string}) {
  const stripe=getStripe();
  if(payload.type.startsWith('customer.subscription.')) {await retrieveAndIngest(payload.objectId);return;}
  if(payload.type.startsWith('checkout.session.')) {
    const session=await stripe.checkout.sessions.retrieve(payload.objectId);
    const id=typeof session.subscription==='string'?session.subscription:session.subscription?.id;
    if(id)await retrieveAndIngest(id);return;
  }
  if(payload.type==='invoice.paid') {
    const invoice=await stripe.invoices.retrieve(payload.objectId);
    if(invoice.status!=='paid')return;
    const contract=await invoiceContract(invoice);
    if(contract)await recordCharge({userId:contract.userId,contractId:contract.contractId,provider:'stripe',id:invoice.id,kind:'charge',amount:minorAmount(invoice.amount_paid,invoice.currency),currency:invoice.currency,occurredAt:new Date((invoice.status_transitions.paid_at||invoice.created)*1000),environment:invoice.livemode?'production':'test'});
    return;
  }
  const refundEvent=payload.type.startsWith('refund.');
  const refund=refundEvent?await stripe.refunds.retrieve(payload.objectId):null;
  const chargeId=refund?(typeof refund.charge==='string'?refund.charge:refund.charge?.id):payload.objectId;
  if(!chargeId)return;
  const charge=await stripe.charges.retrieve(chargeId);
  const invoiceId=typeof charge.invoice==='string'?charge.invoice:charge.invoice?.id;
  if(!invoiceId)return;
  const contract=await invoiceContract(await stripe.invoices.retrieve(invoiceId));
  if(!contract)return;
  const refunds=refund?[refund]:await stripe.refunds.list({charge:chargeId,limit:100}).autoPagingToArray({limit:10000});
  for(const item of refunds) if(item.status==='succeeded')await recordCharge({userId:contract.userId,contractId:contract.contractId,provider:'stripe',id:item.id,kind:'refund',amount:minorAmount(item.amount,item.currency),currency:item.currency,occurredAt:new Date(item.created*1000),environment:charge.livemode?'production':'test'});
}
