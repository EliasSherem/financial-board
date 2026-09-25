// Explicit operator-only repair for legacy accounts. Never infer a provider from email/hash.
// Usage: node --import tsx server/recovery/classify-credential.ts --user-id 123 --kind local --apply
import { db } from '../db.js';
const args = process.argv.slice(2);
const value = (key: string) => args[args.indexOf(key) + 1];
const userId = Number(value('--user-id'));
const kind = value('--kind');
if (!Number.isSafeInteger(userId) || userId <= 0 || !['local', 'google'].includes(kind) || !args.includes('--apply')) {
    console.error('Required: --user-id <real user id> --kind local|google --apply. Confirm credential provenance independently first.');
    process.exitCode = 1;
}
else {
    const conn = await db.getConnection();
    try {
        await conn.beginTransaction();
        const [rows] = await conn.query('SELECT id, credential_kind FROM users WHERE id = ? FOR UPDATE', [userId]);
        const account = (rows as Array<{
            id: number;
            credential_kind: string;
        }>)[0];
        if (!account || account.credential_kind !== 'unknown')
            throw new Error('Requires one existing account with unknown provenance');
        await conn.query('UPDATE users SET credential_kind = ? WHERE id = ?', [kind, userId]);
        await conn.query('INSERT INTO auth_security_audit (user_id, event_type, received_at) VALUES (?, ?, UTC_TIMESTAMP(3))', [userId, `credential_classified_${kind}`]);
        await conn.commit();
        console.info(`Classified user ${userId} as ${kind}; no password, financial or subscription record changed.`);
    }
    catch {
        await conn.rollback();
        console.error('Classification failed; check migration, user ID and existing credential provenance.');
        process.exitCode = 1;
    }
    finally {
        conn.release();
    }
}
await db.end();
