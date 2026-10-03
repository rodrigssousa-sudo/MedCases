'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('EMULATOR_REQUIRED');
const {initializeApp,deleteApp}=require('firebase-admin/app'),{getFirestore}=require('firebase-admin/firestore');
const app=initializeApp({projectId:'demo-audio-r1'}),db=getFirestore(app);
const {prepareRange,settleRange,rangeRefs}=require('../transcription_range_contract');
after(()=>deleteApp(app));
const range={startFrame:0,endFrame:100,totalFrames:200,sampleRate:24000,originalSha256:'a'.repeat(64)};
async function bind(uid,id,r=range){const ref=db.collection('jobs').doc(id);await db.runTransaction(async tx=>{const old=await tx.get(ref),write=await prepareRange(tx,db,{uid,sourceId:'source',jobId:id,range:r,existing:old.exists?old.data():null});if(!old.exists){write();tx.set(ref,{uid,sourceId:'source',state:'queued',transcriptionRange:r});}});return ref;}
test('Firestore real concurrency binds same range once and rejects second receipt',async()=>{
 const uid=crypto.randomUUID(),id=crypto.randomUUID();await Promise.all(Array.from({length:8},()=>bind(uid,id)));
 const results=await Promise.allSettled(Array.from({length:8},()=>bind(uid,crypto.randomUUID())));assert(results.every(r=>r.status==='rejected'));
 const root=(await rangeRefs(db,uid,'source',range).root.get()).data();assert.equal(root.pendingJobId,id);assert.equal(root.cursorFrame,0);
});
test('settlement and tail race cannot skip or overlap, repeated settlement is stable',async()=>{
 const uid=crypto.randomUUID(),id=crypto.randomUUID(),ref=await bind(uid,id);const job=(await ref.get()).data();
 await ref.set({state:'completed',accountingFinalizedAt:1},{merge:true});
 await Promise.all(Array.from({length:8},()=>settleRange(db,ref,job)));
 const tail={...range,startFrame:100,endFrame:200};
 const results=await Promise.allSettled(Array.from({length:6},()=>bind(uid,crypto.randomUUID(),tail)));
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 const root=(await rangeRefs(db,uid,'source',range).root.get()).data();assert.equal(root.cursorFrame,100);
 assert.equal((await ref.get()).data().transcriptionRangeFinalized,true);
});
