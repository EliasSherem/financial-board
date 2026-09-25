import { createContext, useContext } from 'react';
import type { Momentum, MomentumResponse } from './types';
type Store = {
    state: Momentum | null;
    loading: boolean;
    error: boolean;
    refresh: () => Promise<void>;
    replace: (state: MomentumResponse) => void;
    acknowledgeAchievement: (key: string) => Promise<void>;
};
export const MomentumContext = createContext<Store | null>(null);
export function useMomentum() { const value = useContext(MomentumContext); if (!value)
    throw new Error('MomentumProvider required'); return value; }
