import { randomUUID } from 'node:crypto';
import { recordBillingAnalytics } from '../analytics/repository.js';
import { db } from '../db.js';
import { BillingError, effectiveAccess, retryDelay, safeError, type VerifiedContract } from './types.js';
import { seal, tokenHash, unseal } from './secrets.js';

type Conn = { query: (sql: string, args?: any[]) => Promise<any> };
export async function billingTransaction<T>(fn: (connection: Conn)=>Promise<T>): Promise<T> {
  const connection = await db.getConnection();
  try { await connection.beginTransaction(); const result = await fn(connection); await connection.commit(); return result; }
  catch(error) { await connection.rollback(); throw error; }
  finally { connection.release(); }
}
/** Fresh database authorization without a write or an exclusive user lock. */
export async function readEntitlement(userId: number, connection: Conn = db): Promise<boolean> {
  const [users] = await connection.query(`SELECT (
    EXISTS(SELECT 1 FROM billing_grants g WHERE g.user_id=u.id
      AND (g.expires_at IS NULL OR g.expires_at>UTC_TIMESTAMP(3)))
    OR EXISTS(SELECT 1 FROM billing_contracts c WHERE c.user_id=u.id
      AND c.verified<>0 AND c.replaced_by_id IS NULL
      AND c.status IN ('active','trial','grace','cancel_at_period_end')
      AND c.access_until>UTC_TIMESTAMP(3))
    OR (u.is_pro<>0 AND EXISTS(SELECT 1 FROM billing_contracts c WHERE c.user_id=u.id
      AND c.status='legacy' AND c.created_at>DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 30 DAY)))
    ) AS has_access FROM users u WHERE u.id=?`, [userId]);
  return Number(users[0]?.has_access) === 1;
}
export async function refreshEntitlement(userId: number, connection?: Conn): Promise<boolean> {
  if(!connection)return billingTransaction(conn=>refreshEntitlement(userId,conn));
  const [users] = await connection.query('SELECT is_pro FROM users WHERE id=? FOR UPDATE',[userId]);
  const result = await readEntitlement(userId,connection);
  if (users.length && Boolean(users[0].is_pro) !== result) {
    await connection.query('UPDATE users SET is_pro=? WHERE id=?',[result?1:0,userId]);
  }
  return result;
}
export async function saveContract(userId: number, contract: VerifiedContract, secret?: {value: string; identity?: string},transaction:typeof billingTransaction=billingTransaction): Promise<{contractId:number;tokenId:number|null;isPro:boolean}> {
  // Encrypt before starting a transaction; missing encryption config cannot cause partial grants.
  const encrypted = secret ? seal(secret.value) : null;
  return transaction(async connection=> {
    const [users] = await connection.query('SELECT id FROM users WHERE id=? FOR UPDATE',[userId]);
    if(!users.length)throw new BillingError('user_not_found',404);
    const hash = secret ? tokenHash(secret.identity ?? secret.value) : null;
    if(hash) {
      const [existing] = await connection.query('SELECT user_id FROM billing_purchase_tokens WHERE provider=? AND token_hash=? FOR UPDATE',[contract.provider,hash]);
      if(existing.length && Number(existing[0].user_id)!==userId)throw new BillingError('purchase_owned_by_another_account',409);
    }
    const [rows] = await connection.query('SELECT id,user_id,status,access_until,verified,synced_at,checkout_flow_id FROM billing_contracts WHERE provider=? AND contract_key=? FOR UPDATE',[contract.provider,contract.contractKey]);
    if(rows.length && Number(rows[0].user_id)!==userId)throw new BillingError('purchase_owned_by_another_account',409);
    if(rows.length && contract.observedAt && rows[0].synced_at && new Date(rows[0].synced_at)>contract.observedAt) {
      return {contractId:Number(rows[0].id),tokenId:null,isPro:await refreshEntitlement(userId,connection)};
    }
    // Check legacy ownership as well; old clients and restores cannot transfer a contract.
    if(secret && contract.provider==='google') {
      const [legacy] = await connection.query('SELECT user_id FROM play_subscriptions WHERE purchase_token=? FOR UPDATE',[secret.value]);
      if(legacy.length && Number(legacy[0].user_id)!==userId)throw new BillingError('purchase_owned_by_another_account',409);
    }
    if(contract.provider==='apple') {
      const [legacy] = await connection.query('SELECT user_id FROM app_store_subscriptions WHERE original_transaction_id=? FOR UPDATE',[contract.contractKey]);
      if(legacy.length && Number(legacy[0].user_id)!==userId)throw new BillingError('purchase_owned_by_another_account',409);
    }
    const [result] = await connection.query(`INSERT INTO billing_contracts(user_id,provider,contract_key,product_id,base_plan_id,raw_state,status,access_until,is_trial,auto_renewing,currency,recurring_amount,period_months,environment,verified,synced_at,checkout_flow_id)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,TRUE,UTC_TIMESTAMP(3),?) ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id),product_id=VALUES(product_id),base_plan_id=VALUES(base_plan_id),raw_state=VALUES(raw_state),status=VALUES(status),access_until=VALUES(access_until),is_trial=VALUES(is_trial),auto_renewing=VALUES(auto_renewing),currency=VALUES(currency),recurring_amount=VALUES(recurring_amount),period_months=VALUES(period_months),environment=VALUES(environment),verified=TRUE,synced_at=UTC_TIMESTAMP(3),checkout_flow_id=COALESCE(VALUES(checkout_flow_id),checkout_flow_id)`,
      [userId,contract.provider,contract.contractKey,contract.productId,contract.basePlanId??null,contract.rawState,contract.status,contract.accessUntil,contract.isTrial,contract.autoRenewing,contract.currency??null,contract.recurringAmount??null,contract.periodMonths??null,contract.environment,contract.flowId??null]);
    const contractId = Number(result.insertId || rows[0]?.id);
    const [binding]=await connection.query('SELECT user_id FROM billing_contracts WHERE id=?',[contractId]);
    if(Number(binding[0]?.user_id)!==userId)throw new BillingError('purchase_owned_by_another_account',409);
    if(contract.observedAt)await connection.query('UPDATE billing_contracts SET synced_at=? WHERE id=?',[contract.observedAt,contractId]);
    let tokenId: number|null = null;
    if(secret) {
      const [saved] = await connection.query(`INSERT INTO billing_purchase_tokens(user_id,contract_id,provider,token_hash,secret_encrypted,product_id,acknowledged)
        VALUES(?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id),secret_encrypted=VALUES(secret_encrypted),product_id=VALUES(product_id),acknowledged=VALUES(acknowledged)`,
        [userId,contractId,contract.provider,hash,encrypted,contract.productId,contract.acknowledged??false]);
      tokenId=Number(saved.insertId);
    }
    if(contract.linkedToken) {
      const linkedHash=tokenHash(contract.linkedToken);
      const [old] = await connection.query(`SELECT id,user_id FROM billing_contracts WHERE provider='google' AND contract_key=? FOR UPDATE`,[linkedHash]);
      if(old.length && Number(old[0].user_id)!==userId)throw new BillingError('replacement_owned_by_another_account',409);
      const [oldLegacy] = await connection.query('SELECT user_id FROM play_subscriptions WHERE purchase_token=? FOR UPDATE',[contract.linkedToken]);
      if(oldLegacy.length && Number(oldLegacy[0].user_id)!==userId)throw new BillingError('replacement_owned_by_another_account',409);
      // Preserve the old record for audit; exclude it from access and accounting.
      if(effectiveAccess(contract))await connection.query(`UPDATE billing_contracts SET replaced_by_id=?,status='expired' WHERE provider='google' AND contract_key=? AND id<>?`,[contractId,linkedHash,contractId]);
    }
    if(secret && contract.provider==='google') {
      // Legacy columns remain during rollout; the secret moves to encrypted storage.
      await connection.query(`UPDATE play_subscriptions SET expiry_time=?,last_state=? WHERE user_id=? AND purchase_token=?`,[contract.accessUntil,contract.rawState,userId,secret.value]);
      if(!contract.acknowledged && effectiveAccess(contract)) {
        await connection.query(`INSERT INTO billing_jobs(user_id,job_key,kind,token_id) VALUES(?,?,'ack_google',?) ON DUPLICATE KEY UPDATE status=IF(status IN ('done','processing'),status,'pending'),next_attempt_at=IF(status='pending',UTC_TIMESTAMP(3),next_attempt_at)`,[userId,`ack:${hash}`,tokenId]);
      }
    }
    for(const charge of contract.charges??[])await recordCharge({userId,contractId,provider:contract.provider,environment:contract.environment,...charge},connection);
    if(tokenId && contract.provider==='google')for(const order of contract.orderIds??[])await connection.query("INSERT INTO billing_jobs(user_id,job_key,kind,token_id,order_id) VALUES(?,?,'google_order',?,?) ON DUPLICATE KEY UPDATE status=IF(status='done','pending',status),next_attempt_at=IF(status='pending',UTC_TIMESTAMP(3),next_attempt_at)",[userId,`order:${order}`,tokenId,order]);
    if(!rows.length || rows[0].status!==contract.status || new Date(rows[0].access_until??0).getTime()!==(contract.accessUntil?.getTime()??0)) await connection.query('INSERT INTO billing_state_events(user_id,contract_id,provider,previous_status,status,effective_access,access_until) VALUES(?,?,?,?,?,?,?)',[userId,contractId,contract.provider,rows[0]?.status??null,contract.status,effectiveAccess(contract),contract.accessUntil]);
    if(!rows.length || !rows[0].verified || rows[0].status!==contract.status)await recordBillingAnalytics({eventId:randomUUID(),userId,eventType:effectiveAccess(contract)&&(!rows.length||!rows[0].verified||['pending','legacy','unknown'].includes(rows[0].status))?'purchase_verified':'subscription_state_changed',provider:contract.provider,status:contract.status,flowId:contract.flowId??rows[0]?.checkout_flow_id},connection as any);
    return {contractId,tokenId,isPro:await refreshEntitlement(userId,connection)};
  });
}
export async function storeInbox(provider: string,eventKey: string,payload: unknown,userId: number|null=null): Promise<void> {
  const encrypted=seal(payload);
  await db.query(`INSERT IGNORE INTO billing_inbox(provider,event_key,payload_encrypted,user_id) VALUES(?,?,?,?)`,[provider,eventKey,encrypted,userId]);
}
export async function tokenOwner(provider: string,token: string): Promise<number|null> {
  const [rows]:any=await db.query('SELECT user_id FROM billing_purchase_tokens WHERE provider=? AND token_hash=?',[provider,tokenHash(token)]);
  if(rows.length)return Number(rows[0].user_id);
  if(provider==='google') {
    const [legacy]:any=await db.query('SELECT user_id FROM play_subscriptions WHERE purchase_token=?',[token]);
    return legacy.length?Number(legacy[0].user_id):null;
  }
  return null;
}
export async function contractOwner(provider: string,key: string): Promise<number|null> {
  const [rows]:any=await db.query('SELECT user_id FROM billing_contracts WHERE provider=? AND contract_key=?',[provider,key]);
  return rows.length?Number(rows[0].user_id):null;
}
export async function claimWork(table:'billing_jobs'|'billing_inbox'):Promise<any|null> {
  return billingTransaction(async connection=> {
    const [rows]=await connection.query(`SELECT * FROM ${table} WHERE (status='pending' AND next_attempt_at<=UTC_TIMESTAMP(3)) OR (status='processing' AND lease_until<UTC_TIMESTAMP(3)) ORDER BY id LIMIT 1 FOR UPDATE`);
    if(!rows.length)return null;
    const row=rows[0];
    await connection.query(`UPDATE ${table} SET status='processing',attempts=attempts+1,lease_until=DATE_ADD(UTC_TIMESTAMP(3),INTERVAL 5 MINUTE) WHERE id=?`,[row.id]);
    return {...row,attempts:Number(row.attempts)+1};
  });
}
export async function finishWork(table:'billing_jobs'|'billing_inbox',row:any,error?:unknown):Promise<void> {
  if(!error) { await db.query(`UPDATE ${table} SET status='done',lease_until=NULL,last_error_code=NULL,${table==='billing_jobs'?'completed_at':'processed_at'}=UTC_TIMESTAMP(3) WHERE id=? AND status='processing' AND attempts=?`,[row.id,row.attempts]); return; }
  await db.query(`UPDATE ${table} SET status=?,lease_until=NULL,last_error_code=?,next_attempt_at=DATE_ADD(UTC_TIMESTAMP(3),INTERVAL ? SECOND) WHERE id=? AND status='processing' AND attempts=?`,[row.attempts>=12?'failed':'pending',safeError(error),retryDelay(row.attempts),row.id,row.attempts]);
  if(row.attempts>=12) console.error('[billing] delivery requires attention',{table,id:row.id,code:safeError(error)});
}
export async function recordCharge(data:{userId:number;contractId:number;provider:string;id:string;kind:'charge'|'refund';amount:string;currency:string;occurredAt:Date;environment:string},connection:Conn=db):Promise<void> {
  await connection.query(`INSERT IGNORE INTO billing_charges(user_id,contract_id,provider,provider_charge_id,kind,amount,currency,occurred_at,environment) VALUES(?,?,?,?,?,?,?,?,?)`,[data.userId,data.contractId,data.provider,data.id,data.kind,data.amount,data.currency.toUpperCase(),data.occurredAt,data.environment]);
}
export async function userContracts(userId:number):Promise<any[]> {
  const [rows]:any=await db.query('SELECT id,provider,product_id,base_plan_id,raw_state,status,access_until,is_trial,auto_renewing,currency,recurring_amount,period_months,environment,verified,synced_at,replaced_by_id FROM billing_contracts WHERE user_id=? ORDER BY created_at DESC',[userId]);
  return rows.map((row:any)=>({...row,effective_access:effectiveAccess(row)}));
}
export { unseal };
