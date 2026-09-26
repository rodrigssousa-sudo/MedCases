'use strict';
const {validProof}=require('./audio_media_budget');
const crypto=require('node:crypto');
const {resolveMedCasesTier}=require('./calculator_entitlement_session');
const LIMITS=Object.freeze({free:{recording:15*60000,transcription:15*60000},premium:{recording:240*60000,transcription:90*60000}});
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
function validateRequest({operationId,kinds,maximumMs,executionCount=1}){
 if(!Number.isInteger(executionCount)||executionCount<1||executionCount>64)throw Error('INVALID_EXECUTION_COUNT');
 if(typeof operationId!=='string'||!operationId||operationId.length>180||!Array.isArray(kinds)||!kinds.length||new Set(kinds).size!==kinds.length||kinds.some(k=>!['recording','transcription'].includes(k))||!Number.isSafeInteger(maximumMs)||maximumMs<=0)throw Error('INVALID_USAGE_REQUEST');
}
// uid MUST be supplied by the authenticated route, never the submitted body.
class MonthlyUsageOwner {
 constructor({db,now=()=>Date.now()}){this.db=db;this.now=now;}
 // A read-only transaction returns the same account/month used by reserve.
 // totals already includes reservations: subtracting them again would double count.
 async balance(uid){
  if(typeof uid!=='string'||!uid)throw Error('AUTH_REQUIRED');
  const now=this.now(),month=new Date(now).toISOString().slice(0,7);
  const bucketId=hash(`${uid}\n${month}`);
  return this.db.runTransaction(async tx=>{
   const [user,bucket,operations]=await Promise.all([
    tx.get(this.db.collection('users').doc(uid)),
    tx.get(this.db.collection('monthlyUsage').doc(bucketId)),
    tx.get(this.db.collection('usageReservations').where('uid','==',uid).where('month','==',month))
   ]);
   if(!user.exists)throw Error('AUTH_REQUIRED');
   const tier=resolveMedCasesTier(user.data(),now).tier;
   const total=bucket.exists?bucket.data().totals.transcription:0;
   if(!Number.isSafeInteger(total)||total<0)throw Error('CORRUPT_USAGE');
   let reservedMs=0;
   for(const doc of operations.docs){
    const op=doc.data();
    if(op.state==='reserved'&&op.kinds.includes('transcription')){
     if(!Number.isSafeInteger(op.maximumMs)||op.maximumMs<0)throw Error('CORRUPT_USAGE');
     reservedMs+=op.maximumMs;
    }
   }
   if(reservedMs>total)throw Error('CORRUPT_USAGE');
   const allowanceMs=LIMITS[tier].transcription;
   return {month,tier,allowanceMs,usedMs:total-reservedMs,reservedMs,
    remainingMs:Math.max(0,allowanceMs-total)};
  });
 }
 async reserve(uid,request){
  if(typeof uid!=='string'||!uid)throw Error('AUTH_REQUIRED');validateRequest(request);
  const now=this.now(),month=new Date(now).toISOString().slice(0,7);
  const bucketId=hash(`${uid}\n${month}`),operationKey=hash(`${bucketId}\n${request.operationId}`);
  const bucket=this.db.collection('monthlyUsage').doc(bucketId),operation=this.db.collection('usageReservations').doc(operationKey);
  return this.db.runTransaction(async tx=>{
   const [userSnap,bucketSnap,opSnap]=await Promise.all([tx.get(this.db.collection('users').doc(uid)),tx.get(bucket),tx.get(operation)]);
   if(!userSnap.exists)throw Error('AUTH_REQUIRED');
   const limits=LIMITS[resolveMedCasesTier(userSnap.data(),now).tier];
   const totals=bucketSnap.exists?bucketSnap.data().totals:{recording:0,transcription:0};
   for(const k of ['recording','transcription'])if(!Number.isSafeInteger(totals[k])||totals[k]<0)throw Error('CORRUPT_USAGE');
   const old=opSnap.exists?opSnap.data():null;
   const fingerprint=hash(JSON.stringify({kinds:[...request.kinds].sort(),maximumMs:request.maximumMs,executionCount:request.executionCount||1}));
   if(old&&old.fingerprint!==fingerprint)throw Error('IDEMPOTENCY_CONFLICT');
   if(old)return {id:operationKey,attempt:old.attempt,maximumMs:old.maximumMs,month,state:old.state};
   const maximumMs=Math.min(request.maximumMs,...request.kinds.map(k=>limits[k]-totals[k]));
   if(maximumMs<=0||(!request.allowPartial&&maximumMs<request.maximumMs))throw Error('MONTHLY_USAGE_LIMIT');
   const attempt=crypto.randomUUID();for(const kind of request.kinds)totals[kind]+=maximumMs;
   tx.set(bucket,{uid,month,totals});tx.set(operation,{uid,bucketId,month,attempt,fingerprint,kinds:request.kinds,maximumMs,chargedMs:0,executionCount:request.executionCount||1,completedExecutions:0,state:'reserved',createdAt:now});
   return {id:operationKey,attempt,maximumMs,month,state:'reserved'};
  });
 }
 async finish(uid,{id,attempt,actualMs,success}){
  if(!/^[a-f0-9]{64}$/.test(id)||!Number.isSafeInteger(actualMs)||actualMs<0||typeof success!=='boolean')throw Error('INVALID_USAGE_RESULT');
  return this.db.runTransaction(async tx=>{
   const ref=this.db.collection('usageReservations').doc(id),snapshot=await tx.get(ref);
   if(!snapshot.exists||snapshot.data().uid!==uid)throw Error('RESERVATION_NOT_OWNED');
   const op=snapshot.data();if(op.attempt!==attempt)throw Error('STALE_ATTEMPT');
   if(['completed','server_verified_failed','executing'].includes(op.state))return {state:op.state,chargedMs:op.chargedMs};
   if(actualMs>op.maximumMs)throw Error('USAGE_OUT_OF_BOUNDS');
   const bucket=this.db.collection('monthlyUsage').doc(op.bucketId),snap=await tx.get(bucket);
   if(!snap.exists)throw Error('BUCKET_MISSING');const data=snap.data();// Client-reported outcomes are acknowledgements, never refund authority.
   const charge=op.maximumMs;
   for(const kind of op.kinds){data.totals[kind]-=op.maximumMs-charge;if(data.totals[kind]<0)throw Error('CORRUPT_USAGE');}
   tx.set(bucket,data);tx.set(ref,{...op,state:'completed',chargedMs:charge,finishedAt:this.now()});
   return {state:'completed',chargedMs:charge};
  });
 }
 // Preparatory provider operations share one immutable media/slot binding.
 // Each stage is single-flight and charges the reserved budget before dispatch;
 // final generation consumes the same measured duration, never a second credit.
 async authorizeMediaStage(uid,{id,attempt},index,media,stage){
  if(!/^[a-f0-9]{64}$/.test(id)||!Number.isInteger(index)||index<0||!['upload','cache','countTokens'].includes(stage)||!validProof(media))throw Error('INVALID_MEDIA_STAGE');
  return this.db.runTransaction(async tx=>{
   const key=hash(`${id}:${attempt}:${index}`),ref=this.db.collection('usageReservations').doc(id),binding=this.db.collection('usageMediaBindings').doc(key),execution=this.db.collection('usageExecutions').doc(key);
   const [snap,prior,exec]=await Promise.all([tx.get(ref),tx.get(binding),tx.get(execution)]);
   if(!snap.exists||snap.data().uid!==uid)throw Error('RESERVATION_NOT_OWNED');
   const op=snap.data();if(op.attempt!==attempt||!['reserved','executing'].includes(op.state)||!op.kinds.includes('transcription')||index>=(op.executionCount||1)||exec.exists)throw Error('MEDIA_STAGE_NOT_AUTHORIZED');
   const old=prior.exists?prior.data():null;
   if(old&&(old.mediaHash!==media.sha256||old.durationMs!==media.durationMs))throw Error('MEDIA_STAGE_BINDING_CONFLICT');
   if(old?.stages?.[stage]){if(old.stages[stage]!==media.requestHash)throw Error('MEDIA_STAGE_REQUEST_CONFLICT');return {claimed:false};}
   const used=op.authorizedMediaMs||0,extra=old?0:media.durationMs;
   if(!Number.isSafeInteger(used)||used<0||extra>op.maximumMs-used)throw Error('MEDIA_EXCEEDS_RESERVED_BUDGET');
   tx.set(ref,{...op,state:'executing',chargedMs:op.maximumMs,authorizedMediaMs:used+extra});
   tx.set(binding,{uid,id,attempt,index,mediaHash:media.sha256,durationMs:media.durationMs,stages:{...(old?.stages||{}),[stage]:media.requestHash}});
   return {claimed:true};
  });
 }
 // Only server execution paths can claim work. A finite plan is fixed when the
 // reservation is created; each slot is single-use across ALL providers.
 async claimExecution(uid,{id,attempt},index=0,media){
  if(!/^[a-f0-9]{64}$/.test(id)||!Number.isInteger(index)||index<0)throw Error('INVALID_EXECUTION');
  return this.db.runTransaction(async tx=>{
   const ref=this.db.collection('usageReservations').doc(id);
   const execution=this.db.collection('usageExecutions').doc(hash(`${id}:${attempt}:${index}`));
   const binding=this.db.collection('usageMediaBindings').doc(hash(`${id}:${attempt}:${index}`));
   const [snap,prior,staged]=await Promise.all([tx.get(ref),tx.get(execution),tx.get(binding)]);
   if(!snap.exists||snap.data().uid!==uid)throw Error('RESERVATION_NOT_OWNED');
   const op=snap.data();if(op.attempt!==attempt)throw Error('STALE_ATTEMPT');
   if(prior.exists) {
    if(media && (!validProof(media)||prior.data().mediaHash!==media.sha256||prior.data().requestHash!==media.requestHash))throw Error('EXECUTION_BINDING_CONFLICT');
    return {claimed:false,state:prior.data().state};
   }
   if(!['reserved','executing'].includes(op.state)||index>=(op.executionCount||1)||!op.kinds.includes('transcription'))throw Error('EXECUTION_NOT_AUTHORIZED');
   if(!validProof(media))throw Error('MEDIA_PROOF_REQUIRED');
   if(staged.exists&&(staged.data().mediaHash!==media.sha256||staged.data().durationMs!==media.durationMs))throw Error('MEDIA_STAGE_BINDING_CONFLICT');
   const used=op.authorizedMediaMs||0,extra=staged.exists?0:media.durationMs;
   if(!Number.isSafeInteger(used)||used<0||extra>op.maximumMs-used)throw Error('MEDIA_EXCEEDS_RESERVED_BUDGET');
   tx.set(ref,{...op,state:'executing',chargedMs:op.maximumMs,authorizedMediaMs:used+extra});
   tx.set(execution,{uid,id,attempt,index,mediaHash:media.sha256,requestHash:media.requestHash,durationMs:media.durationMs,state:'executing',startedAt:this.now()});
   return {claimed:true,state:'executing'};
  });
 }
 async completeExecution(uid,{id,attempt},index=0){
  return this.db.runTransaction(async tx=>{
   const ref=this.db.collection('usageReservations').doc(id);
   const execution=this.db.collection('usageExecutions').doc(hash(`${id}:${attempt}:${index}`));
   const [snap,work]=await Promise.all([tx.get(ref),tx.get(execution)]);
   if(!snap.exists||snap.data().uid!==uid||!work.exists||work.data().uid!==uid)throw Error('RESERVATION_NOT_OWNED');
   const op=snap.data();if(op.attempt!==attempt)throw Error('STALE_ATTEMPT');
   if(work.data().state==='completed')return {state:op.state,chargedMs:op.chargedMs};
   const completedExecutions=(op.completedExecutions||0)+1;
   const state=completedExecutions===(op.executionCount||1)?'completed':'executing';
   tx.set(execution,{...work.data(),state:'completed',finishedAt:this.now()});
   tx.set(ref,{...op,completedExecutions,state,chargedMs:op.maximumMs});
   return {state,chargedMs:op.maximumMs};
  });
 }
 // Not exposed by any client route. May be called only after a server proves
 // failure before any execution claim; a terminal attempt is never reopened.
 async failBeforeExecution(uid,{id,attempt}){
  return this.db.runTransaction(async tx=>{
   const ref=this.db.collection('usageReservations').doc(id),snap=await tx.get(ref);
   if(!snap.exists||snap.data().uid!==uid)throw Error('RESERVATION_NOT_OWNED');
   const op=snap.data();if(op.attempt!==attempt)throw Error('STALE_ATTEMPT');
   if(op.state==='server_verified_failed')return {state:op.state,chargedMs:0};
   if(op.state!=='reserved')throw Error('BILLABLE_EXECUTION_STARTED');
   const bucket=this.db.collection('monthlyUsage').doc(op.bucketId),bs=await tx.get(bucket);
   if(!bs.exists)throw Error('BUCKET_MISSING');const data=bs.data();
   for(const kind of op.kinds){data.totals[kind]-=op.maximumMs;if(data.totals[kind]<0)throw Error('CORRUPT_USAGE');}
   tx.set(bucket,data);tx.set(ref,{...op,state:'server_verified_failed',chargedMs:0,finishedAt:this.now()});
   return {state:'server_verified_failed',chargedMs:0};
  });
 }

}
module.exports={MonthlyUsageOwner,LIMITS,validateRequest};
