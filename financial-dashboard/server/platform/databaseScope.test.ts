import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import type {Pool} from 'mysql2/promise';
import type {Request,Response} from 'express';
import {createScopedDatabase} from './databaseScope.js';
function fixture(){const log:string[]=[],connections:Array<{id:number}>=[];let next=0;const pool={query:async(sql:string)=>{log.push(`pool:${sql}`);return [[],[]];},getConnection:async()=>{const id=++next;connections.push({id});return {query:async(sql:string)=>{log.push(`${id}:${sql}`);return [[],[]];},execute:async(sql:string)=>{log.push(`${id}:${sql}`);return [[],[]];},beginTransaction:async()=>{log.push(`${id}:begin`);},commit:async()=>{log.push(`${id}:commit`);},rollback:async()=>{log.push(`${id}:rollback`);},release:()=>{log.push(`${id}:release`);}};}};return {scope:createScopedDatabase(pool as unknown as Pool),log,connections};}
test('concurrent scoped transactions route helpers to their own reserved connection',async()=>{
 const {scope,log}=fixture();let arrived=0;let release!:()=>void;const barrier=new Promise<void>(resolve=>release=resolve);
 const request=(label:string)=>new Promise<void>((resolve,reject)=>{const response=new EventEmitter();scope.middleware({} as Request,response as Response,()=>{void(async()=>{await scope.database.query('START TRANSACTION');await scope.database.query(`base:${label}`);if(++arrived===2)release();await barrier;await scope.database.execute(`helper:${label}`);await scope.database.query('COMMIT');response.emit('finish');resolve();})().catch(reject);});});
 await Promise.all([request('a'),request('b')]);assert.equal(log.filter(s=>s.endsWith(':commit')).length,2);assert.equal(log.some(s=>s.startsWith('pool:')),false);for(const label of ['a','b']){const base=log.find(s=>s.endsWith(`base:${label}`))!;assert.ok(log.includes(`${base.split(':')[0]}:helper:${label}`));}
});
test('exception rolls back all helpers and releases once; nested transaction joins outer',async()=>{
 const {scope,log}=fixture();await assert.rejects(scope.transaction(async()=>{await scope.database.query('base');await scope.transaction(async()=>{await scope.database.execute('outbox');});throw new Error('failure');}));assert.deepEqual(log,['1:begin','1:base','1:outbox','1:rollback','1:release']);
});
test('aborted legacy request rolls back and cannot continue autocommitting on pool',async()=>{
 const {scope,log}=fixture();await new Promise<void>((resolve,reject)=>{const response=new EventEmitter();scope.middleware({}as Request,response as Response,()=>{void(async()=>{await scope.database.query('START TRANSACTION');await scope.database.query('base');response.emit('close');await assert.rejects(scope.database.query('partial-after-close'),/closed/);await new Promise(r=>setImmediate(r));resolve();})().catch(reject);});});assert.deepEqual(log,['1:begin','1:base','1:rollback','1:release']);
});
test('parallel BEGIN in one request cannot allocate or leak a second connection',async()=>{
 const {scope,log,connections}=fixture();await new Promise<void>((resolve,reject)=>{const response=new EventEmitter();scope.middleware({}as Request,response as Response,()=>{void(async()=>{const starts=await Promise.allSettled([scope.database.query('START TRANSACTION'),scope.database.query('START TRANSACTION')]);assert.equal(starts.filter(s=>s.status==='fulfilled').length,1);await scope.database.query('ROLLBACK');response.emit('finish');resolve();})().catch(reject);});});assert.equal(connections.length,1);assert.deepEqual(log,['1:begin','1:rollback','1:release']);
});
