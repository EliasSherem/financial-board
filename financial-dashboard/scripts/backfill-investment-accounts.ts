/** Explicit legacy data repair; never imported by API boot and never loads .env. */
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import mysql, { type Connection, type RowDataPacket, type ResultSetHeader } from 'mysql2/promise';

type Issue='orphan_investment_account'|'contribution_owner_mismatch'|'account_name_too_long'|'balance_out_of_range';
type Candidate={investment_id:number;user_id:number;name:string;principal:string;updated_at:Date|string;expected_balance:string;contribution_count:number;issues:Issue[]};
export type BackfillPlan={digest:string;candidates:Candidate[];blocked:number;already_linked:number;invalid_links:number};
export type BackfillOptions={apply?:boolean;expectedPlan?:string;userId?:number;maintenance?:boolean};
export function exactCents(value:string):bigint {
  const match=/^(-?)(\d+)(?:\.(\d{1,2}))?$/.exec(value);
  if(!match)throw new Error('INVALID_DECIMAL');
  return (match[1]? -1n:1n)*(BigInt(match[2])*100n+BigInt((match[3]??'').padEnd(2,'0')));
}
export function assertLocalTarget(env:NodeJS.ProcessEnv){
  if(env.NODE_ENV==='production'||!['localhost','127.0.0.1','::1'].includes(env.MYSQL_HOST??'')||!/_((test)|(local)|(staging))$/.test(env.MYSQL_DATABASE??'')||env.MYSQL_URL)throw new Error('LOCAL_OR_STAGING_TARGET_REQUIRED');
}
function scope(userId:number|undefined,alias='i'):{sql:string;args:number[]}{
  if(userId!==undefined&&(!Number.isSafeInteger(userId)||userId<1))throw new Error('INVALID_USER_ID');
  return userId===undefined?{sql:'TRUE',args:[]}:{sql:`${alias}.user_id=?`,args:[userId]};
}
export async function inspectInvestmentAccounts(conn:Connection,userId?:number,lock=false):Promise<BackfillPlan>{
  const filter=scope(userId);
  const [columns]=await conn.query<RowDataPacket[]>("SELECT CHARACTER_MAXIMUM_LENGTH max_name FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='accounts' AND COLUMN_NAME='name'");
  if(!columns[0]?.max_name)throw new Error('BASELINE_MIGRATIONS_REQUIRED');
  // Missing baseline account_id/contribution columns fail instead of executing boot DDL.
  const [investments]=await conn.query<RowDataPacket[]>(`SELECT i.id,i.user_id,i.name,CAST(i.principal AS CHAR) principal,i.updated_at FROM investments i WHERE i.account_id IS NULL AND ${filter.sql} ORDER BY i.user_id,i.id LIMIT 1001 ${lock?'FOR UPDATE':''}`,filter.args);
  if(investments.length>1000)throw new Error('BATCH_TOO_LARGE_USE_USER_ID');
  const candidates:Candidate[]=[];
  for(const investment of investments){
    const id=Number(investment.id),uid=Number(investment.user_id);
    const [contributions]=await conn.query<RowDataPacket[]>(`SELECT id,user_id,CAST(amount AS CHAR) amount,transaction_id,date FROM investment_contributions WHERE investment_id=? ORDER BY id ${lock?'FOR UPDATE':''}`,[id]);
    const [orphan]=await conn.query<RowDataPacket[]>(`SELECT a.id FROM accounts a LEFT JOIN investments linked ON linked.account_id=a.id WHERE a.user_id=? AND a.type='Investment' AND linked.id IS NULL ORDER BY a.id ${lock?'FOR UPDATE':''}`,[uid]);
    const balance=exactCents(String(investment.principal))+contributions.reduce((total,row)=>total+exactCents(String(row.amount)),0n);
    const unsigned=balance<0n?-balance:balance;
    const expected=`${balance<0n?'-':''}${unsigned/100n}.${String(unsigned%100n).padStart(2,'0')}`;
    const issues:Issue[]=[];
    if(orphan.length)issues.push('orphan_investment_account');
    if(contributions.some(row=>Number(row.user_id)!==uid))issues.push('contribution_owner_mismatch');
    if([...String(investment.name)].length>Number(columns[0].max_name))issues.push('account_name_too_long');
    if(unsigned>999999999999999n)issues.push('balance_out_of_range');
    candidates.push({investment_id:id,user_id:uid,name:String(investment.name),principal:String(investment.principal),updated_at:investment.updated_at,expected_balance:expected,contribution_count:contributions.length,issues});
  }
  const [links]=await conn.query<RowDataPacket[]>(`SELECT COUNT(*) linked,SUM(a.id IS NULL OR a.user_id<>i.user_id OR a.type<>'Investment') invalid_links FROM investments i LEFT JOIN accounts a ON a.id=i.account_id WHERE i.account_id IS NOT NULL AND ${filter.sql}`,filter.args);
  // Include financial values only inside this in-memory hash; CLI output never prints them.
  const digest=createHash('sha256').update(JSON.stringify({candidates,invalid_links:Number(links[0].invalid_links??0),already_linked:Number(links[0].linked)})).digest('hex');
  return {digest,candidates,blocked:candidates.filter(c=>c.issues.length).length,already_linked:Number(links[0].linked),invalid_links:Number(links[0].invalid_links??0)};
}
export async function backfillInvestmentAccounts(conn:Connection,options:BackfillOptions={}){
  if(options.apply&&(!options.maintenance||!options.expectedPlan))throw new Error('MAINTENANCE_AND_REVIEWED_PLAN_REQUIRED');
  await conn.query("SET time_zone='+00:00'");
  const [locks]=await conn.query<RowDataPacket[]>("SELECT GET_LOCK(SHA2(CONCAT(DATABASE(),':legacy-investment-backfill'),256),0) acquired");
  if(Number(locks[0].acquired)!==1)throw new Error('BACKFILL_ALREADY_RUNNING');
  try {
    await conn.beginTransaction();
    const plan=await inspectInvestmentAccounts(conn,options.userId,Boolean(options.apply));
    if(!options.apply){await conn.rollback();return {plan,created:0};}
    if(plan.digest!==options.expectedPlan)throw new Error('PLAN_CHANGED_RUN_PREFLIGHT_AGAIN');
    if(plan.blocked||plan.invalid_links)throw new Error('MANUAL_REVIEW_REQUIRED');
    for(const row of plan.candidates){
      const [account]=await conn.query<ResultSetHeader>("INSERT INTO accounts(user_id,name,type,balance,account_number,bank_name,is_active) VALUES(?,?,'Investment',?,NULL,NULL,TRUE)",[row.user_id,row.name,row.expected_balance]);
      const [linked]=await conn.query<ResultSetHeader>('UPDATE investments SET account_id=?,updated_at=updated_at WHERE id=? AND user_id=? AND account_id IS NULL',[account.insertId,row.investment_id,row.user_id]);
      if(linked.affectedRows!==1)throw new Error('INVESTMENT_CHANGED_DURING_REPAIR');
      // A migration-created account is evidence for backfill, not a new user action/DAU.
      await conn.query("UPDATE engagement_events SET source='migration',status='processed',processed_at=UTC_TIMESTAMP(3) WHERE user_id=? AND event_type='accounts.insert' AND JSON_UNQUOTE(JSON_EXTRACT(payload_json,'$.entity_id'))=?",[row.user_id,String(account.insertId)]);
    }
    await conn.commit();
    return {plan,created:plan.candidates.length};
  }catch(error){await conn.rollback();throw error;}
  finally{await conn.query("SELECT RELEASE_LOCK(SHA2(CONCAT(DATABASE(),':legacy-investment-backfill'),256))").catch(()=>{});}
}
async function main(){
  const args=process.argv.slice(2);
  if(args.includes('--help')){console.log('Explicit local/staging legacy repair. Default: read-only preflight.\n--user-id=N optional scope; --apply --expect-plan=SHA256 requires INVESTMENT_BACKFILL_MAINTENANCE_CONFIRMED=true and stopped app/workers. See docs/implementation/investment-account-backfill.md.');return;}
  if(args.some(arg=>arg!=='--apply'&&!/^--user-id=\d+$/.test(arg)&&!/^--expect-plan=[a-f0-9]{64}$/.test(arg)))throw new Error('INVALID_ARGUMENT');
  assertLocalTarget(process.env);
  const conn=await mysql.createConnection({host:process.env.MYSQL_HOST,port:Number(process.env.MYSQL_PORT??3306),user:process.env.MYSQL_USER,password:process.env.MYSQL_PASSWORD,database:process.env.MYSQL_DATABASE,timezone:'Z',multipleStatements:false});
  try{
    const userArg=args.find(arg=>arg.startsWith('--user-id='));
    const result=await backfillInvestmentAccounts(conn,{apply:args.includes('--apply'),expectedPlan:args.find(arg=>arg.startsWith('--expect-plan='))?.split('=')[1],userId:userArg?Number(userArg.split('=')[1]):undefined,maintenance:process.env.INVESTMENT_BACKFILL_MAINTENANCE_CONFIRMED==='true'});
    const issues:Record<string,number>={};for(const row of result.plan.candidates)for(const issue of row.issues)issues[issue]=(issues[issue]??0)+1;
    console.log(JSON.stringify({mode:args.includes('--apply')?'applied':'preflight',plan:result.plan.digest,candidates:result.plan.candidates.length,blocked:result.plan.blocked,already_linked:result.plan.already_linked,invalid_links:result.plan.invalid_links,created:result.created,issues}));
    if(result.plan.blocked||result.plan.invalid_links)process.exitCode=2;
  }finally{await conn.end();}
}
if(process.argv[1]&&pathToFileURL(process.argv[1]).href===import.meta.url)void main().catch(error=>{console.error(error instanceof Error&&/^[A-Z_]+$/.test(error.message)?error.message:'INVESTMENT_BACKFILL_FAILED');process.exitCode=1;});
