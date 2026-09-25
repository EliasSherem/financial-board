import { useCallback, useEffect, useState, useSyncExternalStore, type ReactNode } from 'react';
import { platformRequest } from './service';
import type { MomentumResponse } from './types';
import { MomentumContext as Context } from './context';
import { track } from '../analytics/client';
import { MomentumClient, type MomentumSession } from './client';

function session(): MomentumSession | null {
    try {
        const token = localStorage.getItem('token');
        const user = JSON.parse(localStorage.getItem('user') || '{}') as { id?: number };
        const userId = Number(user.id);
        if (!token || !Number.isSafeInteger(userId) || userId <= 0) return null;
        let expiresAt: number | undefined;
        try {
            const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))) as { exp?: number };
            if (typeof payload.exp === 'number') expiresAt = payload.exp * 1000;
        } catch { /* The server remains responsible for validating credentials. */ }
        return { token, userId, expiresAt };
    } catch { return null; }
}
function createClient() {
    return new MomentumClient({
        session,
        storage: {
            getItem: key => sessionStorage.getItem(key),
            setItem: (key, value) => sessionStorage.setItem(key, value),
            removeItem: key => sessionStorage.removeItem(key),
        },
        fingerprint: async token => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token))), byte => byte.toString(16).padStart(2, '0')).join(''),
        visible: () => document.visibilityState === 'visible',
        request: signal => {
            const query = new URLSearchParams({ timezone_name: Intl.DateTimeFormat().resolvedOptions().timeZone, timezone_offset_min: String(-new Date().getTimezoneOffset()) });
            return platformRequest<MomentumResponse>(`/engagement/me?${query}`, undefined, signal);
        },
        seen: key => platformRequest(`/engagement/achievements/${encodeURIComponent(key)}/seen`, {}),
        transition: (before, after) => {
            if (before?.user_id !== after.user_id) return;
            const steps: Record<string, string> = { activation_first_account: 'account', activation_first_transactions: 'transactions', activation_categories: 'categories', activation_first_payment: 'payment', activation_first_insight: 'insight', activation_weekly_review: 'review' };
            for (const mission of after.missions) if (mission.status === 'completed' && steps[mission.key] && before.missions.some(old => old.key === mission.key && old.status === 'active')) void track('onboarding_step_completed', 'onboarding', { step: steps[mission.key] });
        },
    });
}
export function MomentumProvider({ children }: { children: ReactNode }) {
    const [client] = useState(createClient);
    const { state, loading, error } = useSyncExternalStore(client.subscribe, client.snapshot, client.snapshot);
    const refresh = useCallback(() => client.refresh(true), [client]);
    useEffect(() => {
        // Show this session's saved view immediately; always validate it in the background on entry.
        void client.refresh(true);
        const visible = () => { if (document.visibilityState === 'visible') void client.refresh(); };
        const online = () => { if (document.visibilityState === 'visible') void client.refresh(true); };
        const changed = () => { void client.refresh(true); };
        const storage = (event: StorageEvent) => { if (event.key === 'token' || event.key === 'user' || event.key === null) changed(); };
        const interval = window.setInterval(visible, 60_000);
        window.addEventListener('focus', visible);
        window.addEventListener('online', online);
        document.addEventListener('visibilitychange', visible);
        window.addEventListener('finsight:financial-changed', client.invalidate);
        window.addEventListener('finsight:session-changed', changed);
        window.addEventListener('storage', storage);
        return () => {
            clearInterval(interval);
            window.removeEventListener('focus', visible);
            window.removeEventListener('online', online);
            document.removeEventListener('visibilitychange', visible);
            window.removeEventListener('finsight:financial-changed', client.invalidate);
            window.removeEventListener('finsight:session-changed', changed);
            window.removeEventListener('storage', storage);
            client.stopWhenUnused();
        };
    }, [client]);
    return <Context.Provider value={{ state, loading, error, refresh, replace: client.replace, acknowledgeAchievement: client.acknowledgeAchievement }}>{children}</Context.Provider>;
}
