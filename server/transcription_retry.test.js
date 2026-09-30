'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {fixture}=require('./transcription_durable_queue.test');
const {resumeTranscriptionJob}=require('./transcription_retry');
test('retry resumes only owner job and preserves provider and audio binding',async()=>{
 const f=fixture(),ref=f.jobRef.collection('logical').doc('recording');
 await ref.set({state:'retryable_error',retrySuspended:true,consecutiveFailures:5,providerTranscriptId:'qa-provider',objectKey:'qa-object',physicalSegments:[{sha256:'qa-hash'}]});
 const args={db:f.db,jobRef:f.jobRef,uid:f.job.uid,expectedSegments:1,requestId:'qa-retry-1'};
 await assert.rejects(resumeTranscriptionJob({...args,uid:'someone-else'}),/RETRY_NOT_OWNED/);
 assert.equal((await ref.get()).data().retrySuspended,true);
 assert.equal((await resumeTranscriptionJob(args)).resumed,true);
 assert.equal((await resumeTranscriptionJob(args)).idempotent,true);
 const value=(await ref.get()).data();assert.equal(value.providerTranscriptId,'qa-provider');assert.equal(value.objectKey,'qa-object');assert.equal(value.retrySuspended,false);assert.equal((await f.jobRef.get()).data().workerPending,true);
});
test('retry does not wake a normally active or completed job',async()=>{
 const f=fixture();await f.jobRef.set({state:'completed',workerPending:false},{merge:true});
 assert.equal((await resumeTranscriptionJob({db:f.db,jobRef:f.jobRef,uid:f.job.uid,expectedSegments:1,requestId:'qa-retry-2'})).idempotent,true);
 assert.equal((await f.jobRef.get()).data().workerPending,false);
});
