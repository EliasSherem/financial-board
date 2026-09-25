import type { RowDataPacket } from 'mysql2/promise';
import { db } from '../db.js';
const args = process.argv.slice(2), emailIndex = args.indexOf('--email'), idIndex = args.indexOf('--user-id');
if ((emailIndex >= 0) === (idIndex >= 0) || !args.includes('--apply'))
    throw new Error('Usage: bootstrap-owner --email <existing-email> | --user-id <existing-id> --apply [--revoke]');
const value = emailIndex >= 0 ? args[emailIndex + 1]?.trim().toLowerCase() : Number(args[idIndex + 1]);
if (!value || (idIndex >= 0 && (!Number.isSafeInteger(value) || Number(value) < 1)))
    throw new Error('Invalid user identifier');
const conn = await db.getConnection();
try {
    await conn.beginTransaction();
    const [rows] = await conn.query<RowDataPacket[]>(`SELECT id FROM users WHERE ${emailIndex >= 0 ? 'LOWER(TRIM(email))' : 'id'} = ? FOR UPDATE`, [value]);
    if (rows.length !== 1)
        throw new Error('Expected exactly one existing user');
    const id = Number(rows[0].id);
    if (args.includes('--revoke'))
        await conn.query('DELETE FROM admin_roles WHERE user_id = ?', [id]);
    else
        await conn.query("INSERT INTO admin_roles (user_id,role,granted_by) VALUES (?,'owner','operator_cli') ON DUPLICATE KEY UPDATE role='owner',granted_by='operator_cli'", [id]);
    await conn.query('INSERT INTO admin_audit (user_id,action,filters_json) VALUES (?,?,JSON_OBJECT())', [id, args.includes('--revoke') ? 'owner_revoked_cli' : 'owner_granted_cli']);
    await conn.commit();
    console.log('Owner role updated for existing user ID', id);
}
catch (error) {
    await conn.rollback();
    throw error;
}
finally {
    conn.release();
    await db.end();
}
