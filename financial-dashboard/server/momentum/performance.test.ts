import test from 'node:test';
import assert from 'node:assert/strict';
import type { PoolConnection } from 'mysql2/promise';
import { ACHIEVEMENTS, MISSIONS } from './catalog.js';
import { collectFacts, periodBudgets, rewards, saveAchievements, saveMissions, type Row } from './repository.js';
import { evaluate } from './service.js';
import { periodAt } from '../platform/periods.js';
import type { Mission } from './types.js';

// No app bootstrap, database connection, provider or environment-file access.
assert.equal(process.env.NODE_ENV,'test');
type Command = {sql: string; values: unknown[]};
function recordingConnection(reply: (command: Command) => Row[] = () => []) {
  const commands: Command[] = [];
  const conn = {query: async (sql: string, values: unknown[] = []) => {
    const command = {sql:sql.replace(/\s+/g,' ').trim(),values};
    commands.push(command);
    assert.equal((sql.match(/\?/g) ?? []).length,values.length,'Every SQL value must be bound');
    return [reply(command),[]];
  }} as unknown as PoolConnection;
  return {conn,commands};
}

test('whole mission and achievement catalogs require one command each, retaining completion and immutable targets',async()=>{
  const {conn,commands} = recordingConnection();
  const entries = MISSIONS.map((def,index) => ({nominalXp:def.xp,mission:{key:def.key,scope:def.scope,period:'2026-W39',slot:null,target:def.target,progress:index,status:index%2?'completed':'unavailable',grantedXp:index%2?def.xp:0,targetKeys:[`canonical:${index}`],reason:index%2?null:'no_data'} as Mission}));
  await saveMissions(conn,17,entries);
  await saveAchievements(conn,17,ACHIEVEMENTS.map((def,index)=>({key:def.key,progress:Math.min(index,def.target),complete:index%2===0})));
  assert.equal(commands.length,2);
  assert.equal(commands[0].values.length,MISSIONS.length*14);
  for (let index=0;index<entries.length;index++) {
    const values=commands[0].values.slice(index*14,(index+1)*14),entry=entries[index];
    assert.equal(values[0],17);assert.equal(values[1],entry.mission.key);
    assert.equal(values[8],JSON.stringify(entry.mission.targetKeys));
    assert.equal(values[10],entry.nominalXp);assert.equal(values[11],entry.mission.grantedXp);
    assert.equal(values[12],entry.mission.reason);
    assert.equal(values[13] instanceof Date,entry.mission.status==='completed');
  }
  const updates=commands[0].sql.split('ON DUPLICATE KEY UPDATE')[1];
  assert.doesNotMatch(updates,/\b(target|target_json|slot|nominal_xp)\s*=/);
  assert.match(updates,/completed_at=COALESCE\(completed_at,VALUES\(completed_at\)\)/);
  assert.equal(commands[1].values.length,ACHIEVEMENTS.length*4);
  assert.match(commands[1].sql,/progress=GREATEST\(progress,VALUES\(progress\)\)/);
});

test('bulk rewards retain zero capped awards and every idempotency key; empty collections issue no SQL',async()=>{
  const {conn,commands}=recordingConnection();
  await saveMissions(conn,17,[]);await saveAchievements(conn,17,[]);await rewards(conn,17,[]);
  assert.equal(commands.length,0);
  await rewards(conn,17,[
    {origin:'mission:a',period:'2026-W39',capGroup:'weekly',xp:0,nominalXp:15,idempotencyKey:'mission:a:2026-W39'},
    {origin:'achievement:b',period:'lifetime',capGroup:'none',xp:25,nominalXp:25,idempotencyKey:'achievement:b'},
  ]);
  assert.equal(commands.length,1);
  assert.match(commands[0].sql,/^INSERT IGNORE INTO reward_ledger/);
  assert.deepEqual(commands[0].values,[17,'mission:a','2026-W39','weekly',0,15,'mission:a:2026-W39',17,'achievement:b','lifetime','none',25,25,'achievement:b']);
});

