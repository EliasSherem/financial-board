import test,{after,before} from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { db } from '../db.js';
import { saveContract,refreshEntitlement,storeInbox,recordCharge,claimWork,finishWork,tokenOwner,contractOwner } from './repository.js';
import { tokenHash } from './secrets.js';
import type { VerifiedContract } from './types.js';
import { scheduleReconciliation } from './worker.js';
const enabled=process.env.RUN_DB_TESTS==='true';
const prefix=`billing_sql_${randomUUID().slice(0,8)}`;const ids:number[]=[];
if(enabled){assert.equal(process.env.NODE_ENV,'test');assert.equal(process.env.MYSQL_URL,undefined);assert.ok(['127.0.0.1','localhost'].includes(process.env.MYSQL_HOST||''));assert.match(process.env.MYSQL_DATABASE||'',/_test$/);}
before(async()=>{if(!enabled)return;process.env.BILLING_ENCRYPTION_KEY=Buffer.alloc(32,8).toString('base64');process.env.ADMIN_ANALYTICS_ENABLED='true';for(let n=0;n<2;n++){const [r]:any=await db.query('INSERT INTO users(username,email,password) VALUES(?,?,?)',[`${prefix}_${n}`,`${prefix}_${n}@example.invalid`,'not-a-login-hash']);ids.push(Number(r.insertId));}});
after(async()=>{if(enabled){for(const id of ids)await db.query('DELETE FROM users WHERE id=?',[id]);await db.query('DELETE FROM billing_inbox WHERE event_key LIKE ?',[`${prefix}%`]);}await db.end();});
const contract=(key:string,status:VerifiedContract['status']='active'):VerifiedContract=>({provider:'google',contractKey:tokenHash(key),productId:'finsight_monthly',rawState:status,status,accessUntil:new Date(Date.now()+86400000),isTrial:false,autoRenewing:true,environment:'test',acknowledged:false});
test('SQL: concurrent same-account deliveries commit one contract, one ACK job, one trusted event',{skip:!enabled},async()=>{
 const token=prefix+'_token';await Promise.all(Array.from({length:4},()=>saveContract(ids[0],contract(token),{value:token})));
 const [c]:any=await db.query('SELECT * FROM billing_contracts WHERE user_id=?',[ids[0]]);assert.equal(c.length,1);
 const [jobs]:any=await db.query("SELECT id FROM billing_jobs WHERE user_id=? AND kind='ack_google'",[ids[0]]);assert.equal(jobs.length,1);
 const [a]:any=await db.query("SELECT event_type FROM analytics_events WHERE user_id=?",[ids[0]]);assert.deepEqual(a.map((v:any)=>v.event_type),['purchase_verified']);
 await assert.rejects(saveContract(ids[1],contract(token),{value:token}),/purchase_owned_by_another_account/);
});
test('SQL: multiple sources OR, stale snapshots rejected, replacements retain audit and exclude old entitlement',{skip:!enabled},async()=>{
 const token=prefix+'_token';const newer=new Date();await saveContract(ids[0],{...contract(token,'hold'),observedAt:newer},{value:token});
 await saveContract(ids[0],{...contract(token,'active'),observedAt:new Date(newer.getTime()-10000)},{value:token});assert.equal(await refreshEntitlement(ids[0]),false);
 await saveContract(ids[0],{...contract(prefix+'_stripe'),provider:'stripe',contractKey:prefix+'_stripe'});assert.equal(await refreshEntitlement(ids[0]),true);
 const replacement=prefix+'_replacement';
 await saveContract(ids[0],{...contract(replacement,'pending'),linkedToken:token},{value:replacement});
 const [pendingOld]:any=await db.query('SELECT replaced_by_id FROM billing_contracts WHERE contract_key=?',[tokenHash(token)]);assert.equal(pendingOld[0].replaced_by_id,null);
 await saveContract(ids[0],{...contract(replacement),linkedToken:token},{value:replacement});
 const [rows]:any=await db.query('SELECT status,replaced_by_id FROM billing_contracts WHERE contract_key=?',[tokenHash(token)]);assert.equal(rows[0].status,'expired');assert.ok(rows[0].replaced_by_id);
 await saveContract(ids[0],{...contract(prefix+'_stripe','revoked'),provider:'stripe',contractKey:prefix+'_stripe'});assert.equal(await refreshEntitlement(ids[0]),true);
});
test('SQL: pending flow survives app kill and emits purchase_verified once after delivery',{skip:!enabled},async()=>{
 const token=prefix+'_pending',flow=randomUUID();await saveContract(ids[1],{...contract(token,'pending'),flowId:flow},{value:token});
 await saveContract(ids[1],contract(token),{value:token});await saveContract(ids[1],contract(token),{value:token});
 const [events]:any=await db.query("SELECT event_type,JSON_UNQUOTE(JSON_EXTRACT(metadata_json,'$.flow_id')) flow FROM analytics_events WHERE user_id=? ORDER BY received_at,event_id",[ids[1]]);
 assert.equal(events.filter((e:any)=>e.event_type==='purchase_verified').length,1);assert.ok(events.every((e:any)=>e.flow===flow));
});
test('SQL: durable duplicate inbox, lease retry and charge/refund deduplication',{skip:!enabled},async()=>{
 await Promise.all([storeInbox('google',prefix+'_event',{test:true},ids[0]),storeInbox('google',prefix+'_event',{test:true},ids[0])]);
 const [rows]:any=await db.query('SELECT * FROM billing_inbox WHERE event_key=?',[prefix+'_event']);assert.equal(rows.length,1);
 // Claim only synthetic queues; global worker is not running in this isolated test service.
 await db.query("UPDATE billing_inbox SET status='processing',attempts=1,lease_until=UTC_TIMESTAMP()-INTERVAL 1 MINUTE WHERE id=?",[rows[0].id]);
 const row=await claimWork('billing_inbox');assert.equal(row.id,rows[0].id);await finishWork('billing_inbox',row,new Error('secret error must be sanitized'));
 const [retry]:any=await db.query('SELECT status,last_error_code,attempts,next_attempt_at FROM billing_inbox WHERE id=?',[row.id]);assert.equal(retry[0].status,'pending');assert.equal(retry[0].last_error_code,'provider_or_storage_unavailable');assert.equal(retry[0].attempts,2);
 await db.query("UPDATE billing_inbox SET next_attempt_at=UTC_TIMESTAMP()-INTERVAL 1 SECOND WHERE id=?",[row.id]);const retryRow=await claimWork('billing_inbox');await finishWork('billing_inbox',retryRow);const [c]:any=await db.query('SELECT id FROM billing_contracts WHERE user_id=? LIMIT 1',[ids[0]]);
 const charge={userId:ids[0],contractId:c[0].id,provider:'google',id:prefix+'_order',amount:'9.990000',currency:'USD',occurredAt:new Date(),environment:'test'};
 await Promise.all([recordCharge({...charge,kind:'charge'}),recordCharge({...charge,kind:'charge'})]);await recordCharge({...charge,kind:'refund',amount:'2.000000'});
 const [ledger]:any=await db.query('SELECT kind,amount FROM billing_charges WHERE provider_charge_id=? ORDER BY kind',[charge.id]);assert.equal(ledger.length,2);assert.equal(Number(ledger[0].amount),9.99);assert.equal(Number(ledger[1].amount),2);
});
test('SQL: opaque contract and legacy token ownership distinguish case without transferring exact identities',{skip:!enabled},async()=>{
 const upper=`${prefix}_Contract_Case`,lower=`${prefix}_Contract_case`;
 const stripe=(key:string):VerifiedContract=>({...contract(key),provider:'stripe',contractKey:key});
 const first=await saveContract(ids[0],stripe(upper)),second=await saveContract(ids[1],stripe(lower));
 assert.notEqual(first.contractId,second.contractId);
 assert.equal((await saveContract(ids[0],stripe(upper))).contractId,first.contractId);
 assert.equal(await contractOwner('stripe',upper),ids[0]);assert.equal(await contractOwner('stripe',lower),ids[1]);
 await assert.rejects(saveContract(ids[1],stripe(upper)),/purchase_owned_by_another_account/);
 const upperToken=`${prefix}_Legacy_Token`,lowerToken=`${prefix}_Legacy_token`;
 await db.query('INSERT INTO play_subscriptions(user_id,product_id,purchase_token) VALUES(?,?,?),(?,?,?)',[ids[0],'finsight_monthly',upperToken,ids[1],'finsight_monthly',lowerToken]);
 assert.equal(await tokenOwner('google',upperToken),ids[0]);assert.equal(await tokenOwner('google',lowerToken),ids[1]);
 assert.equal(await tokenOwner('google',`${upperToken} `),null);
 await assert.rejects(db.query('INSERT INTO play_subscriptions(user_id,product_id,purchase_token) VALUES(?,?,?)',[ids[1],'finsight_monthly',upperToken]),(error:any)=>error.code==='ER_DUP_ENTRY');
 await saveContract(ids[0],contract(upperToken),{value:upperToken});await saveContract(ids[1],contract(lowerToken),{value:lowerToken});
 assert.equal(await tokenOwner('google',upperToken),ids[0]);assert.equal(await tokenOwner('google',lowerToken),ids[1]);
});
test('SQL: inbox, jobs and charges retain case and trailing-space variants while exact repeats deduplicate',{skip:!enabled},async()=>{
 const keys=[`${prefix}_Identity_Case`,`${prefix}_Identity_case`,`${prefix}_Identity_Case `];
 const saved=await saveContract(ids[0],{...contract(`${prefix}_identity_ledger`),provider:'stripe',contractKey:`${prefix}_identity_ledger`});
 for(const key of [...keys,keys[0]]) {
  await storeInbox('stripe',key,{test:true},ids[0]);
  await db.query("INSERT IGNORE INTO billing_jobs(user_id,job_key,kind) VALUES(?,?,'sync_user')",[ids[0],key]);
  await recordCharge({userId:ids[0],contractId:saved.contractId,provider:'stripe',id:key,kind:'charge',amount:'1.000000',currency:'USD',occurredAt:new Date(),environment:'test'});
 }
 for(const [table,column] of [['billing_inbox','event_key'],['billing_jobs','job_key'],['billing_charges','provider_charge_id']]) {
  const [rows]:any=await db.query(`SELECT ${column} identity_key FROM ${table} WHERE ${column} IN (?)`,[keys]);
  assert.deepEqual(rows.map((r:any)=>r.identity_key).sort(),[...keys].sort(),table);
  for(const key of keys){const [exact]:any=await db.query(`SELECT COUNT(*) n FROM ${table} WHERE ${column}=?`,[key]);assert.equal(Number(exact[0].n),1,`${table} exact identity`);}
 }
});
test('SQL: reconciliation schedules legacy users once and preserves processing/retry/failed job states on repeat',{skip:!enabled},async()=>{
 const [insert]:any=await db.query('INSERT INTO users(username,email,password) VALUES(?,?,?)',[`${prefix}_schedule`,`${prefix}_schedule@example.invalid`,'not-a-login-hash']);
 const userId=Number(insert.insertId);ids.push(userId);const key=`sync:${userId}`;
 for(const suffix of ['A','B'])await db.query("INSERT INTO billing_contracts(user_id,provider,contract_key,product_id,raw_state,status,verified,environment) VALUES(?,'stripe',?,'legacy','unknown','legacy',FALSE,'test')",[userId,`${prefix}_schedule_${suffix}`]);
 await scheduleReconciliation();await scheduleReconciliation();
 const read=async()=>{const [rows]:any=await db.query('SELECT id,status,attempts,last_error_code,next_attempt_at,lease_until FROM billing_jobs WHERE job_key=?',[key]);assert.equal(rows.length,1);return rows[0];};
 const initial=await read();assert.equal(initial.status,'pending');assert.equal(initial.attempts,0);
 for(const state of ['pending','processing','failed']) {
  await db.query("UPDATE billing_jobs SET status=?,attempts=3,last_error_code='TEST_RETRY',next_attempt_at='2040-01-01 00:00:00',lease_until='2040-01-01 00:00:00' WHERE job_key=?",[state,key]);
  await scheduleReconciliation();const row=await read();assert.equal(row.id,initial.id);assert.equal(row.status,state);assert.equal(row.attempts,3);
  assert.equal(row.lease_until.toISOString(),'2040-01-01T00:00:00.000Z');
  assert.equal(row.next_attempt_at.toISOString(),'2040-01-01T00:00:00.000Z');
  assert.equal(row.last_error_code,'TEST_RETRY');
 }
 await db.query("UPDATE billing_jobs SET status='done',attempts=12,completed_at=UTC_TIMESTAMP(3),next_attempt_at='2040-01-01 00:00:00' WHERE job_key=?",[key]);
 await scheduleReconciliation();await scheduleReconciliation();const reopened=await read();assert.equal(reopened.status,'pending');assert.equal(reopened.id,initial.id);assert.equal(reopened.attempts,0);assert.equal(reopened.last_error_code,null);assert.ok(reopened.next_attempt_at.getTime()<=Date.now()+1000);
});
test('SQL: order reconciliation queues recent charges once and only reopens completed orders after one day',{skip:!enabled},async()=>{
 const token=`${prefix}_scheduled_order_token`,order=`${prefix}_scheduled_order`,key=`order:${order}`;
 const saved=await saveContract(ids[0],contract(token),{value:token});
 await recordCharge({userId:ids[0],contractId:saved.contractId,provider:'google',id:order,kind:'charge',amount:'3.000000',currency:'USD',occurredAt:new Date(),environment:'test'});
 await scheduleReconciliation();await scheduleReconciliation();
 const read=async()=>{const [rows]:any=await db.query('SELECT id,status,attempts,last_error_code,token_id,order_id,next_attempt_at,lease_until FROM billing_jobs WHERE job_key=?',[key]);assert.equal(rows.length,1);return rows[0];};
 const initial=await read();assert.equal(initial.status,'pending');assert.equal(Number(initial.token_id),saved.tokenId);assert.equal(initial.order_id,order);
 await db.query("UPDATE billing_jobs SET attempts=2,next_attempt_at='2040-01-01 00:00:00' WHERE job_key=?",[key]);
 await scheduleReconciliation();const retry=await read();assert.equal(retry.status,'pending');assert.equal(retry.attempts,2);assert.equal(retry.next_attempt_at.toISOString(),'2040-01-01T00:00:00.000Z');
 await db.query("UPDATE billing_jobs SET status='processing',attempts=2,lease_until='2040-01-01 00:00:00',next_attempt_at='2040-01-01 00:00:00' WHERE job_key=?",[key]);
 await scheduleReconciliation();const processing=await read();assert.equal(processing.status,'processing');assert.equal(processing.attempts,2);assert.equal(processing.lease_until.toISOString(),'2040-01-01T00:00:00.000Z');
 await db.query("UPDATE billing_jobs SET status='done',attempts=12,last_error_code='TEST_STALE_ERROR',completed_at=UTC_TIMESTAMP(3) WHERE job_key=?",[key]);
 await scheduleReconciliation();const recent=await read();assert.equal(recent.status,'done');assert.equal(recent.attempts,12);assert.equal(recent.last_error_code,'TEST_STALE_ERROR');
 await db.query("UPDATE billing_jobs SET completed_at=UTC_TIMESTAMP(3)-INTERVAL 2 DAY WHERE job_key=?",[key]);
 await scheduleReconciliation();await scheduleReconciliation();const reopened=await read();assert.equal(reopened.status,'pending');assert.equal(reopened.id,initial.id);assert.equal(reopened.attempts,0);assert.equal(reopened.last_error_code,null);assert.ok(reopened.next_attempt_at.getTime()<=Date.now()+1000);
});
