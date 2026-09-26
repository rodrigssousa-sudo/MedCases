'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {Timestamp} = require('firebase-admin/firestore');
const {TranscriptionDurableQueue} = require('./transcription_durable_queue');
const hash = x => require('node:crypto').createHash('sha256').update(x).digest('hex');
function wav(seconds=1) {
  const data=16000*2*seconds,b=Buffer.alloc(44+data);
  b.write('RIFF');b.writeUInt32LE(36+data,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);
  b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(16000,24);b.writeUInt32LE(32000,28);
  b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(data,40);
  for(let i=44;i<b.length;i+=2)b.writeInt16LE(Math.round(1000*Math.sin(i/20)),i);
  return b;
}
function fixture(transcribe=async()=> 'Synthetic non-patient fixture') {
  const rows=new Map(),objects=new Map();let txTail=Promise.resolve(),calls=0,settled=0;
  function collection(path,filter) {
    return {doc:id=>ref(`${path}/${id}`),where:(field,op,value)=>collection(path,[field,value]),limit(){return this;},
      async get(){return {docs:[...rows].filter(([k,v])=>k.startsWith(path+'/')&&!k.slice(path.length+1).includes('/')&&(!filter||v[filter[0]]===filter[1])).map(([k,v])=>({id:k.split('/').at(-1),ref:ref(k),data:()=>v}))};}};
  }
  function ref(path) {return {id:path.split('/').at(-1),path,collection:n=>collection(`${path}/${n}`),
    async get(){return {exists:rows.has(path),data:()=>rows.get(path)};},
    async set(v,o){rows.set(path,o?.merge?{...rows.get(path),...v}:v);},async delete(){rows.delete(path);}};}
  const db={collection,runTransaction(fn){const run=txTail.then(()=>fn({get:r=>r.get(),set:(r,v,o)=>r.set(v,o)}));txTail=run.catch(()=>{});return run;}};
  const usage={'x-medcases-usage-reservation':'b'.repeat(64),'x-medcases-usage-attempt':'test-attempt'};
  const job={uid:'synthetic-owner',usage,expectedSegments:1,expiresAt:Timestamp.fromMillis(Date.now()+3600000)};
  rows.set('usageReservations/'+usage['x-medcases-usage-reservation'],{uid:job.uid,state:'reserved',attempt:'test-attempt',kinds:['transcription'],maximumMs:120000});
  const jobRef=ref('_study_background_transcription_jobs/'+'a'.repeat(64));rows.set(jobRef.path,job);
  const storage={key:(j,i,t)=>`segments/${j}/${i}/${t}`,async put(k,b){objects.set(k,Buffer.from(b));},async get(k){if(!objects.has(k))throw Error('missing');return Buffer.from(objects.get(k));},async remove(k){objects.delete(k);}};
  const execution=ref('usageExecutions/'+hash(`${usage['x-medcases-usage-reservation']}:test-attempt:0`));
  const owner={async claimExecution(){if(rows.has(execution.path))return {claimed:false};rows.set(execution.path,{state:'executing'});return {claimed:true};},async completeExecution(){settled++;rows.set(execution.path,{state:'completed'});}};
  const queue=new TranscriptionDurableQueue({db,storage,owner,transcribe:async(...a)=>{calls++;return transcribe(...a);}});
  const segment=jobRef.collection('segments').doc('0');
  return {queue,db,job,jobRef,segment,rows,objects,storage,owner,execution,calls:()=>calls,settled:()=>settled};
}
test('enqueue is durable and early; restart worker finishes and deletes audio after result',async()=>{
  const f=fixture();const result=await f.queue.enqueue(f.jobRef,f.job,0,wav(),Date.now());
  assert.equal(result.state,'queued');assert.equal(f.calls(),0);assert.equal(f.objects.size,1);
  const restarted=new TranscriptionDurableQueue({db:f.db,storage:f.storage,owner:f.owner,transcribe:async()=> 'Recovered'});
  await restarted.tick();const v=(await f.segment.get()).data();
  assert.equal(v.state,'done');assert.equal(v.transcript,'Recovered');assert.equal(f.objects.size,0);assert.equal(f.settled(),1);
  assert(v.timings.providerCallStart<=v.timings.providerCallEnd);assert(v.completedAt);
});
test('completed replay returns same transcript with no provider duplication',async()=>{
  const f=fixture(),b=wav();await f.queue.enqueue(f.jobRef,f.job,0,b,Date.now());await f.queue.tick();
  const replay=await f.queue.enqueue(f.jobRef,f.job,0,b,Date.now());
  assert.equal(replay.state,'completed');assert.equal(f.calls(),1);assert.equal(f.objects.size,0);
});
test('active execution replay is accepted as processing, never terminal',async()=>{
  let release;const wait=new Promise(r=>release=r);const f=fixture(async()=>{await wait;return 'Ready';}),b=wav();
  await f.queue.enqueue(f.jobRef,f.job,0,b,Date.now());const worker=f.queue.tick();
  while(!f.calls())await new Promise(r=>setTimeout(r,10));
  const again=await f.queue.enqueue(f.jobRef,f.job,0,b,Date.now());assert.equal(again.state,'processing');
  release();await worker;assert.equal(f.calls(),1);
});
test('stale processing with prior execution persists terminal state without redispatch',async()=>{
  const f=fixture();await f.queue.enqueue(f.jobRef,f.job,0,wav(),Date.now());
  await f.segment.set({state:'processing',leaseUntil:Timestamp.fromMillis(1)},{merge:true});
  await f.execution.set({state:'completed'});await f.queue.tick();
  assert.equal((await f.segment.get()).data().state,'terminal_error');assert.equal(f.calls(),0);assert.equal(f.objects.size,1);
});
test('stale processing before execution resumes same stored audio',async()=>{
  const f=fixture();await f.queue.enqueue(f.jobRef,f.job,0,wav(),Date.now());
  await f.segment.set({state:'processing',leaseUntil:Timestamp.fromMillis(1)},{merge:true});await f.queue.tick();
  assert.equal((await f.segment.get()).data().state,'done');assert.equal(f.calls(),1);
});
test('provider error becomes durable terminal error, never repeats consumed execution',async()=>{
  const f=fixture(async()=>{throw Error('openai_transcription_504');}),b=wav();
  await f.queue.enqueue(f.jobRef,f.job,0,b,Date.now());await f.queue.tick();
  const v=(await f.segment.get()).data();assert.equal(v.state,'terminal_error');assert.equal(v.errorCategory,'OPENAI_TRANSCRIPTION_504');
  assert.equal((await f.queue.enqueue(f.jobRef,f.job,0,b,Date.now())).state,'terminal_error');assert.equal(f.calls(),1);
});
test('object storage failure is retryable and does not call provider',async()=>{
  const f=fixture();f.storage.put=async()=>{throw Error('storage unavailable');};
  await assert.rejects(f.queue.enqueue(f.jobRef,f.job,0,wav(),Date.now()));
  assert.equal((await f.segment.get()).data().state,'retryable_error');assert.equal(f.calls(),0);
});
test('same segment cannot replace audio with different bytes',async()=>{
  const f=fixture();await f.queue.enqueue(f.jobRef,f.job,0,wav(),Date.now());
  await assert.rejects(f.queue.enqueue(f.jobRef,f.job,0,wav(2),Date.now()),/SEGMENT_CONTENT_CONFLICT/);
});

module.exports={fixture,wav};
