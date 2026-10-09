'use strict';
const {hash,DerivativeError}=require('./derivative_contract');
const {CLINICAL,STUDY}=require('./derivative_policy');
const {DerivativeR21Operations}=require('./derivative_r21_operations');
const {DerivativeR21FirestoreStore}=require('./derivative_r21_firestore_store');
const {ExtractiveDerivativeEngine}=require('./extractive_derivative_engine');
const {resolveMedCasesTier}=require('./calculator_entitlement_session');

class DerivativeRollout {
 constructor({routes={},internalUids=[],approvedTypes=[]}={}) {
  this.routes=structuredClone(routes);this.internalUids=new Set(internalUids);
  this.approved=new Set(approvedTypes);
 }
 enabled(uid,type) {
  if(![...CLINICAL,...STUDY].includes(type)||!this.approved.has(type))return false;
  const route=this.routes[type];
  if(route?.stage==='full')return true;
  if(['internal','limited'].includes(route?.stage)&&this.internalUids.has(uid))return true;
  return route?.stage==='limited'&&Number.isInteger(route.percent)&&route.percent>0&&route.percent<=100&&
    parseInt(hash(uid).slice(0,8),16)%100<route.percent;
 }
}

function createDerivativeRuntime({db,store=new DerivativeR21FirestoreStore(db),
 clinicalEngine=new ExtractiveDerivativeEngine(),studyEngine,policy,
 rollout=new DerivativeRollout(),readUser=async uid=>(await db.collection('users').doc(uid).get()).data()??{}}) {
 const operations=new DerivativeR21Operations({store,clinicalEngine,studyEngine,policy,enabled:true});
 if(studyEngine)studyEngine.resolveSummary=async input=>{
  if(!rollout.enabled(input.ownerUid,'SUMMARY'))throw new DerivativeError('summary_dependency_disabled');
  const operationId=hash(JSON.stringify(['r24',input.ownerUid,input.sourceId,input.transcriptHash,'SUMMARY',input.locale]));
  const response=await operations.create(input.ownerUid,{...input,operationId,derivativeType:'SUMMARY'});
  if(['FAILED_NONRETRYABLE','RECONCILIATION_REQUIRED'].includes(response.status))throw new DerivativeError('summary_dependency_failed');
  if(response.status==='FAILED_RETRYABLE')throw new DerivativeError('summary_dependency_retry_required',true);
  if(response.status!=='COMPLETED')throw new DerivativeError('derivative_dependency_pending',true);
  const job=await store.transaction(response.operationKey,tx=>tx.read());
  const result=job.result??await store.getCache(job.cacheKey);
  if(!result)throw new DerivativeError('derivative_dependency_pending',true);
  return result;
 };
 async function authorize(uid,type) {
  if(!rollout.enabled(uid,type)||STUDY.includes(type)&&!studyEngine)throw new DerivativeError('derivative_engine_disabled');
  if(['VISUAL_SUMMARY','ORAL_EXAM'].includes(type)&&resolveMedCasesTier(await readUser(uid)).tier!=='premium') {
   throw new DerivativeError('premium_required');
  }
 }
 const handler=fn=>async(req,res)=>{
  try {
   const uid=req.auth?.uid;
   if(typeof uid!=='string'||!uid)throw new DerivativeError('unauthenticated');
   await fn(req,res,uid);
  } catch(e) {
   const code=e instanceof DerivativeError?e.code:'derivative_runtime_unavailable';
   const status={unauthenticated:401,premium_required:403,not_found:404,operation_conflict:409,
    retry_not_due:429,derivative_engine_disabled:503,derivative_runtime_unavailable:503}[code]??400;
   res.status(status).json({error:code});
  }
 };
 const handlers={
  create:handler(async(req,res,uid)=>{
   await authorize(uid,req.body?.derivativeType);
   return res.status(202).json(await operations.create(uid,req.body));
  }),
  status:handler(async(req,res,uid)=>res.status(200).json(await operations.status(uid,req.params.operationKey))),
  retry:handler(async(req,res,uid)=>{
   const prior=await operations.status(uid,req.params.operationKey);
   await authorize(uid,prior.derivativeType);
   return res.status(202).json(await operations.retry(uid,prior.operationKey));
  }),
 };
 let running=false;
 async function tick() {
  if(running)return;running=true;
  try {
   const keys=await store.readyKeys(100);
   for(let i=0;i<keys.length;i+=2)await Promise.all(keys.slice(i,i+2).map(async key=>{
    // A rollback stops queued work; completed readback stays available.
    const job=await store.transaction(key,tx=>tx.read());
    if(!job||job.nextAttemptAt>Date.now()||!rollout.enabled(job.ownerUid,job.input?.derivativeType))return;
    try {await operations.process(key);} catch { /* The durable typed state is the diagnostic. */ }
   }));
  } finally {running=false;}
 }
 return {operations,handlers,tick};
}
function mountDerivativeRuntime(app,runtime) {
 // Must be mounted after the application's Firebase authentication middleware.
 app.post('/api/ai/derivatives',runtime.handlers.create);
 app.get('/api/ai/derivatives/:operationKey',runtime.handlers.status);
 app.post('/api/ai/derivatives/:operationKey/retry',runtime.handlers.retry);
}
module.exports={DerivativeRollout,createDerivativeRuntime,mountDerivativeRuntime};
