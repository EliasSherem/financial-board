import { localParts } from '../platform/periods.js';
import { ACHIEVEMENTS, MISSIONS } from './catalog.js';
import { eligibility } from './missionGenerator.js';
import type { Facts, Mission, Reward } from './types.js';

export const WEEKLY_CAP = 100;
export const MONTHLY_CAP = 75;
export const WEEK_BONUS = 20;
export function cappedXp(nominal: number, awarded: number, cap: number): number {
  return Math.max(0, Math.min(nominal, cap - Math.max(0, awarded)));
}
export function progressFor(mission: Mission, facts: Facts): number {
  const def = MISSIONS.find(d => d.key === mission.key)!;
  if (def.metric === 'categorize_targets') return mission.targetKeys.filter(key => facts.categorized.has(key)).length;
  if (def.scope === 'weekly' || def.scope === 'monthly' || def.scope === 'comeback') return facts.counts[`${def.metric}:${mission.period}`] ?? 0;
  return facts.counts[def.metric] ?? 0;
}
export function evaluateMissions(missions: Mission[], facts: Facts, budget: { weekly: number; monthly: number }): { missions: Mission[]; rewards: Reward[] } {
  const rewards: Reward[] = [];
  const updated = missions.map(m => ({ ...m }));
  for (const mission of updated) {
    if (mission.status === 'completed' || mission.status === 'replaced') continue;
    const def = MISSIONS.find(d => d.key === mission.key)!;
    const progress = progressFor(mission, facts);
    mission.progress = Math.max(mission.progress, Math.min(mission.target, progress));
    const reason = eligibility(def, facts);
    // Destructive removals cannot earn progress. Captured categorization identities remain valid.
    const satisfiedTargets = def.metric === 'categorize_targets' && mission.progress >= mission.target;
    const resolvedOverdue = def.key === 'weekly_overdue_payment' && mission.progress >= mission.target;
    if (reason && !satisfiedTargets && !resolvedOverdue) { mission.reason = reason; continue; }
    if (mission.progress < mission.target) continue;
    mission.status = 'completed'; mission.reason = null;
    const capGroup = ['weekly', 'comeback'].includes(def.scope) ? 'weekly' : def.scope === 'monthly' ? 'monthly' : 'none';
    const xp = capGroup === 'weekly' ? cappedXp(def.xp, budget.weekly, WEEKLY_CAP) : capGroup === 'monthly' ? cappedXp(def.xp, budget.monthly, MONTHLY_CAP) : def.xp;
    if (capGroup === 'weekly') budget.weekly += xp;
    if (capGroup === 'monthly') budget.monthly += xp;
    mission.grantedXp = xp;
    rewards.push({ origin: `mission:${mission.key}`, period: mission.period, capGroup, nominalXp: def.xp, xp, idempotencyKey: `mission:${mission.key}:${mission.period}` });
  }
  return { missions: updated, rewards };
}
export function achievementProgress(facts: Facts, completedActivations: number) {
  return ACHIEVEMENTS.map(def => {
    const count = def.metric === 'activations' ? completedActivations : facts.counts[def.metric] ?? 0;
    return { key: def.key, progress: Math.min(def.target, count), eligible: facts.capabilities[def.capability], complete: facts.capabilities[def.capability] && count >= def.target };
  });
}
export function completedWeek(missions: Mission[]): boolean {
  const required = missions.filter(m => m.scope === 'weekly' && m.slot && m.status !== 'replaced');
  return required.length === 3 && required.every(m => m.status === 'completed');
}
export function mayApplyGrace(missingPeriodStart: Date, usedGraceStarts: Date[], enabled = true, windowWeeks = 8, timezone='UTC', offset=0): boolean {
  const civil=(date:Date)=>{const p=localParts(date,timezone,offset);return Date.UTC(p.year,p.month-1,p.day);};
  const missing=civil(missingPeriodStart);
  if (!enabled || usedGraceStarts.some(d => civil(d) === missing)) return false;
  const start = missing - Math.max(1, windowWeeks - 1) * 7 * 86_400_000;
  return !usedGraceStarts.some(d => civil(d) >= start && civil(d) <= missing);
}
