'use strict';
const {createHash}=require('node:crypto');
const hash=x=>createHash('sha256').update(x).digest('hex');
const validId=x=>typeof x==='string'&&/^[A-Za-z0-9_.-]{1,180}$/.test(x);
const STATES=['REQUESTED','PROVIDER','PARSING','PERSISTING','COMPLETED','FAILED'];
const REASONS=['SOURCE_NOT_READY','TRANSCRIPT_NOT_READY','CONTEXT_EMPTY','AUTH','PROVIDER_TIMEOUT','PROVIDER_5XX','TRUNCATED_OUTPUT','PARSE_FAILURE','PERSISTENCE_FAILURE','RENDER_FAILURE','NETWORK','CLIENT_TIMEOUT','OTHER'];
function metadata(v){
 const keys=['attemptId','artifactId','sourceIds','sessionIds','studyId','type','platform','locale','appVersion','buildNumber'];
 if(!v||Object.keys(v).some(k=>!keys.includes(k))||!['summary','visual','oral'].includes(v.type)||!validId(v.attemptId)||!validId(v.artifactId)||!validId(v.studyId)||!Array.isArray(v.sourceIds)||v.sourceIds.length<1||v.sourceIds.length>40||!v.sourceIds.every(validId)||!Array.isArray(v.sessionIds)||v.sessionIds.length>40||!v.sessionIds.every(validId)||!['ios','android','unknown'].includes(v.platform)||!['pt','es'].includes(v.locale)||!/^\d+\.\d+\.\d+$/.test(v.appVersion)||!/^\d{1,10}$/.test(v.buildNumber))throw Error('INVALID_ARTIFACT_METADATA');
 return Object.fromEntries(keys.map(k=>[k,v[k]]));
}
class StudyArtifactAttemptLedger {
 constructor({db,now=()=>Date.now()}){this.db=db;this.now=now;}
 ref(uid,id){if(!validId(uid)||!validId(id))throw Error('INVALID_ARTIFACT_ID');return this.db.collection('adminOperationalJobs').doc(hash(`study-artifact\n${uid}\n${id}`));}
 async create(uid,input){
  const m=metadata(input),ref=this.ref(uid,m.attemptId),fingerprint=hash(JSON.stringify(m));
  return this.db.runTransaction(async tx=>{
   const old=await tx.get(ref);
   if(old.exists){if(old.data().owner!==uid||old.data().fingerprint!==fingerprint)throw Error('ARTIFACT_BINDING_CONFLICT');return {id:ref.id,state:old.data().status,idempotent:true};}
   const at=this.now();tx.create(ref,{...m,owner:uid,fingerprint,sourceId:m.sourceIds[0],status:'REQUESTED',stage:'REQUESTED',createdAt:at,startedAt:at,updatedAt:at,attempts:1,retrySupported:true,cancelSupported:false,timeline:[{state:'REQUESTED',at}]});
   return {id:ref.id,state:'REQUESTED'};
  });
 }
 async expirePending(){
  const cutoff=this.now()-30*60*1000;
  for(const status of STATES.filter(x=>!['COMPLETED','FAILED'].includes(x))){
   let cursor;
   for(;;){
    let query=this.db.collection('adminOperationalJobs').where('status','==',status).limit(100);
    if(cursor)query=query.startAfter(cursor);
    const page=await query.get();
    for(const doc of page.docs){const v=doc.data();if(v.fingerprint&&v.attemptId&&v.updatedAt<cutoff)await this.advance(v.owner,v.attemptId,{state:'FAILED',reasonCode:'CLIENT_TIMEOUT'},{staleBefore:cutoff});}
    if(page.size<100)break;
    cursor=page.docs[page.docs.length-1];
   }
  }
 }
 async advance(uid,id,event,{staleBefore}={}){
  if(!event||Object.keys(event).some(k=>!['state','reasonCode'].includes(k))||!STATES.includes(event.state)||event.reasonCode!=null&&!REASONS.includes(event.reasonCode)||event.state==='FAILED'&&!REASONS.includes(event.reasonCode))throw Error('INVALID_ARTIFACT_EVENT');
  const ref=this.ref(uid,id);
  return this.db.runTransaction(async tx=>{
   const snap=await tx.get(ref);if(!snap.exists||snap.data().owner!==uid)throw Error('ARTIFACT_NOT_OWNED');const old=snap.data();
   if(staleBefore!==undefined&&old.updatedAt>=staleBefore)return {state:old.status,ignored:true};
   const lateCompletion=old.status==='FAILED'&&old.lastErrorCode==='CLIENT_TIMEOUT'&&event.state==='COMPLETED';
   if(!lateCompletion&&(['COMPLETED','FAILED'].includes(old.status)||STATES.indexOf(event.state)<=STATES.indexOf(old.status)))return {state:old.status,idempotent:true};
   const at=this.now(),terminal=['COMPLETED','FAILED'].includes(event.state);
   let incident,prior;
   if(event.state==='FAILED'){incident=this.db.collection('admin_incidents').doc(hash(JSON.stringify(['study-artifact',old.type,event.reasonCode,old.appVersion,old.buildNumber,old.platform])));prior=(await tx.get(incident)).data()||{};}
   tx.update(ref,{status:event.state,stage:event.state==='FAILED'?old.stage:event.state,lastErrorCode:event.reasonCode||null,updatedAt:at,...(terminal?{completedAt:at}:{}),timeline:[...old.timeline,{state:event.state,reasonCode:event.reasonCode||null,at}].slice(-16)});
   if(incident)tx.set(incident,{service:'study-artifact',module:old.type,reasonCode:event.reasonCode,appVersion:old.appVersion,buildNumber:old.buildNumber,platform:old.platform,count:(prior.count||0)+1,lastSeenAt:at,status:'open'},{merge:true});
   return {state:event.state};
  });
 }
}
module.exports={StudyArtifactAttemptLedger,metadata,STATES,REASONS};
