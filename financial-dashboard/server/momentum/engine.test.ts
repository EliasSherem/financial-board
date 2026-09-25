import test from 'node:test';
import assert from 'node:assert/strict';
import { ACHIEVEMENTS, MISSIONS, levelFor } from './catalog.js';
import { achievementProgress, cappedXp, completedWeek, evaluateMissions, mayApplyGrace } from './engine.js';
import { assignedMission, generateWeekly } from './missionGenerator.js';
import { periodAt, withinPeriod } from '../platform/periods.js';
import type { Facts } from './types.js';
const facts=():Facts=>({counts:{ai_access:1,accounts:1,transactions:10,payments:1,projects:1,active_projects:1,invoices:1,open_invoices:1,investments:1,budgets:1,upcoming_payments:1,overdue_payments:1},uncategorized:['a','b','c','d','e'],categorized:new Set(),pro:true,lastSignificant:new Date('2026-08-01'),hasMissedWeek:true,comebackEpisode:'2026-08-01',capabilities:{core:true,projects:true,invoices:true,investments:true,budgets:true,receipt:true,ai:true,report:true,project_milestones:false}});
test('catalog has 41 unique missions, 34 badges, six activations250 and clear_view50',()=>{
 assert.equal(MISSIONS.length,41);assert.equal(new Set(MISSIONS.map(m=>m.key)).size,41);assert.equal(ACHIEVEMENTS.length,34);
 assert.equal(MISSIONS.filter(m=>m.scope==='activation').reduce((n,m)=>n+m.xp,0),250);assert.equal(ACHIEVEMENTS.find(a=>a.key==='clear_view')?.xp,50);
 for(const d of [...MISSIONS,...ACHIEVEMENTS])for(const language of ['es','en'] as const){assert.ok(d.title[language]);assert.ok(d.requirement[language]);}
});
test('every mission rule reaches its target from verified facts and does not reward twice',()=>{
 for(const def of MISSIONS){const f=facts();f.counts.uncategorized=0;f.counts[def.metric]=def.target;f.counts[`${def.metric}:2026-W39`]=def.target;f.categorized=new Set(f.uncategorized);
 const mission=assignedMission(def,'2026-W39',f);const result=evaluateMissions([mission],f,{weekly:0,monthly:0});
 assert.equal(result.missions[0].status,'completed',def.key);assert.equal(result.rewards.length,1,def.key);assert.equal(evaluateMissions(result.missions,f,{weekly:def.xp,monthly:def.xp}).rewards.length,0,def.key);}
});
test('34 badge thresholds are finite; spending cannot enable unsupported project milestones',()=>{
 const f=facts();for(const badge of ACHIEVEMENTS)f.counts[badge.metric]=badge.target;
 const results=achievementProgress(f,6);assert.equal(results.length,34);assert.equal(results.filter(r=>r.complete).length,31);
 assert.deepEqual(results.filter(r=>!r.complete).map(r=>r.key),['goal_builder_1','goal_builder_2','goal_builder_3']);
});
test('level boundaries are stable',()=>{assert.deepEqual([249,250,749,750,1499,1500].map(x=>levelFor(x).key),['explorer','organizer','organizer','planner','planner','strategist']);});
test('weekly and monthly caps grant only remaining XP including zero, completion survives cap',()=>{
 assert.equal(cappedXp(50,95,100),5);assert.equal(cappedXp(75,75,75),0);
 const f=facts();const defs=MISSIONS.filter(m=>m.scope==='monthly');for(const d of defs)f.counts[`${d.metric}:2026-09`]=1;f.counts.uncategorized=0;
 const result=evaluateMissions(defs.map(d=>assignedMission(d,'2026-09',f)),f,{weekly:100,monthly:70});assert.equal(result.rewards.reduce((n,r)=>n+r.xp,0),5);assert.equal(result.missions.filter(m=>m.status==='completed').length,defs.length);
});
test('Free receives3 feasible required missions; Pro expiry replaces only impossible goal',()=>{
 const f=facts();f.pro=false;const first=generateWeekly([],'2026-W39',f).missions;assert.equal(first.length,3);assert.ok(first.every(m=>!MISSIONS.find(d=>d.key===m.key)!.pro));
 f.pro=true;const pro=generateWeekly([],'2026-W39',f).missions;pro[0].status='completed';f.pro=false;
 const changed=generateWeekly(pro,'2026-W39',f);assert.equal(changed.missions[0].status,'completed');assert.equal(changed.replacements.length,1);assert.equal(changed.missions.filter(m=>m.status!=='replaced').length,3);
 assert.deepEqual(generateWeekly(changed.missions,'2026-W39',f).missions,changed.missions);
 assert.equal(completedWeek(changed.missions),false);
});
test('no required week before real data; captured categorization cannot farm recategorization',()=>{
 const f=facts();f.counts.accounts=0;assert.equal(generateWeekly([],'2026-W39',f).missions.length,0);
 f.counts.accounts=1;const d=MISSIONS.find(d=>d.key==='weekly_categorize')!,mission=assignedMission(d,'2026-W39',f);f.categorized=new Set(['a']);
 let result=evaluateMissions([mission],f,{weekly:0,monthly:0});assert.equal(result.missions[0].progress,1);f.categorized=new Set();result=evaluateMissions(result.missions,f,{weekly:0,monthly:0});f.categorized=new Set(['a']);result=evaluateMissions(result.missions,f,{weekly:0,monthly:0});assert.equal(result.missions[0].progress,1);assert.equal(result.rewards.length,0);
});
test('grace once per rolling8weeks without a reward or review',()=>{const lost=new Date('2026-09-21T00:00:00Z');assert.equal(mayApplyGrace(lost,[]),true);assert.equal(mayApplyGrace(lost,[lost]),false);assert.equal(mayApplyGrace(lost,[new Date('2026-08-03T00:00:00Z')]),false);assert.equal(mayApplyGrace(lost,[new Date('2026-07-27T00:00:00Z')]),true);assert.equal(mayApplyGrace(lost,[],false),false);});
test('IANA DST and ISO year boundaries; offline period guard',()=>{
 const spring=periodAt(new Date('2026-03-08T15:00:00Z'),'week','America/New_York');assert.equal((spring.end.getTime()-spring.start.getTime())/3600000,167);
 const fall=periodAt(new Date('2026-11-01T15:00:00Z'),'week','America/New_York');assert.equal((fall.end.getTime()-fall.start.getTime())/3600000,169);
 assert.equal(periodAt(new Date('2027-01-01T12:00:00Z'),'week','UTC').key,'2026-W53');
 assert.equal(withinPeriod(new Date('2026-03-08T15:00:00Z'),spring,new Date('2026-03-09T12:00:00Z')),false);
 assert.equal(periodAt(new Date('2026-09-24T23:00:00Z'),'month','invalid',120).timezone,'offset');
});

test('grace uses civil weeks through autumn DST, not49times24hours',()=>{assert.equal(mayApplyGrace(new Date('2026-11-02T05:00:00Z'),[new Date('2026-09-14T04:00:00Z')],true,8,'America/New_York'),false);});
