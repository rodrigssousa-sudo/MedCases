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
test('failed/cancelled retry, old callback, duplicate result and UID isolation',async()=>{
 const owner=new MonthlyUsageOwner({db:database()});let r=await owner.reserve('A',req('job',900000));
 await owner.finish('A',{...r,actualMs:1,success:false});const retry=await owner.reserve('A',req('job',900000));assert.notEqual(r.attempt,retry.attempt);
 await assert.rejects(owner.finish('A',{...r,actualMs:1,success:true}),/STALE/);
 await assert.rejects(owner.finish('B',{...retry,actualMs:1,success:true}),/NOT_OWNED/);
 const result=await owner.finish('A',{...retry,actualMs:60000,success:true});assert.equal(result.chargedMs,60000);
 assert.deepEqual(await owner.finish('A',{...retry,actualMs:60000,success:true}),result);
 await owner.reserve('A',req('remaining',840000));await assert.rejects(owner.reserve('A',req('over',1)),/LIMIT/);
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
