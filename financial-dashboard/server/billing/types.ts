export type Provider = 'google' | 'apple' | 'stripe';
export type Status = 'pending' | 'trial' | 'active' | 'cancel_at_period_end' | 'grace' | 'hold' | 'paused' | 'expired' | 'revoked' | 'refunded' | 'unknown' | 'legacy';
export type Environment = 'production' | 'test' | 'unknown';
export interface VerifiedContract {
  provider: Provider; contractKey: string; productId: string; basePlanId?: string | null;
  rawState: string; status: Status; accessUntil: Date | null; isTrial: boolean;
  autoRenewing: boolean | null; currency?: string | null; recurringAmount?: string | null;
  periodMonths?: number | null; environment: Environment;
  linkedToken?: string; acknowledged?: boolean; accountId?: string;
  observedAt?: Date; flowId?: string; orderIds?: string[];
  charges?: Array<{id:string;kind:"charge"|"refund";amount:string;currency:string;occurredAt:Date}>;
}
export class BillingError extends Error {
  constructor(public code: string, public httpStatus = 400) { super(code); }
}
export function effectiveAccess(contract: {status: string; accessUntil?: Date | string | null; access_until?: Date | string | null; verified?: boolean | number; replaced_by_id?: number | null}, now = new Date()): boolean {
  if (contract.verified === false || contract.verified === 0 || contract.replaced_by_id) return false;
  if (!['active','trial','grace','cancel_at_period_end'].includes(contract.status)) return false;
  const until = contract.accessUntil ?? contract.access_until;
  return until != null && Number.isFinite(new Date(until).getTime()) && new Date(until).getTime() > now.getTime();
}
export function parseProviderTime(value: unknown): Date | null {
  if (typeof value !== 'string' && typeof value !== 'number') return null;
  const result = new Date(typeof value === 'string' && /^\d{13}$/.test(value) ? Number(value) : value);
  return Number.isFinite(result.getTime()) ? result : null;
}
export function normalizeGoogle(state: string, until: Date | null, now = new Date()): Status {
  const map: Record<string, Status> = {SUBSCRIPTION_STATE_ACTIVE:'active',SUBSCRIPTION_STATE_IN_GRACE_PERIOD:'grace',SUBSCRIPTION_STATE_CANCELED:'cancel_at_period_end',SUBSCRIPTION_STATE_ON_HOLD:'hold',SUBSCRIPTION_STATE_PAUSED:'paused',SUBSCRIPTION_STATE_EXPIRED:'expired',SUBSCRIPTION_STATE_PENDING:'pending',SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED:'expired'};
  const status = map[state] ?? 'unknown';
  return ['active','grace','cancel_at_period_end'].includes(status) && (!until || until <= now) ? 'expired' : status;
}
export function normalizeStripe(state: string, cancelAtEnd: boolean): Status {
  if (state === 'trialing') return 'trial';
  if (state === 'active') return cancelAtEnd ? 'cancel_at_period_end' : 'active';
  // Stripe past_due is not proof of a paid grace entitlement. No arbitrary grace is granted.
  return ({past_due:'hold',unpaid:'hold',paused:'paused',canceled:'expired',incomplete:'pending',incomplete_expired:'expired'} as Record<string, Status>)[state] ?? 'unknown';
}
export function safeError(error: unknown): string {
  return error instanceof BillingError ? error.code : 'provider_or_storage_unavailable';
}
export function retryDelay(attempt: number): number { return Math.min(6 * 3600, 30 * 2 ** Math.min(attempt, 10)); }
