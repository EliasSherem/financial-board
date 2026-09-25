import { useEffect, useState } from 'react';
import { useTheme } from '../contexts/ThemeContext';
type Entry = {
    key: string;
    files: Record<string, string>;
};
let manifestPromise: Promise<Entry[]> | undefined;
function manifest() { return manifestPromise ??= fetch('/momentum/assets/manifest.json').then(r => { if (!r.ok)
    throw new Error('ASSET_MANIFEST'); return r.json(); }).then((m: Record<string, unknown>) => Object.values(m).flatMap(v => Array.isArray(v) ? v : []) as Entry[]); }
export function MomentumAsset({ assetKey, size = 40, locked = false, alt = '' }: {
    assetKey: string;
    size?: 24 | 40 | 64 | 96 | 128;
    locked?: boolean;
    alt?: string;
}) {
    const { theme } = useTheme();
    const [entry, setEntry] = useState<Entry>();
    useEffect(() => { let active = true; manifest().then(items => { if (active)
        setEntry(items.find(x => x.key === assetKey)); }).catch(() => { }); return () => { active = false; }; }, [assetKey]);
    const path = entry?.files[locked ? `locked_${theme}` : theme] ?? entry?.files[theme];
    return path ? <img src={`/momentum/${path}`} width={size} height={size} alt={alt} aria-hidden={alt ? undefined : true} className="shrink-0"/> : <span style={{ width: size, height: size }} aria-hidden="true"/>;
}
