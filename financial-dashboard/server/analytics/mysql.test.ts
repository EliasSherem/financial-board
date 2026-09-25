import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { ResultSetHeader,RowDataPacket } from 'mysql2/promise';
import { db } from '../db.js';
import { ingestEvents,recordDomainAnalytics,recordBillingAnalytics,recordSignup } from './repository.js';
import type { AnalyticsInput } from './validation.js';
test('MySQL analytics: dedup, platform ownership, trusted significant activity, provider isolation, opt-out',{skip:process.env.RUN_DB_TESTS!=='true'},async()=>{
  assert.equal(process.env.NODE_ENV,'test');assert.ok(['127.0.0.1','localhost'].includes(process.env.MYSQL_HOST??''));assert.match(process.env.MYSQL_DATABASE??'',/test/);assert.ok(!process.env.MYSQL_URL);
  const ids:number[]=[],prefix='analytics_'+randomUUID().slice(0,8);process.env.ADMIN_ANALYTICS_ENABLED='true';
  const create=async(suffix:string)=>{const [r]=await db.query<ResultSetHeader>('INSERT INTO users(username,password) VALUES (?,?)',[prefix+suffix,'not-a-real-password']);ids.push(r.insertId);return r.insertId;};
  try{
    const user=await create('_a'),other=await create('_b');await recordSignup(user,'web');await recordSignup(other,undefined);
    const event:AnalyticsInput={event_id:randomUUID(),schema_version:1,event_type:'screen_view',session_id:randomUUID(),client_platform:'web',client_occurred_at:new Date(Date.now()-60000).toISOString(),source_screen:'dashboard'};
    assert.equal(await ingestEvents(user,[event]),1);assert.equal(await ingestEvents(user,[event]),0);
    assert.equal(await ingestEvents(other,[{...event,event_id:randomUUID()}]),0);
    assert.equal(await ingestEvents(user,[{...event,event_id:randomUUID(),client_platform:'android'}]),0);
    const domain=randomUUID();await recordDomainAnalytics({userId:user,eventId:domain,eventType:'transaction.created'});await recordDomainAnalytics({userId:user,eventId:domain,eventType:'transaction.created'});
    const billing=randomUUID();const conn=await db.getConnection();try{await conn.beginTransaction();await recordBillingAnalytics({userId:user,eventId:billing,eventType:'purchase_verified',provider:'google',status:'active',flowId:randomUUID()},conn);await conn.commit();}finally{conn.release();}
    const [counts]=await db.query<RowDataPacket[]>('SELECT COUNT(*) AS total,SUM(significant) AS meaningful FROM analytics_events WHERE user_id=?',[user]);assert.equal(Number(counts[0].total),3);assert.equal(Number(counts[0].meaningful),1);
    const [provider]=await db.query<RowDataPacket[]>('SELECT client_platform,significant,session_id FROM analytics_events WHERE event_id=?',[billing]);assert.equal(provider[0].client_platform,'unknown');assert.equal(provider[0].significant,0);assert.equal(provider[0].session_id,null);
    const [sessions]=await db.query<RowDataPacket[]>('SELECT client_platform,last_seen_at FROM analytics_sessions WHERE user_id=?',[user]);assert.equal(sessions.length,1);assert.equal(sessions[0].client_platform,'web');assert.equal(new Date(sessions[0].last_seen_at).getTime(),Date.parse(event.client_occurred_at));
    const [settings]=await db.query<RowDataPacket[]>('SELECT signup_platform FROM analytics_user_settings WHERE user_id=?',[other]);assert.equal(settings[0].signup_platform,null);
    await db.query('UPDATE analytics_user_settings SET enabled=FALSE WHERE user_id=?',[user]);assert.equal(await ingestEvents(user,[{...event,event_id:randomUUID()}]),0);await recordDomainAnalytics({userId:user,eventType:'review.completed'});const [after]=await db.query<RowDataPacket[]>('SELECT COUNT(*) AS total FROM analytics_events WHERE user_id=?',[user]);assert.equal(Number(after[0].total),3);
  }finally{if(ids.length)await db.query('DELETE FROM users WHERE id IN (?)',[ids]);await db.end();}
});
