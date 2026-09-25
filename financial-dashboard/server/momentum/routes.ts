import { randomUUID } from 'node:crypto';
import { Router } from 'express';
import type { PoolConnection } from 'mysql2/promise';
import { authenticateToken } from '../auth.js';
import { enabled, endpoint, HttpError, limit, object, timestamp, uuid } from '../platform/http.js';
import { validZone, withinPeriod } from '../platform/periods.js';
import { MISSIONS, ACHIEVEMENTS } from './catalog.js';
import { eligibility } from './missionGenerator.js';
import { context, evaluate, evaluateWithContext, getMomentum, reviewSections, type Context } from './service.js';
import { currentPeriods, fact, hash, json, locked, rows, type Row } from './repository.js';

const router=Router();
router.use('/api/engagement',authenticateToken,(req,res,next)=>{
  res.setHeader('Cache-Control','no-store');
  if (!enabled('MOMENTUM_ENABLED') && req.path!=='/me') return res.status(404).json({code:'MOMENTUM_DISABLED'});
  next();
});
function fields(body:Record<string,unknown>,allowed:string[]) { if(Object.keys(body).some(k=>!allowed.includes(k))) throw new HttpError(400,'UNSUPPORTED_FIELD'); }
async function zone(conn:PoolConnection,userId:number,body:Record<string,unknown>,explicit=false) {
  if (body.timezone_name===undefined && body.timezone_offset_min===undefined) return;
  const name=body.timezone_name===undefined ? null : validZone(body.timezone_name);
  const offset=body.timezone_offset_min===undefined ? null : Number(body.timezone_offset_min);
  if ((body.timezone_name!==undefined && !name) || (offset!==null && (!Number.isInteger(offset)||offset < -720 || offset > 840))) throw new HttpError(400,'INVALID_TIMEZONE');
  if(explicit) {
    await conn.query('UPDATE user_momentum SET preferred_timezone_name=?,preferred_timezone_offset_min=? WHERE user_id=?',[name,offset,userId]);
  } else {
    const existing=(await rows(conn,'SELECT timezone_name FROM users WHERE id=?',[userId]))[0];
    if(!validZone(existing?.timezone_name)) await conn.query('UPDATE users SET timezone_name=COALESCE(?,timezone_name),timezone_offset_min=COALESCE(?,timezone_offset_min) WHERE id=?',[name,offset,userId]);
  }
}
router.get('/api/engagement/me',endpoint(async(req,res)=>{
  const userId=req.user!.id;
  if(!enabled('MOMENTUM_ENABLED')) return res.json({enabled:false,user_id:userId});
  await limit(`momentum:read:${userId}`,60);
  return res.json(await locked(userId,async(conn,state)=>{await zone(conn,userId,req.query as Record<string,unknown>);return evaluate(conn,userId,state);}));
}));
router.get('/api/engagement/missions/current',endpoint(async(req,res)=>{await limit(`momentum:read:${req.user!.id}`,60);const state=await getMomentum(req.user!.id);res.json('missions' in state?{missions:state.missions,week:state.week,month:state.month}:state);}));
router.get('/api/engagement/achievements',endpoint(async(req,res)=>{await limit(`momentum:read:${req.user!.id}`,60);const state=await getMomentum(req.user!.id);res.json('achievements' in state?{achievements:state.achievements}:state);}));
function reviewPeriod(kind:string,ctx:Context) {return kind==='monthly'||kind.startsWith('monthly_')||kind==='report'?ctx.month:ctx.week;}
async function assertReview(conn:PoolConnection,userId:number,kind:string,ctx:Context) {
  if(['weekly','monthly','report'].includes(kind)) {
    if(!ctx.facts.counts.accounts || !ctx.facts.counts.transactions) throw new HttpError(409,'REVIEW_REQUIRES_DATA');
    return;
  }
  const def=MISSIONS.find(d=>d.key===kind && d.review);
  if(!def) throw new HttpError(400,'INVALID_REVIEW_KIND');
  const assigned=(await rows(conn,'SELECT target_json FROM user_missions WHERE user_id=? AND mission_key=? AND period_key IN (?,?) AND status<>?', [userId,kind,'lifetime',reviewPeriod(kind,ctx).key,'replaced']))[0];
  if(!assigned) throw new HttpError(409,'MISSION_NOT_ASSIGNED');
  if(kind==='comeback_clarity') ctx.facts.comebackEpisode=json<string[]>(assigned.target_json,[])[0] ?? null;
  const reason=eligibility(def,ctx.facts);
  if(reason) throw new HttpError(409,'REVIEW_UNAVAILABLE');
  if(kind==='monthly_uncategorized_clear' && (ctx.facts.counts.transactions<5 || ctx.facts.counts.uncategorized>0)) throw new HttpError(409,'UNCATEGORIZED_RECORDS_REMAIN');
}
router.get('/api/engagement/review/:kind',endpoint(async(req,res)=>{
  const userId=req.user!.id,kind=String(req.params.kind);await limit(`momentum:snapshot:${userId}`,20);
  res.json(await locked(userId,async(conn,state)=>{
    const {context:ctx}=await evaluateWithContext(conn,userId,state,true);await assertReview(conn,userId,kind,ctx);
    const period=reviewPeriod(kind,ctx),sections=reviewSections(kind,ctx.sections);
    if(!withinPeriod(new Date(),period)) throw new HttpError(409,'PERIOD_CLOSED');
    const snapshotId=randomUUID(),expiresAt=new Date(Math.min(Date.now()+15*60000,period.end.getTime()));
    // Persist evidence digest and applicable section names only, never a second financial-data copy.
    await conn.query('INSERT INTO momentum_review_snapshots(snapshot_id,user_id,kind,period_key,evidence_hash,sections_json,expires_at) VALUES (?,?,?,?,?,?,?)',[snapshotId,userId,kind,period.key,hash(sections),JSON.stringify(sections.filter(s=>s.applicable).map(s=>s.key)),expiresAt]);
    return {snapshot_id:snapshotId,kind,period:period.key,expires_at:expiresAt,sections};
  }));
}));
async function confirm(conn:PoolConnection,userId:number,state:Row,kind:string,body:Record<string,unknown>,report=false) {
  const snapshotId=uuid(body.snapshot_id);
  const snapshot=(await rows(conn,'SELECT * FROM momentum_review_snapshots WHERE snapshot_id=? AND user_id=? FOR UPDATE',[snapshotId,userId]))[0];
  if(!snapshot || snapshot.kind!==kind) throw new HttpError(400,'INVALID_REVIEW_EVIDENCE');
  if(snapshot.used_at) return; // Lost-response retry is harmless and cannot award twice.
  const ctx=await context(conn,userId,state),period=reviewPeriod(kind,ctx);
  if(String(snapshot.period_key)!==period.key || new Date(snapshot.expires_at as string)<=new Date() || !withinPeriod(new Date(),period)) throw new HttpError(409,'REVIEW_EXPIRED');
  await assertReview(conn,userId,kind,ctx);
  const sections=reviewSections(kind,ctx.sections);
  if(hash(sections)!==snapshot.evidence_hash) throw new HttpError(409,'REVIEW_DATA_CHANGED');
  const confirmed=body.confirmed_sections;
  if(!report && (!Array.isArray(confirmed) || confirmed.some(v=>typeof v!=='string') || json<string[]>(snapshot.sections_json,[]).some(key=>!confirmed.includes(key)))) throw new HttpError(400,'REVIEW_CHECKLIST_INCOMPLETE');
  if(['weekly','monthly'].includes(kind)) {
    if(!['review_spending','organize_categories','check_obligations','review_goal','keep_plan'].includes(String(body.next_step))) throw new HttpError(400,'NEXT_STEP_REQUIRED');
    await conn.query(`INSERT IGNORE INTO ${kind==='weekly'?'weekly_reviews':'monthly_reviews'}(user_id,period_key,timezone_name,checklist_json,next_step) VALUES (?,?,?,?,?)`,[userId,period.key,period.timezone,JSON.stringify(confirmed),body.next_step]);
    await fact(conn,userId,'summary_reviews',`${kind}:${period.key}`,'review');
    if(kind==='weekly' && sections.some(s=>s.key==='obligations'&&s.applicable)) {
      await fact(conn,userId,'payment_reviews',period.key,'review');
      await fact(conn,userId,'cashflow_reviews',period.key,'review');
    }
  } else if(report) {
    await fact(conn,userId,'reports',String(snapshot.evidence_hash),'client_export');
    await fact(conn,userId,`period_reports:${ctx.month.key}`,String(snapshot.evidence_hash),'client_export');
  } else {
    const def=MISSIONS.find(d=>d.key===kind)!;
    const metric=['activation','feature'].includes(def.scope)?def.metric:`${def.metric}:${period.key}`;
    await fact(conn,userId,metric,period.key,'review');
    const badgeMetric=kind.includes('recurring')?'recurring_reviews':kind.includes('payment')?'payment_reviews':kind.includes('invoice')||kind.includes('customer')?'invoice_reviews':kind==='monthly_investment_check'?'investment_monthly_reviews':null;
    if(badgeMetric) await fact(conn,userId,badgeMetric,badgeMetric==='investment_monthly_reviews'?ctx.month.key:ctx.week.key,'review');
  }
  await conn.query('UPDATE momentum_review_snapshots SET used_at=UTC_TIMESTAMP(3) WHERE snapshot_id=?',[snapshotId]);
  await conn.query("INSERT IGNORE INTO engagement_events(event_id,user_id,event_type,source,idempotency_key,payload_json,occurred_at) VALUES (?,?,'review.completed','server',?,JSON_OBJECT('kind',?),UTC_TIMESTAMP(3))",[snapshotId,userId,`review:${snapshotId}`,kind]);
  // Assignment stores its episode before the activity timestamp changes.
  await conn.query('UPDATE user_momentum SET last_significant_at=UTC_TIMESTAMP(3) WHERE user_id=?',[userId]);
}
for(const kind of ['weekly','monthly']) router.post(`/api/engagement/${kind}-review`,endpoint(async(req,res)=>{
  const userId=req.user!.id,body=object(req.body);fields(body,['snapshot_id','confirmed_sections','next_step']);await limit(`momentum:write:${userId}`,30);
  res.json(await locked(userId,async(conn,state)=>{await confirm(conn,userId,state,kind,body);return evaluate(conn,userId,state);}));
}));
router.post('/api/engagement/client-events',endpoint(async(req,res)=>{
  const userId=req.user!.id,body=object(req.body);fields(body,['event_id','type','mission_key','snapshot_id','confirmed_sections','occurred_at']);
  const eventId=uuid(body.event_id),type=String(body.type),occurred=timestamp(body.occurred_at,15*60000);
  if(!['review_confirmed','report_exported','week_presented','coachmark_seen','backfill_seen'].includes(type)) throw new HttpError(400,'EVENT_NOT_ALLOWED');
  if(type==='review_confirmed' && !MISSIONS.some(d=>d.key===body.mission_key && d.review && !['weekly_summary','activation_weekly_review','monthly_review'].includes(d.key))) throw new HttpError(400,'INVALID_REVIEW_KIND');
  await limit(`momentum:write:${userId}`,30);
  res.json(await locked(userId,async(conn,state)=>{
    const prior=(await rows(conn,'SELECT user_id,event_type FROM engagement_events WHERE event_id=?',[eventId]))[0];
    if(prior) {if(Number(prior.user_id)!==userId || prior.event_type!==type) throw new HttpError(409,'EVENT_ID_UNAVAILABLE');return evaluate(conn,userId,state);}
    // Presentation ACKs only need fixed period boundaries; confirmation below
    // independently retrieves and verifies financial evidence before any reward.
    const ctx=await currentPeriods(conn,userId);
    if(!withinPeriod(occurred,type==='report_exported'||String(body.mission_key).startsWith('monthly_')?ctx.month:ctx.week)) throw new HttpError(409,'PERIOD_CLOSED');
    if(type==='review_confirmed') await confirm(conn,userId,state,String(body.mission_key),body);
    else if(type==='report_exported') await confirm(conn,userId,state,'report',body,true);
    else if(type==='week_presented') await conn.query("UPDATE momentum_periods SET presented_at=COALESCE(presented_at,UTC_TIMESTAMP(3)) WHERE user_id=? AND kind='week' AND period_key=? AND assigned_at IS NOT NULL",[userId,ctx.week.key]);
    else await conn.query(`UPDATE user_momentum SET ${type==='coachmark_seen'?'coachmark_seen_at':'backfill_seen_at'}=COALESCE(${type==='coachmark_seen'?'coachmark_seen_at':'backfill_seen_at'},UTC_TIMESTAMP(3)) WHERE user_id=?`,[userId]);
    if(type==='backfill_seen') await conn.query('UPDATE user_achievement_progress SET seen_at=COALESCE(seen_at,UTC_TIMESTAMP(3)) WHERE user_id=? AND completed_at<=?',[userId,state.backfilled_at]);
    await conn.query("INSERT INTO engagement_events(event_id,user_id,event_type,source,idempotency_key,payload_json,occurred_at,status,processed_at) VALUES (?,?,?,'client',?,JSON_OBJECT(),?,'processed',UTC_TIMESTAMP(3))",[eventId,userId,type,`client:${eventId}`,occurred]);
    return evaluate(conn,userId,state);
  }));
}));
router.post('/api/engagement/achievements/:key/seen',endpoint(async(req,res)=>{
  await limit(`momentum:write:${req.user!.id}`,30);
  const key=String(req.params.key);if(!ACHIEVEMENTS.some(a=>a.key===key)) throw new HttpError(404,'UNKNOWN_ACHIEVEMENT');
  await locked(req.user!.id,conn=>conn.query('UPDATE user_achievement_progress SET seen_at=COALESCE(seen_at,UTC_TIMESTAMP(3)) WHERE user_id=? AND achievement_key=? AND completed_at IS NOT NULL',[req.user!.id,key]));res.json({ok:true});
}));
router.post('/api/engagement/preferences',endpoint(async(req,res)=>{
  await limit(`momentum:write:${req.user!.id}`,30);
  const body=object(req.body);fields(body,['notifications_enabled','quiet_start','quiet_end','locale','timezone_name','timezone_offset_min']);
  if(body.notifications_enabled!==undefined && typeof body.notifications_enabled!=='boolean') throw new HttpError(400,'INVALID_PREFERENCE');
  for(const key of ['quiet_start','quiet_end']) if(body[key]!==undefined && (!Number.isInteger(body[key]) || Number(body[key])<0 || Number(body[key])>23)) throw new HttpError(400,'INVALID_QUIET_HOURS');
  if(body.locale!==undefined && !['en','es'].includes(String(body.locale))) throw new HttpError(400,'INVALID_LOCALE');
  res.json(await locked(req.user!.id,async(conn,state)=>{await zone(conn,req.user!.id,body,true);await conn.query('UPDATE user_momentum SET notifications_enabled=COALESCE(?,notifications_enabled),quiet_start=COALESCE(?,quiet_start),quiet_end=COALESCE(?,quiet_end),locale=COALESCE(?,locale) WHERE user_id=?',[body.notifications_enabled??null,body.quiet_start??null,body.quiet_end??null,body.locale??null,req.user!.id]);return evaluate(conn,req.user!.id,state);}));
}));
export default router;
