'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {resolveMedCasesTier,issueCalculatorSession}=require('../calculator_entitlement_session');
const now=Date.now(),grant={active:true,source:'admin_manual_v1',expiresAt:now+60000};
test('manual grant is effective with inactive billing without changing base allowance definitions',()=>{
 assert.equal(resolveMedCasesTier({billingEntitlementActive:false,entitlements:{adminPremium:grant}},now).tier,'premium');
 assert.equal(resolveMedCasesTier({entitlements:{adminVip:{...grant,expiresAt:null}}},now).tier,'premium');
});
test('expired, invalid or revoked manual grants never grant access',()=>{
 for(const g of [{...grant,active:false},{...grant,expiresAt:now},{...grant,expiresAt:'9999999999999'},{...grant,expiresAt:Infinity},{...grant,source:'client'},{active:true}])assert.equal(resolveMedCasesTier({entitlements:{adminPremium:g}},now).tier,'free');
});
test('revoking manual access preserves a valid purchased subscription',()=>{
 assert.equal(resolveMedCasesTier({billingEntitlementActive:true,billingEntitlementId:'medcases_pro_premium',billingEntitlementExpiresAtMs:now+60000,entitlements:{adminPremium:{...grant,active:false}}},now).source,'server_revenuecat_entitlement');
});
test('manual session expires no later than grant and never extends offline access',()=>{
 const epoch=Math.floor(now/1000),expiresAt=(epoch+20)*1000;
 const s=issueCalculatorSession({uid:'synthetic',userDoc:{entitlements:{adminPremium:{...grant,expiresAt}}},secret:'x'.repeat(64),nowEpoch:epoch});
 assert.equal(s.claims.exp,epoch+20);assert.equal(s.entitlementSource,'server_admin_manual');
});