const week=periodAt(new Date(),'week','UTC'),month=periodAt(new Date(),'month','UTC');
const counts={accounts:1,transactions:5,payments:1,upcoming_payments:1,overdue_payments:0,projects:0,active_projects:0,completed_projects:0,invoices:0,open_invoices:0,invoice_payments:0,investments:0,budgets:0,uncategorized:0,weekly_reviews:2,monthly_reviews:1,weekly_reviews_period:0,monthly_reviews_period:0};
function fixture() {
  const state: Row={user_id:17,lifetime_xp:0,rhythm:0,backfilled_at:new Date(),preferred_timezone_name:'UTC',preferred_timezone_offset_min:0,notifications_enabled:1,quiet_start:22,quiet_end:8,locale:'es'};
  const periodRow=(kind:unknown)=>{const p=kind==='month'?month:week;return {id:kind==='month'?2:1,period_key:p.key,timezone_name:p.timezone,offset_min:p.offset,starts_at:p.start,ends_at:p.end,assigned_at:new Date(),completed_at:null,bonus_xp:0,grace_applied:0};};
  return {...recordingConnection(({sql,values})=>{
    if(sql.startsWith('SELECT (SELECT COALESCE(JSON_ARRAYAGG')) {
      const metrics=[{metric:'categorized',n:5,records:5},{metric:'weekly_reviews',n:999,records:1}];
      const categorized=Array.from({length:5},(_,i)=>({fact_key:`canonical:${i}`}));
      if(sql.includes(' AS zone,'))return [{zone:[{timezone_name:'UTC',timezone_offset_min:0}],week:[periodRow('week')],month:[periodRow('month')]}];
      if(!sql.includes(' AS counts,') && sql.includes(' AS metrics,'))return [{metrics,categorized}];
      const common={achievements:[],periods:[periodRow('week')],ledger:[{xp:170,weekly:0,monthly:0}],history:[],credits:[{balance:0,expires_at:null}],holds:[{n:0}],state:[{...state,lifetime_xp:170}]};
      if(!sql.includes(' AS counts,'))return [common];
      return [{...common,counts:[counts],uncategorized:[],receipts:Array.from({length:250},(_,i)=>({image_sha256:i.toString(16).padStart(64,'0')})),repair:[{entities:1,categorized:1,subcategories:1}],metrics,categorized,completed:[],missions:[],achievement_rewards:[],organizer:[],comebacks:[]}];
    }
    if (!sql.startsWith('SELECT')) return [];
    if (sql.startsWith('SELECT is_pro')) return [{is_pro:0}];
    if (sql.includes(' AS has_access FROM users')) return [{has_access:0}];
    if (sql.includes('FROM billing_contracts') || sql.includes('FROM billing_grants')) return [];
    if (sql.startsWith('SELECT (SELECT COUNT')) return [counts];
    if (sql.startsWith('SELECT COALESCE(m.preferred_timezone_name')) return [{timezone_name:'UTC',timezone_offset_min:0}];
    if (sql.startsWith('SELECT * FROM momentum_periods') && sql.includes('kind=?')) return [periodRow(values[1])];
    if (sql.startsWith('SELECT * FROM momentum_periods') && sql.includes('period_key=?')) return [periodRow('week')];
    if (sql.includes('FROM momentum_periods')) return [];
    if (sql.startsWith('SELECT * FROM user_momentum')) return [state];
    if (sql.startsWith('SELECT * FROM user_missions') || sql.startsWith('SELECT 1 FROM user_missions')) return [];
    if (sql.startsWith('SELECT * FROM user_achievement_progress')) return [];
    if (sql.includes('FROM reward_ledger')) return sql.includes('AS weekly')?[{weekly:0,monthly:0}]:sql.includes(' AS n ')?[{n:170}]:[];
    if (sql.startsWith('SELECT metric,SUM(value)')) return [{metric:'categorized',n:5},{metric:'weekly_reviews',n:999}];
    if (sql.startsWith('SELECT fact_key')) return Array.from({length:5},(_,i)=>({fact_key:`canonical:${i}`}));
    if (sql.startsWith('SELECT DISTINCT momentum_identity')) return [];
    if (sql.startsWith('SELECT DISTINCT image_sha256')) return Array.from({length:250},(_,i)=>({image_sha256:i.toString(16).padStart(64,'0')}));
    if (sql.startsWith('SELECT COUNT(*) AS n') || sql.includes('FROM ai_credit_ledger')) return [{n:0,balance:0,expires_at:null}];
    if (sql.startsWith('SELECT name,type,balance')) return [{name:'Fixture',type:'Checking',balance:50}];
    if (sql.startsWith('SELECT date,description') || sql.startsWith('SELECT name,amount,frequency') || sql.startsWith('SELECT COALESCE(c.name')) return [];
    if (sql.includes(' AS income,')) return [{income:100,expenses:50,net:50}];
    throw new Error(`Unexpected fixture command: ${sql}`);
  }),state};
}

