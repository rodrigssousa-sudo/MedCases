'use strict';
const {Timestamp}=require('firebase-admin/firestore');
async function resumeTranscriptionJob({db,jobRef,uid,expectedSegments,requestId,now=()=>Date.now()}){
 if(typeof requestId!=='string'||!/^[A-Za-z0-9_-]{8,100}$/.test(requestId))throw Error('RETRY_REQUEST_INVALID');
 return db.runTransaction(async tx=>{
  const root=await tx.get(jobRef),ref=jobRef.collection('logical').doc('recording'),logical=await tx.get(ref);
  const job=root.data(),value=logical.data()||{},time=now();
  if(!job||job.deleted||job.uid!==uid||job.expectedSegments!==expectedSegments)throw Error('RETRY_NOT_OWNED');
  if(value.lastRetryRequestId===requestId)return {state:job.state,idempotent:true};
  if(value.retrySuspended!==true)return {state:job.state,idempotent:true};
  if(value.lastRetryAt&&time-value.lastRetryAt<30000)throw Error('RETRY_COOLDOWN');
  // Retain provider ID, transcript, hashes, object and execution receipt.
  tx.set(ref,{retrySuspended:false,consecutiveFailures:0,lastRetryRequestId:requestId,lastRetryAt:time,updatedAt:Timestamp.fromMillis(time)},{merge:true});
  tx.set(jobRef,{workerPending:true,updatedAt:Timestamp.fromMillis(time)},{merge:true});
  return {state:job.state,resumed:true};
 });
}
module.exports={resumeTranscriptionJob};
