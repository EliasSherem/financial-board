import assert from 'node:assert/strict';
import { test } from 'node:test';
import { publishFinancialChange } from './financialEvents';

test('category and subcategory creation, updates and deletion invalidate Momentum with a valid analytics feature', () => {
    const target = new EventTarget(); let changes = 0; const features: string[] = [];
    target.addEventListener('finsight:financial-changed', () => { changes++; });
    for (const path of ['/expense-categories', '/expense-subcategories']) for (const method of ['POST', 'PUT', 'DELETE']) {
        publishFinancialChange(target, `${path}/12?source=synthetic`, method, feature => features.push(feature));
    }
    assert.equal(changes, 6); assert.deepEqual(features, Array(6).fill('categories'));
});

test('all financial mutation families invalidate, including installments and customer changes without invented analytics enums', () => {
    const target = new EventTarget(); let changes = 0; const features: string[] = [];
    target.addEventListener('finsight:financial-changed', () => { changes++; });
    for (const path of ['/accounts/1', '/transactions/2', '/payments/process-overdue', '/projects/3', '/invoices/4/payments', '/investments/5/contributions', '/categories/6', '/credit/installments', '/customers/7', '/balance-history/rebuild']) {
        publishFinancialChange(target, path, 'POST', feature => features.push(feature));
    }
    assert.equal(changes, 10); assert.deepEqual(features, ['accounts', 'transactions', 'payments', 'projects', 'invoices', 'investments', 'categories']);
});

test('reads and unrelated writes neither invalidate nor emit feature activity', () => {
    const target = new EventTarget(); let changes = 0; const features: string[] = [];
    target.addEventListener('finsight:financial-changed', () => { changes++; });
    for (const method of [undefined, 'GET', 'HEAD', 'OPTIONS']) publishFinancialChange(target, '/expense-categories', method, feature => features.push(feature));
    for (const path of ['/stripe/portal', '/account/delete', '/customers-other', '/credit/estimate']) publishFinancialChange(target, path, 'POST', feature => features.push(feature));
    assert.equal(changes, 0); assert.deepEqual(features, []);
});
