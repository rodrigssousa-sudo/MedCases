'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {DerivativeRollout,createDerivativeRuntime}=require('../derivative_r24_runtime');
const {hash}=require('../derivative_contract');
const {ExtractiveDerivativeEngine}=require('../extractive_derivative_engine');
class Store {
 constructor(){this.jobs=new Map();this.cache=new Map();this.claims=new Map();this.tail=Promise.resolve();}
 transaction(k,fn){const p=this.tail.then(()=>fn({read:async()=>structuredClone(this.jobs.get(k)),write:async v=>this.jobs.set(k,structuredClone(v))}));this.tail=p.catch(()=>{});return p;}
 async getCache(k){return this.cache.get(k);}
 async putCache(k,v){this.cache.set(k,v);}
 async claim(k,v){if(this.claims.has(k))return false;this.claims.set(k,v);return true;}
 async release(k,v){if(this.claims.get(k)===v)this.claims.delete(k);}
 async readyKeys(){return [...this.jobs.values()].filter(j=>['READY','CACHE_PENDING'].includes(j.status)).map(j=>j.operationKey);}
}
const request=(type='ORGANIZATION')=>({sourceId:'source',operationId:type,derivativeType:type,locale:'pt',rawTranscript:'Texto fictício.',transcriptHash:hash('Texto fictício.')});
function capture(){let body,status;const res={status(s){status=s;return res;},json(v){body=v;}};return {res,get body(){return body;},get status(){return status;}};}
const rollout=()=>new DerivativeRollout({approvedTypes:['ANAMNESIS','EVOLUTION','ORGANIZATION','VISUAL_SUMMARY'],internalUids:['u'],routes:Object.fromEntries(['ANAMNESIS','EVOLUTION','ORGANIZATION','VISUAL_SUMMARY'].map(t=>[t,{stage:'internal'}]))});
test('all derivatives default off and an unapproved route cannot be enabled by full rollout',()=>{
 assert.equal(new DerivativeRollout().enabled('u','SUMMARY'),false);
 assert.equal(new DerivativeRollout({routes:{SUMMARY:{stage:'full'}}}).enabled('u','SUMMARY'),false);
 assert.equal(rollout().enabled('other','ORGANIZATION'),false);
});
test('internal and limited cohorts are deterministic; rollback disables all creates',()=>{
 const config={approvedTypes:['SUMMARY'],internalUids:['u'],routes:{SUMMARY:{stage:'limited',percent:1}}};
 const a=new DerivativeRollout(config),b=new DerivativeRollout(config);
 assert.equal(a.enabled('u','SUMMARY'),true);
 for(let i=0;i<100;i++)assert.equal(a.enabled('test'+i,'SUMMARY'),b.enabled('test'+i,'SUMMARY'));
 a.routes.SUMMARY.stage='off';assert.equal(a.enabled('u','SUMMARY'),false);
});
test('actual clinical engine runs after HTTP create, with durable readback and owner isolation',async()=>{
 const store=new Store();const runtime=createDerivativeRuntime({store,rollout:rollout(),readUser:async()=>({})});
 const c=capture();await runtime.handlers.create({auth:{uid:'u'},body:{...request(),ownerUid:'forged'}},c.res);
 assert.equal(c.status,202);assert.equal(c.body.status,'READY');
 await runtime.tick();
 const s=capture();await runtime.handlers.status({auth:{uid:'u'},params:{operationKey:c.body.operationKey}},s.res);
 assert.equal(s.status,200);assert.equal(s.body.status,'COMPLETED');
 const wrong=capture();await runtime.handlers.status({auth:{uid:'forged'},params:{operationKey:c.body.operationKey}},wrong.res);assert.equal(wrong.status,404);
});
test('premium decisions use canonical server entitlement and ignore body tier',async()=>{
 const runtime=createDerivativeRuntime({store:new Store(),studyEngine:{},rollout:rollout(),readUser:async()=>({plan:'premium',billingEntitlementActive:false})});
 const c=capture();await runtime.handlers.create({auth:{uid:'u'},body:{...request('VISUAL_SUMMARY'),tier:'premium'}},c.res);
 assert.equal(c.status,403);assert.equal(c.body.error,'premium_required');
});
test('concurrent worker ticks do not duplicate or crosswrite clinical results',async()=>{
 const store=new Store();let calls=0;const engine={generate:async input=>{calls++;return new ExtractiveDerivativeEngine().generate(input);}};
 const runtime=createDerivativeRuntime({store,rollout:rollout(),clinicalEngine:engine});
 const keys=[];
 for(const type of ['ANAMNESIS','EVOLUTION','ORGANIZATION'])keys.push((await runtime.operations.create('u',request(type))).operationKey);
 await Promise.all([runtime.tick(),runtime.tick()]);assert.equal(calls,3);
 for(const key of keys)assert.equal((await runtime.operations.status('u',key)).status,'COMPLETED');
});
test('rollback holds queued jobs but preserves completed readback',async()=>{
 const flag=rollout(),runtime=createDerivativeRuntime({store:new Store(),rollout:flag});
 const a=await runtime.operations.create('u',request());await runtime.tick();
 const b=await runtime.operations.create('u',request('EVOLUTION'));
 flag.routes.EVOLUTION.stage='off';await runtime.tick();
 assert.equal((await runtime.operations.status('u',a.operationKey)).status,'COMPLETED');
 assert.equal((await runtime.operations.status('u',b.operationKey)).status,'READY');
});
test('unauthenticated requests cannot create jobs',async()=>{
 const runtime=createDerivativeRuntime({store:new Store(),rollout:rollout()});const c=capture();
 await runtime.handlers.create({body:request()},c.res);assert.equal(c.status,401);
});

for(const status of ['FAILED_NONRETRYABLE','RECONCILIATION_REQUIRED','FAILED_RETRYABLE'])test('summary dependency '+status+' does not spin forever',async()=>{
 const studyEngine={},store=new Store(),flags=new DerivativeRollout({approvedTypes:['SUMMARY','KEY_POINTS'],routes:{SUMMARY:{stage:'full'},KEY_POINTS:{stage:'full'}}});
 const runtime=createDerivativeRuntime({store,studyEngine,rollout:flags});
 runtime.operations.create=async()=>({status});
 await assert.rejects(studyEngine.resolveSummary({...request('KEY_POINTS'),ownerUid:'u'}),e=>e.code===(status==='FAILED_RETRYABLE'?'summary_dependency_retry_required':'summary_dependency_failed'));
});
test('disabled summary dependency never queues hidden provider work',async()=>{
 const studyEngine={},store=new Store();createDerivativeRuntime({store,studyEngine});
 await assert.rejects(studyEngine.resolveSummary({...request('KEY_POINTS'),ownerUid:'u'}),e=>e.code==='summary_dependency_disabled');
 assert.equal(store.jobs.size,0);
});
