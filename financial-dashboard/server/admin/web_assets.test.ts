import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { ACHIEVEMENTS } from '../momentum/catalog.js';
test('web manifest covers every catalog badge, all four levels and 168 original SVG variants',async()=>{
  const base=new URL('../../public/momentum/',import.meta.url);
  const manifest=JSON.parse(await readFile(new URL('assets/manifest.json',base),'utf8'));
  assert.equal(manifest.badges.length,34);assert.equal(manifest.levels.length,4);assert.equal(manifest.ui.length,12);
  assert.deepEqual(new Set(manifest.badges.map((b:{key:string})=>b.key)),new Set(ACHIEVEMENTS.map(b=>b.key)));
  const files:string[]=Object.values(manifest).flatMap(value=>Array.isArray(value)?value.flatMap(entry=>Object.values(entry.files) as string[]):[]);
  assert.equal(files.length,168);assert.equal(new Set(files).size,168);
  for(const path of files){assert.match(path,/^assets\/(badges|levels|ui)\/[a-z0-9_]+\.svg$/);assert.match(await readFile(new URL(path,base),'utf8'),/<svg/);}
  for(const badge of manifest.badges)for(const variant of ['light','dark','locked_light','locked_dark'])assert.ok(badge.files[variant]);
});
