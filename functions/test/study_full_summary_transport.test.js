'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {utilityOutputBudget}=require('../study_full_summary_transport');
test('complete summary preserves requested 6500 tokens in contingency',()=>assert.equal(utilityOutputBudget({mode:'estudo',studyFullSummaryVersion:'study-full-summary-v1',maxOutputTokens:6500}),6500));
test('complete summary remains capped',()=>assert.equal(utilityOutputBudget({mode:'estudo',studyFullSummaryVersion:'study-full-summary-v1',maxOutputTokens:12000}),8192));
test('Plantao cannot select summary budget',()=>assert.equal(utilityOutputBudget({mode:'plantao',studyFullSummaryVersion:'study-full-summary-v1',maxOutputTokens:6500}),2048));
test('other Study consumers keep old budget',()=>{for(const kind of [undefined,'study-visual-v1','invalid'])assert.equal(utilityOutputBudget({mode:'estudo',studyFullSummaryVersion:kind,maxOutputTokens:6500}),2048);});
test('canonical chat budget has precedence',()=>assert.equal(utilityOutputBudget({mode:'estudo',studyFullSummaryVersion:'study-full-summary-v1',maxOutputTokens:6500},4096),4096));
test('nonfinite values never reach provider',()=>{for(const value of [NaN,Infinity,-Infinity,'bad'])assert.equal(utilityOutputBudget({mode:'estudo',studyFullSummaryVersion:'study-full-summary-v1',maxOutputTokens:value}),800);});
