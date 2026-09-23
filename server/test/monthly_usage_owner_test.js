const {proof}=require('./media_fixture');
'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {MonthlyUsageOwner}=require('../monthly_usage_owner');
// A shared serial transaction adapter models two independent server workers.
// Firestore production uses runTransaction; no emulator/deployment is claimed.
function database(){const records=new Map([['users/A',{plan:'free'}],['users/B',{plan:'premium'}]]);let queue=Promise.resolve();
 return {records,collection:name=>({doc:id=>`${name}/${id}`}),runTransaction(action){const run=queue.then(async()=>{const staged=new Map();const result=await action({get:async ref=>({exists:records.has(ref),data:()=>structuredClone(records.get(ref))}),set:(ref,data)=>staged.set(ref,structuredClone(data))});for(const [k,v]of staged)records.set(k,v);return result;});queue=run.catch(()=>{});return run;}};}
const req=(operationId,maximumMs=60000)=>({operationId,maximumMs,kinds:['recording']});
test('two server workers cannot exceed account quota; preferences/reinstall are irrelevant',async()=>{
 const db=database();const a=new MonthlyUsageOwner({db}),b=new MonthlyUsageOwner({db});
 const results=await Promise.all(Array.from({length:20},(_,i)=>(i%2?a:b).reserve('A',req(`device-${i}`)).then(()=>true,()=>false)));assert.equal(results.filter(Boolean).length,15);
});
test('client cancellation cannot refund; terminal operation never reopens',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});const r=await owner.reserve('A',req('job',900000));
 const result=await owner.finish('A',{...r,actualMs:0,success:false});assert.equal(result.chargedMs,900000);
 const retry=await owner.reserve('A',req('job',900000));assert.equal(r.attempt,retry.attempt);assert.equal(retry.state,'completed');
 await assert.rejects(owner.finish('A',{...r,attempt:'old',actualMs:1,success:true}),/STALE/);
 await assert.rejects(owner.finish('B',{...r,actualMs:1,success:true}),/NOT_OWNED/);
 assert.deepEqual(await owner.finish('A',{...r,actualMs:60000,success:true}),result);
 await assert.rejects(owner.reserve('A',req('over',1)),/LIMIT/);
});
test('idempotent concurrent retry, monthly rollover and original-bucket completion',async()=>{
 let now=Date.UTC(2026,8,30);const owner=new MonthlyUsageOwner({db:database(),now:()=>now});
 const [a,b]=await Promise.all([owner.reserve('A',req('same',900000)),owner.reserve('A',req('same',900000))]);assert.equal(a.attempt,b.attempt);
 now=Date.UTC(2026,9,1);await owner.reserve('A',req('same',900000));await owner.finish('A',{...a,actualMs:60000,success:true});await assert.rejects(owner.reserve('A',req('oct-over',1)),/LIMIT/);
});
test('Premium limits and invalid payloads are server-owned',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});await owner.reserve('B',req('paid',240*60000));await assert.rejects(owner.reserve('B',req('paid-over',1)),/LIMIT/);
 await owner.reserve('B',{...req('trans',90*60000),kinds:['transcription']});await assert.rejects(owner.reserve('A',req('negative',-1)),/INVALID/);
 await assert.rejects(owner.reserve('A',{...req('bad'),kinds:['invented']}),/INVALID/);
});
for(const state of ['TRIAL','PAID','CANCELLED_STILL_ACTIVE','EXPIRED'])test(`sovereign billing state ${state} controls account quota`,async()=>{
 const db=database(),now=Date.UTC(2026,8,21);
 db.records.set('users/A',{plan:'premium',subscriptionStatus:state.toLowerCase(),
  billingEntitlementActive:true,billingEntitlementId:'medcases_pro_premium',billingEntitlementExpiresAtMs:now+(state==='EXPIRED'?-1:7200000)});
 const owner=new MonthlyUsageOwner({db,now:()=>now});const minutes=state==='EXPIRED'?15:240;
 await owner.reserve('A',req('limit',minutes*60000));await assert.rejects(owner.reserve('A',req('overflow',1)),/LIMIT/);
});
test('Free transcription limit is 30 minutes, independent of device',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});await owner.reserve('A',{...req('trans',30*60000),kinds:['transcription']});
 await assert.rejects(owner.reserve('A',{...req('overflow',1),kinds:['transcription']}),/LIMIT/);
});

test('execution slots are atomic, bounded, shared across providers and never refunded by client',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});
 const r=await owner.reserve('A',{...req('audio',900000),kinds:['transcription'],executionCount:2});
 const media=await proof();
 const claims=await Promise.all([owner.claimExecution('A',r,0,media),owner.claimExecution('A',r,0,media)]);
 assert.equal(claims.filter(c=>c.claimed).length,1);
 assert.equal((await owner.finish('A',{...r,actualMs:0,success:false})).chargedMs,900000);
 await assert.rejects(owner.claimExecution('B',r,1),/NOT_OWNED/);
 await assert.rejects(owner.claimExecution('A',{...r,attempt:'stale'},1),/STALE/);
 await assert.rejects(owner.claimExecution('A',r,2),/NOT_AUTHORIZED/);
 await assert.rejects(owner.failBeforeExecution('A',r),/BILLABLE/);
 await owner.completeExecution('A',r,0);await owner.completeExecution('A',r,0);
 assert.equal((await owner.claimExecution('A',r,1,media)).claimed,true);
 assert.equal((await owner.completeExecution('A',r,1)).state,'completed');
 assert.equal((await owner.claimExecution('A',r,0)).claimed,false);
});
test('server verified failure before work can release, but never reopen attempt',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});const r=await owner.reserve('A',req('failed',900000));
 assert.equal((await owner.failBeforeExecution('A',r)).chargedMs,0);
 assert.equal((await owner.reserve('A',req('failed',900000))).state,'server_verified_failed');
 await assert.rejects(owner.claimExecution('A',r),/NOT_AUTHORIZED/);
 await owner.reserve('A',req('new',900000));
});
