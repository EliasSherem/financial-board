import test,{before,after} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import type {Connection} from 'mysql2/promise';
import {db} from '../db.js';
import {backfillInvestmentAccounts} from '../../scripts/backfill-investment-accounts.js';
const enabled=process.env.RUN_DB_TESTS==='true';const prefix=`investment_sql_${randomUUID().slice(0,8)}`;let user=0,investment=0;
if(enabled){assert.equal(process.env.NODE_ENV,'test');assert.equal(process.env.MYSQL_URL,undefined);assert.equal(process.env.MYSQL_HOST,'127.0.0.1');assert.match(process.env.MYSQL_DATABASE??'',/_test$/);}
before(async()=>{if(!enabled)return;const [u]:any=await db.query('INSERT INTO users(username,email,password) VALUES(?,?,?)',[prefix,`${prefix}@example.invalid`,'not-a-password']);user=u.insertId;const [i]:any=await db.query("INSERT INTO investments(user_id,name,principal,annual_rate,start_date) VALUES(?,'Synthetic fixture','10.10','3.25','2025-01-01')",[user]);investment=i.insertId;await db.query("INSERT INTO investment_contributions(user_id,investment_id,amount,date) VALUES(?,?,'0.20','2025-02-01')",[user,investment]);});
after(async()=>{if(enabled&&user)await db.query('DELETE FROM users WHERE id=?',[user]);await db.end();});
test('SQL repair dry-run, exact balance, rollback, idempotency, preserved records and no artificial activity',{skip:!enabled},async()=>{
 const conn=await db.getConnection();try{
  const options={userId:user,maintenance:true};const before=await backfillInvestmentAccounts(conn as Connection,options);assert.equal(before.plan.candidates.length,1);assert.equal(before.plan.candidates[0].expected_balance,'10.30');assert.equal(before.created,0);
  const [empty]:any=await db.query('SELECT id FROM accounts WHERE user_id=?',[user]);assert.equal(empty.length,0);
  const broken=new Proxy(conn,{get(target,key){if(key==='query')return (sql:string,args?:unknown[])=>{if(sql.startsWith('UPDATE investments SET account_id='))throw Error('INJECTED_LINK_FAILURE');return (target.query as any)(sql,args);};const value=Reflect.get(target,key);return typeof value==='function'?value.bind(target):value;}});
  await assert.rejects(backfillInvestmentAccounts(broken as Connection,{...options,apply:true,expectedPlan:before.plan.digest}),/INJECTED_LINK_FAILURE/);
  const [rolledBack]:any=await db.query('SELECT id FROM accounts WHERE user_id=?',[user]);assert.equal(rolledBack.length,0);
  assert.equal((await backfillInvestmentAccounts(conn as Connection,{...options,apply:true,expectedPlan:before.plan.digest})).created,1);
  const [state]:any=await db.query('SELECT i.principal,i.annual_rate,i.start_date,i.account_id,a.balance FROM investments i JOIN accounts a ON a.id=i.account_id WHERE i.id=?',[investment]);assert.equal(state[0].principal,'10.10');assert.equal(state[0].annual_rate,'3.2500');assert.equal(state[0].balance,'10.30');assert.ok(state[0].account_id);
  const [contrib]:any=await db.query('SELECT amount,date FROM investment_contributions WHERE investment_id=?',[investment]);assert.equal(contrib.length,1);assert.equal(contrib[0].amount,'0.20');
  const [events]:any=await db.query("SELECT source,status FROM engagement_events WHERE user_id=? AND event_type='accounts.insert'",[user]);assert.deepEqual(events.map((e:any)=>[e.source,e.status]),[['migration','processed']]);
  const again=await backfillInvestmentAccounts(conn as Connection,options);assert.equal(again.plan.candidates.length,0);assert.equal(again.plan.already_linked,1);assert.equal((await backfillInvestmentAccounts(conn as Connection,{...options,apply:true,expectedPlan:again.plan.digest})).created,0);
 }finally{conn.release();}
});
test('SQL orphan account or changed plan prevents any ambiguous repair',{skip:!enabled},async()=>{
 await db.query("INSERT INTO investments(user_id,name,principal,annual_rate,start_date) VALUES(?,'Second fixture',5,0,'2025-01-01')",[user]);
 const conn=await db.getConnection();try{
  const before=await backfillInvestmentAccounts(conn as Connection,{userId:user});await db.query("INSERT INTO accounts(user_id,name,type,balance) VALUES(?,'Unclassified legacy account','Investment',5)",[user]);
  await assert.rejects(backfillInvestmentAccounts(conn as Connection,{userId:user,apply:true,maintenance:true,expectedPlan:before.plan.digest}),/PLAN_CHANGED/);
  const ambiguous=await backfillInvestmentAccounts(conn as Connection,{userId:user});assert.equal(ambiguous.plan.blocked,1);assert.deepEqual(ambiguous.plan.candidates[0].issues,['orphan_investment_account']);await assert.rejects(backfillInvestmentAccounts(conn as Connection,{userId:user,apply:true,maintenance:true,expectedPlan:ambiguous.plan.digest}),/MANUAL_REVIEW/);
 }finally{conn.release();}
});
