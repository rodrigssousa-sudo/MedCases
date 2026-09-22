'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {resolveMedCasesTier, issueCalculatorSession, capabilitiesForTier} = require('../calculator_entitlement_session');
const now=2000000000000;
const active={billingEntitlementActive:true,billingEntitlementId:'medcases_pro_premium',billingEntitlementExpiresAtMs:now+60000};
test('store trial equals paid and cancelled-but-active; SDK labels never grant',()=>{
 const trial=resolveMedCasesTier({...active,subscriptionStatus:'trial'},now);
 const paid=resolveMedCasesTier({...active,subscriptionStatus:'paid'},now);
 const cancelled=resolveMedCasesTier({...active,subscriptionStatus:'cancelled'},now);
 assert.equal(trial.tier,'premium');assert.deepEqual(capabilitiesForTier(trial.tier),capabilitiesForTier(paid.tier));assert.equal(cancelled.tier,'premium');
 assert.equal(resolveMedCasesTier({subscriptionStatus:'trial'},now).tier,'free');
});
test('expired/revoked/invalid billing outranks stale legacy plan',()=>{
 for(const patch of [{billingEntitlementActive:false},{billingEntitlementExpiresAtMs:now},{billingEntitlementId:'wrong'},{billingEntitlementExpiresAtMs:'NaN'}])
 assert.equal(resolveMedCasesTier({...active,plan:'premium',subscriptionStatus:'active',...patch},now).tier,'free');
});
test('signed premium cannot outlive billing expiration; no clinical capabilities minted',()=>{
 const issued=issueCalculatorSession({uid:'A',userDoc:active,secret:'test-only-secret-for-entitlement-matrix-0123456789',nowEpoch:now/1000});
 assert.equal(issued.claims.exp,active.billingEntitlementExpiresAtMs/1000);
 for(const cap of ['calculationAuthorized','infusionAuthority','pediatricAuthority','doseAuthority']) assert.equal(issued.claims.cap.includes(cap),false);
});
