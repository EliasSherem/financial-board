import { createHash } from 'node:crypto';
import type { PoolConnection } from 'mysql2/promise';
import { withTransaction } from '../db.js';
import { readEntitlement, refreshEntitlement } from '../billing/repository.js';
import { enabled } from '../platform/http.js';
import { localParts, periodAt, type Period } from '../platform/periods.js';
import { CATALOG_VERSION } from './catalog.js';
import type { Facts, Mission, Reward, Section } from './types.js';
import { readBundle, rowFields } from './readBundle.js';

export type Row = Record<string, unknown>;
export async function rows(conn: PoolConnection, sql: string, values: unknown[] = []): Promise<Row[]> {
  const [result] = await conn.query(sql, values);
  return result as Row[];
}
export function json<T>(value: unknown, fallback: T): T {
  if (typeof value === 'string') { try { return JSON.parse(value) as T; } catch { return fallback; } }
  return value == null ? fallback : value as T;
}
export function hash(value: unknown): string { return createHash('sha256').update(JSON.stringify(value)).digest('hex'); }
export async function locked<T>(userId: number, work: (conn: PoolConnection, state: Row) => Promise<T>): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await withTransaction(async conn => {
        // Match billing's lock order. Lock the parent before FK inserts to avoid S→X upgrade deadlocks.
        const found = (await rows(conn, `SELECT STRAIGHT_JOIN m.*,u.id AS locked_user_id,u.is_pro AS locked_user_pro
          FROM users u LEFT JOIN user_momentum m ON m.user_id=u.id WHERE u.id=? FOR UPDATE`, [userId]))[0];
        if(!found) throw new Error('Momentum user no longer exists');
        let state=found;
        if(state.user_id==null) {
          await conn.query('INSERT INTO user_momentum (user_id) VALUES (?)', [userId]);
          state={...(await rows(conn,'SELECT * FROM user_momentum WHERE user_id=?',[userId]))[0],locked_user_pro:found.locked_user_pro};
        }
        return work(conn, state);
      });
    } catch (error) {
      if (attempt >= 2 || !['ER_LOCK_DEADLOCK', 'ER_LOCK_WAIT_TIMEOUT'].includes(String((error as { code?: string }).code))) throw error;
    }
  }
}
export type CurrentPeriod = Period & {assigned:boolean;presented:boolean;bonusXp:number;completed:boolean;grace:boolean};
const periodFields=['id','period_key','kind','timezone_name','offset_min','starts_at','ends_at','assigned_at','presented_at','completed_at','bonus_xp','grace_applied'];
const periodDates=['starts_at','ends_at','assigned_at','presented_at','completed_at'];
export const periodJsonFields=rowFields(periodFields,periodDates);
export async function currentPeriods(conn:PoolConnection,userId:number,now=new Date()):Promise<{week:CurrentPeriod;month:CurrentPeriod}> {
  const result=await readBundle(conn,{
    zone:{sql:'SELECT COALESCE(m.preferred_timezone_name,u.timezone_name) AS timezone_name,COALESCE(m.preferred_timezone_offset_min,u.timezone_offset_min) AS timezone_offset_min FROM users u LEFT JOIN user_momentum m ON m.user_id=u.id WHERE u.id=?',values:[userId],fields:['timezone_name','timezone_offset_min']},
    week:{sql:"SELECT * FROM momentum_periods WHERE user_id=? AND kind='week' ORDER BY starts_at DESC LIMIT 1",values:[userId],fields:periodJsonFields},
    month:{sql:"SELECT * FROM momentum_periods WHERE user_id=? AND kind='month' ORDER BY starts_at DESC LIMIT 1",values:[userId],fields:periodJsonFields},
  });
  const zone=result.zone[0],created:Period[]=[],periods={} as {week:CurrentPeriod;month:CurrentPeriod};
  for(const kind of ['week','month'] as const) {
    const previous=result[kind][0];let proposed=periodAt(now,kind,zone.timezone_name,Number(zone.timezone_offset_min??0));
    if(previous && (new Date(previous.ends_at as string)>now || proposed.key<=String(previous.period_key))) {
      periods[kind]={key:String(previous.period_key),kind,timezone:String(previous.timezone_name),offset:Number(previous.offset_min),start:new Date(previous.starts_at as string),end:new Date(previous.ends_at as string),assigned:!!previous.assigned_at,presented:!!previous.presented_at,completed:!!previous.completed_at,bonusXp:Number(previous.bonus_xp),grace:!!previous.grace_applied};
    } else {
      if(previous && proposed.start<new Date(previous.ends_at as string))proposed={...proposed,start:new Date(previous.ends_at as string)};
      created.push(proposed);periods[kind]={...proposed,assigned:false,presented:false,completed:false,bonusXp:0,grace:false};
    }
  }
  if(created.length)await conn.query(`INSERT INTO momentum_periods(user_id,kind,period_key,timezone_name,offset_min,starts_at,ends_at) VALUES ${created.map(()=>'(?,?,?,?,?,?,?)').join(',')}`,created.flatMap(p=>[userId,p.kind,p.key,p.timezone,p.offset,p.start,p.end]));
  return periods;
}
export async function fact(conn: PoolConnection, userId: number, metric: string, key: string, provenance: string, value = 1) {
  await conn.query('INSERT IGNORE INTO momentum_facts (user_id,metric,fact_key,value,provenance) VALUES (?,?,?,?,?)', [userId, metric, key, value, provenance]);
}
export async function currentPeriod(conn: PoolConnection, userId: number, kind: 'week' | 'month', now = new Date()): Promise<Period & { assigned: boolean; presented: boolean; bonusXp: number; completed: boolean; grace: boolean }> {
  const user = (await rows(conn, 'SELECT COALESCE(m.preferred_timezone_name,u.timezone_name) AS timezone_name,COALESCE(m.preferred_timezone_offset_min,u.timezone_offset_min) AS timezone_offset_min FROM users u LEFT JOIN user_momentum m ON m.user_id=u.id WHERE u.id=?', [userId]))[0];
  const previous = (await rows(conn, 'SELECT * FROM momentum_periods WHERE user_id=? AND kind=? ORDER BY starts_at DESC LIMIT 1', [userId, kind]))[0];
  let proposed = periodAt(now, kind, user.timezone_name, Number(user.timezone_offset_min ?? 0));
  // Never create an overlapping period or revisit an older local key after a zone change.
  if (previous && (new Date(previous.ends_at as string) > now || proposed.key <= String(previous.period_key))) {
    return { key: String(previous.period_key), kind, timezone: String(previous.timezone_name), offset: Number(previous.offset_min), start: new Date(previous.starts_at as string), end: new Date(previous.ends_at as string), assigned: !!previous.assigned_at, presented: !!previous.presented_at, completed: !!previous.completed_at, bonusXp: Number(previous.bonus_xp), grace: !!previous.grace_applied };
  }
  if (previous && proposed.start < new Date(previous.ends_at as string)) proposed = { ...proposed, start: new Date(previous.ends_at as string) };
  await conn.query('INSERT IGNORE INTO momentum_periods (user_id,kind,period_key,timezone_name,offset_min,starts_at,ends_at) VALUES (?,?,?,?,?,?,?)', [userId, kind, proposed.key, proposed.timezone, proposed.offset, proposed.start, proposed.end]);
  return { ...proposed, assigned: false, presented: false, bonusXp: 0, completed: false, grace: false };
}
export async function loadMissions(conn: PoolConnection, userId: number, week: string, month: string): Promise<Mission[]> {
  return missionRows(await rows(conn, "SELECT * FROM user_missions WHERE user_id=? AND period_key IN ('lifetime',?,?) ORDER BY assigned_at,id", [userId, week, month]));
}
export function missionRows(found:Row[]):Mission[] {
  return [...found].sort((a,b)=>new Date(a.assigned_at as string).getTime()-new Date(b.assigned_at as string).getTime() || Number(a.id)-Number(b.id)).map(row=>({key:String(row.mission_key),scope:row.scope as Mission['scope'],period:String(row.period_key),slot:row.slot as Mission['slot'],target:Number(row.target),progress:Number(row.progress),status:row.status as Mission['status'],grantedXp:Number(row.granted_xp),targetKeys:json<string[]>(row.target_json,[]),reason:row.reason_code?String(row.reason_code):null}));
}
export async function saveMission(conn: PoolConnection, userId: number, mission: Mission, nominalXp: number) {
  return saveMissions(conn,userId,[{mission,nominalXp}]);
}
export async function saveMissions(conn: PoolConnection, userId: number, entries: Array<{mission: Mission; nominalXp: number}>) {
  if (!entries.length) return;
  const values = entries.flatMap(({mission,nominalXp}) => [userId, mission.key, CATALOG_VERSION, mission.period, mission.scope, mission.slot, mission.target, mission.progress, JSON.stringify(mission.targetKeys), mission.status, nominalXp, mission.grantedXp, mission.reason, mission.status === 'completed' ? new Date() : null]);
  await conn.query(`INSERT INTO user_missions (user_id,mission_key,catalog_version,period_key,scope,slot,target,progress,target_json,status,nominal_xp,granted_xp,reason_code,completed_at)
    VALUES ${entries.map(() => '(?,?,?,?,?,?,?,?,?,?,?,?,?,?)').join(',')} ON DUPLICATE KEY UPDATE progress=VALUES(progress), status=VALUES(status), granted_xp=VALUES(granted_xp),reason_code=VALUES(reason_code),completed_at=COALESCE(completed_at,VALUES(completed_at))`, values);
}
export async function saveAchievements(conn: PoolConnection, userId: number, entries: Array<{key: string; progress: number; complete: boolean}>) {
  if (!entries.length) return;
  await conn.query(`INSERT INTO user_achievement_progress(user_id,achievement_key,progress,completed_at) VALUES ${entries.map(() => '(?,?,?,?)').join(',')}
    ON DUPLICATE KEY UPDATE progress=GREATEST(progress,VALUES(progress)),completed_at=COALESCE(completed_at,VALUES(completed_at))`, entries.flatMap(entry => [userId,entry.key,entry.progress,entry.complete ? new Date() : null]));
}
export async function reward(conn: PoolConnection, userId: number, entry: Reward) {
  return rewards(conn,userId,[entry]);
}
export async function rewards(conn: PoolConnection, userId: number, entries: Reward[]) {
  if (!entries.length) return;
  await conn.query(`INSERT IGNORE INTO reward_ledger (user_id,origin,period_key,cap_group,xp,nominal_xp,idempotency_key) VALUES ${entries.map(() => '(?,?,?,?,?,?,?)').join(',')}`, entries.flatMap(entry => [userId, entry.origin, entry.period, entry.capGroup, entry.xp, entry.nominalXp, entry.idempotencyKey]));
}
export async function budgetUsed(conn: PoolConnection, userId: number, period: string, group: string): Promise<number> {
  const result = await rows(conn, 'SELECT COALESCE(SUM(GREATEST(xp,0)),0) AS n FROM reward_ledger WHERE user_id=? AND period_key=? AND cap_group=?', [userId, period, group]);
  return Number(result[0].n);
}

