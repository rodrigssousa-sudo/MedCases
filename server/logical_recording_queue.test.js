'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {Readable}=require('node:stream');
const {fixture,wav}=require('./transcription_durable_queue.test');
const {MedCasesTranscriptionService}=require('./medcases_transcription_service');
const {LogicalRecordingQueue}=require('./logical_recording_queue');
const {Timestamp}=require('firebase-admin/firestore');
function setup(){
 const f=fixture();f.job.provider='assemblyai';f.job.mode='lecture';f.job.locale='pt';f.job.sessionId='synthetic';
 let submissions=0,polls=0,deleted=0,failClaim=false;
 f.storage.getStream=async key=>({body:Readable.from([await f.storage.get(key)])});
 const put=f.storage.put;f.storage.put=async(k,b)=>{if(Buffer.isBuffer(b))return put(k,b);const chunks=[];for await(const c of b)chunks.push(c);return put(k,Buffer.concat(chunks));};
 const provider={async upload(stream){for await(const c of stream)assert(c.length);return 'https://synthetic.invalid/audio';},async submit(){submissions++;return {providerTranscriptId:'synthetic-provider-id'};},async poll(){polls++;return {status:'completed',text:'Primeira fala. Segunda fala.',utterances:[],words:[{text:'Primeira fala.',startMs:0,endMs:500},{text:'Segunda fala.',startMs:1000,endMs:1500}]};},async remove(){deleted++;}};
 const centralService=new MedCasesTranscriptionService({providers:{assemblyai:provider}});
 const claim=f.owner.claimExecution;f.owner.claimExecution=async(...args)=>{const r=await claim(...args);if(failClaim){failClaim=false;throw Error('SIMULATED_PROCESS_EXIT_AFTER_CLAIM');}return r;};
 const assemble=async({segments})=>{const dir=fs.mkdtempSync(path.join(os.tmpdir(),'logical-test-')),file=path.join(dir,'audio.wav');fs.writeFileSync(file,wav(segments.length));return {path:file,byteLength:fs.statSync(file).size,totalDurationMs:segments.length*1000,totalBytes:segments.length*32044,physicalSegments:segments.map(v=>({index:v.index,durationMs:1000,sha256:v.bodyHash})),cleanup:async()=>fs.rmSync(dir,{recursive:true,force:true})};};
 const build=()=>new LogicalRecordingQueue({db:f.db,storage:f.storage,owner:f.owner,centralService,assemble});
 return {...f,build,provider,submissions:()=>submissions,polls:()=>polls,deleted:()=>deleted,crashAfterClaim:()=>{failClaim=true;}};
}
test('physical files become one durable logical provider job across worker restart',async()=>{
 const f=setup();f.job.expectedSegments=2;
 await f.queue.enqueue(f.jobRef,f.job,0,wav(),Date.now());await f.queue.enqueue(f.jobRef,f.job,1,wav(),Date.now());
 await f.build().process(f.jobRef,f.job);assert.equal(f.submissions(),1);
 await f.build().process(f.jobRef,f.job);assert.equal(f.submissions(),1);assert.equal(f.objects.size,0);
 assert.equal((await f.jobRef.get()).data().state,'completed');
 assert.equal((await f.segment.get()).data().transcript,'Primeira fala.');
 assert.equal((await f.jobRef.collection('segments').doc('1').get()).data().transcript,'Segunda fala.');
});
test('crash after usage claim recovers same logical recording without terminal execution error',async()=>{
 const f=setup();await f.queue.enqueue(f.jobRef,f.job,0,wav(),Date.now());f.crashAfterClaim();
 await f.build().process(f.jobRef,f.job);assert.equal(f.submissions(),0);
 const logical=f.jobRef.collection('logical').doc('recording');assert.equal((await logical.get()).data().state,'retryable_error');
 await logical.set({leaseUntil:Timestamp.fromMillis(1)},{merge:true});
 await f.build().process(f.jobRef,f.job);await f.build().process(f.jobRef,f.job);
 assert.equal(f.submissions(),1);assert.equal((await f.jobRef.get()).data().state,'completed');
});
for(const state of ['queued','processing','completed'])test('cancel '+state+' keeps tombstone and removes synthetic objects',async()=>{
 const f=setup();await f.queue.enqueue(f.jobRef,f.job,0,wav(),Date.now());const worker=f.build();
 if(state!=='queued')await worker.process(f.jobRef,f.job);
 if(state==='completed')await worker.process(f.jobRef,f.job);
 await worker.cancel(f.jobRef);
 await f.build().process(f.jobRef,(await f.jobRef.get()).data());
 assert.equal((await f.jobRef.get()).data().deleted,true);assert.equal((await f.jobRef.get()).data().state,'cancelled');assert.equal(f.objects.size,0);assert.equal((await f.segment.get()).data().transcript,null);
});
test('late provider result cannot recreate deleted transcript',async()=>{
 const f=setup();await f.queue.enqueue(f.jobRef,f.job,0,wav(),Date.now());const worker=f.build();await worker.process(f.jobRef,f.job);
 let release,entered;const signal=new Promise(r=>entered=r);const wait=new Promise(r=>release=r);const poll=f.provider.poll;f.provider.poll=async()=>{entered();await wait;return poll();};
 const running=worker.process(f.jobRef,f.job);await signal;await worker.cancel(f.jobRef);release();await running;
 assert.equal((await f.jobRef.get()).data().state,'cancelled');assert.equal((await f.segment.get()).data().transcript,null);assert.equal(f.objects.size,0);
});
test('worker whose lease was replaced cannot persist a submission intent',async()=>{
 const f=setup(),worker=f.build(),ref=f.jobRef.collection('logical').doc('recording');
 await ref.set({state:'processing',leaseToken:'new-owner'});
 await assert.rejects(worker.guardedRef(f.jobRef,ref,'expired-owner').set({submissionIntent:true},{merge:true}),/WORKER_LEASE_LOST/);
 assert.equal((await ref.get()).data().submissionIntent,undefined);assert.equal(f.submissions(),0);
});
