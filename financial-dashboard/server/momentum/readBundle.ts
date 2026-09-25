import type { PoolConnection } from 'mysql2/promise';

/** Internal, static SQL only. Each subquery keeps its bound user/period scope.
 * A single statement observes one transaction snapshot and pays one DB round trip.
 * JSON_ARRAYAGG order is unspecified: callers must explicitly sort ordered data.
 */
export type ReadPart = { sql: string; values: unknown[]; fields: string[] | Record<string,string> };
export async function readBundle<T extends Record<string,ReadPart>>(conn:PoolConnection, parts:T):Promise<Record<keyof T,Record<string,unknown>[]>> {
  const entries=Object.entries(parts);
  if(!entries.length) return {} as Record<keyof T,Record<string,unknown>[]>;
  const sql=entries.map(([key,part])=>{
    if(!/^[a-z_][a-z0-9_]*$/i.test(key))throw new Error('Invalid internal read alias');
    const fields=Array.isArray(part.fields)?Object.fromEntries(part.fields.map(name=>[name,`r.${name}`])):part.fields;
    const object=Object.entries(fields).map(([name,expression])=>{
      if(!/^[a-z_][a-z0-9_]*$/i.test(name))throw new Error('Invalid internal field alias');
      return `'${name}',${expression}`;
    }).join(',');
    return `(SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT(${object})),JSON_ARRAY()) FROM (${part.sql}) r) AS ${key}`;
  }).join(',');
  const [result]=await conn.query(`SELECT ${sql}`,entries.flatMap(([,part])=>part.values));
  const row=(result as Record<string,unknown>[])[0];
  return Object.fromEntries(entries.map(([key])=>{
    const value=row[key], parsed=typeof value==='string'?JSON.parse(value):value;
    if(!Array.isArray(parsed))throw new Error('Invalid internal read result');
    return [key,parsed];
  })) as Record<keyof T,Record<string,unknown>[]>;
}

/** MySQL JSON dates otherwise lose mysql2's UTC/date conversion. Keep milliseconds. */
export function utcJson(column:string) {
  if(!/^r\.[a-z_][a-z0-9_]*$/i.test(column))throw new Error('Invalid internal date column');
  return `CONCAT(DATE_FORMAT(${column},'%Y-%m-%dT%H:%i:%s.'),LEFT(DATE_FORMAT(${column},'%f'),3),'Z')`;
}

export function rowFields(names:string[], dates:string[] = []):Record<string,string> {
  return Object.fromEntries(names.map(name=>[name,dates.includes(name)?utcJson(`r.${name}`):`r.${name}`]));
}