test('facts batch independent counts, bind period boundaries and reconcile 250 receipts in two bounded queries',async()=>{
  const {conn,commands,state}=fixture();
  const {facts,sections}=await collectFacts(conn,17,state,week,month,{includeSections:false});
  assert.equal(sections.length,0);
  assert.equal(facts.counts.accounts,1);assert.equal(facts.counts.transactions,5);
  assert.equal(facts.counts.categorized,5);assert.equal(facts.counts.weekly_reviews,2,'Review rows override colliding fact metrics');
  assert.equal(facts.counts[`weekly_reviews_period:${week.key}`],0);
  assert.equal(facts.counts[`monthly_reviews_period:${month.key}`],0);
  const snapshot=commands.find(c=>c.sql.includes(' AS counts,'))!;
  assert.ok(snapshot);
  assert.ok(snapshot.values.includes(week.key));assert.ok(snapshot.values.includes(month.key));
  assert.match(snapshot.sql,/SELECT DISTINCT image_sha256.*status='confirmed'.*IS NOT NULL LIMIT 250/);
  const writes=commands.filter(c=>c.sql.startsWith('INSERT IGNORE INTO momentum_facts('));
  assert.equal(writes.length,1);assert.equal(writes[0].values.length,503);
  assert.deepEqual(writes[0].values.slice(3,5),[17,'0'.repeat(64)]);
  assert.equal(commands.length,6,'Fact collection cost is bounded with 250 receipts');
});

test('explicit review contexts still retrieve fresh financial sections',async()=>{
  const {conn,commands,state}=fixture();
  const {sections}=await collectFacts(conn,17,state,week,month);
  assert.deepEqual(sections.map(s=>s.key),['accounts','recent_activity','net','categories','obligations']);
  assert.deepEqual(sections[0].data,[{name:'Fixture',type:'Checking',balance:50}]);
  assert.deepEqual(sections.find(s=>s.key==='net')!.data,[{income:100,expenses:50,net:50}]);
  assert.equal(commands.length,11);
});

test('evaluation has bounded round trips for the entire catalog and skips review-only financial details',async()=>{
  const {conn,commands,state}=fixture();
  const result=await evaluate(conn,17,state);
  assert.equal(result.enabled,true);assert.equal(result.achievements.length,34);
  assert.ok(result.missions.length>=26);assert.equal(result.week.total,3);
  assert.equal(result.missions.find(m=>m.key==='activation_first_account')!.status,'completed');
  assert.equal(result.preferences.locale,'es');
  assert.equal(commands.filter(c=>c.sql.startsWith('INSERT INTO user_missions ')).length,1);
  assert.equal(commands.filter(c=>c.sql.startsWith('INSERT INTO user_achievement_progress(')).length,1);
  assert.equal(commands.filter(c=>c.sql.startsWith('SELECT name,type,balance')||c.sql.startsWith('SELECT date,description')).length,0);
  assert.ok(commands.length<=17,`Expected <=17 SQL commands, got ${commands.length}`);
  assert.equal(commands.filter(c=>c.sql.includes('AS has_unavailable')).length,1);
});

test('combined period budgets preserve periods, cap groups and positive-only sums',async()=>{
  const {conn,commands}=recordingConnection(()=>[{weekly:'95',monthly:'70'}]);
  assert.deepEqual(await periodBudgets(conn,17,'2026-W39','2026-09'),{weekly:95,monthly:70});
  assert.equal(commands.length,1);
  assert.deepEqual(commands[0].values,['2026-W39','2026-09',17,'2026-W39','2026-09']);
  assert.match(commands[0].sql,/cap_group='weekly' THEN GREATEST\(xp,0\)/);
  assert.match(commands[0].sql,/cap_group='monthly' THEN GREATEST\(xp,0\)/);
});
