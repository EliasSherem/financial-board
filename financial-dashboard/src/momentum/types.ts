export type Text = {
    en: string;
    es: string;
};
export type Mission = {
    key: string;
    scope: 'activation' | 'feature' | 'weekly' | 'monthly' | 'comeback';
    title: Text;
    requirement: Text;
    deeplink: string;
    period: string;
    status: 'active' | 'completed' | 'unavailable' | 'replaced';
    slot: 'review' | 'maintenance' | 'goal' | null;
    target: number;
    progress: number;
    nominal_xp: number;
    granted_xp: number;
    reason: Text | null;
    review: boolean;
};
export type Achievement = {
    key: string;
    title: Text;
    requirement: Text;
    progress: number;
    target: number;
    xp: number;
    completed_at: string | null;
    seen_at: string | null;
    available: boolean;
    reason: Text | null;
};
export type Momentum = {
    enabled: true;
    user_id: number;
    generated_at: string;
    xp_history: {
        period: string;
        xp: number;
    }[];
    lifetime_xp: number;
    level: {
        key: string;
        title: Text;
        minimum_xp: number;
        next_xp: number | null;
    };
    week: {
        key: string;
        timezone: string;
        starts_at: string;
        ends_at: string;
        assigned: boolean;
        completed: number;
        total: number;
        bonus_xp: number;
        repeatable_xp: number;
        cap: number;
        new_week: boolean;
        unavailable: boolean;
        grace_applied: boolean;
    };
    month: {
        key: string;
        repeatable_xp: number;
        cap: number;
    };
    rhythm: number;
    missions: Mission[];
    achievements: Achievement[];
    ai_credits: {
        available: boolean;
        balance: number;
        expires_at: string | null;
    };
    backfill: {
        completed: boolean;
        unseen: boolean;
    };
    coachmark_seen: boolean;
    preferences: {
        timezone_name?: string;
        timezone_offset_min?: number;
        notifications_enabled: boolean;
        quiet_start: number;
        quiet_end: number;
        locale: 'en' | 'es';
    };
};
export type MomentumResponse = Momentum | {
    enabled: false;
    user_id: number;
};
export type Review = {
    snapshot_id: string;
    kind: string;
    period: string;
    expires_at: string;
    sections: {
        key: string;
        title: Text;
        applicable: boolean;
        data: Record<string, unknown>[];
    }[];
};
