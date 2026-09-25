import { MISSIONS } from './catalog.js';
import type { Facts, Mission, MissionDefinition, Slot } from './types.js';

export function eligibility(def: MissionDefinition, facts: Facts): string | null {
  if (!facts.capabilities[def.capability]) return def.capability === 'project_milestones' ? 'project_milestones' : 'unavailable';
  if (def.pro && !facts.pro) return 'pro_required';
  const key = def.key, n = facts.counts;
  if (key === 'weekly_ai_action' && !n.ai_access) return 'unavailable';
  if (def.scope === 'activation' || def.scope === 'feature') {
    if (def.review && (n.transactions < 1 || n.accounts < 1)) return 'no_data';
    return null;
  }
  if (!n.accounts || !n.transactions) return 'no_data';
  if (key === 'monthly_uncategorized_clear' && (n.transactions < 5 || n.uncategorized > 0)) return 'no_data';
  if (key.includes('project') && !n.active_projects) return 'no_data';
  if ((key.includes('invoice') || key.includes('customer')) && !n.open_invoices) return 'no_data';
  if (key.includes('investment') && !n.investments) return 'no_data';
  if (key.includes('budget') && !n.budgets) return 'no_data';
  if (key.includes('recurring') && !n.payments) return 'no_data';
  if (key.includes('upcoming') && !n.upcoming_payments) return 'no_data';
  if (key.includes('overdue') && !n.overdue_payments) return 'no_data';
  if (key.includes('payment_check') && !n.payments) return 'no_data';
  if (['weekly_categorize', 'weekly_category_cleanup'].includes(key) && !facts.uncategorized.length) return 'no_data';
  if (key === 'comeback_clarity' && !facts.comebackEpisode) return 'no_data';
  if (key === 'comeback_week' && !facts.hasMissedWeek) return 'no_data';
  return null;
}
export function assignedMission(def: MissionDefinition, period: string, facts: Facts, slot: Slot | null = null): Mission {
  const targetKeys = def.metric === 'categorize_targets' ? facts.uncategorized.slice(0, def.target) : [];
  return { key: def.key, scope: def.scope, period, slot, target: targetKeys.length || def.target, targetKeys, progress: 0, status: 'active', grantedXp: 0, reason: null };
}
const candidates: Record<Slot, string[]> = {
  review: ['weekly_summary'],
  maintenance: ['weekly_overdue_payment', 'weekly_categorize', 'weekly_upcoming_payments', 'weekly_recurring_review', 'weekly_accounts_review'],
  goal: ['weekly_invoice_review', 'weekly_project_review', 'weekly_budget_review', 'weekly_investment_review', 'weekly_month_net'],
};
/** Existing completed missions are immutable. Only the impossible slot can be replaced. */
export function generateWeekly(existing: Mission[], period: string, facts: Facts): { missions: Mission[]; replacements: { old: string; next: string | null; reason: string }[] } {
  const replacements: { old: string; next: string | null; reason: string }[] = [];
  const result = existing.map(m => ({ ...m }));
  const used = new Set(result.map(m => m.key));
  const choose = (slot: Slot) => candidates[slot].map(key => MISSIONS.find(d => d.key === key)!).find(d => !used.has(d.key) && eligibility(d, facts) === null);
  if (!result.some(m => m.slot)) {
    const selected = (['review', 'maintenance', 'goal'] as Slot[]).map(slot => ({ slot, def: choose(slot) }));
    if (selected.some(m => !m.def)) return { missions: result, replacements };
    for (const { slot, def } of selected) { result.push(assignedMission(def!, period, facts, slot)); used.add(def!.key); }
  } else {
    for (const mission of result) {
      if (!mission.slot || mission.status === 'completed' || mission.status === 'replaced') continue;
      const def = MISSIONS.find(d => d.key === mission.key)!;
      const reason = eligibility(def, facts);
      // A target that has just been categorized is progress, not a lost-eligibility condition.
      const satisfied = def.metric === 'categorize_targets' ? mission.targetKeys.every(key => facts.categorized.has(key)) : (facts.counts[`${def.metric}:${period}`] ?? 0) >= mission.target;
      if (!reason || satisfied) { mission.status = 'active'; mission.reason = null; continue; }
      const replacement = choose(mission.slot);
      if (replacement) {
        const next = assignedMission(replacement, period, facts, mission.slot);
        mission.status = 'replaced'; mission.reason = 'replaced';
        result.push(next); used.add(next.key);
        replacements.push({ old: mission.key, next: next.key, reason });
      } else if (mission.status !== 'unavailable') {
        mission.status = 'unavailable'; mission.reason = 'no_replacement';
        replacements.push({ old: mission.key, next: null, reason });
      }
    }
  }
  return { missions: result, replacements };
}
