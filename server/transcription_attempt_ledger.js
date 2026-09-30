'use strict';
const crypto=require('node:crypto');
const COLLECTION='transcriptionAttempts';
const STATES=['REQUESTED','VALIDATING','MEDIA_VALIDATED','QUOTA_RESERVED','JOB_CREATED','UPLOADING','UPLOADED','PROCESSING','PERSISTING','COMPLETED','RECOVERABLE_FAILED','FAILED','CANCELLED'];
const TERMINAL=new Set(['COMPLETED','FAILED','CANCELLED']);
const CLIENT_STATES=new Set(['VALIDATING','MEDIA_VALIDATED','QUOTA_RESERVED','UPLOADING','FAILED','CANCELLED']);
const REASONS=new Set(['AUTH_FAILURE','ELIGIBILITY_FAILURE','MEDIA_PROOF_FAILURE','DURATION_LIMIT','TRANSCRIPTION_LIMIT_REACHED','UPLOAD_FAILURE','UPLOAD_INCOMPLETE','FILE_TOO_LARGE','JOB_CREATE_FAILURE','WORKER_FAILURE','PROVIDER_TIMEOUT','PROVIDER_5XX','PROVIDER_REJECTION','PERSISTENCE_FAILURE','CLIENT_TIMEOUT','NETWORK_FAILURE','PIPELINE_CONFLICT','CANCELLED','UNKNOWN','UPLOAD_STALLED','UPLOAD_FAILED','ATTEMPT_STALLED','MEDIA_PROOF_FAILED','QUOTA_RESERVATION_FAILED','MEDIA_ASSEMBLY_FAILED','TRANSCRIPT_PERSIST_FAILED','ACCOUNTING_FINALIZATION_FAILED']);
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
function identifier(v){return typeof v==='string'&&/^[A-Za-z0-9_.-]{1,160}$/.test(v);}
function validateIdentity(v){
 if(!v||!identifier(v.attemptId)||!identifier(v.sourceId)||!identifier(v.sessionId)||!['ios','android','unknown'].includes(v.platform)||!['pt','es'].includes(v.locale)||!/^\d+\.\d+\.\d+$/.test(v.appVersion)||!/^\d{1,10}$/.test(v.buildNumber))throw Error('INVALID_ATTEMPT_METADATA');
 const keys=['attemptId','sourceId','sessionId','platform','locale','appVersion','buildNumber'];
 if(Object.keys(v).some(k=>!keys.includes(k)))throw Error('INVALID_ATTEMPT_METADATA');
 return Object.fromEntries(keys.map(k=>[k,v[k]]));
}
class TranscriptionAttemptLedger {
 constructor({db,now=()=>Date.now()}){this.db=db;this.now=now;}
 ref(uid,id){if(!uid||!identifier(id))throw Error('INVALID_ATTEMPT_ID');return this.db.collection(COLLECTION).doc(hash(`${uid}\n${id}`));}
 async create(uid,metadata){
  const m=validateIdentity(metadata),ref=this.ref(uid,m.attemptId),time=this.now();
  return this.db.runTransaction(async tx=>{
   const snap=await tx.get(ref);
   if(snap.exists){const old=snap.data();if(old.userId!==uid||old.sourceId!==m.sourceId||old.sessionId!==m.sessionId)throw Error('ATTEMPT_BINDING_CONFLICT');return {attemptId:m.attemptId,state:old.state,idempotent:true};}
   const value={...m,userId:uid,state:'REQUESTED',lastStage:'REQUESTED',reasonCode:null,createdAt:time,updatedAt:time,timeline:[{state:'REQUESTED',at:time,origin:'client'}]};
   tx.set(ref,value);return {attemptId:m.attemptId,state:value.state,idempotent:false};
  });
 }
 async bind(uid,id,metadata){
  const allowed=['jobId','durationMs','fileSize','provider'];
  if(Object.keys(metadata).some(k=>!allowed.includes(k))||metadata.jobId!==undefined&&!/^[a-f0-9]{64}$/.test(metadata.jobId)||metadata.provider!==undefined&&metadata.provider!=='assemblyai'||['durationMs','fileSize'].some(k=>metadata[k]!==undefined&&(!Number.isSafeInteger(metadata[k])||metadata[k]<0)))throw Error('INVALID_ATTEMPT_METADATA');
  const ref=this.ref(uid,id);
  await this.db.runTransaction(async tx=>{const snap=await tx.get(ref);if(!snap.exists||snap.data().userId!==uid)throw Error('ATTEMPT_NOT_OWNED');const old=snap.data();if(old.jobId&&metadata.jobId&&old.jobId!==metadata.jobId)throw Error('ATTEMPT_BINDING_CONFLICT');tx.set(ref,metadata,{merge:true});});
 }
 async expireUnbound(){
  const cutoff=this.now()-15*60*1000;
  for(const state of ['REQUESTED','VALIDATING','MEDIA_VALIDATED','QUOTA_RESERVED']){
   const page=await this.db.collection(COLLECTION).where('state','==',state).limit(100).get();
   for(const doc of page.docs){const v=doc.data();if(!v.jobId&&v.updatedAt<cutoff)
    await this.advance(v.userId,v.attemptId,{eventId:'prejob-deadline-'+v.updatedAt,state:'RECOVERABLE_FAILED',stage:state,reasonCode:'ATTEMPT_STALLED'},{requireUnboundBefore:cutoff});
   }
  }
 }
 async advance(uid,id,event,{origin='server',requireUnboundBefore}={}){
  const {state,reasonCode=null,stage=state,eventId}=event||{};
  if(!STATES.includes(state)||!STATES.includes(stage)||!identifier(eventId)||reasonCode!==null&&!REASONS.has(reasonCode)||['FAILED','RECOVERABLE_FAILED','CANCELLED'].includes(state)&&!reasonCode)throw Error('INVALID_ATTEMPT_EVENT');
  if(origin==='client'&&!CLIENT_STATES.has(state))throw Error('CLIENT_STATE_FORBIDDEN');
  if(Object.keys(event).some(k=>!['state','reasonCode','stage','eventId'].includes(k)))throw Error('INVALID_ATTEMPT_EVENT');
  const ref=this.ref(uid,id),eventRef=ref.collection('events').doc(hash(eventId)),time=this.now();
  return this.db.runTransaction(async tx=>{
   const [snap,seen]=await Promise.all([tx.get(ref),tx.get(eventRef)]);
   if(!snap.exists||snap.data().userId!==uid)throw Error('ATTEMPT_NOT_OWNED');
   const old=snap.data();if(requireUnboundBefore!==undefined&&(old.jobId||old.updatedAt>=requireUnboundBefore))return {state:old.state,ignored:true};if(seen.exists)return {state:old.state,idempotent:true};
   // Client connectivity/cancellation cannot erase an acknowledged remote result.
   const remote=old.serverOwned===true;
   const ignore=TERMINAL.has(old.state)||(origin==='client'&&remote)||(old.state!=='RECOVERABLE_FAILED'&&!TERMINAL.has(state)&&STATES.indexOf(state)<STATES.indexOf(old.state));
   const entry={state,stage,reasonCode,at:time,origin,applied:!ignore};
   let incidentRef,incident;
   if(!ignore&&['FAILED','RECOVERABLE_FAILED'].includes(state)){
    incidentRef=this.db.collection('admin_incidents').doc(hash(JSON.stringify(['transcription',reasonCode,old.appVersion,old.buildNumber,old.platform])));
    incident=(await tx.get(incidentRef)).data()||{};
   }
   tx.set(eventRef,entry);
   if(ignore){
    // Keep connectivity diagnostics visible without overriding server-owned state.
    tx.set(ref,{timeline:[...old.timeline,entry].slice(-24)},{merge:true});
    return {state:old.state,ignored:true};
   }
   const timeline=[...old.timeline,entry].slice(-24);
   tx.set(ref,{state,lastStage:stage,reasonCode,updatedAt:time,timeline,...(origin==='server'?{serverOwned:true}:{}),...(TERMINAL.has(state)?{finishedAt:time,...(state==='FAILED'?{failedAt:time}:{})}:{})},{merge:true});
   if(incidentRef)tx.set(incidentRef,{service:'transcription',module:'transcription',reasonCode,appVersion:old.appVersion,buildNumber:old.buildNumber,platform:old.platform,count:(incident.count||0)+1,lastSeenAt:time,status:'open'},{merge:true});
   return {state,idempotent:false};
  });
 }
}
module.exports={TranscriptionAttemptLedger,COLLECTION,STATES,REASONS,validateIdentity};
