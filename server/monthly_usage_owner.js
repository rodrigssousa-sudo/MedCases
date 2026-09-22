'use strict';
const crypto=require('node:crypto');
const {resolveMedCasesTier}=require('./calculator_entitlement_session');
const LIMITS=Object.freeze({free:{recording:15*60000,transcription:30*60000},premium:{recording:240*60000,transcription:90*60000}});
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
function validateRequest({operationId,kinds,maximumMs}){
 if(typeof operationId!=='string'||!operationId||operationId.length>180||!Array.isArray(kinds)||!kinds.length||new Set(kinds).size!==kinds.length||kinds.some(k=>!['recording','transcription'].includes(k))||!Number.isSafeInteger(maximumMs)||maximumMs<=0)throw Error('INVALID_USAGE_REQUEST');
}
// uid MUST be supplied by the authenticated route, never the submitted body.
class MonthlyUsageOwner {
 constructor({db,now=()=>Date.now()}){this.db=db;this.now=now;}
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
   const fingerprint=hash(JSON.stringify({kinds:[...request.kinds].sort(),maximumMs:request.maximumMs}));
   if(old&&old.fingerprint!==fingerprint)throw Error('IDEMPOTENCY_CONFLICT');
   if(old&&(old.state==='reserved'||old.chargedMs>0))return {id:operationKey,attempt:old.attempt,maximumMs:old.maximumMs,month,state:old.state};
   const maximumMs=Math.min(request.maximumMs,...request.kinds.map(k=>limits[k]-totals[k]));
   if(maximumMs<=0||(!request.allowPartial&&maximumMs<request.maximumMs))throw Error('MONTHLY_USAGE_LIMIT');
   const attempt=crypto.randomUUID();for(const kind of request.kinds)totals[kind]+=maximumMs;
   tx.set(bucket,{uid,month,totals});tx.set(operation,{uid,bucketId,month,attempt,fingerprint,kinds:request.kinds,maximumMs,chargedMs:0,state:'reserved',createdAt:now});
   return {id:operationKey,attempt,maximumMs,month,state:'reserved'};
  });
 }
 async finish(uid,{id,attempt,actualMs,success}){
  if(!/^[a-f0-9]{64}$/.test(id)||!Number.isSafeInteger(actualMs)||actualMs<0||typeof success!=='boolean')throw Error('INVALID_USAGE_RESULT');
  return this.db.runTransaction(async tx=>{
   const ref=this.db.collection('usageReservations').doc(id),snapshot=await tx.get(ref);
   if(!snapshot.exists||snapshot.data().uid!==uid)throw Error('RESERVATION_NOT_OWNED');
   const op=snapshot.data();if(op.attempt!==attempt)throw Error('STALE_ATTEMPT');
   if(op.state==='completed')return {state:'completed',chargedMs:op.chargedMs};
   if(actualMs>op.maximumMs)throw Error('USAGE_OUT_OF_BOUNDS');
   const bucket=this.db.collection('monthlyUsage').doc(op.bucketId),snap=await tx.get(bucket);
   if(!snap.exists)throw Error('BUCKET_MISSING');const data=snap.data();const charge=success?actualMs:0;
   for(const kind of op.kinds){data.totals[kind]-=op.maximumMs-charge;if(data.totals[kind]<0)throw Error('CORRUPT_USAGE');}
   tx.set(bucket,data);tx.set(ref,{...op,state:'completed',chargedMs:charge,finishedAt:this.now()});
   return {state:'completed',chargedMs:charge};
  });
 }
}
module.exports={MonthlyUsageOwner,LIMITS,validateRequest};
