import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {setTimeout as delay} from 'node:timers/promises';
import {performance} from 'node:perf_hooks';
import type {PoolConnection} from 'mysql2/promise';
import {db,pooledDb} from '../db.js';
import {getMomentum,context} from './service.js';
import {locked} from './repository.js';
import {periodAt} from '../platform/periods.js';

const run=process.env.RUN_DB_TESTS==='true';
let userId:number,accountId:number;
let captured:string[]|null=null;
const injectedRtt=15;
const originalConnection=pooledDb.getConnection.bind(pooledDb);
const queries=async(sql:string,values:unknown[]=[])=> (await db.query(sql,values))[0] as Record<string,unknown>[];
before(async()=>{
  if(!run)return;
  assert.equal(process.env.NODE_ENV,'test');assert.equal(process.env.MYSQL_HOST,'127.0.0.1');assert.match(process.env.MYSQL_DATABASE??'',/_test$/);assert.equal(process.env.MYSQL_URL,undefined);
  process.env.MOMENTUM_ENABLED='true';process.env.MOMENTUM_AI_CREDITS_ENABLED='false';process.env.MOMENTUM_AI_REWARDS_ENABLED='false';process.env.OPENAI_API_KEY='';
  const suffix=randomUUID().slice(0,8);
  const [user]=await db.query("INSERT INTO users(username,email,password,credential_kind,timezone_name) VALUES (?,?,'unusable','local','UTC')",[`latency_${suffix}`,`latency_${suffix}@example.invalid`]);userId=Number((user as {insertId:number}).insertId);
  const [account]=await db.query("INSERT INTO accounts(user_id,name,type,balance) VALUES (?,'Synthetic snapshot','Checking',123.45)",[userId]);accountId=Number((account as {insertId:number}).insertId);
  for(let i=0;i<5;i++)await db.query("INSERT INTO transactions(user_id,account_id,date,description,amount,type,category) VALUES (?,?,UTC_DATE(),?,-12.34,'Expense','Fixtures')",[userId,accountId,`Base ${i}`]);
  await db.query("INSERT INTO payments(user_id,account_id,name,amount,frequency,next_date,is_active) VALUES (?,?,'Fixture bill',12.34,'Monthly',DATE_ADD(UTC_DATE(),INTERVAL 2 DAY),1)",[userId,accountId]);
  pooledDb.getConnection=async()=>{
    const conn=await originalConnection();
    // PromisePool wraps each checkout: this changes only the test connection wrapper.
    for(const method of ['query','beginTransaction','commit','rollback'] as const) {
      const original=conn[method].bind(conn) as (...args:unknown[])=>Promise<unknown>;
      (conn as unknown as Record<string,unknown>)[method]=async(...args:unknown[])=>{
        if(captured){captured.push(method==='query'?String(args[0]).replace(/\s+/g,' ').trim():method);await delay(injectedRtt);}
        return original(...args);
      };
    }
    return conn as PoolConnection;
  };
});
after(async()=>{if(!run)return;pooledDb.getConnection=originalConnection;await db.query('DELETE FROM users WHERE id=?',[userId]);await db.end();});

async function measured(){captured=[];const started=performance.now();try{const state=await getMomentum(userId);return {state,commands:captured,elapsed:performance.now()-started};}finally{captured=null;}}
function comparable(value:unknown){const result=JSON.parse(JSON.stringify(value));delete result.generated_at;return result;}

test('SQL: unchanged read remains authoritative with six round trips and zero writes', {skip:!run},async t=>{
  const first=await measured(),repeat=await measured();
  assert.deepEqual(comparable(repeat.state),comparable(first.state));
  assert.equal(repeat.commands.length,6,'BEGIN + parent/child lock + periods + live entitlement + verified snapshot + COMMIT');
  assert.equal(repeat.commands.filter(sql=>/^(INSERT|UPDATE|DELETE)/.test(sql)).length,0);
  assert.ok(first.commands.length>repeat.commands.length);
  t.diagnostic(JSON.stringify({injected_rtt_ms:injectedRtt,cold:{round_trips:first.commands.length,elapsed_ms:Math.round(first.elapsed)},unchanged:{round_trips:repeat.commands.length,elapsed_ms:Math.round(repeat.elapsed)}}));
});

