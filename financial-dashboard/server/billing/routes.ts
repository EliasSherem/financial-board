import { HttpError, limit as sharedLimit, UUID } from '../platform/http.js';
import { Router, type Request, type Response } from 'express';
import { acceptGoogleRtdn } from './rtdn.js';
import { authenticateToken } from '../auth.js';
import { BillingError, safeError } from './types.js';
import { verifyGoogle } from './google.js';
import { receiveAppleNotification, verifyApple } from './apple.js';
import { appleAccountToken, obfuscatedAccountId, productIds } from './secrets.js';
import { refreshEntitlement, userContracts } from './repository.js';
import { syncBillingUser } from './worker.js';

const router=Router();
function fail(res:Response,error:unknown) {return res.status(error instanceof BillingError?error.httpStatus:error instanceof HttpError?error.status:503).json({message:safeError(error)});}
const handle=(fn:(req:Request,res:Response)=>Promise<any>)=>async(req:Request,res:Response)=>{try {await sharedLimit(`billing:${req.user!.id}`,30);await fn(req,res);}catch(error){fail(res,error);}};
router.get('/api/billing/config',authenticateToken,handle(async(req,res)=>{
  res.json({googleProductIds:productIds('google'),appleProductIds:productIds('apple'),obfuscatedAccountId:obfuscatedAccountId(req.user!.id),appleAppAccountToken:appleAccountToken(req.user!.id),checkoutEnabled:process.env.BILLING_CHECKOUT_ENABLED!=='false',ackOwner:'server'});
}));
router.get('/api/billing/contracts',authenticateToken,handle(async(req,res)=>res.json({contracts:await userContracts(req.user!.id),is_pro:await refreshEntitlement(req.user!.id)})));
router.post('/api/play/link',authenticateToken,handle(async(req,res)=>{
  const {productId,purchaseToken}=req.body||{};
  if(typeof productId!=='string'||typeof purchaseToken!=='string'||!productIds('google').includes(productId))throw new BillingError('invalid_purchase_payload');
  const result=await verifyGoogle(req.user!.id,purchaseToken,productId,undefined,UUID.test(req.body.flow_id??'')?req.body.flow_id:undefined);
  // Internal storage IDs never leave this endpoint; ACK is durable before this response.
  res.json({success:true,verified:result.verified,state:result.state,expiry:result.expiry,is_pro:result.is_pro,acknowledged:result.acknowledged,ack_owner:'server'});
}));
router.post('/api/appstore/link',authenticateToken,handle(async(req,res)=>{
  const {productId,receiptData}=req.body||{};
  if(typeof productId!=='string'||typeof receiptData!=='string')throw new BillingError('invalid_purchase_payload');
  const result=await verifyApple(req.user!.id,receiptData,productId,UUID.test(req.body.flow_id??'')?req.body.flow_id:undefined);
  res.json({success:true,verified:true,state:result.state,expiry:result.expiry,is_pro:result.is_pro,environment:result.environment,acknowledged:true});
}));
for(const path of ['/api/billing/sync','/api/play/sync','/api/appstore/sync'])router.post(path,authenticateToken,handle(async(req,res)=>res.json({success:true,...await syncBillingUser(req.user!.id)})));
router.post('/api/pro/activate',authenticateToken,handle(async(_req,res)=>res.status(409).json({success:false,message:'Restore your store purchase to verify your subscription.',code:'purchase_verification_required'})));

export async function googleRtdnHandler(req:Request,res:Response) {
  try {
    await acceptGoogleRtdn(req.headers.authorization,req.body?.message);
    return res.status(204).send();
  }catch(error){return fail(res,error);}
}
export async function appleNotificationHandler(req:Request,res:Response) {
  try {await receiveAppleNotification(req.body?.signedPayload);return res.status(204).send();}catch(error){return fail(res,error);}
}
router.post('/webhooks/google-play',googleRtdnHandler);
router.post('/webhooks/app-store',appleNotificationHandler);
export default router;
