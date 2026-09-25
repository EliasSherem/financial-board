import { OAuth2Client } from 'google-auth-library';
import { BillingError } from './types.js';
import { googlePackage } from './google.js';
import { storeInbox } from './repository.js';
const verify = async (token:string,audience:string)=>{
  try{return (await new OAuth2Client().verifyIdToken({idToken:token,audience})).getPayload();}
  catch{throw new BillingError('invalid_rtdn_signature',401);}
};
export async function acceptGoogleRtdn(authorization:string|undefined,message:any,ports:{verify:typeof verify;storeInbox:typeof storeInbox}={verify,storeInbox}):Promise<void> {
  const audience=process.env.GOOGLE_RTDN_AUDIENCE,account=process.env.GOOGLE_RTDN_SERVICE_ACCOUNT;
  if(!audience||!account)throw new BillingError('rtdn_auth_not_configured',503);
  const bearer=authorization?.match(/^Bearer (\S+)$/)?.[1];
  if(!bearer)throw new BillingError('rtdn_auth_required',401);
  const claims=await ports.verify(bearer,audience);
  if(!claims||!['accounts.google.com','https://accounts.google.com'].includes(claims.iss)||claims.email!==account||claims.email_verified!==true||claims.aud!==audience)throw new BillingError('invalid_rtdn_identity',403);
  if(typeof message?.messageId!=='string'||!message.messageId||message.messageId.length>191||typeof message.data!=='string'||message.data.length>65536)throw new BillingError('invalid_rtdn_message');
  let payload:any;try{payload=JSON.parse(Buffer.from(message.data,'base64').toString('utf8'));}catch{throw new BillingError('invalid_rtdn_data');}
  if(payload.packageName!==googlePackage())throw new BillingError('rtdn_package_mismatch');
  const token=payload.subscriptionNotification?.purchaseToken??payload.voidedPurchaseNotification?.purchaseToken;
  if(!payload.testNotification&&(typeof token!=='string'||token.length<8||token.length>4096))throw new BillingError('invalid_rtdn_purchase_token');
  const clean=payload.testNotification?{test:true}:{packageName:payload.packageName,subscriptionNotification:payload.subscriptionNotification?{purchaseToken:token}:undefined,voidedPurchaseNotification:payload.voidedPurchaseNotification?{purchaseToken:token,orderId:typeof payload.voidedPurchaseNotification.orderId==='string'?payload.voidedPurchaseNotification.orderId.slice(0,191):undefined}:undefined};
  // Provider acknowledgement happens only after this durable, encrypted write resolves.
  await ports.storeInbox('google',message.messageId,clean);
}
