'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {hash}=require('../derivative_contract');
const {DerivativeR21Operations,DerivativeR21Worker,createDerivativeHandlers}=require('../derivative_r21_operations');
const {ExtractiveDerivativeEngine}=require('../extractive_derivative_engine');
class Store {
 constructor(){this.jobs=new Map();this.cache=new Map();this.claims=new Map();this.tail=Promise.resolve();}
 transaction(k,fn){const task=this.tail.then(()=>fn({read:async()=>structuredClone(this.jobs.get(k)),write:async v=>this.jobs.set(k,structuredClone(v))}));this.tail=task.catch(()=>{});return task;}
 async getCache(k){return this.cache.get(k);}
 async putCache(k,v){this.cache.set(k,v);}
 async claim(k,l){if(this.claims.has(k))return false;this.claims.set(k,l);return true;}
 async release(k,l){if(this.claims.get(k)===l)this.claims.delete(k);}
 async readyKeys(){return [...this.jobs.values()].filter(j=>['READY','CACHE_PENDING'].includes(j.status)).map(j=>j.operationKey);}
}
const request=()=>({sourceId:'s',operationId:'o',derivativeType:'ORGANIZATION',locale:'pt',rawTranscript:'Não usa Test-A.',transcriptHash:hash('Não usa Test-A.')});
function ops(store,engine=new ExtractiveDerivativeEngine()){return new DerivativeR21Operations({store,clinicalEngine:engine,enabled:true});}
test('create returns before generation; restarted worker processes durable queue',async()=>{
 const store=new Store();let calls=0;const e={generate:async i=>{calls++;return new ExtractiveDerivativeEngine().generate(i);}};
 const first=ops(store,e);const created=await first.create('owner',request());assert.equal(created.status,'READY');assert.equal(calls,0);
 const restarted=ops(store,e);await new DerivativeR21Worker(restarted).tick();assert.equal(calls,1);
 assert.equal((await restarted.status('owner',created.operationKey)).status,'COMPLETED');
 assert.equal(store.jobs.get(created.operationKey).input.rawTranscript,request().rawTranscript);
});
test('repeated operation is idempotent; changed source under same operation conflicts',async()=>{
 const o=ops(new Store());const a=await o.create('owner',request());const b=await o.create('owner',request());assert.equal(a.operationKey,b.operationKey);
 await assert.rejects(o.create('owner',{...request(),rawTranscript:'changed',transcriptHash:hash('changed')}),{code:'operation_conflict'});
});
test('status enforces owner isolation and excludes source and ledger',async()=>{
 const o=ops(new Store());const a=await o.create('owner',request());await assert.rejects(o.status('other',a.operationKey),{code:'not_found'});
 const status=await o.status('owner',a.operationKey);assert.equal(JSON.stringify(status).includes('Não usa'),false);assert.equal(status.input,undefined);
});
test('cache recovers a new operation without generating twice',async()=>{
 const store=new Store();let calls=0;const o=ops(store,{generate:async i=>{calls++;return new ExtractiveDerivativeEngine().generate(i);}});
 const a=await o.create('owner',request());await o.process(a.operationKey);
 const b=await o.create('owner',{...request(),operationId:'other'});assert.equal(b.status,'COMPLETED');await o.process(b.operationKey);assert.equal(calls,1);
});
test('lost worker outcome is not retried automatically',async()=>{
 const store=new Store();const o=ops(store);const a=await o.create('owner',request());await o.update(a.operationKey,j=>({...j,status:'PROCESSING'}));
 await o.recoverInterrupted(a.operationKey);assert.equal((await o.status('owner',a.operationKey)).status,'RECONCILIATION_REQUIRED');
 await new DerivativeR21Worker(o).tick();assert.equal((await o.status('owner',a.operationKey)).status,'RECONCILIATION_REQUIRED');
});
test('cache write failure is recovered from persisted result after restart',async()=>{
 const store=new Store();let calls=0;let fail=true;const put=store.putCache.bind(store);store.putCache=async(k,v)=>{if(fail)throw Error('save');return put(k,v);};
 const e={generate:async i=>{calls++;return new ExtractiveDerivativeEngine().generate(i);}};const o=ops(store,e);
 const a=await o.create('owner',request());await assert.rejects(o.process(a.operationKey));assert.equal(store.claims.size,1);
 fail=false;await new DerivativeR21Worker(ops(store,e)).tick();assert.equal(calls,1);assert.equal(store.claims.size,0);assert.equal((await o.status('owner',a.operationKey)).status,'COMPLETED');
});
test('HTTP handler gets owner from trusted auth, not request body; no source in response',async()=>{
 const o=ops(new Store());const h=createDerivativeHandlers({operations:o,authenticate:async()=> 'authenticated-owner'});
 let status;let body;const res={status:s=>{status=s;return res;},json:v=>body=v};
 await h.create({body:{...request(),ownerUid:'attacker'}},res);assert.equal(status,202);
 assert.equal((await o.status('authenticated-owner',body.operationKey)).status,'READY');assert.equal(JSON.stringify(body).includes('Não usa'),false);
});
test('readback binds transcript, type, source, locale and operation key',async()=>{
 const o=ops(new Store());const r=request();const a=await o.create('owner',r);
 const status=await o.status('owner',a.operationKey);
 for(const k of ['transcriptHash','derivativeType','sourceId','locale','operationId'])assert.equal(status[k],r[k]);
 assert.equal(status.operationKey,a.operationKey);
});
test('manual retry is bounded, owner isolated and respects provider retry time',async()=>{
 const store=new Store();const o=ops(store);const a=await o.create('owner',request());
 await o.update(a.operationKey,j=>({...j,status:'FAILED_RETRYABLE',nextAttemptAt:Date.now()+60000}));
 await assert.rejects(o.retry('other',a.operationKey),{code:'not_found'});
 await assert.rejects(o.retry('owner',a.operationKey),{code:'retry_not_due'});
 await o.update(a.operationKey,j=>({...j,nextAttemptAt:0}));
 assert.equal((await o.retry('owner',a.operationKey)).status,'READY');
 assert.equal(store.jobs.get(a.operationKey).retryCount,1);
 await o.retry('owner',a.operationKey);assert.equal(store.jobs.get(a.operationKey).retryCount,1);
 await o.update(a.operationKey,j=>({...j,status:'FAILED_RETRYABLE',retryCount:3}));
 await assert.rejects(o.retry('owner',a.operationKey),{code:'retry_exhausted'});
});
test('worker cannot bypass manual retry or unknown-outcome reconciliation',async()=>{
 const store=new Store();let calls=0;const o=ops(store,{generate:async()=>{calls++;throw Error('unexpected');}});
 const a=await o.create('owner',request());
 for(const status of ['FAILED_RETRYABLE','FAILED_NONRETRYABLE','RECONCILIATION_REQUIRED']) {
  await o.update(a.operationKey,j=>({...j,status}));await o.process(a.operationKey);
  assert.equal(calls,0);
  if(status!=='FAILED_RETRYABLE')await assert.rejects(o.retry('owner',a.operationKey),{code:'retry_not_safe'});
 }
});
test('retry after completion reads preserved result without another engine call',async()=>{
 const store=new Store();let calls=0;const o=ops(store,{generate:async i=>{calls++;return new ExtractiveDerivativeEngine().generate(i);}});
 const a=await o.create('owner',request());await o.process(a.operationKey);
 const before=await o.status('owner',a.operationKey);const after=await o.retry('owner',a.operationKey);
 assert.deepEqual(after,before);assert.equal(calls,1);
});
test('late lease after stale empty cache cannot generate a second time',async()=>{
 const store=new Store();let calls=0;const o=ops(store,{generate:async i=>{calls++;return new ExtractiveDerivativeEngine().generate(i);}});
 const a=await o.create('owner',request());
 const originalClaim=store.claim.bind(store);let intercepted=false;
 store.claim=async(k,lease)=>{
  if(!intercepted){intercepted=true;await o.process(a.operationKey);}
  return originalClaim(k,lease);
 };
 await o.process(a.operationKey);
 assert.equal(calls,1);assert.equal((await o.status('owner',a.operationKey)).status,'COMPLETED');
});
