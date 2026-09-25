import type { PoolConnection } from 'mysql2/promise';
import { enabled } from '../platform/http.js';
import { ACHIEVEMENTS, CATALOG_VERSION, MISSIONS, REASONS, levelFor } from './catalog.js';
import { achievementProgress, completedWeek, evaluateMissions, mayApplyGrace, MONTHLY_CAP, WEEKLY_CAP, WEEK_BONUS } from './engine.js';
import { assignedMission, eligibility, generateWeekly } from './missionGenerator.js';
import { collectFacts, currentPeriods, fact, missionRows, locked, reward, rewards, rows, saveAchievements, saveMissions, periodJsonFields, type Row } from './repository.js';
import { creditsEnabled, grantOrganizerCredits } from './credits.js';
import type { Mission, Section } from './types.js';
import { readBundle, rowFields } from './readBundle.js';

export type Context = Awaited<ReturnType<typeof context>>;
export async function context(conn: PoolConnection, userId: number, state: Row, options: {includeSections?: boolean} = {}) {
  const {week,month}=await currentPeriods(conn,userId);
  const collected = await collectFacts(conn,userId,state,week,month,options);
  return { week, month, ...collected };
}
async function rhythm(conn: PoolConnection, userId: number, current: string, periodRows:Row[]): Promise<{count:number;changed:boolean}> {
  const periods=periodRows.filter(p=>p.assigned_at).sort((a,b)=>new Date(b.starts_at as string).getTime()-new Date(a.starts_at as string).getTime()).slice(0,105);
  let changed=false;
  const history = periods.filter(p => String(p.period_key) !== current || p.completed_at);
  let count = 0;
  for (let i = 0; i < history.length; i++) {
    const p = history[i];
    if (i && new Date(history[i-1].starts_at as string).getTime() - new Date(p.ends_at as string).getTime() > 86400000) break;
    if (p.completed_at) { count++; continue; }
    if (p.grace_applied) continue;
    if (p.has_unavailable) continue; // An impossible required slot does not penalize rhythm.
    const used = periods.filter(x => x.grace_applied).map(x => new Date(x.starts_at as string));
    if (i === 0 && history[i+1]?.completed_at && mayApplyGrace(new Date(p.starts_at as string),used,enabled('MOMENTUM_GRACE_ENABLED'),8,String(p.timezone_name),Number(p.offset_min))) {
      await conn.query("UPDATE momentum_periods SET grace_applied=1 WHERE id=?",[p.id]);
      await conn.query('UPDATE user_momentum SET last_grace_week=? WHERE user_id=?',[p.period_key,userId]);
      changed=true;
      p.grace_applied=1;
      continue;
    }
    break;
  }
  return {count,changed};
}
function reasonText(reason: string | null) { return reason ? REASONS[reason as keyof typeof REASONS] ?? REASONS.unavailable : null; }
export async function evaluate(conn: PoolConnection, userId: number, state: Row) {
  return (await evaluateWithContext(conn,userId,state)).response;
}
/** A review can reuse this operation's verified facts/sections, never a cached response. */
export async function evaluateWithContext(conn:PoolConnection,userId:number,state:Row,includeSections=false) {
  const ctx = await context(conn,userId,state,{includeSections});
  const {week,month,facts} = ctx;
  const initial=ctx.initial;
  let missions = missionRows(initial.missions);
  const priorMissions=new Map(missions.map(m=>[`${m.key}:${m.period}`,JSON.stringify([m.progress,m.status,m.grantedXp,m.reason])]));
  let writes=false;
  // Capture a comeback episode before updating last_significant_at. Existing assignment survives return activity.
  const comeback = missions.find(m => m.key === 'comeback_clarity');
  if (comeback?.targetKeys[0]) facts.comebackEpisode = comeback.targetKeys[0];
  for (const def of MISSIONS.filter(d => ['activation','feature','monthly','comeback'].includes(d.scope))) {
    const period = ['activation','feature'].includes(def.scope) ? 'lifetime' : def.scope === 'monthly' ? month.key : week.key;
    if (missions.some(m => m.key === def.key && m.period === period)) continue;
    if (def.scope === 'comeback' && eligibility(def,facts)) continue;
    const mission = assignedMission(def,period,facts);
    if (def.key === 'comeback_clarity') mission.targetKeys = [facts.comebackEpisode!];
    missions.push(mission);
  }
  // One persisted optional discovery, rotated by fixed ISO week and user, never on refresh.
  const optionalPool = ['weekly_receipt_confirm','weekly_ai_action','weekly_project_update','weekly_customer_review','weekly_category_cleanup'];
  const rotation = (Number(week.key.slice(-2)) + userId) % optionalPool.length;
  const optionalOrder = [...optionalPool.slice(rotation),...optionalPool.slice(0,rotation)];
  for (const key of optionalOrder) {
    if (missions.some(m => m.scope === 'weekly' && !m.slot && m.period === week.key)) break;
    const def = MISSIONS.find(d => d.key === key)!;
    if (!eligibility(def,facts) && !missions.some(m => m.key === key && m.period === week.key)) missions.push(assignedMission(def,week.key,facts));
  }
  const weekly = generateWeekly(missions.filter(m => m.scope === 'weekly'),week.key,facts);
  missions = [...missions.filter(m => m.scope !== 'weekly'),...weekly.missions];
  for (const replacement of weekly.replacements) await conn.query('INSERT INTO mission_replacements(user_id,period_key,old_mission_key,new_mission_key,reason_code) VALUES (?,?,?,?,?)',[userId,week.key,replacement.old,replacement.next,replacement.reason]);
  if (!week.assigned && weekly.missions.some(m => m.slot)) {writes=true;await conn.query("UPDATE momentum_periods SET assigned_at=COALESCE(assigned_at,UTC_TIMESTAMP(3)) WHERE user_id=? AND kind='week' AND period_key=?",[userId,week.key]);}
  const budget = {weekly:Number(initial.ledger[0].weekly),monthly:Number(initial.ledger[0].monthly)};
  // Expired fixed periods can remain during a backwards timezone move, but cannot award again.
  const active = missions.filter(m => m.period === 'lifetime' || (m.scope === 'monthly' ? month.end : week.end) > new Date());
  const result = evaluateMissions(active,facts,budget);
  const byKey = new Map(result.missions.map(m => [`${m.key}:${m.period}`,m]));
  missions = missions.map(m => byKey.get(`${m.key}:${m.period}`) ?? m);
  const missionRewards = [...result.rewards];
  if (missions.some(m => m.scope === 'weekly' && m.status === 'completed') && facts.hasMissedWeek) {
    facts.counts[`comeback_week:${week.key}`] = 1;
    const second = evaluateMissions(missions.filter(m => m.key === 'comeback_week'),facts,budget);
    missionRewards.push(...second.rewards);
    missions = missions.map(m => second.missions.find(n => n.key === m.key) ?? m);
  }
  await rewards(conn,userId,missionRewards);
  writes ||= missionRewards.length>0;
  for (const mission of missions) {
    const def = MISSIONS.find(d => d.key === mission.key)!;
    if (!['completed','replaced'].includes(mission.status)) {
      const reason = eligibility(def,facts);
      mission.reason = mission.slot && mission.status === 'unavailable' ? 'no_replacement' : reason;
      if (!mission.slot) mission.status = reason ? 'unavailable' : 'active';
    }
  }
  const changedMissions=missions.filter(m=>priorMissions.get(`${m.key}:${m.period}`)!==JSON.stringify([m.progress,m.status,m.grantedXp,m.reason]));
  await saveMissions(conn,userId,changedMissions.map(mission=>({mission,nominalXp:MISSIONS.find(d=>d.key===mission.key)!.xp})));
  writes ||= changedMissions.length>0 || weekly.replacements.length>0;
  let comebackChanged=false;
  for (const mission of missions) if (mission.key === 'comeback_clarity' && mission.status === 'completed' && !initial.comebacks.some(row=>row.fact_key===(mission.targetKeys[0]??week.key))) {
    await fact(conn,userId,'comebacks',mission.targetKeys[0] ?? week.key,'review');comebackChanged=true;
  }
  const rewardKeys=new Set(initial.achievement_rewards.map(row=>String(row.idempotency_key)));
  if (completedWeek(missions) && week.end > new Date()) {
    if(!rewardKeys.has(`week_bonus:${week.key}`)) {await reward(conn,userId,{origin:'week_complete',period:week.key,capGroup:'week_bonus',xp:WEEK_BONUS,nominalXp:WEEK_BONUS,idempotencyKey:`week_bonus:${week.key}`});writes=true;}
    if(!week.completed || week.bonusXp!==WEEK_BONUS) {
      await conn.query("UPDATE momentum_periods SET completed_at=COALESCE(completed_at,UTC_TIMESTAMP(3)),bonus_xp=? WHERE user_id=? AND kind='week' AND period_key=?",[WEEK_BONUS,userId,week.key]);writes=true;
      const period=initial.periods.find(p=>p.period_key===week.key);if(period)period.completed_at=new Date();
    }
  }
  const current=initial.periods.find(p=>p.period_key===week.key);
  if(current) {
    if(weekly.missions.some(m=>m.slot))current.assigned_at ||= new Date();
    current.has_unavailable=missions.some(m=>m.slot && m.status==='unavailable')?1:0;
  }
  const rhythmic=await rhythm(conn,userId,week.key,initial.periods),actualRhythm=rhythmic.count;
  writes ||= rhythmic.changed;
  facts.counts.rhythm=actualRhythm;
  if(comebackChanged) facts.counts.comebacks=Number((await rows(conn,"SELECT COUNT(*) AS n FROM momentum_facts WHERE user_id=? AND metric='comebacks'",[userId]))[0].n);
  const progress=achievementProgress(facts,missions.filter(m=>m.scope==='activation' && m.status==='completed').length);
  const changedAchievements=progress.filter(p=>{
    const previous=initial.achievements.find(row=>row.achievement_key===p.key);
    return !previous || p.progress>Number(previous.progress) || (p.complete && !previous.completed_at);
  });
  await saveAchievements(conn,userId,changedAchievements);
  const achievementRewards=progress.filter(p=>p.complete && !rewardKeys.has(`achievement:${p.key}`)).map(p=>{
    const def=ACHIEVEMENTS.find(a=>a.key===p.key)!;
    return {origin:`achievement:${def.key}`,period:'lifetime',capGroup:'none' as const,xp:def.xp,nominalXp:def.xp,idempotencyKey:`achievement:${def.key}`};
  });
  await rewards(conn,userId,achievementRewards);
  writes ||= changedAchievements.length>0 || achievementRewards.length>0;
  const ledgerChanged=missionRewards.length>0 || achievementRewards.length>0 || (completedWeek(missions) && week.end>new Date() && !rewardKeys.has(`week_bonus:${week.key}`));
  const lifetimeXp=ledgerChanged ? Number((await rows(conn,'SELECT COALESCE(SUM(xp),0) AS n FROM reward_ledger WHERE user_id=?',[userId]))[0].n) : Number(initial.ledger[0].xp);
  const storedState=initial.state[0];
  if(Number(storedState.lifetime_xp)!==lifetimeXp || Number(storedState.rhythm)!==actualRhythm || !storedState.backfilled_at) {
    await conn.query('UPDATE user_momentum SET lifetime_xp=?,rhythm=?,backfilled_at=COALESCE(backfilled_at,UTC_TIMESTAMP(3)) WHERE user_id=?',[lifetimeXp,actualRhythm,userId]);writes=true;
  }
  if(creditsEnabled() && lifetimeXp>=250 && !initial.organizer.length) {await grantOrganizerCredits(conn,userId,lifetimeXp);writes=true;}
  if(writes) Object.assign(initial,await outputRows(conn,userId,week.key,month.key));
  return {response:serialize(userId,initial.state[0],ctx,missions,lifetimeXp),context:ctx};
}
async function outputRows(conn:PoolConnection,userId:number,week:string,month:string) {
  return readBundle(conn,{
    achievements:{sql:'SELECT * FROM user_achievement_progress WHERE user_id=?',values:[userId],fields:rowFields(['achievement_key','progress','completed_at','seen_at'],['completed_at','seen_at'])},
    periods:{sql:"SELECT * FROM momentum_periods WHERE user_id=? AND kind='week' AND period_key<=? ORDER BY starts_at DESC LIMIT 2",values:[userId,week],fields:periodJsonFields},
    ledger:{sql:`SELECT COALESCE(SUM(CASE WHEN period_key=? AND cap_group='weekly' THEN GREATEST(xp,0) ELSE 0 END),0) AS weekly,COALESCE(SUM(CASE WHEN period_key=? AND cap_group='monthly' THEN GREATEST(xp,0) ELSE 0 END),0) AS monthly FROM reward_ledger WHERE user_id=?`,values:[week,month,userId],fields:['weekly','monthly']},
    history:{sql:"SELECT DATE_FORMAT(created_at,'%Y-%m-%d') AS period,SUM(xp) AS xp FROM reward_ledger WHERE user_id=? AND created_at>=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 30 DAY) GROUP BY DATE_FORMAT(created_at,'%Y-%m-%d')",values:[userId],fields:['period','xp']},
    credits:{sql:"SELECT COALESCE(SUM(credits),0) AS balance,MAX(expires_at) AS expires_at FROM ai_credit_ledger WHERE user_id=? AND (expires_at IS NULL OR expires_at>UTC_TIMESTAMP(3))",values:[userId],fields:rowFields(['balance','expires_at'],['expires_at'])},
    holds:{sql:"SELECT COUNT(*) AS n FROM ai_credit_reservations WHERE user_id=? AND uses_credit=1 AND status='pending' AND expires_at>UTC_TIMESTAMP(3)",values:[userId],fields:['n']},
    state:{sql:'SELECT * FROM user_momentum WHERE user_id=?',values:[userId],fields:rowFields(['lifetime_xp','rhythm','backfilled_at','backfill_seen_at','coachmark_seen_at','preferred_timezone_name','preferred_timezone_offset_min','notifications_enabled','quiet_start','quiet_end','locale'],['backfilled_at','backfill_seen_at','coachmark_seen_at'])},
  });
}
function serialize(userId:number,state:Row,ctx:Context,missions:Mission[],xp:number) {
  const {week,month,facts,initial}=ctx;
  const achievements=ACHIEVEMENTS.map(def=>{
    const row=initial.achievements.find(r=>r.achievement_key===def.key),available=facts.capabilities[def.capability];
    return {key:def.key,title:def.title,requirement:def.requirement,progress:Number(row?.progress??0),target:def.target,xp:def.xp,completed_at:row?.completed_at??null,seen_at:row?.seen_at??null,available,reason:available?null:reasonText(def.capability==='project_milestones'?'project_milestones':'unavailable')};
  });
  const weekly=missions.filter(m=>m.scope==='weekly' && m.slot && m.status!=='replaced');
  const period=initial.periods.find(p=>p.period_key===week.key)!;
  const priorWeek=initial.periods.filter(p=>String(p.period_key)<week.key).sort((a,b)=>new Date(b.starts_at as string).getTime()-new Date(a.starts_at as string).getTime())[0];
  const budget={weekly:Number(initial.ledger[0].weekly),monthly:Number(initial.ledger[0].monthly)};
  return {enabled:true,catalog_version:CATALOG_VERSION,user_id:userId,generated_at:new Date().toISOString(),lifetime_xp:xp,level:levelFor(xp),xp_history:initial.history.map(row=>({period:String(row.period),xp:Number(row.xp)})).sort((a,b)=>a.period.localeCompare(b.period)),
    week:{key:week.key,timezone:week.timezone,starts_at:week.start,ends_at:week.end,assigned:!!period.assigned_at,completed:weekly.filter(m=>m.status==='completed').length,total:weekly.length,bonus_xp:Number(period.bonus_xp),repeatable_xp:budget.weekly,cap:WEEKLY_CAP,new_week:!!period.assigned_at && !period.presented_at,unavailable:weekly.some(m=>m.status==='unavailable'),grace_applied:!!period.grace_applied || !!priorWeek?.grace_applied,grace_period_key:priorWeek?.grace_applied?String(priorWeek.period_key):period.grace_applied?week.key:null},
    month:{key:month.key,repeatable_xp:budget.monthly,cap:MONTHLY_CAP},rhythm:Number(state.rhythm),
    missions:missions.map(m=>{const def=MISSIONS.find(d=>d.key===m.key)!;return {key:m.key,scope:m.scope,title:def.title,requirement:def.requirement,deeplink:def.deeplink,review:def.review,period:m.period,status:m.status,slot:m.slot,target:m.target,progress:m.progress,nominal_xp:def.xp,granted_xp:m.grantedXp,reason:reasonText(m.reason)};}),
    achievements,ai_credits:{available:creditsEnabled(),balance:Math.max(0,Number(initial.credits[0].balance)-Number(initial.holds[0].n)),expires_at:initial.credits[0].expires_at??null},backfill:{completed:!!state.backfilled_at,unseen:!state.backfill_seen_at && achievements.some(a=>a.completed_at && new Date(a.completed_at as string)<=new Date(state.backfilled_at as string))},coachmark_seen:!!state.coachmark_seen_at,
    preferences:{timezone_name:state.preferred_timezone_name??week.timezone,timezone_offset_min:state.preferred_timezone_offset_min??week.offset,notifications_enabled:!!state.notifications_enabled,quiet_start:Number(state.quiet_start),quiet_end:Number(state.quiet_end),locale:String(state.locale)}};
}

export async function getMomentum(userId:number) {
  if (!enabled('MOMENTUM_ENABLED')) return {enabled:false,user_id:userId};
  return locked(userId,(conn,state)=>evaluate(conn,userId,state));
}

export function reviewSections(kind:string,sections:Section[]):Section[] {
  let keys: string[];
  if (['weekly','comeback_clarity'].includes(kind)) keys=['accounts','recent_activity','net','obligations'];
  else if (kind==='monthly') keys=['accounts','net','categories','obligations'];
  else if (kind==='report') keys=['recent_activity','net','categories'];
  else if (kind.includes('account') || kind.includes('balance')) keys=['accounts'];
  else if (kind.includes('payment') || kind.includes('recurring')) keys=['obligations'];
  else if (kind.includes('project')) keys=['projects'];
  else if (kind.includes('invoice') || kind.includes('customer')) keys=['invoices'];
  else if (kind.includes('investment')) keys=['investments'];
  else if (kind.includes('budget')) keys=['budgets','categories'];
  else if (kind.includes('uncategorized')) keys=['recent_activity','categories'];
  else keys=['net','categories'];
  return sections.filter(s=>keys.includes(s.key));
}
