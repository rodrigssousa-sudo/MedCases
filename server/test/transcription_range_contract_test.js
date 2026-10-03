'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {database}=require('./transaction_fixture');
const {parseRange,rangeRefs,prepareRange,settleRange,assertRangeMedia}=require('../transcription_range_contract');
const first={startFrame:0,endFrame:100,totalFrames:200,sampleRate:24000,originalSha256:'a'.repeat(64)};
async function bind(db,range=first,id='job-first',uid='A'){
 const job=db.collection('jobs').doc(id);
 await db.runTransaction(async tx=>{const existing=await tx.get(job);const commit=await prepareRange(tx,db,{uid,sourceId:'source',jobId:id,range,existing:existing.exists?existing.data():null});if(!existing.exists){commit();tx.set(job,{uid,sourceId:'source',transcriptionRange:range,state:'queued'});}});
 return job;
}
async function completed(db,job){const data=(await job.get()).data();await job.set({...data,state:'completed',accountingFinalizedAt:1});await settleRange(db,job,data);}
test('range parser rejects incomplete, inverted, fractional and forged identities',()=>{
 assert.equal(parseRange({singleAudio:true}),null);
 const body={singleAudio:true,rangeStartFrame:0,rangeEndFrame:100,rangeTotalFrames:200,rangeSampleRate:24000,originalSha256:'a'.repeat(64)};
 assert.deepEqual(parseRange(body),first);
 for(const change of [{rangeEndFrame:0},{rangeStartFrame:0.5},{rangeTotalFrames:99},{rangeSampleRate:999},{originalSha256:'token'},{singleAudio:false}])assert.throws(()=>parseRange({...body,...change}),/RANGE_INVALID/);
});
test('single original supports tail only after server accounting, with exactly-once cursor',async()=>{
 const db=database(),job=await bind(db);
 await assert.rejects(settleRange(db,job,(await job.get()).data()),/SETTLEMENT_INVALID/);
 await assert.rejects(bind(db,{...first,startFrame:100,endFrame:200},'tail'),/CURSOR_CONFLICT/);
 await completed(db,job);await completed(db,job);
 assert.equal((await rangeRefs(db,'A','source',first).root.get()).data().cursorFrame,100);
 const tail=await bind(db,{...first,startFrame:100,endFrame:200},'tail');await completed(db,tail);
 assert.equal((await rangeRefs(db,'A','source',first).root.get()).data().cursorFrame,200);
 await bind(db,first,'job-first');
});
test('same range request is idempotent; different receipt cannot replay it',async()=>{
 const db=database();await Promise.all(Array.from({length:8},()=>bind(db)));
 assert.equal([...db.records.keys()].filter(k=>k.startsWith('jobs/')).length,1);
 await assert.rejects(bind(db,first,'second'),/SOURCE_JOB_ALREADY_EXISTS/);
 await assert.rejects(bind(db,{...first,endFrame:101}),/RANGE_CONFLICT/);
});
test('original fingerprint, total frames and rate cannot change on continuation',async()=>{
 const db=database(),job=await bind(db);await completed(db,job);
 for(const change of [{originalSha256:'b'.repeat(64)},{totalFrames:300},{sampleRate:16000}])await assert.rejects(bind(db,{...first,startFrame:100,endFrame:200,...change},'tail'),/SOURCE_MISMATCH/);
 await assert.rejects(bind(db,{...first,startFrame:101,endFrame:200},'gap'),/CURSOR_CONFLICT/);
});
test('other user has an independent source and cannot settle another owner job',async()=>{
 const db=database(),job=await bind(db);await bind(db,first,'other','B');
 await completed(db,job);await assert.rejects(settleRange(db,job,{...(await job.get()).data(),uid:'B'}),/SETTLEMENT_INVALID/);
 assert.equal((await rangeRefs(db,'B','source',first).root.get()).data().cursorFrame,0);
});
test('uploaded frame count/rate and server-proved duration must all match range',()=>{
 const durationMs=Math.ceil(100*1024*1000/24000);
 assertRangeMedia(first,{durationMs,frameCount:100,sampleRate:24000});
 for(const change of [{durationMs:1},{frameCount:99},{sampleRate:48000}])assert.throws(()=>assertRangeMedia(first,{durationMs,frameCount:100,sampleRate:24000,...change}),/MEDIA_MISMATCH/);
});
