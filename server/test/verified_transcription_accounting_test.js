'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {MonthlyUsageOwner}=require('../monthly_usage_owner');const {database,proof}=require('./media_fixture');
const request=(id,ms=900000)=>({operationId:id,kinds:['transcription'],maximumMs:ms,verifiedMediaOnly:true});
for(const ms of [1000,20000,59000,60000,899000,900000])test(`verified ${ms} only is reserved and consumed`,async()=>{
 const owner=new MonthlyUsageOwner({db:database()});const r=await owner.reserve('A',request('one'));
 assert.equal((await owner.balance('A')).remainingMs,900000);
 const p=await proof(ms);await owner.claimExecution('A',r,0,p);
 const held=await owner.balance('A');assert.equal(held.reservedMs,ms);assert.equal(held.usedMs,0);
 await owner.completeExecution('A',r);await owner.completeExecution('A',r);
 assert.equal((await owner.finish('A',{...r,actualMs:0,success:false})).chargedMs,ms);
 const balance=await owner.balance('A');assert.equal(balance.usedMs,ms);assert.equal(balance.reservedMs,0);assert.equal(balance.remainingMs,900000-ms);
});
test('unexecuted intent and forged client duration never charge or refund',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});const r=await owner.reserve('A',request('one'));
 await assert.rejects(owner.claimExecution('A',r,0,{durationMs:1}),/PROOF/);
 await assert.rejects(owner.claimExecution('B',r,0,await proof(1000)),/OWNED/);
 assert.equal((await owner.finish('A',{...r,actualMs:800000,success:true})).chargedMs,0);
 assert.equal((await owner.balance('A')).remainingMs,900000);
});
test('concurrent actual media cannot overspend; duplicate execution holds once',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});const a=await owner.reserve('A',request('a')),b=await owner.reserve('A',request('b'));
 const p=await proof(600000);const results=await Promise.allSettled([owner.claimExecution('A',a,0,p),owner.claimExecution('A',b,0,p)]);
 assert.equal(results.filter(x=>x.status==='fulfilled').length,1);
 assert.equal(results.filter(x=>x.status==='rejected')[0].reason.message,'TRANSCRIPTION_LIMIT_REACHED');
 const winner=results[0].status==='fulfilled'?a:b;assert.equal((await owner.claimExecution('A',winner,0,p)).claimed,false);
 assert.equal((await owner.balance('A')).reservedMs,600000);
});
test('manual base split is settled once using verified duration',async()=>{
 const db=database();const owner=new MonthlyUsageOwner({db});
 db.records.set('adminManualCredits/c',{userId:'A',status:'ACTIVE',amountSeconds:300,remainingSeconds:300,reservedSeconds:0,expiresAt:null});
 const first=await owner.reserve('A',request('base'));await owner.claimExecution('A',first,0,await proof(899000));await owner.completeExecution('A',first);
 const r=await owner.reserve('A',request('mixed'));await owner.claimExecution('A',r,0,await proof(20000));
 assert.equal(db.records.get('usageReservations/'+r.id).baseReservedSeconds,1);assert.equal(db.records.get('usageReservations/'+r.id).manualReservedSeconds,19);
 await owner.completeExecution('A',r);await owner.completeExecution('A',r);
 assert.equal(db.records.get('adminManualCredits/c').remainingSeconds,281);assert.equal(db.records.get('adminManualCredits/c').reservedSeconds,0);
 assert.equal((await owner.balance('A')).remainingMs,281000);
});
test('preparatory media stage and execution share a single allocation',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});const r=await owner.reserve('A',request('stages'));const p=await proof(20000);
 await owner.authorizeMediaStage('A',r,0,p,'upload');await owner.claimExecution('A',r,0,p);await owner.completeExecution('A',r);
 assert.equal((await owner.balance('A')).usedMs,20000);
});
test('zero balance denies verified processing without charging an upload intent',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});const full=await owner.reserve('A',request('full'));
 await owner.claimExecution('A',full,0,await proof(900000));await owner.completeExecution('A',full);
 const next=await owner.reserve('A',request('next'));await assert.rejects(owner.claimExecution('A',next,0,await proof(20000)),/TRANSCRIPTION_LIMIT_REACHED/);
 assert.equal((await owner.finish('A',{...next,actualMs:20000,success:false})).chargedMs,0);
 assert.equal((await owner.balance('A')).usedMs,900000);
});
test('multiple verified segments settle exact total once in reverse completion order',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});const r=await owner.reserve('A',{...request('segments'),executionCount:2});
 await owner.claimExecution('A',r,0,await proof(20000,'first'));await owner.claimExecution('A',r,1,await proof(60000,'second'));
 await owner.completeExecution('A',r,1);await owner.completeExecution('A',r,0);await owner.completeExecution('A',r,1);
 const b=await owner.balance('A');assert.equal(b.usedMs,80000);assert.equal(b.reservedMs,0);assert.equal(b.remainingMs,820000);
});
