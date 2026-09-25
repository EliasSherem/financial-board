import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const source = path.join(root, 'finsight-momentum');
const manifest = JSON.parse(await fs.readFile(path.join(source, 'assets/manifest.json'), 'utf8'));
const files = Object.values(manifest).filter(Array.isArray).flatMap(items => items.flatMap(item => Object.values(item.files)));
if (manifest.badges.length !== 34 || files.length !== 168 || new Set(files).size !== 168) throw new Error('Unexpected Momentum asset catalog');
for (const relative of ['assets/manifest.json', ...files]) {
  if (!/^assets\/[a-z0-9_./]+$/.test(relative) || relative.includes('..')) throw new Error('Invalid manifest path');
  const bytes = await fs.readFile(path.join(source, relative));
  for (const target of ['financial-dashboard/public/momentum', 'mobile/assets/momentum']) {
    const output = path.join(root, target, relative);
    if (!process.argv.includes('--check')) { await fs.mkdir(path.dirname(output), { recursive: true }); await fs.writeFile(output, bytes); }
    const actual = await fs.readFile(output);
    if (createHash('sha256').update(bytes).digest('hex') !== createHash('sha256').update(actual).digest('hex')) throw new Error(`Asset mismatch: ${output}`);
  }
}
console.log('34 badge keys / 168 original SVGs and manifest verified byte-for-byte in web and Flutter.');
