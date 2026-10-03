'use strict';
const {createHash}=require('node:crypto');
const hash=s=>createHash('sha256').update(s).digest('hex');
function parseRange(body) {
 if(body.rangeStartFrame==null)return null;
 const r={startFrame:body.rangeStartFrame,endFrame:body.rangeEndFrame,totalFrames:body.rangeTotalFrames,sampleRate:body.rangeSampleRate,originalSha256:body.originalSha256};
 if(body.singleAudio!==true||![r.startFrame,r.endFrame,r.totalFrames,r.sampleRate].every(Number.isSafeInteger)||r.startFrame<0||r.endFrame<=r.startFrame||r.totalFrames<r.endFrame||![8000,11025,12000,16000,22050,24000,32000,44100,48000].includes(r.sampleRate)||! /^[a-f0-9]{64}$/.test(r.originalSha256||''))throw Error('TRANSCRIPTION_RANGE_INVALID');
 return r;
}
function rangeRefs(db,uid,sourceId,r) {
 if(!uid||typeof sourceId!=='string'||!/^[A-Za-z0-9_.-]{1,160}$/.test(sourceId))throw Error('TRANSCRIPTION_RANGE_INVALID');
 const key=hash(`${uid}\n${sourceId}\nr1`);
 return {root:db.collection('transcriptionRangeSources').doc(key),binding:db.collection('transcriptionSourceJobs').doc(hash(`${key}\n${r.startFrame}`))};
}
function sameRange(a,b){return a&&b&&['startFrame','endFrame','totalFrames','sampleRate','originalSha256'].every(k=>a[k]===b[k]);}
async function prepareRange(tx,db,{uid,sourceId,jobId,range,existing}) {
 const refs=rangeRefs(db,uid,sourceId,range),root=await tx.get(refs.root),binding=await tx.get(refs.binding);
 const state=root.data();
 if(state&&(state.uid!==uid||state.sourceId!==sourceId||state.originalSha256!==range.originalSha256||state.totalFrames!==range.totalFrames||state.sampleRate!==range.sampleRate))throw Error('TRANSCRIPTION_RANGE_SOURCE_MISMATCH');
 if(binding.exists&&binding.data().jobId!==jobId)throw Error('SOURCE_JOB_ALREADY_EXISTS');
 if(existing){if(!sameRange(existing.transcriptionRange,range))throw Error('TRANSCRIPTION_RANGE_CONFLICT');return ()=>{};}
 if((state?.cursorFrame||0)!==range.startFrame||state?.pendingJobId&&state.pendingJobId!==jobId)throw Error('TRANSCRIPTION_RANGE_CURSOR_CONFLICT');
 return ()=>{
  tx.set(refs.root,{uid,sourceId,originalSha256:range.originalSha256,totalFrames:range.totalFrames,sampleRate:range.sampleRate,cursorFrame:range.startFrame,pendingJobId:jobId},{merge:true});
  tx.set(refs.binding,{uid,sourceId,jobId,transcriptionRange:range});
 };
}
function assertRangeMedia(range,{durationMs,frameCount,sampleRate}) {
 if(!range)return;
 if(frameCount!==range.endFrame-range.startFrame||sampleRate!==range.sampleRate||durationMs!==Math.ceil(frameCount*1024*1000/sampleRate))throw Error('TRANSCRIPTION_RANGE_MEDIA_MISMATCH');
}
async function settleRange(db,jobRef,job) {
 if(!job.transcriptionRange)return;
 const range=job.transcriptionRange,refs=rangeRefs(db,job.uid,job.sourceId,range);
 await db.runTransaction(async tx=>{
  const [root,j]=await Promise.all([tx.get(refs.root),tx.get(jobRef)]),state=root.data(),value=j.data();
  if(!value||value.uid!==job.uid||value.sourceId!==job.sourceId||value.deleted||value.accountingFinalizedAt==null||value.state!=='completed'||!sameRange(value.transcriptionRange,range)||state?.uid!==job.uid||state?.sourceId!==job.sourceId)throw Error('TRANSCRIPTION_RANGE_SETTLEMENT_INVALID');
  if(state.cursorFrame>=range.endFrame){tx.set(jobRef,{transcriptionRangeFinalized:true},{merge:true});return;}
  if(state.cursorFrame!==range.startFrame||state.pendingJobId!==jobRef.id)throw Error('TRANSCRIPTION_RANGE_CURSOR_CONFLICT');
  tx.set(refs.root,{cursorFrame:range.endFrame,pendingJobId:null},{merge:true});
  tx.set(jobRef,{transcriptionRangeFinalized:true},{merge:true});
 });
}
module.exports={parseRange,rangeRefs,sameRange,prepareRange,assertRangeMedia,settleRange};
