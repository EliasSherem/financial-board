import { createHash, createHmac, randomBytes } from 'node:crypto';
export type CredentialKind = 'unknown' | 'local' | 'google';
export type RecoveryFailure = 'invalid' | 'expired' | 'used';
export type RecoveryAccount = {
    id: number;
    email: string;
    kind: CredentialKind;
};
export type RecoveryResult = {
    ok: true;
    account: RecoveryAccount;
} | {
    ok: false;
    reason: RecoveryFailure;
};
export interface RecoveryRepository {
    issue(input: {
        email: string;
        ipKey: string;
        accountKey: string;
        tokenHash: string;
        now: Date;
        expiresAt: Date;
    }): Promise<RecoveryAccount | null>;
    allowReset(ipKey: string, now: Date): Promise<boolean>;
    consume(tokenHash: string, passwordHash: string, now: Date): Promise<RecoveryResult>;
    changePassword(userId: number, currentPassword: string, passwordHash: string, now: Date): Promise<RecoveryAccount | null>;
    audit(event: string, userId?: number): Promise<void>;
}
export type RecoveryConfig = {
    origin: string;
    allowedOrigins: string[];
    ttlMinutes: number;
    rateSecret: string;
};
export type RecoveryMail = {
    to: string;
    subject: string;
    text: string;
    html: string;
};
export type RecoveryDependencies = {
    repository: RecoveryRepository;
    config: RecoveryConfig;
    hashPassword: (password: string) => Promise<string>;
    send: (mail: RecoveryMail) => Promise<boolean>;
    now?: () => Date;
    randomToken?: () => string;
};
export function normalizeEmail(value: unknown): string | null {
    if (typeof value !== 'string')
        return null;
    const email = value.trim().toLowerCase();
    return email.length <= 100 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null;
}
// Matches existing signup's six-character minimum, rejects bcrypt's silent 72-byte truncation.
export function validPassword(password: unknown, confirmation: unknown): password is string {
    return typeof password === 'string' && password.length >= 6 && Buffer.byteLength(password, 'utf8') <= 72 && password === confirmation;
}
export function hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
}
export function rateKey(secret: string, namespace: string, value: string): string {
    if (secret.length < 32)
        throw new Error('RECOVERY_RATE_SECRET must contain at least 32 characters');
    return createHmac('sha256', secret).update(`${namespace}:${value}`).digest('hex');
}
export function recoveryUrl(config: RecoveryConfig, token: string): string {
    const origin = new URL(config.origin);
    if (origin.protocol !== 'https:' || origin.username || origin.password || origin.pathname !== '/' || origin.search || origin.hash || !config.allowedOrigins.includes(origin.origin)) {
        throw new Error('Recovery origin must be an explicitly allowed HTTPS origin');
    }
    const url = new URL('/reset-password', origin.origin);
    // Fragments never travel in HTTP access logs or Referer headers.
    url.hash = `token=${token}`;
    return url.toString();
}
function html(value: string): string {
    return value.replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]!));
}
export function resetEmail(to: string, url: string, minutes: number, language: string): RecoveryMail {
    const es = language === 'es';
    const subject = es ? 'Restablece tu contraseña de FinSight' : 'Reset your FinSight password';
    const explanation = es ? `Este enlace vence en ${minutes} minutos y sólo puede usarse una vez.` : `This link expires in ${minutes} minutes and can only be used once.`;
    const ignore = es ? 'Si no solicitaste este cambio, ignora este correo. Tu contraseña no ha cambiado.' : 'If you did not request this change, ignore this email. Your password has not changed.';
    const cta = es ? 'Elegir nueva contraseña' : 'Choose a new password';
    const text = `FinSight\n\n${subject}\n${explanation}\n\n${cta}: ${url}\n\n${ignore}`;
    return { to, subject, text, html: `<!doctype html><html lang="${es ? 'es' : 'en'}"><body style="font-family:Arial,sans-serif;background:#f1f5f9;color:#0f172a;padding:24px"><main style="max-width:560px;margin:auto;background:white;border-radius:20px;padding:32px"><p style="color:#2563eb;font-weight:700">FinSight</p><h1 style="font-size:24px">${subject}</h1><p>${explanation}</p><p style="margin:28px 0"><a href="${html(url)}" style="background:#2563eb;color:white;padding:14px 20px;border-radius:10px;display:inline-block">${cta}</a></p><p>${ignore}</p><p style="font-size:13px;overflow-wrap:anywhere">${html(url)}</p></main></body></html>` };
}
export function changedEmail(to: string, language: string): RecoveryMail {
    const es = language === 'es';
    const subject = es ? 'Tu contraseña de FinSight cambió' : 'Your FinSight password changed';
    const text = es ? 'Tu contraseña cambió y cerramos tus sesiones en todos los dispositivos. Si no hiciste este cambio, solicita una nueva recuperación y contacta al soporte de FinSight.' : 'Your password changed and all devices were signed out. If you did not make this change, request a new recovery and contact FinSight support.';
    return { to, subject, text, html: `<html lang="${es ? 'es' : 'en'}"><body style="font-family:Arial,sans-serif;color:#0f172a"><h1>FinSight</h1><h2>${subject}</h2><p>${text}</p></body></html>` };
}
export class RecoveryService {
    private readonly now: () => Date;
    constructor(private readonly deps: RecoveryDependencies) { this.now = deps.now ?? (() => new Date()); }
    private deliver(mail: RecoveryMail, userId: number) {
        // The database commit precedes delivery. Email provider latency must not disclose account existence.
        void this.deps.send(mail).then(ok => { if (!ok)
            return this.deps.repository.audit('recovery_mail_failed', userId); }).catch(() => undefined);
    }
    async forgot(emailInput: unknown, ip: string, language: string): Promise<void> {
        const email = normalizeEmail(emailInput);
        const token = (this.deps.randomToken ?? (() => randomBytes(32).toString('base64url')))();
        const url = recoveryUrl(this.deps.config, token);
        const now = this.now();
        const account = await this.deps.repository.issue({
            email: email ?? '',
            ipKey: rateKey(this.deps.config.rateSecret, 'forgot-ip', ip),
            accountKey: rateKey(this.deps.config.rateSecret, 'forgot-account', email ?? 'invalid'),
            tokenHash: hashToken(token), now,
            expiresAt: new Date(now.getTime() + this.deps.config.ttlMinutes * 60000),
        });
        if (account?.kind === 'local')
            this.deliver(resetEmail(account.email, url, this.deps.config.ttlMinutes, language), account.id);
    }
    async reset(input: {
        token: unknown;
        password: unknown;
        confirmation: unknown;
        ip: string;
        language: string;
    }): Promise<RecoveryResult | {
        ok: false;
        reason: 'password' | 'rate_limit';
    }> {
        const now = this.now();
        if (!await this.deps.repository.allowReset(rateKey(this.deps.config.rateSecret, 'reset-ip', input.ip), now))
            return { ok: false, reason: 'rate_limit' };
        if (!validPassword(input.password, input.confirmation))
            return { ok: false, reason: 'password' };
        if (typeof input.token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(input.token)) {
            await this.deps.repository.audit('recovery_invalid');
            return { ok: false, reason: 'invalid' };
        }
        const result = await this.deps.repository.consume(hashToken(input.token), await this.deps.hashPassword(input.password), now);
        if (result.ok)
            this.deliver(changedEmail(result.account.email, input.language), result.account.id);
        return result;
    }
    async change(userId: number, input: {
        current: unknown;
        password: unknown;
        confirmation: unknown;
        language: string;
    }): Promise<boolean> {
        if (!await this.deps.repository.allowReset(rateKey(this.deps.config.rateSecret, 'change-account', String(userId)), this.now()))
            return false;
        if (!validPassword(input.password, input.confirmation) || typeof input.current !== 'string' || Buffer.byteLength(input.current) > 1024)
            return false;
        const account = await this.deps.repository.changePassword(userId, input.current, await this.deps.hashPassword(input.password), this.now());
        if (!account)
            return false;
        this.deliver(changedEmail(account.email, input.language), account.id);
        return true;
    }
}
