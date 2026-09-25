import { db } from '../db.js';
import { enabled } from '../platform/http.js';
import { localParts, withinPeriod } from '../platform/periods.js';
import { recordDomainAnalytics } from '../analytics/repository.js';
import { evaluate, evaluateWithContext } from './service.js';
import { fact, json, locked, rows, type Row } from './repository.js';

export async function processDomainEvent(eventId:number) {
  const [items]=await db.query('SELECT user_id FROM engagement_events WHERE id=?',[eventId]);
  const item=(items as Row[])[0];if(!item)return;
  const userId=Number(item.user_id);
  await locked(userId,async(conn,state)=>{
    const event=(await rows(conn,"SELECT * FROM engagement_events WHERE id=? AND status IN ('pending','retry') AND next_attempt_at<=UTC_TIMESTAMP(3) FOR UPDATE",[eventId]))[0];
    if(!event)return;
    const type=String(event.event_type),payload=json<Record<string,unknown>>(event.payload_json,{}),occurred=new Date(event.occurred_at as string);
    const significant=/^(accounts|transactions|expense_categories|expense_subcategories|payments|projects|invoices|invoice_payments|investments|investment_contributions)\.(insert|update)$/.test(type) || type==='ai.response' || type==='review.completed' || (type==='transaction_drafts.update' && payload.status==='confirmed');
    if(enabled('MOMENTUM_ENABLED')) {
      // Assign from verified current data before the first returned activity closes a comeback episode.
      const {context:ctx}=await evaluateWithContext(conn,userId,state);
      if(withinPeriod(occurred,ctx.week)) {
        if(type==='ai.response') await fact(conn,userId,`period_ai_responses:${ctx.week.key}`,String(event.event_id),'verified_provider');
        if(type==='transaction_drafts.update' && payload.status==='confirmed' && typeof payload.image_hash==='string') await fact(conn,userId,`period_receipts:${ctx.week.key}`,payload.image_hash,'verified_data');
        if(type==='invoice_payments.insert') await fact(conn,userId,'invoice_reviews',ctx.week.key,'verified_data');
        if(type==='projects.update') await fact(conn,userId,`project_updates:${ctx.week.key}`,String(payload.entity_id),'verified_data');
        if(type==='payments.update') {
          const p=localParts(occurred,ctx.week.timezone,ctx.week.offset),today=`${p.year}-${String(p.month).padStart(2,'0')}-${String(p.day).padStart(2,'0')}`;
          const previous=String(payload.previous_date??'').slice(0,10),next=String(payload.next_date??'').slice(0,10);
          if(previous && previous<today && (next>=today || payload.active===false || payload.active===0)) await fact(conn,userId,`overdue_resolved:${ctx.week.key}`,String(payload.entity_id),'verified_data');
        }
      }
      await evaluate(conn,userId,state);
    }
    if(significant) {
      await recordDomainAnalytics({eventId:String(event.event_id),userId,eventType:type,platform:'unknown',occurredAt:occurred});
      await conn.query('UPDATE user_momentum SET last_significant_at=GREATEST(COALESCE(last_significant_at,?),?) WHERE user_id=?',[occurred,occurred,userId]);
    }
    await conn.query("UPDATE engagement_events SET status='processed',processed_at=UTC_TIMESTAMP(3),last_error_code=NULL WHERE id=?",[eventId]);
  });
}
export async function runMomentumBatch(maximum=30) {
  const [events]=await db.query("SELECT id FROM engagement_events WHERE status IN ('pending','retry') AND next_attempt_at<=UTC_TIMESTAMP(3) ORDER BY id LIMIT ?",[maximum]);
  for(const row of events as Row[]) {
    try {await processDomainEvent(Number(row.id));}
    catch {await db.query("UPDATE engagement_events SET attempts=attempts+1,status=IF(attempts>=10,'failed','retry'),next_attempt_at=TIMESTAMPADD(SECOND,LEAST(3600,POW(2,LEAST(attempts,10))*15),UTC_TIMESTAMP(3)),last_error_code='EVALUATION_FAILED' WHERE id=? AND status<>'processed'",[row.id]);}
  }
}
export async function reconcileMomentumBatch() {
  if(!enabled('MOMENTUM_ENABLED'))return;
  const [settings]=await db.query("SELECT value_json FROM platform_settings WHERE setting_key='momentum_reconcile_cursor'");
  const cursor=Number(json<Record<string,unknown>>((settings as Row[])[0]?.value_json,{}).id??0);
  const [users]=await db.query('SELECT id FROM users WHERE id>? ORDER BY id LIMIT 50',[cursor]);
  let last=0;
  for(const user of users as Row[]) {
    last=Number(user.id);
    try {await locked(last,(conn,state)=>evaluate(conn,last,state));}
    catch {console.error('momentum_reconciliation_failed',{user_id:last,code:'EVALUATION_FAILED'});}
  }
  await db.query("INSERT INTO platform_settings(setting_key,value_json) VALUES ('momentum_reconcile_cursor',JSON_OBJECT('id',?)) ON DUPLICATE KEY UPDATE value_json=VALUES(value_json)",[last]);
}
export async function cleanupMomentum() {
  await db.query("DELETE FROM momentum_review_snapshots WHERE expires_at<DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 1 DAY)");
  await db.query("DELETE FROM engagement_events WHERE status='processed' AND processed_at<DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 30 DAY)");
  await db.query("DELETE FROM platform_rate_limits WHERE window_start<DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 2 DAY)");
  await db.query("UPDATE ai_credit_reservations SET status='failed',completed_at=UTC_TIMESTAMP(3) WHERE status='pending' AND expires_at<=UTC_TIMESTAMP(3)");
  // Responses are private retry caches. Keep the UUID tombstone to prevent a paid call replay.
  await db.query("UPDATE ai_credit_reservations SET response_json=NULL WHERE completed_at<DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 1 DAY) AND response_json IS NOT NULL");
}
export function startMomentumWorker() {
  if(!enabled('MOMENTUM_WORKER_ENABLED'))return ()=>{};
  let busy=false,lastReconcile=0;
  const tick=async()=>{if(busy)return;busy=true;try {await runMomentumBatch();if(Date.now()-lastReconcile>300000){await reconcileMomentumBatch();await cleanupMomentum();lastReconcile=Date.now();}}catch{console.error('momentum_worker_failed');}finally{busy=false;}};
  void tick();const timer=setInterval(()=>void tick(),15000);timer.unref();return ()=>clearInterval(timer);
}