test('SQL: financial mutation after a fast read appears immediately and earns exactly once',{skip:!run},async()=>{
  const before=await getMomentum(userId);assert.ok('lifetime_xp' in before);
  for(let i=0;i<5;i++)await db.query("INSERT INTO transactions(user_id,account_id,date,description,amount,type,category) VALUES (?,?,UTC_DATE(),?,-1.23,'Expense','Fixtures')",[userId,accountId,`New ${i}`]);
  const after=await measured();assert.ok('achievements' in after.state);
  const badge=after.state.achievements.find(a=>a.key==='spending_detective_1')!;
  assert.equal(badge.progress,10);assert.ok(badge.completed_at);assert.equal(after.state.lifetime_xp,before.lifetime_xp+20);
  const expectedXp=after.state.lifetime_xp;
  const repeats=await Promise.all(Array.from({length:4},()=>getMomentum(userId)));
  assert.ok(repeats.every(s=>'lifetime_xp' in s && s.lifetime_xp===expectedXp));
  assert.equal(Number((await queries("SELECT COUNT(*) AS n FROM reward_ledger WHERE user_id=? AND idempotency_key='achievement:spending_detective_1'",[userId]))[0].n),1);
});

test('SQL: bundled UTC milliseconds match wire DTO, while review decimals remain mysql2 strings',{skip:!run},async()=>{
  await db.query("UPDATE user_achievement_progress SET completed_at='2020-01-02 03:04:05.123',seen_at='2020-01-02 03:05:06.456' WHERE user_id=? AND achievement_key='account_organizer'",[userId]);
  const oldZone=process.env.TZ;process.env.TZ='America/Los_Angeles';
  try {
    const state=await getMomentum(userId);assert.ok('achievements' in state);
    const achievement=state.achievements.find(a=>a.key==='account_organizer')!;
    assert.equal(achievement.completed_at,'2020-01-02T03:04:05.123Z');assert.equal(achievement.seen_at,'2020-01-02T03:05:06.456Z');
    const ctx=await locked(userId,(conn,stored)=>context(conn,userId,stored));
    assert.equal(ctx.sections.find(s=>s.key==='accounts')!.data[0].balance,'123.45');
    assert.equal(typeof ctx.sections.find(s=>s.key==='recent_activity')!.data[0].amount,'string');
    assert.ok(ctx.sections.find(s=>s.key==='recent_activity')!.data[0].date instanceof Date);
  } finally {if(oldZone===undefined)delete process.env.TZ;else process.env.TZ=oldZone;}
});

test('SQL: unassigned weeks cannot truncate the 105 assigned periods used for rhythm',{skip:!run},async()=>{
  const current=periodAt(new Date(),'week','UTC');
  const values:unknown[]=[],placeholders:string[]=[];
  for(let i=1;i<=215;i++) {
    const period=periodAt(new Date(current.start.getTime()-i*7*86400000),'week','UTC');
    placeholders.push("(?,'week',?,'UTC',0,?,?,?,?)");
    const assigned=i%2===0?period.start:null;
    values.push(userId,period.key,period.start,period.end,assigned,assigned);
  }
  await db.query(`INSERT INTO momentum_periods(user_id,kind,period_key,timezone_name,offset_min,starts_at,ends_at,assigned_at,completed_at) VALUES ${placeholders.join(',')}`,values);
  const ctx=await locked(userId,(conn,stored)=>context(conn,userId,stored,{includeSections:false}));
  const expected=await queries("SELECT period_key FROM momentum_periods WHERE user_id=? AND kind='week' AND assigned_at IS NOT NULL AND period_key<=? ORDER BY starts_at DESC LIMIT 105",[userId,current.key]);
  const actual=ctx.initial.periods.filter(p=>p.assigned_at).sort((a,b)=>String(b.starts_at).localeCompare(String(a.starts_at))).slice(0,105);
  assert.deepEqual(actual.map(p=>p.period_key),expected.map(p=>p.period_key));
  assert.equal(actual.length,105);assert.ok(ctx.initial.periods.some(p=>p.period_key===current.key));
});
