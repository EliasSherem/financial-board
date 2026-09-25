import test from 'node:test';
import assert from 'node:assert/strict';
import type {PoolConnection} from 'mysql2/promise';
import {readBundle,rowFields} from './readBundle.js';
import {missionRows} from './repository.js';

test('bundled reads retain bound tenant values, JSON nulls and millisecond UTC dates',async()=>{
  const commands:Array<{sql:string;values:unknown[]}>=[];
  const conn={query:async(sql:string,values:unknown[])=>{
    commands.push({sql,values});
    return [[{receipts:'[{"image_sha256":"abc","completed_at":"2020-01-02T03:04:05.123Z","seen_at":null}]',empty:[]}],[]];
  }} as unknown as PoolConnection;
  const result=await readBundle(conn,{
    receipts:{sql:'SELECT image_sha256,completed_at,seen_at FROM fixture WHERE user_id=?',values:[17],fields:rowFields(['image_sha256','completed_at','seen_at'],['completed_at','seen_at'])},
    empty:{sql:'SELECT id FROM fixture WHERE user_id=? AND id=?',values:[18,9],fields:['id']},
  });
  assert.equal(commands.length,1);assert.deepEqual(commands[0].values,[17,18,9]);
  assert.equal((commands[0].sql.match(/\?/g)??[]).length,3);
  assert.doesNotMatch(commands[0].sql,/;|user_id=17/);
  assert.match(commands[0].sql,/%Y-%m-%dT%H:%i:%s\./);
  assert.deepEqual(result.receipts,[{image_sha256:'abc',completed_at:'2020-01-02T03:04:05.123Z',seen_at:null}]);
  assert.deepEqual(result.empty,[]);
});

test('mission order is explicit after unordered JSON transport, preserving cap award priority',()=>{
  const row=(id:number,date:string,key:string)=>({id,assigned_at:date,mission_key:key,scope:'weekly',period_key:'2026-W39',slot:null,target:1,progress:0,status:'active',granted_xp:0,target_json:[],reason_code:null});
  const input=[row(3,'2026-09-23T00:00:00.000Z','third'),row(2,'2026-09-22T00:00:00.000Z','second'),row(1,'2026-09-22T00:00:00.000Z','first')];
  assert.deepEqual(missionRows(input).map(m=>m.key),['first','second','third']);
  assert.equal(input[0].id,3,'Transported snapshot is not sorted in place');
});

test('bundled result corruption fails rather than returning fictional empty progress',async()=>{
  const conn={query:async()=>[[{items:'{}'}],[]]} as unknown as PoolConnection;
  await assert.rejects(readBundle(conn,{items:{sql:'SELECT id FROM fixture',values:[],fields:['id']}}),/Invalid internal read result/);
});
