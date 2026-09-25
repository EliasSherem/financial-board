import test from 'node:test';
import assert from 'node:assert/strict';
import { assertLocalTarget,exactCents } from '../../scripts/backfill-investment-accounts.js';
test('legacy repair refuses non-local, production or implicit URL targets',()=>{
 assert.doesNotThrow(()=>assertLocalTarget({MYSQL_HOST:'127.0.0.1',MYSQL_DATABASE:'finsight_test'}));
 for(const env of [{MYSQL_HOST:'example.invalid',MYSQL_DATABASE:'finsight_test'},{MYSQL_HOST:'127.0.0.1',MYSQL_DATABASE:'finsight'},{MYSQL_HOST:'127.0.0.1',MYSQL_DATABASE:'finsight_staging',NODE_ENV:'production'},{MYSQL_HOST:'127.0.0.1',MYSQL_DATABASE:'finsight_test',MYSQL_URL:'mysql://forbidden'}])assert.throws(()=>assertLocalTarget(env),/LOCAL_OR_STAGING_TARGET_REQUIRED/);
});
test('legacy monetary arithmetic is exact cents including negatives and upper precision',()=>{
 assert.equal(exactCents('10.10')+exactCents('0.20'),1030n);assert.equal(exactCents('-0.01'),-1n);assert.equal(exactCents('9999999999999.99'),999999999999999n);assert.throws(()=>exactCents('1.001'));assert.throws(()=>exactCents('Infinity'));
});
