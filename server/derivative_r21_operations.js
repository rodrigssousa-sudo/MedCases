'use strict';
const {randomUUID}=require('node:crypto');
const {hash,DerivativeError}=require('./derivative_contract');
const {DerivativePolicy}=require('./derivative_policy');
const {TranscriptFactLedger}=require('./transcript_fact_ledger');
const VERSION='r21_operations_v1';
class DerivativeR21Operations {
 constructor({store,policy=new DerivativePolicy(),clinicalEngine,studyEngine,enabled=false}) {Object.assign(this,{store,policy,clinicalEngine,studyEngine,enabled});}
 async create(ownerUid,request) {
  if(!this.enabled)throw new DerivativeError('derivative_engine_disabled');
  if(typeof ownerUid!=='string'||!ownerUid||!request||!['sourceId','operationId'].every(k=>typeof request[k]==='string'&&request[k].length>0&&request[k].length<=256)||
    typeof request.rawTranscript!=='string'||Buffer.byteLength(request.rawTranscript)>250000||hash(request.rawTranscript)!==request.transcriptHash)throw new DerivativeError('invalid_input');
  const input={ownerUid,sourceId:request.sourceId,operationId:request.operationId,rawTranscript:request.rawTranscript,
   transcriptHash:request.transcriptHash,derivativeType:request.derivativeType,locale:request.locale,
   profile:request.profile,knowledgeMode:request.knowledgeMode,promptVersion:VERSION};
  const policy=this.policy.resolve(input);const ledger=TranscriptFactLedger.extract(input.rawTranscript);
  const operationKey=hash(JSON.stringify([ownerUid,input.sourceId,input.operationId,input.derivativeType,policy.profile,VERSION]));
  const cacheKey=DerivativePolicy.cacheKey(input,policy);
  await this.store.transaction(operationKey,async tx=>{
   const previous=await tx.read();
   if(previous){if(previous.cacheKey!==cacheKey)throw new DerivativeError('operation_conflict');return;}
   await tx.write({operationKey,cacheKey,ownerUid,status:'READY',input:JSON.parse(JSON.stringify(input)),
    policy,ledgerHash:ledger.ledgerHash,result:null,errorCode:null,createdAt:Date.now()});
  });
  // No provider call, background promise, in-memory timer, or long HTTP here.
  return {operationKey,...await this.status(ownerUid,operationKey)};
 }
 async status(ownerUid,key) {
  const job=await this.store.transaction(key,async tx=>{const j=await tx.read();if(!j||j.ownerUid!==ownerUid)throw new DerivativeError('not_found');return j;});
  let result=job.result;let status=job.status;
  if(!result){const cached=await this.store.getCache(job.cacheKey);if(cached?.ledgerHash===job.ledgerHash){result=cached;status='COMPLETED';}}
  return {operationKey:key,transcriptHash:job.input.transcriptHash,locale:job.input.locale,operationId:job.input.operationId,sourceId:job.input.sourceId,derivativeType:job.input.derivativeType,status,
   errorCode:status==='COMPLETED'?null:job.errorCode,result:result?{structuredResult:result.structuredResult,profile:job.policy.profile}:null};
 }
 async retry(ownerUid,key) {
  if(!this.enabled)throw new DerivativeError('derivative_engine_disabled');
  await this.store.transaction(key,async tx=>{
   const job=await tx.read();
   if(!job||job.ownerUid!==ownerUid)throw new DerivativeError('not_found');
   if(job.status==='FAILED_RETRYABLE') {
    if((job.retryCount??0)>=3)throw new DerivativeError('retry_exhausted');
    if(job.nextAttemptAt>Date.now())throw new DerivativeError('retry_not_due',true);
    await tx.write({...job,status:'READY',retryCount:(job.retryCount??0)+1,errorCode:null});
   } else if(!['READY','PROCESSING','CACHE_PENDING','COMPLETED'].includes(job.status)) {
    throw new DerivativeError('retry_not_safe');
   }
  });
  return {operationKey:key,...await this.status(ownerUid,key)};
 }
 async process(key) {
  if(!this.enabled)throw new DerivativeError('derivative_engine_disabled');
  let job;await this.store.transaction(key,async tx=>{job=await tx.read();if(!job)throw new DerivativeError('not_found');});
  if(['COMPLETED','CACHE_PENDING'].includes(job.status)&&job.result){
   await this.store.putCache(job.cacheKey,job.result);
   await this.update(key,j=>({...j,status:'COMPLETED'}));
   if(job.lease)await this.store.release(job.cacheKey,job.lease);return;
  }
  const cached=await this.store.getCache(job.cacheKey);
  if(cached?.ledgerHash===job.ledgerHash){await this.update(key,j=>({...j,status:'COMPLETED',result:cached,errorCode:null}));return;}
  if(job.status!=='READY'||job.nextAttemptAt>Date.now())return;
  const lease=randomUUID();if(!await this.store.claim(job.cacheKey,lease))return;
  let release=true;
  try {
   // The cache may have been filled while this worker waited for a lease.
   // Recheck under the acquired lease to close the stale-read/late-claim window.
   const completed=await this.store.getCache(job.cacheKey);
   if(completed?.ledgerHash===job.ledgerHash){
    await this.update(key,j=>({...j,status:'COMPLETED',result:completed,errorCode:null}));
    return;
   }
   let acquired=false;
   await this.store.transaction(key,async tx=>{
    const current=await tx.read();
    if(current?.status!=='READY')return;
    job=current;acquired=true;
    await tx.write({...current,status:'PROCESSING',lease,startedAt:Date.now(),errorCode:null});
   });
   if(!acquired)return;
   const engine=job.policy.profile==='CLINICAL_DOCUMENTATION'?this.clinicalEngine:this.studyEngine;
   if(!engine)throw new DerivativeError('route_unavailable');
   if(engine.policy&&hash(JSON.stringify(engine.policy.resolve(job.input)))!==hash(JSON.stringify(job.policy)))throw new DerivativeError('route_revision_changed');
   const result=await engine.generate(job.input);
   if(result.grounding?.supported!==true||result.ledgerHash&&result.ledgerHash!==job.ledgerHash||result.grounding.ledgerHash!==job.ledgerHash)throw new DerivativeError('grounding_rejected');
   const persisted={...result,ledgerHash:job.ledgerHash};
   // Persist before cache. Retry of the save path uses this result, not provider.
   await this.update(key,j=>({...j,status:'CACHE_PENDING',result:persisted,completedAt:Date.now(),errorCode:null}));
   await this.store.putCache(job.cacheKey,persisted);
   await this.update(key,j=>({...j,status:'COMPLETED'}));
  }catch(e){
   const unknown=['generation_timeout','retryable_network_error','provider_outcome_unknown'].includes(e.code);
   release=!unknown;
   await this.store.transaction(key,async tx=>{if((await tx.read())?.result)release=false;});
   await this.update(key,j=>j.result?j:{...j,status:e.code==='derivative_dependency_pending'?'READY':unknown?'RECONCILIATION_REQUIRED':e.retryable?'FAILED_RETRYABLE':'FAILED_NONRETRYABLE',errorCode:e.code??'operation_failed',nextAttemptAt:Date.now()+Math.max(1000,e.metadata?.retryAfterMs??0)});
   throw e;
  }finally{if(release)await this.store.release(job.cacheKey,lease);}
 }
 async recoverInterrupted(key) {
  // A worker lost after sending a request must not silently bill it twice.
  await this.update(key,j=>j.status==='PROCESSING'?{...j,status:'RECONCILIATION_REQUIRED',errorCode:'provider_outcome_unknown'}:j);
 }
 async update(key,fn){return this.store.transaction(key,async tx=>{const j=await tx.read();if(!j)throw new DerivativeError('not_found');await tx.write(fn(j));});}
}
class DerivativeR21Worker {
 constructor(operations){this.operations=operations;}
 async tick(){for(const key of await this.operations.store.readyKeys(10)){
  try{await this.operations.process(key);}catch{/* Typed status is persisted; never log transcript or provider body. */}
 }}
}
function createDerivativeHandlers({operations,authenticate}) {
 const handler=fn=>async(req,res)=>{try{const owner=await authenticate(req);if(!owner)throw new DerivativeError('unauthenticated');await fn(req,res,owner);}
 catch(e){const status=e.code==='unauthenticated'?401:e.code==='not_found'?404:e.code==='operation_conflict'?409:e.code==='derivative_engine_disabled'?503:400;res.status(status).json({error:e.code??'request_failed'});}};
 return {create:handler(async(req,res,owner)=>res.status(202).json(await operations.create(owner,req.body))),
 status:handler(async(req,res,owner)=>res.status(200).json(await operations.status(owner,req.params.operationKey))),
 retry:handler(async(req,res,owner)=>res.status(202).json(await operations.retry(owner,req.params.operationKey)))};
}
module.exports={DerivativeR21Operations,DerivativeR21Worker,createDerivativeHandlers};