export async function periodBudgets(conn: PoolConnection, userId: number, week: string, month: string): Promise<{weekly: number; monthly: number}> {
  const result = (await rows(conn, `SELECT
    COALESCE(SUM(CASE WHEN period_key=? AND cap_group='weekly' THEN GREATEST(xp,0) ELSE 0 END),0) AS weekly,
    COALESCE(SUM(CASE WHEN period_key=? AND cap_group='monthly' THEN GREATEST(xp,0) ELSE 0 END),0) AS monthly
    FROM reward_ledger WHERE user_id=? AND period_key IN (?,?) AND cap_group IN ('weekly','monthly')`, [week,month,userId,week,month]))[0];
  return {weekly:Number(result.weekly),monthly:Number(result.monthly)};
}

export async function collectFacts(conn: PoolConnection, userId: number, state: Row, week: Period, month: Period, options: {includeSections?: boolean} = {}) {
  const pro = state.locked_user_pro === undefined ? await refreshEntitlement(userId,conn) : await readEntitlement(userId,conn);
  if(state.locked_user_pro !== undefined && Boolean(state.locked_user_pro)!==pro) await conn.query('UPDATE users SET is_pro=? WHERE id=?',[pro?1:0,userId]);
  const counts: Record<string, number> = {};
  const local = localParts(new Date(), week.timezone, week.offset);
  const localDate = new Date(Date.UTC(local.year, local.month - 1, local.day)).toISOString().slice(0, 10);
  const monthStart = `${month.key}-01`;
  const nextMonth = new Date(Date.UTC(Number(month.key.slice(0,4)), Number(month.key.slice(5,7)), 1)).toISOString().slice(0,10);
  const queries: Record<string, string> = {
    accounts: 'SELECT COUNT(*) AS n FROM accounts WHERE user_id=? AND is_active=1',
    transactions: "SELECT COUNT(DISTINCT momentum_identity) AS n FROM transactions WHERE user_id=? AND type<>'Transfer'",
    payments: 'SELECT COUNT(*) AS n FROM payments WHERE user_id=? AND is_active=1',
    upcoming_payments: 'SELECT COUNT(*) AS n FROM payments WHERE user_id=? AND is_active=1 AND next_date BETWEEN ? AND DATE_ADD(?,INTERVAL 7 DAY)',
    overdue_payments: 'SELECT COUNT(*) AS n FROM payments WHERE user_id=? AND is_active=1 AND next_date<?',
    projects: 'SELECT COUNT(*) AS n FROM projects WHERE user_id=?',
    active_projects: "SELECT COUNT(*) AS n FROM projects WHERE user_id=? AND status='Active'",
    completed_projects: "SELECT COUNT(*) AS n FROM projects WHERE user_id=? AND status='Completed'",
    invoices: 'SELECT COUNT(*) AS n FROM invoices WHERE user_id=?',
    open_invoices: "SELECT COUNT(*) AS n FROM invoices WHERE user_id=? AND status NOT IN ('paid','void')",
    invoice_payments: 'SELECT COUNT(*) AS n FROM invoice_payments p JOIN invoices i ON i.id=p.invoice_id WHERE i.user_id=?',
    investments: 'SELECT COUNT(*) AS n FROM investments WHERE user_id=?',
    budgets: 'SELECT COUNT(*) AS n FROM expense_subcategories WHERE user_id=? AND budget>0',
    uncategorized: "SELECT COUNT(*) AS n FROM transactions WHERE user_id=? AND type<>'Transfer' AND category_id IS NULL AND NULLIF(TRIM(category),'') IS NULL",
    weekly_reviews: 'SELECT COUNT(*) AS n FROM weekly_reviews WHERE user_id=?',
    monthly_reviews: 'SELECT COUNT(*) AS n FROM monthly_reviews WHERE user_id=?',
    weekly_reviews_period: 'SELECT COUNT(*) AS n FROM weekly_reviews WHERE user_id=? AND period_key=?',
    monthly_reviews_period: 'SELECT COUNT(*) AS n FROM monthly_reviews WHERE user_id=? AND period_key=?',
  };
  // These independent aggregates share the transaction snapshot. Send one command
  // instead of paying the database network round trip for every counter.
  const countValues = Object.keys(queries).flatMap(key => key === 'upcoming_payments' ? [userId,localDate,localDate] : key === 'overdue_payments' ? [userId,localDate] : key === 'weekly_reviews_period' ? [userId,week.key] : key === 'monthly_reviews_period' ? [userId,month.key] : [userId]);
  const initial=await readBundle(conn,{
    counts:{sql:`SELECT ${Object.entries(queries).map(([key,sql])=>`(${sql}) AS ${key}`).join(',')}`,values:countValues,fields:Object.keys(queries)},
    uncategorized:{sql:"SELECT DISTINCT momentum_identity AS canonical_key FROM transactions WHERE user_id=? AND type<>'Transfer' AND category_id IS NULL AND NULLIF(TRIM(category),'') IS NULL ORDER BY canonical_key LIMIT 1000",values:[userId],fields:['canonical_key']},
    receipts:{sql:"SELECT d.image_sha256 FROM (SELECT DISTINCT image_sha256 FROM transaction_drafts WHERE user_id=? AND status='confirmed' AND image_sha256 IS NOT NULL LIMIT 250) d WHERE NOT EXISTS(SELECT 1 FROM momentum_facts f WHERE f.user_id=? AND f.metric='receipts' AND BINARY f.fact_key=BINARY d.image_sha256)",values:[userId,userId],fields:['image_sha256']},
    repair:{sql:`SELECT
      EXISTS(SELECT 1 FROM transactions t WHERE t.user_id=? AND t.type<>'Transfer' AND t.momentum_identity IS NOT NULL AND NOT EXISTS(SELECT 1 FROM momentum_entities e WHERE e.user_id=t.user_id AND e.entity_type='transaction' AND e.entity_id=t.id)) AS entities,
      EXISTS(SELECT 1 FROM transactions t JOIN momentum_entities e ON e.user_id=t.user_id AND e.entity_type='transaction' AND e.entity_id=t.id WHERE t.user_id=? AND t.type<>'Transfer' AND (t.category_id IS NOT NULL OR NULLIF(TRIM(t.category),'') IS NOT NULL) AND NOT EXISTS(SELECT 1 FROM momentum_facts f WHERE f.user_id=t.user_id AND f.metric='categorized' AND BINARY f.fact_key=BINARY e.canonical_key)) AS categorized,
      EXISTS(SELECT 1 FROM transactions t WHERE t.user_id=? AND t.type<>'Transfer' AND t.subcategory_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM momentum_facts f WHERE f.user_id=t.user_id AND f.metric='used_subcategories' AND BINARY f.fact_key=BINARY CAST(t.subcategory_id AS CHAR))) AS subcategories`,values:[userId,userId,userId],fields:['entities','categorized','subcategories']},
    metrics:{sql:'SELECT metric,SUM(value) AS n,COUNT(*) AS records FROM momentum_facts WHERE user_id=? GROUP BY metric',values:[userId],fields:['metric','n','records']},
    categorized:{sql:"SELECT fact_key FROM momentum_facts WHERE user_id=? AND metric='categorized'",values:[userId],fields:['fact_key']},
    periods:{sql:"SELECT p.*,EXISTS(SELECT 1 FROM user_missions m WHERE m.user_id=p.user_id AND m.period_key=p.period_key AND m.slot IS NOT NULL AND m.status='unavailable') AS has_unavailable FROM ((SELECT * FROM momentum_periods WHERE user_id=? AND kind='week' AND assigned_at IS NOT NULL AND period_key<=? ORDER BY starts_at DESC LIMIT 105) UNION DISTINCT (SELECT * FROM momentum_periods WHERE user_id=? AND kind='week' AND period_key<=? ORDER BY starts_at DESC LIMIT 2)) p",values:[userId,week.key,userId,week.key],fields:{...periodJsonFields,has_unavailable:'r.has_unavailable'}},
    comebacks:{sql:"SELECT fact_key FROM momentum_facts WHERE user_id=? AND metric='comebacks'",values:[userId],fields:['fact_key']},
    completed:{sql:"SELECT 1 AS n FROM user_missions WHERE user_id=? AND period_key=? AND scope='weekly' AND status='completed' LIMIT 1",values:[userId,week.key],fields:['n']},
    missions:{sql:"SELECT * FROM user_missions WHERE user_id=? AND period_key IN ('lifetime',?,?) ORDER BY assigned_at,id",values:[userId,week.key,month.key],fields:rowFields(['id','mission_key','scope','period_key','slot','target','progress','status','granted_xp','target_json','reason_code','assigned_at'],['assigned_at'])},
    achievements:{sql:'SELECT * FROM user_achievement_progress WHERE user_id=?',values:[userId],fields:rowFields(['achievement_key','progress','completed_at','seen_at'],['completed_at','seen_at'])},
    ledger:{sql:`SELECT COALESCE(SUM(xp),0) AS xp,COALESCE(SUM(CASE WHEN period_key=? AND cap_group='weekly' THEN GREATEST(xp,0) ELSE 0 END),0) AS weekly,COALESCE(SUM(CASE WHEN period_key=? AND cap_group='monthly' THEN GREATEST(xp,0) ELSE 0 END),0) AS monthly FROM reward_ledger WHERE user_id=?`,values:[week.key,month.key,userId],fields:['xp','weekly','monthly']},
    achievement_rewards:{sql:"SELECT idempotency_key FROM reward_ledger WHERE user_id=? AND (origin LIKE 'achievement:%' OR origin='week_complete')",values:[userId],fields:['idempotency_key']},
    history:{sql:"SELECT DATE_FORMAT(created_at,'%Y-%m-%d') AS period,SUM(xp) AS xp FROM reward_ledger WHERE user_id=? AND created_at>=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 30 DAY) GROUP BY DATE_FORMAT(created_at,'%Y-%m-%d')",values:[userId],fields:['period','xp']},
    credits:{sql:"SELECT COALESCE(SUM(credits),0) AS balance,MAX(expires_at) AS expires_at FROM ai_credit_ledger WHERE user_id=? AND (expires_at IS NULL OR expires_at>UTC_TIMESTAMP(3))",values:[userId],fields:rowFields(['balance','expires_at'],['expires_at'])},
    holds:{sql:"SELECT COUNT(*) AS n FROM ai_credit_reservations WHERE user_id=? AND uses_credit=1 AND status='pending' AND expires_at>UTC_TIMESTAMP(3)",values:[userId],fields:['n']},
    organizer:{sql:"SELECT 1 AS n FROM ai_credit_ledger WHERE user_id=? AND idempotency_key='organizer:v1' LIMIT 1",values:[userId],fields:['n']},
    state:{sql:'SELECT * FROM user_momentum WHERE user_id=?',values:[userId],fields:rowFields(['lifetime_xp','rhythm','backfilled_at','backfill_seen_at','coachmark_seen_at','preferred_timezone_name','preferred_timezone_offset_min','notifications_enabled','quiet_start','quiet_end','locale'],['backfilled_at','backfill_seen_at','coachmark_seen_at'])},
  });
  const counted=initial.counts[0];
  for(const key of Object.keys(queries))counts[key]=Number(counted[key]);
  const repair=initial.repair[0], receipts=initial.receipts;
  if(repair.entities) await conn.query(`INSERT IGNORE INTO momentum_entities(user_id,entity_type,entity_id,canonical_key)
    SELECT user_id,'transaction',id,momentum_identity FROM transactions WHERE user_id=? AND type<>'Transfer' AND momentum_identity IS NOT NULL`,[userId]);
  const factSelects:string[]=[],factValues:unknown[]=[];
  // Table columns and CAST/parameter expressions can inherit different collations.
  // Normalize identity keys before UNION resolves its result type; INSERT's target
  // collation is applied too late to prevent ER_CANT_AGGREGATE_NCOLLATIONS.
  if(repair.entities || repair.categorized) {
    factSelects.push(`SELECT t.user_id,'categorized',CAST(e.canonical_key AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_bin,1,? FROM transactions t JOIN momentum_entities e ON e.user_id=t.user_id AND e.entity_type='transaction' AND e.entity_id=t.id WHERE t.user_id=? AND t.type<>'Transfer' AND (t.category_id IS NOT NULL OR NULLIF(TRIM(t.category),'') IS NOT NULL)`);
    factValues.push(state.backfilled_at?'reconciliation':'backfill',userId);
  }
  if(repair.subcategories) {
    factSelects.push("SELECT user_id,'used_subcategories',CAST(subcategory_id AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_bin,1,'verified_data' FROM transactions WHERE user_id=? AND subcategory_id IS NOT NULL AND type<>'Transfer'");factValues.push(userId);
  }
  // Receipt sources were read without locks, exactly like the former bounded VALUES batch.
  for(const receipt of receipts) {factSelects.push("SELECT ?,'receipts',CAST(? AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_bin,1,'verified_data'");factValues.push(userId,String(receipt.image_sha256));}
  if(factSelects.length) await conn.query(`INSERT IGNORE INTO momentum_facts(user_id,metric,fact_key,value,provenance) ${factSelects.join(' UNION ALL ')}`,factValues);
  const changed=repair.entities || factSelects.length;
  const metrics=changed ? await readBundle(conn,{
    metrics:{sql:'SELECT metric,SUM(value) AS n,COUNT(*) AS records FROM momentum_facts WHERE user_id=? GROUP BY metric',values:[userId],fields:['metric','n','records']},
    categorized:{sql:"SELECT fact_key FROM momentum_facts WHERE user_id=? AND metric='categorized'",values:[userId],fields:['fact_key']},
  }) : initial;
  for(const metric of metrics.metrics)counts[String(metric.metric)]=Number(metric.n);
  counts.comebacks=Number(metrics.metrics.find(metric=>metric.metric==='comebacks')?.records??0);
  counts.weekly_reviews=Number(counted.weekly_reviews);counts.monthly_reviews=Number(counted.monthly_reviews);
  counts[`weekly_reviews_period:${week.key}`]=Number(counted.weekly_reviews_period);counts[`monthly_reviews_period:${month.key}`]=Number(counted.monthly_reviews_period);
  counts.ai_access=pro || ((enabled('MOMENTUM_AI_REWARDS_ENABLED') || enabled('MOMENTUM_AI_CREDITS_ENABLED')) && Number(initial.credits[0].balance)>0)?1:0;
  const categorized=new Set(metrics.categorized.map(row=>String(row.fact_key)));
  const uncategorized=initial.uncategorized.map(row=>String(row.canonical_key)).sort();
  const previous=initial.periods.filter(row=>String(row.period_key)<week.key).sort((a,b)=>String(b.period_key).localeCompare(String(a.period_key)))[0];
  const hasMissedWeek=!!previous?.assigned_at && !previous?.completed_at && week.start.getTime()-new Date(previous.ends_at as string).getTime()<86400000;
  if(hasMissedWeek && initial.completed.length)counts[`comeback_week:${week.key}`]=1;
  const lastSignificant = state.last_significant_at ? new Date(state.last_significant_at as string) : null;
  const episode = lastSignificant && Date.now() - lastSignificant.getTime() >= 14 * 86_400_000 ? lastSignificant.toISOString() : null;
  const facts: Facts = { counts, categorized, uncategorized: [...new Set(uncategorized)], pro, lastSignificant, hasMissedWeek, comebackEpisode: episode, capabilities: { core: true, projects: true, invoices: true, investments: true, budgets: true, receipt: enabled('RECEIPT_SCANNING_ENABLED') && !!process.env.OPENAI_API_KEY, ai: !!process.env.OPENAI_API_KEY, report: true, project_milestones: false } };
  // Evaluation never serializes financial sections. Explicit review contexts
  // retain the default and still read fresh evidence inside their transaction.
  if (options.includeSections === false) return {facts,sections:[] as Section[],initial};
  const accounts = await rows(conn, 'SELECT name,type,balance FROM accounts WHERE user_id=? AND is_active=1 ORDER BY id LIMIT 100', [userId]);
  const activity = await rows(conn, "SELECT date,description,type,amount,category FROM transactions WHERE user_id=? AND type<>'Transfer' ORDER BY date DESC,id DESC LIMIT 20", [userId]);
  const net = await rows(conn, `SELECT COALESCE(SUM(CASE WHEN type='Income' THEN ABS(amount) ELSE 0 END),0) AS income,COALESCE(SUM(CASE WHEN type='Expense' THEN ABS(amount) ELSE 0 END),0) AS expenses,COALESCE(SUM(CASE WHEN type='Income' THEN ABS(amount) WHEN type='Expense' THEN -ABS(amount) ELSE 0 END),0) AS net FROM transactions WHERE user_id=? AND date>=? AND date<?`, [userId, monthStart, nextMonth]);
  const obligations = await rows(conn, 'SELECT name,amount,frequency,next_date FROM payments WHERE user_id=? AND is_active=1 ORDER BY next_date LIMIT 100', [userId]);
  const categories = await rows(conn, "SELECT COALESCE(c.name,t.category,'Uncategorized') AS category,COUNT(*) AS records, SUM(ABS(t.amount)) AS amount FROM transactions t LEFT JOIN expense_categories c ON c.id=t.category_id AND c.user_id=t.user_id WHERE t.user_id=? AND t.type='Expense' AND t.date>=? AND t.date<? GROUP BY COALESCE(c.name,t.category,'Uncategorized') ORDER BY records DESC LIMIT 100", [userId, monthStart, nextMonth]);
  const sections: Section[] = [
    { key: 'accounts', title: { en: 'Accounts', es: 'Cuentas' }, applicable: counts.accounts > 0, data: accounts },
    { key: 'recent_activity', title: { en: 'Recent activity', es: 'Actividad reciente' }, applicable: counts.transactions > 0, data: activity },
    { key: 'net', title: { en: 'Income, expenses and net', es: 'Ingresos, gastos y neto' }, applicable: counts.transactions > 0, data: net },
    { key: 'categories', title: { en: 'Categories', es: 'Categorías' }, applicable: categories.length > 0, data: categories },
    { key: 'obligations', title: { en: 'Obligations', es: 'Compromisos' }, applicable: counts.payments > 0, data: obligations },
  ];
  if (pro) {
    for (const [key, table, fields, title] of [
      ['projects','projects','name,status,start_date,end_date', { en:'Projects',es:'Proyectos' }],
      ['invoices','invoices','number,status,due_date,amount_due,currency', { en:'Invoices',es:'Facturas' }],
      ['investments','investments','name,principal,annual_rate,start_date',{en:'Investments',es:'Inversiones'}],
      ['budgets','expense_subcategories','name,budget',{en:'Budgets',es:'Presupuestos'}],
    ] as const) {
      const data = await rows(conn, `SELECT ${fields} FROM ${table} WHERE user_id=? ${key === 'budgets' ? 'AND budget>0' : ''} ORDER BY id LIMIT 100`, [userId]);
      sections.push({ key, title, applicable: data.length > 0, data });
    }
  }
  return { facts, sections, initial };
}
