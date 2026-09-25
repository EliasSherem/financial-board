const trackedFeatures = new Set(['accounts', 'transactions', 'payments', 'projects', 'invoices', 'investments', 'categories']);

/** Call only after a successful financial mutation. Cache invalidation does not depend on telemetry consent. */
export function publishFinancialChange(target: Pick<EventTarget, 'dispatchEvent'>, url: string, method: string | undefined, trackFeature: (feature: string) => void) {
    if (!method || !['POST', 'PUT', 'PATCH', 'DELETE'].includes(method.toUpperCase())) return;
    const path = url.split('?')[0];
    if (!/^\/(accounts|transactions|payments|projects|invoices|investments|categories|expense-categories|expense-subcategories|customers|balance-history)(\/|$)/.test(path) && !/^\/credit\/installments(\/|$)/.test(path)) return;
    target.dispatchEvent(new Event('finsight:financial-changed'));
    const prefix = path.split('/')[1];
    const feature = ['expense-categories', 'expense-subcategories'].includes(prefix) ? 'categories' : prefix;
    if (trackedFeatures.has(feature)) trackFeature(feature);
}
