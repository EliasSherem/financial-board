import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { clearTelemetry, flushTelemetry, foregroundHeartbeat, initializeTelemetry, observeCheckoutReturn, screenForPath, touchTelemetry, track } from './client';
export function TelemetryLifecycle() {
    const { pathname } = useLocation();
    useEffect(() => {
        const screen = screenForPath(pathname);
        if (!screen || !localStorage.getItem('token'))
            return;
        let active = true;
        void initializeTelemetry().then(() => { if (active) {
            void track('screen_view', screen);
            void observeCheckoutReturn();
        } });
        const foreground = () => { if (document.visibilityState === 'visible') {
            track('app_foregrounded', screen);
            void flushTelemetry();
        } };
        const activity = () => touchTelemetry();
        const clear = () => clearTelemetry();
        const heartbeat = window.setInterval(() => foregroundHeartbeat(screen), 60000);
        document.addEventListener('visibilitychange', foreground);
        window.addEventListener('online', foreground);
        window.addEventListener('finsight:session-changed', clear);
        window.addEventListener('pointerdown', activity);
        window.addEventListener('keydown', activity);
        return () => { active = false; clearInterval(heartbeat); document.removeEventListener('visibilitychange', foreground); window.removeEventListener('online', foreground); window.removeEventListener('finsight:session-changed', clear); window.removeEventListener('pointerdown', activity); window.removeEventListener('keydown', activity); };
    }, [pathname]);
    return null;
}
