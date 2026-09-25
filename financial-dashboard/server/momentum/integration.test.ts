import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import express from 'express';
import type {Server} from 'node:http';
import {db,withTransaction} from '../db.js';
import {generateToken} from '../auth.js';
import router from './routes.js';
import {getMomentum} from './service.js';
import {locked,rows} from './repository.js';
import {reserveAi,finishAi,creditState} from './credits.js';
import {processDomainEvent} from './worker.js';
const run=process.env.RUN_DB_TESTS==='true';
let uid:number,account:number,server:Server,base:string,token:string;
const result=async(sql:string,args:unknown[]=[])=> (await db.query(sql,args))[0] as Array<Record<string,unknown>>;
before(async()=>{
 if(!run)return;
 assert.equal(process.env.NODE_ENV,'test');assert.equal(process.env.MYSQL_HOST,'127.0.0.1');assert.match(process.env.MYSQL_DATABASE??'',/_test$/);assert.equal(process.env.MYSQL_URL,undefined);
 process.env.MOMENTUM_ENABLED='true';process.env.MOMENTUM_AI_CREDITS_ENABLED='true';process.env.OPENAI_API_KEY='test-placeholder-no-provider-calls';process.env.JWT_SECRET='test-only-secret';
 const suffix=randomUUID().slice(0,8);
 const [user]=await db.query("INSERT INTO users(username,email,password,credential_kind,timezone_name) VALUES (?,?,'unusable','local','UTC')",[`momentum_${suffix}`,`momentum_${suffix}@example.invalid`]);uid=Number((user as {insertId:number}).insertId);token=generateToken({id:uid,username:`momentum_${suffix}`});
 const [acc]=await db.query("INSERT INTO accounts(user_id,name,type) VALUES (?,'Test','Checking')",[uid]);account=Number((acc as {insertId:number}).insertId);
 for(let n=0;n<5;n++)await db.query("INSERT INTO transactions(user_id,account_id,date,description,amount,type,category) VALUES (?,?,UTC_DATE(),?,-10,'Expense','Groceries')",[uid,account,`Verified ${n}`]);
 await db.query("INSERT INTO payments(user_id,account_id,name,amount,frequency,next_date,is_active) VALUES (?,?,'Obligation',10,'Monthly',DATE_ADD(UTC_DATE(),INTERVAL 2 DAY),1)",[uid,account]);
 const app=express();app.use(express.json());app.use(router);server=await new Promise<Server>(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});base=`http://127.0.0.1:${(server.address() as {port:number}).port}`;
});
after(async()=>{if(!run)return;await db.query('DELETE FROM users WHERE id=?',[uid]);await new Promise<void>(resolve=>server.close(()=>resolve()));await db.end();});
async function api(path:string,body?:unknown,bearer=token){const r=await fetch(`${base}/api/engagement${path}`,{method:body===undefined?'GET':'POST',headers:{Authorization:`Bearer ${bearer}`,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,body:await r.json() as any};}
test('SQL: repeated backfill and two devices preserve ledger and finite activation', {skip:!run},async()=>{
 const states=await Promise.all(Array.from({length:4},()=>getMomentum(uid)));
 assert.ok(states.every(s=>'lifetime_xp'in s && s.lifetime_xp===(states[0] as any).lifetime_xp));
 const count=await result('SELECT COUNT(*) n,COUNT(DISTINCT idempotency_key) distinct_n FROM reward_ledger WHERE user_id=?',[uid]);assert.equal(count[0].n,count[0].distinct_n);
 const state=states[0] as any;assert.equal(state.achievements.length,34);assert.equal(state.week.total,3);assert.equal(state.missions.filter((m:any)=>m.scope==='activation'&&m.status==='completed').length,4);
 assert.equal((await api('/me',undefined,'bad')).status,401);assert.equal((await api('/client-events',{event_id:randomUUID(),type:'award_xp',xp:999,occurred_at:new Date().toISOString()})).status,400);
});
test('SQL: review needs fresh real evidence, confirmation and unique local period',{skip:!run},async()=>{
 const before=await result('SELECT COUNT(*) n FROM weekly_reviews WHERE user_id=?',[uid]);const snap=await api('/review/weekly');assert.equal(snap.status,200);assert.equal((await result('SELECT COUNT(*) n FROM weekly_reviews WHERE user_id=?',[uid]))[0].n,before[0].n);
 assert.equal((await api('/weekly-review',{snapshot_id:snap.body.snapshot_id,confirmed_sections:[],next_step:'keep_plan'})).status,400);
 const confirm={snapshot_id:snap.body.snapshot_id,confirmed_sections:snap.body.sections.filter((s:any)=>s.applicable).map((s:any)=>s.key),next_step:'keep_plan'};
 const replies=await Promise.all([api('/weekly-review',confirm),api('/weekly-review',confirm)]);assert.ok(replies.every(r=>r.status===200));assert.equal(Number((await result('SELECT COUNT(*) n FROM weekly_reviews WHERE user_id=?',[uid]))[0].n),1);
 const stale=await api('/review/monthly');await db.query('UPDATE accounts SET balance=12 WHERE id=?',[account]);assert.equal((await api('/monthly-review',{snapshot_id:stale.body.snapshot_id,confirmed_sections:stale.body.sections.filter((s:any)=>s.applicable).map((s:any)=>s.key),next_step:'keep_plan'})).status,409);
});
test('SQL: canonical identity survives edits and delete/recreate of original financial record',{skip:!run},async()=>{
 const old=(await result('SELECT id,momentum_identity FROM transactions WHERE user_id=? AND description=?',[uid,'Verified 0']))[0];await db.query("UPDATE transactions SET description='Edited',category=NULL WHERE id=?",[old.id]);assert.equal((await result('SELECT momentum_identity FROM transactions WHERE id=?',[old.id]))[0].momentum_identity,old.momentum_identity);
 await db.query('DELETE FROM transactions WHERE id=?',[old.id]);await db.query("INSERT INTO transactions(user_id,account_id,date,description,amount,type,category) VALUES (?,?,UTC_DATE(),'Verified 0',-10,'Expense','Groceries')",[uid,account]);assert.equal((await result("SELECT momentum_identity FROM transactions WHERE user_id=? AND description='Verified 0'",[uid]))[0].momentum_identity,old.momentum_identity);
 await getMomentum(uid);assert.equal(Number((await result("SELECT COUNT(*) n FROM momentum_facts WHERE user_id=? AND metric='categorized'",[uid]))[0].n),5);
});
test('SQL: financial transaction rollback includes its trigger outbox; evaluator failure is later',{skip:!run},async()=>{
 const before=Number((await result('SELECT COUNT(*) n FROM engagement_events WHERE user_id=?',[uid]))[0].n);
 await assert.rejects(withTransaction(async conn=>{await conn.query("INSERT INTO accounts(user_id,name,type) VALUES (?,'Rollback','Checking')",[uid]);throw new Error('test rollback');}));
 assert.equal(Number((await result("SELECT COUNT(*) n FROM accounts WHERE user_id=? AND name='Rollback'",[uid]))[0].n),0);assert.equal(Number((await result('SELECT COUNT(*) n FROM engagement_events WHERE user_id=?',[uid]))[0].n),before);
 const event=(await result("SELECT id FROM engagement_events WHERE user_id=? AND event_type='accounts.insert' LIMIT 1",[uid]))[0];await processDomainEvent(Number(event.id));await processDomainEvent(Number(event.id));assert.equal((await result('SELECT status FROM engagement_events WHERE id=?',[event.id]))[0].status,'processed');
});
test('SQL: credit holds concurrent, failed call released, successful response charged once',{skip:!run},async()=>{
 await db.query("INSERT IGNORE INTO ai_credit_ledger(user_id,credits,kind,idempotency_key,expires_at) VALUES (?,3,'grant','organizer:v1',DATE_ADD(UTC_TIMESTAMP(3),INTERVAL 30 DAY))",[uid]);
 const ids=Array.from({length:4},()=>randomUUID());const holds=await Promise.allSettled(ids.map(id=>reserveAi(uid,id)));assert.equal(holds.filter(h=>h.status==='fulfilled').length,3);
 const successful=ids.filter((_,i)=>holds[i].status==='fulfilled');await finishAi(uid,successful[0]);await finishAi(uid,successful[1],'Private cached answer');await finishAi(uid,successful[1],'Duplicate');
 const balance=await locked(uid,conn=>creditState(conn,uid));assert.equal(balance.balance,1);assert.equal((await reserveAi(uid,successful[1])).cached?.reply,'Private cached answer');await assert.rejects(reserveAi(uid,successful[0]));
 assert.equal(Number((await result("SELECT COUNT(*) n FROM ai_credit_ledger WHERE user_id=? AND kind='consume'",[uid]))[0].n),1);
 await finishAi(uid,successful[2]);
});
test('SQL: concurrent required completions cap weekly100 plus20 and monthly75',{skip:!run},async()=>{
 const state=await getMomentum(uid) as any;
 const used=state.week.repeatable_xp;
 await db.query("INSERT INTO reward_ledger(user_id,origin,period_key,cap_group,xp,nominal_xp,idempotency_key) VALUES (?,'fixture',?,'weekly',?,?,'test:remaining-cap')",[uid,state.week.key,95-used,95-used]);
 const active=state.missions.filter((m:any)=>m.scope==='weekly'&&m.slot&&m.status!=='completed'&&m.status!=='replaced');assert.equal(active.length,2);
 const snapshots=await Promise.all(active.map((m:any)=>api(`/review/${m.key}`)));
 const confirmed=await Promise.all(snapshots.map((snap:any,i:number)=>api('/client-events',{event_id:randomUUID(),type:'review_confirmed',mission_key:active[i].key,snapshot_id:snap.body.snapshot_id,confirmed_sections:snap.body.sections.filter((s:any)=>s.applicable).map((s:any)=>s.key),occurred_at:new Date().toISOString()})));
 assert.ok(confirmed.every(r=>r.status===200));const complete=await getMomentum(uid) as any;assert.equal(complete.week.repeatable_xp,100);assert.equal(complete.week.bonus_xp,20);assert.equal(complete.week.completed,3);
 const main=await api('/review/monthly'),extra=await api('/review/monthly_balance_history');
 const monthly=await Promise.all([api('/monthly-review',{snapshot_id:main.body.snapshot_id,confirmed_sections:main.body.sections.filter((s:any)=>s.applicable).map((s:any)=>s.key),next_step:'keep_plan'}),api('/client-events',{event_id:randomUUID(),type:'review_confirmed',mission_key:'monthly_balance_history',snapshot_id:extra.body.snapshot_id,confirmed_sections:extra.body.sections.filter((s:any)=>s.applicable).map((s:any)=>s.key),occurred_at:new Date().toISOString()})]);assert.ok(monthly.every(r=>r.status===200));assert.equal((await getMomentum(uid) as any).month.repeatable_xp,75);
 await assert.rejects(db.query('UPDATE reward_ledger SET xp=999 WHERE user_id=?',[uid]),/append-only/);
});
test('SQL: failed outbox insert rolls back base statement; failed evaluator retains committed finance',{skip:!run},async()=>{
 const trigger=`test_outbox_failure_${uid}`;
 try {
 await db.query(`CREATE TRIGGER ${trigger} BEFORE INSERT ON engagement_events FOR EACH ROW BEGIN IF NEW.user_id=${uid} AND NEW.event_type='accounts.insert' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Test outbox failure'; END IF; END`);
 await assert.rejects(db.query("INSERT INTO accounts(user_id,name,type) VALUES (?,'Should rollback','Checking')",[uid]),/Test outbox failure/);
 assert.equal(Number((await result("SELECT COUNT(*) n FROM accounts WHERE user_id=? AND name='Should rollback'",[uid]))[0].n),0);
 } finally {await db.query(`DROP TRIGGER IF EXISTS ${trigger}`);}
 const [insert]=await db.query("INSERT INTO accounts(user_id,name,type) VALUES (?,'Committed before evaluator','Checking')",[uid]);const id=Number((insert as {insertId:number}).insertId);
 const event=(await result("SELECT id FROM engagement_events WHERE user_id=? AND event_type='accounts.insert' AND JSON_EXTRACT(payload_json,'$.entity_id')=?",[uid,id]))[0];
 await db.query("INSERT INTO user_missions(user_id,mission_key,catalog_version,period_key,scope,nominal_xp) VALUES (?,'test_missing_catalog',1,'lifetime','activation',1)",[uid]);
 await assert.rejects(processDomainEvent(Number(event.id)));
 assert.equal(Number((await result('SELECT COUNT(*) n FROM accounts WHERE id=?',[id]))[0].n),1);assert.equal((await result('SELECT status FROM engagement_events WHERE id=?',[event.id]))[0].status,'pending');
 await db.query("DELETE FROM user_missions WHERE user_id=? AND mission_key='test_missing_catalog'",[uid]);await processDomainEvent(Number(event.id));assert.equal((await result('SELECT status FROM engagement_events WHERE id=?',[event.id]))[0].status,'processed');
});
test('SQL: explicit timezone survives device refresh, fixed current period does not award again',{skip:!run},async()=>{
 const before=await getMomentum(uid) as any;const preference=await api('/preferences',{timezone_name:'America/New_York',timezone_offset_min:-240});assert.equal(preference.status,200);
 await db.query("UPDATE users SET timezone_name='Asia/Tokyo',timezone_offset_min=540 WHERE id=?",[uid]);const updated=await api('/me?timezone_name=Europe%2FMadrid');assert.equal(updated.status,200);assert.equal(updated.body.preferences.timezone_name,'America/New_York');assert.equal(updated.body.week.key,before.week.key);assert.equal(updated.body.week.starts_at,new Date(before.week.starts_at).toISOString());assert.equal(updated.body.week.repeatable_xp,before.week.repeatable_xp);
 assert.equal((await api('/client-events',{event_id:randomUUID(),type:'review_confirmed',mission_key:'report',snapshot_id:randomUUID(),confirmed_sections:[],occurred_at:new Date().toISOString()})).status,400);
});
test('SQL: expired Pro replaces only its unfinished goal and retains completed work',{skip:!run},async()=>{
 const suffix=randomUUID().slice(0,8);const [insert]=await db.query("INSERT INTO users(username,email,password,credential_kind,timezone_name) VALUES (?,?,'unusable','local','UTC')",[`momentum_pro_${suffix}`,`momentum_pro_${suffix}@example.invalid`]);const userId=Number((insert as {insertId:number}).insertId);
 try {
 await db.query("INSERT INTO billing_grants(user_id,source,expires_at) VALUES (?,'test_manual',DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY))",[userId]);const [a]=await db.query("INSERT INTO accounts(user_id,name,type) VALUES (?,'Test Pro','Checking')",[userId]);const accountId=Number((a as {insertId:number}).insertId);
 await db.query("INSERT INTO transactions(user_id,account_id,date,description,amount,type,category) VALUES (?,?,UTC_DATE(),'Pro fixture',-1,'Expense','Existing')",[userId,accountId]);await db.query("INSERT INTO projects(user_id,name,status) VALUES (?,'Existing goal','Active')",[userId]);
 const pro=await getMomentum(userId) as any;assert.equal(pro.missions.find((m:any)=>m.slot==='goal').key,'weekly_project_review');await db.query("UPDATE user_missions SET status='completed',granted_xp=15 WHERE user_id=? AND mission_key='weekly_summary'",[userId]);
 await db.query("UPDATE billing_grants SET expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE user_id=?",[userId]);const free=await getMomentum(userId) as any;assert.equal(free.missions.find((m:any)=>m.key==='weekly_summary').status,'completed');assert.equal(free.missions.find((m:any)=>m.key==='weekly_project_review').status,'replaced');assert.equal(free.missions.find((m:any)=>m.slot==='goal'&&m.status!=='replaced').key,'weekly_month_net');assert.equal(Number((await result('SELECT COUNT(*) n FROM mission_replacements WHERE user_id=?',[userId]))[0].n),1);
 } finally {await db.query('DELETE FROM users WHERE id=?',[userId]);}
});
test('SQL: confirmed receipt event uses the actual trigger image_hash field and deduplicates it',{skip:!run},async()=>{
 const imageHash='f'.repeat(64);const [draft]=await db.query("INSERT INTO transaction_drafts(user_id,status,image_sha256) VALUES (?,'ready',?)",[uid,imageHash]);const id=Number((draft as {insertId:number}).insertId);
 await db.query("UPDATE transaction_drafts SET status='confirmed' WHERE id=?",[id]);const event=(await result("SELECT id,payload_json FROM engagement_events WHERE user_id=? AND event_type='transaction_drafts.update' AND JSON_EXTRACT(payload_json,'$.entity_id')=?",[uid,id]))[0];
 const payload=typeof event.payload_json==='string'?JSON.parse(event.payload_json):event.payload_json as Record<string,unknown>;assert.equal(payload.image_hash,imageHash);
 await processDomainEvent(Number(event.id));await processDomainEvent(Number(event.id));const state=await getMomentum(uid) as any;
 assert.equal(Number((await result('SELECT COUNT(*) n FROM momentum_facts WHERE user_id=? AND metric=? AND fact_key=?',[uid,`period_receipts:${state.week.key}`,imageHash]))[0].n),1);
});
test('SQL: review net equals income minus expenses with either legacy amount sign',{skip:!run},async()=>{
 const [insert]=await db.query("INSERT INTO transactions(user_id,account_id,date,description,amount,type) VALUES (?,?,UTC_DATE(),'Legacy positive expense',12,'Expense')",[uid,account]);
 const id=Number((insert as {insertId:number}).insertId);
 try {
  const review=await api('/review/monthly');assert.equal(review.status,200);
  const net=review.body.sections.find((section:any)=>section.key==='net').data[0];
  assert.equal(Number(net.net),Number(net.income)-Number(net.expenses));assert.equal(Number(net.expenses),62);
 } finally {await db.query('DELETE FROM transactions WHERE id=?',[id]);}
});

test('SQL: batched evaluation preserves reward keys, completion and seen timestamps across concurrent replay',{skip:!run},async()=>{
 const suffix=randomUUID().slice(0,8);
 const [insert]=await db.query("INSERT INTO users(username,email,password,credential_kind,timezone_name) VALUES (?,?,'unusable','local','UTC')",[`momentum_bulk_${suffix}`,`momentum_bulk_${suffix}@example.invalid`]);
 const userId=Number((insert as {insertId:number}).insertId);
 try {
  const [a]=await db.query("INSERT INTO accounts(user_id,name,type) VALUES (?,'Bulk fixture','Checking')",[userId]);
  const accountId=Number((a as {insertId:number}).insertId);
  await db.query(`INSERT INTO transactions(user_id,account_id,date,description,amount,type,category) VALUES ${Array.from({length:5},()=>"(?,?,UTC_DATE(),?,-10,'Expense','Existing')").join(',')}`,Array.from({length:5},(_,i)=>[userId,accountId,`Bulk transaction ${i}`]).flat());
  await db.query("INSERT INTO payments(user_id,account_id,name,amount,frequency,next_date,is_active) VALUES (?,?,'Bulk obligation',10,'Monthly',DATE_ADD(UTC_DATE(),INTERVAL 2 DAY),1)",[userId,accountId]);
  await db.query("INSERT INTO transaction_drafts(user_id,status,image_sha256) VALUES (?,'confirmed',?),(?,'confirmed',?),(?,'confirmed',?),(?,'ready',?),(?,'confirmed',NULL)",[userId,'a'.repeat(64),userId,'a'.repeat(64),userId,'b'.repeat(64),userId,'c'.repeat(64),userId]);
  const first=await getMomentum(userId) as any;
  assert.equal(first.missions.filter((m:any)=>m.scope==='activation'&&m.status==='completed').length,4);
  assert.equal(first.achievements.length,34);
  assert.deepEqual((await result("SELECT fact_key FROM momentum_facts WHERE user_id=? AND metric='receipts' ORDER BY fact_key",[userId])).map(r=>r.fact_key),['a'.repeat(64),'b'.repeat(64)]);
  // Replaying completed rows must keep their original dates, including seen_at.
  await db.query("UPDATE user_missions SET completed_at='2020-01-02 03:04:05.006' WHERE user_id=? AND status='completed'",[userId]);
  await db.query("UPDATE user_achievement_progress SET completed_at='2020-01-02 03:04:05.006',seen_at='2020-01-03 04:05:06.007' WHERE user_id=? AND completed_at IS NOT NULL",[userId]);
  const snapshot=async()=>({
   missions:await result('SELECT mission_key,period_key,status,progress,granted_xp,target_json,completed_at FROM user_missions WHERE user_id=? ORDER BY mission_key,period_key',[userId]),
   achievements:await result('SELECT achievement_key,progress,completed_at,seen_at FROM user_achievement_progress WHERE user_id=? ORDER BY achievement_key',[userId]),
   rewards:await result('SELECT idempotency_key,xp,nominal_xp,created_at FROM reward_ledger WHERE user_id=? ORDER BY idempotency_key',[userId]),
   receipts:await result("SELECT fact_key,value,provenance,created_at FROM momentum_facts WHERE user_id=? AND metric='receipts' ORDER BY fact_key",[userId]),
  });
  const before=await snapshot();
  assert.ok(before.achievements.some(row=>row.completed_at),'Fixture exercises completed achievement timestamps');
  const repeated=await Promise.all(Array.from({length:4},()=>getMomentum(userId)));
  assert.ok(repeated.every(s=>'lifetime_xp'in s && s.lifetime_xp===first.lifetime_xp));
  assert.deepEqual(await snapshot(),before);
 } finally {await db.query('DELETE FROM users WHERE id=?',[userId]);}
});
