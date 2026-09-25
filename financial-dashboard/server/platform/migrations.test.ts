import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import mysql from 'mysql2/promise';
import {assertPlatformSchema} from './startup.js';
import fs from 'node:fs/promises';
const exec=promisify(execFile),run=process.env.RUN_DB_TESTS==='true';
test('SQL: all migrations install into an empty database and repeat without schema or data changes',{skip:!run},async()=>{
 assert.equal(process.env.NODE_ENV,'test');assert.equal(process.env.MYSQL_HOST,'127.0.0.1');assert.equal(process.env.MYSQL_URL,undefined);
 const name=`finsight_schema_${randomUUID().slice(0,8)}_test`;
 const conn=await mysql.createConnection({host:'127.0.0.1',port:Number(process.env.MYSQL_PORT),user:process.env.MYSQL_USER,password:process.env.MYSQL_PASSWORD,timezone:'Z'});
 try {
 await conn.query(`CREATE DATABASE \`${name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
 const env={...process.env,MYSQL_DATABASE:name};
 const first=await exec(process.execPath,['--import','tsx','scripts/migrate.ts','--apply'],{env,maxBuffer:2*1024*1024});assert.match(first.stdout,/010_notification_delivery.sql: complete/);
 const [migrations]:any=await conn.query(`SELECT COUNT(*) n FROM \`${name}\`.platform_migrations WHERE completed_at IS NOT NULL`);assert.equal(Number(migrations[0].n),11);
 const [triggers]:any=await conn.query('SELECT COUNT(*) n FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=?',[name]);assert.equal(Number(triggers[0].n),32);
 const [users]:any=await conn.query(`SELECT COUNT(*) n FROM \`${name}\`.users`);assert.equal(Number(users[0].n),0);
 const second=await exec(process.execPath,['--import','tsx','scripts/migrate.ts','--apply'],{env,maxBuffer:2*1024*1024});assert.match(second.stdout,/010_notification_delivery.sql: complete/);
 const [again]:any=await conn.query(`SELECT COUNT(*) n FROM \`${name}\`.users`);assert.equal(Number(again[0].n),0);
 await conn.query(`USE \`${name}\``);await assertPlatformSchema(conn,{NODE_ENV:'test'});
 } finally {await conn.query(`DROP DATABASE IF EXISTS \`${name}\``);await conn.end();}
});

test('SQL: upgrading legacy transactions preserves financial values, edit timestamps and activity history',{skip:!run},async()=>{
 assert.equal(process.env.NODE_ENV,'test');assert.equal(process.env.MYSQL_HOST,'127.0.0.1');assert.equal(process.env.MYSQL_URL,undefined);
 const name=`finsight_legacy_${randomUUID().slice(0,8)}_test`;
 const conn=await mysql.createConnection({host:'127.0.0.1',port:Number(process.env.MYSQL_PORT),user:process.env.MYSQL_USER,password:process.env.MYSQL_PASSWORD,timezone:'Z'});
 const migrations=new URL('../../../database/migrations/',import.meta.url);
 const apply=async(file:string)=>{
  const sql=await fs.readFile(new URL(file,migrations),'utf8');
  for(const statement of sql.replace(/^--.*$/gm,'').split(/;\s*(?:\n|$)/).map(s=>s.trim()).filter(Boolean))await conn.query(statement);
 };
 try {
  await conn.query(`CREATE DATABASE \`${name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  await conn.query(`USE \`${name}\``);await conn.query("SET time_zone='+00:00'");
  await apply('000_legacy_baseline.sql');
  await conn.query("INSERT INTO users(id,username,password,email) VALUES (9000,'legacy_migration_fixture','unusable','migration@example.invalid')");
  await conn.query("INSERT INTO accounts(id,user_id,name,type,balance) VALUES (9000,9000,'Historical account','Checking',87.50)");
  await conn.query("INSERT INTO transactions(id,user_id,account_id,date,description,amount,type,category,created_at,updated_at) VALUES (9000,9000,9000,'2020-01-15','Existing expense',-12.50,'Expense','Existing category','2020-01-15 10:00:00','2020-01-17 12:00:00')");
  const columns='id,user_id,account_id,date,description,amount,type,category,created_at,updated_at';
  const [before]=await conn.query(`SELECT ${columns} FROM transactions`);
  const files=(await fs.readdir(migrations)).filter(file=>/^\d+.*\.sql$/.test(file)&&!file.startsWith('000')).sort();
  for(const file of files)await apply(file);
  const [after]=await conn.query(`SELECT ${columns} FROM transactions`);assert.deepEqual(after,before);
  const [identity]:any=await conn.query('SELECT momentum_identity FROM transactions');assert.match(identity[0].momentum_identity,/^[a-f0-9]{64}$/);
  const [balance]:any=await conn.query('SELECT balance FROM accounts WHERE id=9000');assert.equal(balance[0].balance,'87.50');
  const [events]:any=await conn.query('SELECT COUNT(*) n FROM engagement_events');assert.equal(Number(events[0].n),0);
 } finally {await conn.query(`DROP DATABASE IF EXISTS \`${name}\``);await conn.end();}
});
