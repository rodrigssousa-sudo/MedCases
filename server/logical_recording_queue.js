'use strict';
const fs=require('node:fs'),crypto=require('node:crypto');
const {Timestamp}=require('firebase-admin/firestore');
const {assembleLogicalAudio}=require('./logical_recording_audio');
const {storedProof,combineProofs,digest}=require('./audio_media_budget');
const {usageReceipt}=require('./usage_reservation_guard');
const now=()=>Timestamp.now(),ms=v=>v?.toMillis?.()||0;
const LEASE=180000;
class LogicalRecordingQueue {
 constructor({db,storage,owner,centralService,assemble=assembleLogicalAudio}){Object.assign(this,{db,storage,owner,centralService,assemble});}
 async cancelled(jobRef){return (await jobRef.get()).data()?.deleted===true;}
 async cancel(jobRef){
  await this.db.runTransaction(async tx=>{const snap=await tx.get(jobRef);if(!snap.exists)return;tx.set(jobRef,{deleted:true,state:'cancelled',cancelledAt:now(),workerPending:true},{merge:true});});
  await this.cleanupCancelled(jobRef);
 }
 async cleanupCancelled(jobRef){
  const logical=jobRef.collection('logical').doc('recording'),v=(await logical.get()).data()||{};
  const segments=await jobRef.collection('segments').get();
  const keys=new Set([v.objectKey,...segments.docs.map(d=>d.data().objectKey)].filter(Boolean));
  for(const key of keys)await this.storage.remove(key);
  if(v.providerTranscriptId&&!v.providerDeleted){await this.centralService.provider({provider:'assemblyai'}).remove(v.providerTranscriptId);await logical.set({providerDeleted:true,providerAudioUrl:null},{merge:true});}
  // Retain a tombstone, never delete the binding while a worker may be in flight.
  for(const d of segments.docs)await d.ref.set({state:'cancelled',objectKey:null,transcript:null},{merge:true});
  await logical.set({state:'cancelled',objectKey:null,transcript:null,rawTranscript:null},{merge:true});
  const children=await logical.collection('utterances').get();for(const d of children.docs)await d.ref.delete();
  const words=await logical.collection('words').get();for(const d of words.docs)await d.ref.delete();
  await jobRef.set({state:'cancelled',cleanupCompletedAt:now(),workerPending:ms(v.leaseUntil)>Date.now()},{merge:true});
 }
 guardedRef(jobRef,ref,leaseToken){
  const self=this;
  return {get:()=>ref.get(),collection:name=>({doc:id=>self.guardedRef(jobRef,ref.collection(name).doc(id),leaseToken)}),
   async set(value,options){await self.db.runTransaction(async tx=>{
    const job=await tx.get(jobRef);
    const lease=leaseToken?await tx.get(jobRef.collection('logical').doc('recording')):null;
    if(leaseToken&&!job.data()?.deleted&&lease.data()?.leaseToken!==leaseToken)throw Error('WORKER_LEASE_LOST');
    if(!job.exists||job.data().deleted){
     // Save a late accepted provider ID only for cancellation cleanup.
     if(value.providerTranscriptId)tx.set(ref,{providerTranscriptId:value.providerTranscriptId,state:'cancelled'},{merge:true});
     else throw Error('LOGICAL_RECORDING_CANCELLED');
    }else tx.set(ref,value,options);
   });if(await self.cancelled(jobRef))throw Error('LOGICAL_RECORDING_CANCELLED');}
  };
 }
 async process(jobRef,job){
  if(job.deleted){await this.cleanupCancelled(jobRef);return;}
  const ref=jobRef.collection('logical').doc('recording'),token=crypto.randomUUID();
  const acquired=await this.db.runTransaction(async tx=>{const j=await tx.get(jobRef),s=await tx.get(ref);if(!j.exists||j.data().deleted)return false;const v=s.data()||{};
   if(ms(v.leaseUntil)>Date.now()||['terminal_error','cancelled'].includes(v.state))return false;
   tx.set(ref,{leaseToken:token,claimCount:(v.claimCount||0)+1,leaseUntil:Timestamp.fromMillis(Date.now()+LEASE),createdAt:v.createdAt||now(),state:v.state||'queued'},{merge:true});return true;});
  if(!acquired)return;
  let lost=false;
  const heartbeat=setInterval(()=>{this.db.runTransaction(async tx=>{const snap=await tx.get(ref);if(snap.data()?.leaseToken!==token){lost=true;return;}tx.set(ref,{leaseUntil:Timestamp.fromMillis(Date.now()+LEASE)},{merge:true});}).catch(()=>{lost=true;});},30000);heartbeat.unref?.();
  try{
   let value=(await ref.get()).data();
   const snap=await jobRef.collection('segments').get();const docs=snap.docs.sort((a,b)=>a.data().index-b.data().index),segments=docs.map(d=>d.data());
   if(segments.length!==job.expectedSegments||segments.some((v,i)=>v.index!==i||(!v.objectKey&&v.state!=='done')))return;
   if(value.state==='done'){await this.finish(jobRef,job,ref,value,docs);return;}
   if(!value.objectKey&&!value.providerTranscriptId){
    const reservation=await this.db.collection('usageReservations').doc(usageReceipt(job.usage).id).get();
    if(reservation.data()?.uid!==job.uid)throw Error('RESERVATION_NOT_OWNED');
    const audio=await this.assemble({storage:this.storage,segments,maximumMs:reservation.data().maximumMs});
    const key=this.storage.key(jobRef.id,'logical',token);let retained=false;
    try{
     await this.storage.put(key,fs.createReadStream(audio.path),audio.byteLength);
     if(lost||await this.cancelled(jobRef))throw Error('LOGICAL_RECORDING_CANCELLED');
     await this.guardedRef(jobRef,ref,token).set({objectKey:key,recordingSessionId:job.sessionId||job.sourceId,logicalRecordingId:jobRef.id,ownerUid:job.uid,mode:job.mode,language:job.locale,
      physicalSegments:audio.physicalSegments,totalDurationMs:audio.totalDurationMs,totalBytes:audio.totalBytes,assembledBytes:audio.byteLength,state:'processing',updatedAt:now()},{merge:true});retained=true;
    }finally{await audio.cleanup();if(!retained)await this.storage.remove(key);}
    value=(await ref.get()).data();
   }
   if(!value.providerTranscriptId){
    for(const p of value.physicalSegments){
     const proof=combineProofs([storedProof(p)],digest(JSON.stringify({logicalRecordingId:jobRef.id,index:p.index,sha256:p.sha256})));
     // An already claimed, hash-bound execution resumes this logical job.
     await this.owner.claimExecution(job.uid,usageReceipt(job.usage),p.index,proof);
    }
   }
   if(lost||await this.cancelled(jobRef))throw Error('LOGICAL_RECORDING_CANCELLED');
   const result=await this.centralService.advance({job,ref:this.guardedRef(jobRef,ref,token),readAudio:async()=>(await this.storage.getStream(value.objectKey)).body});
   if(await this.cancelled(jobRef))throw Error('LOGICAL_RECORDING_CANCELLED');
   await jobRef.set({state:result.state==='done'?'processing':result.state,providerJobId:result.providerTranscriptId||null,workerPending:!['terminal_error'].includes(result.state),updatedAt:now()},{merge:true});
   if(result.state==='done')await this.finish(jobRef,job,ref,result,docs);
  }catch(error){
   if(await this.cancelled(jobRef)){await this.cleanupCancelled(jobRef);return;}
   if((await ref.get()).data()?.leaseToken!==token)return;
   if((await ref.get()).data()?.state==='done'){
    await jobRef.set({workerPending:true},{merge:true});return;
   }
   const fatal=/AUDIO_|MEDIA_|RESERVATION_|BINDING_|PHYSICAL_/.test(error.message||'');
   await ref.set({state:fatal?'terminal_error':'retryable_error',retryable:!fatal,errorCategory:fatal?'LOGICAL_AUDIO_INVALID':'LOGICAL_WORKER_RETRY',updatedAt:now()},{merge:true});
   await jobRef.set({state:fatal?'terminal_error':'retryable_error',workerPending:!fatal},{merge:true});
  }finally{
   clearInterval(heartbeat);
   await this.db.runTransaction(async tx=>{const s=await tx.get(ref);if(s.data()?.leaseToken===token)tx.set(ref,{leaseUntil:null,leaseToken:null},{merge:true});});
   if(await this.cancelled(jobRef))await this.cleanupCancelled(jobRef);
  }
 }
 async finish(jobRef,job,ref,value,docs){
  if(await this.cancelled(jobRef))return this.cleanupCancelled(jobRef);
  const parts=Array.from({length:docs.length},()=>[]);
  if(docs.length===1)parts[0]=[value.transcript];
  else{
   let end=0;const ends=value.physicalSegments.map(s=>end+=s.durationMs);
   for(let p=0;p<(value.wordPages||0);p++){
    const words=(await ref.collection('words').doc(String(p)).get()).data()?.items||[];
    for(const w of words){let index=ends.findIndex(end=>w.startMs<end);if(index<0)index=ends.length-1;parts[index].push(w.text);}
   }
   if(!parts.some(v=>v.length))throw Error('PROVIDER_WORD_TIMESTAMPS_REQUIRED');
  }
  await this.db.runTransaction(async tx=>{
   const current=await tx.get(jobRef);if(current.data()?.deleted)throw Error('LOGICAL_RECORDING_CANCELLED');
   for(let i=0;i<docs.length;i++)tx.set(docs[i].ref,{state:'done',transcript:parts[i].join(' ').trim()||(job.locale==='es'?'[Tramo sin habla reconocida]':'[Trecho sem fala reconhecida]'),logicalRecordingId:jobRef.id,completedAt:now()},{merge:true});
   tx.set(jobRef,{state:'completed',completedSegments:docs.length,failedSegments:0,pendingSegments:0,completedAt:now(),workerPending:true},{merge:true});
  });
  for(const doc of docs){await this.owner.completeExecution(job.uid,usageReceipt(job.usage),doc.data().index);const key=doc.data().objectKey;if(key)await this.storage.remove(key);await doc.ref.set({objectKey:null,usageSettled:true},{merge:true});}
  if(value.objectKey)await this.storage.remove(value.objectKey);
  if(!value.providerDeleted&&value.providerTranscriptId)await this.centralService.provider(job).remove(value.providerTranscriptId);
  await ref.set({objectKey:null,providerDeleted:true,providerAudioUrl:null,cleanupCompletedAt:now()},{merge:true});
  await jobRef.set({workerPending:false},{merge:true});
 }
}
module.exports={LogicalRecordingQueue};
