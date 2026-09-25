export type Localized = { en: string; es: string };
export type Scope = 'activation' | 'feature' | 'weekly' | 'monthly' | 'comeback';
export type Slot = 'review' | 'maintenance' | 'goal';
export type Capability = 'core' | 'projects' | 'invoices' | 'investments' | 'budgets' | 'receipt' | 'ai' | 'report' | 'project_milestones';
export type MissionDefinition = {
  key: string; scope: Scope; title: Localized; requirement: Localized; xp: number;
  metric: string; target: number; capability: Capability; pro: boolean; deeplink: string;
  review: boolean; priority: number;
};
export type AchievementDefinition = { key: string; title: Localized; requirement: Localized; xp: number; metric: string; target: number; capability: Capability };
export type Mission = { key: string; scope: Scope; period: string; slot: Slot | null; target: number; progress: number; status: 'active' | 'completed' | 'unavailable' | 'replaced'; grantedXp: number; targetKeys: string[]; reason: string | null };
export type Facts = { counts: Record<string, number>; uncategorized: string[]; categorized: Set<string>; capabilities: Record<Capability, boolean>; pro: boolean; lastSignificant: Date | null; hasMissedWeek: boolean; comebackEpisode: string | null };
export type Section = { key: string; title: Localized; applicable: boolean; data: Record<string, unknown>[] };
export type Reward = { origin: string; period: string; capGroup: 'weekly' | 'monthly' | 'week_bonus' | 'none'; nominalXp: number; xp: number; idempotencyKey: string };
