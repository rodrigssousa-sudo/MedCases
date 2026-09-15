'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const rules = fs.readFileSync(
  path.resolve(__dirname, '../../firestore.rules'),
  'utf8',
);

assert.equal(
  (rules.match(/MEDCASES_FIRESTORE_ROOT_STRUCTURE_REPAIR_V1_B_R0/g) || []).length,
  1,
);
assert.equal(
  (rules.match(/match \/databases\/\{database\}\/documents \{/g) || []).length,
  1,
);
assert.equal(
  (rules.match(/^\s*\}\/documents \{/gm) || []).length,
  0,
);
assert.ok(
  rules.includes(
    'MEDCASES_COMMERCE_F10_2_SERVER_MANAGED_ENTITLEMENT_RULES_V1_B_R0',
  ),
);
assert.ok(rules.includes('function isWritingCommerceEntitlementFields()'));
assert.ok(rules.includes('function hasSafeInitialCommerceEntitlement()'));
assert.ok(rules.includes('function isSafeClientCommerceEntitlementRepair()'));

for (const field of [
  'plan',
  'subscriptionStatus',
  'subscriptionProvider',
  'subscriptionStore',
  'subscriptionProductId',
  'subscriptionEntitlementId',
  'subscriptionExpiresAt',
  'subscriptionUpdatedAt',
  'subscriptionEventId',
  'revenueCatAppUserId',
  'revenueCatEnvironment',
]) {
  assert.ok(rules.includes(`'${field}'`), `missing commerce field: ${field}`);
}

assert.match(
  rules,
  /allow create: if isAuthed\(\)\s*&& request\.auth\.uid == userId\s*&& hasSafeInitialCommerceEntitlement\(\);/,
);
assert.match(
  rules,
  /!isWritingCommerceEntitlementFields\(\)\s*\|\|\s*isSafeClientCommerceEntitlementRepair\(\)/,
);
assert.ok(
  rules.includes("request.resource.data.get('plan', 'free') == 'free'"),
);
assert.ok(
  rules.includes(
    "request.resource.data.get('subscriptionStatus', 'trial') == 'trial'",
  ),
);
assert.ok(
  rules.includes(
    "resource.data.get('plan', '__missing__') == '__missing__'",
  ),
);
assert.ok(
  rules.includes(
    "resource.data.get('subscriptionStatus', '__missing__') == '__missing__'",
  ),
);

console.log('ROOT_FIRESTORE_STRUCTURE_REPAIR_CONTRACT=PASS');
console.log('F10_2_COMMERCE_ENTITLEMENT_RULES_CONTRACT=PASS');
console.log('CLIENT_CREATE_PREMIUM_SELF_ESCALATION=BLOCKED_BY_CONTRACT');
console.log('CLIENT_UPDATE_PREMIUM_SELF_ESCALATION=BLOCKED_BY_CONTRACT');
console.log('LEGACY_FREE_TRIAL_REPAIR=PRESERVED_BY_CONTRACT');
