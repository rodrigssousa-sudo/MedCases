'use strict';

const assert = require('node:assert/strict');

const {
  FREE_CAPABILITIES,
  PREMIUM_CAPABILITIES,
  resolveMedCasesTier,
  issueCalculatorSession,
  verifyCalculatorSession,
} = require('../calculator_entitlement_session');

const SECRET =
  'test-only-medcases-calculator-session-secret-0123456789abcdef';
const NOW = 2_000_000_000;

function expectThrow(fn, code) {
  assert.throws(fn, (err) => {
    assert.equal(err.message, code);
    return true;
  });
}

assert.equal(resolveMedCasesTier({ plan: 'free' }).tier, 'free');
assert.equal(
  resolveMedCasesTier({
    plan: 'free',
    subscriptionStatus: 'trial',
  }).tier,
  'free',
);
assert.equal(
  resolveMedCasesTier({ plan: 'premium' }).tier,
  'premium',
);
assert.equal(
  resolveMedCasesTier({
    plan: 'free',
    subscriptionStatus: 'trial',
    billingEntitlementActive: true,
    billingEntitlementId: 'medcases_pro_premium',
    billingEntitlementExpiresAtMs: (NOW * 1000) + 60_000,
  }, NOW * 1000).tier,
  'premium',
);
assert.equal(
  resolveMedCasesTier({
    plan: 'free',
    subscriptionStatus: 'trial',
    billingEntitlementActive: true,
    billingEntitlementId: 'medcases_pro_premium',
    billingEntitlementExpiresAtMs: (NOW * 1000) - 1,
  }, NOW * 1000).tier,
  'free',
);

const freeIssued = issueCalculatorSession({
  uid: 'uid-free-1',
  userDoc: {
    plan: 'free',
    subscriptionStatus: 'trial',
  },
  secret: SECRET,
  nowEpoch: NOW,
  sessionId: 'session-free-1',
});

assert.deepEqual(
  freeIssued.claims.cap,
  [...FREE_CAPABILITIES],
);
assert.equal(
  freeIssued.entitlementSource,
  'trial_not_authoritative_for_premium',
);

const freeClaims = verifyCalculatorSession(
  freeIssued.accessToken,
  {
    secret: SECRET,
    nowEpoch: NOW + 30,
  },
);

assert.equal(freeClaims.tier, 'free');
assert.equal(
  freeClaims.cap.includes('drug_catalog_full'),
  false,
);
assert.equal(
  freeClaims.cap.includes('dose_by_weight'),
  false,
);
assert.equal(
  freeClaims.cap.includes('renal_adjustment'),
  false,
);

const premiumIssued = issueCalculatorSession({
  uid: 'uid-premium-1',
  userDoc: {
    plan: 'premium',
    subscriptionStatus: 'active',
  },
  secret: SECRET,
  nowEpoch: NOW,
  sessionId: 'session-premium-1',
});

assert.deepEqual(
  premiumIssued.claims.cap,
  [...PREMIUM_CAPABILITIES],
);

const premiumClaims = verifyCalculatorSession(
  premiumIssued.accessToken,
  {
    secret: SECRET,
    nowEpoch: NOW + 30,
  },
);

assert.equal(
  premiumClaims.cap.includes('drug_catalog_full'),
  true,
);
assert.equal(
  premiumClaims.cap.includes('dose_by_weight'),
  true,
);
assert.equal(
  premiumClaims.cap.includes('renal_adjustment'),
  true,
);

const tampered =
  premiumIssued.accessToken.slice(0, -1) +
  (premiumIssued.accessToken.endsWith('A') ? 'B' : 'A');

expectThrow(
  () => verifyCalculatorSession(tampered, {
    secret: SECRET,
    nowEpoch: NOW + 30,
  }),
  'CALCULATOR_SESSION_BAD_SIGNATURE',
);

expectThrow(
  () => verifyCalculatorSession(
    freeIssued.accessToken,
    {
      secret: SECRET,
      nowEpoch: NOW + 601,
    },
  ),
  'CALCULATOR_SESSION_EXPIRED',
);

console.log('APP_SIGNED_SESSION_CONTRACT_TEST=PASS');
console.log('TRIAL_DOES_NOT_GRANT_PREMIUM=PASS');
console.log('SERVER_BACKED_REVENUECAT_TRIAL_GRANTS_PREMIUM=PASS');
console.log('EXPIRED_REVENUECAT_ENTITLEMENT_FAILS_CLOSED=PASS');
console.log('FREE_CAPABILITIES_CONTRACT=PASS');
console.log('PREMIUM_CAPABILITIES_CONTRACT=PASS');
console.log('TOKEN_TAMPER_REJECTION=PASS');
console.log('TOKEN_EXPIRY_REJECTION=PASS');
