'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8189')throw Error('LOCAL_EMULATOR_REQUIRED');
const {initializeApp,deleteApp}=require('firebase-admin/app');const app=initializeApp({projectId:'demo-transcription-observability'}),db=require('firebase-admin/firestore').getFirestore(app);
const {StudyArtifactAttemptLedger,metadata}=require('../study_artifact_attempt_ledger');
const {createAdminOperations}=require('../../functions/admin_operations');
const ledger=new StudyArtifactAttemptLedger({db});after(()=>deleteApp(app));
const data=type=>({attemptId:crypto.randomUUID(),artifactId:'artifact-test',sourceIds:['source-a'],sessionIds:['session-a'],studyId:'study-a',type,platform:'ios',locale:'pt',appVersion:'7.0.2',buildNumber:'1711'});
for(const type of ['summary','visual','oral'])test(type+' persists pre-provider intent, retry and completion once',async()=>{
 const m=data(type),uid='qa-'+m.attemptId;
 const first=await ledger.create(uid,m);assert.equal(first.state,'REQUESTED');
 assert.equal((await ledger.create(uid,m)).idempotent,true);
 await assert.rejects(ledger.create(uid,{...m,sourceIds:['other']}),/BINDING/);
 for(const state of ['PROVIDER','PARSING','PERSISTING','COMPLETED'])await ledger.advance(uid,m.attemptId,{state});
 await ledger.advance(uid,m.attemptId,{state:'FAILED',reasonCode:'NETWORK'});
 const stored=(await ledger.ref(uid,m.attemptId).get()).data();assert.equal(stored.status,'COMPLETED');assert.equal(stored.sourceId,'source-a');assert.equal(stored.timeline.length,5);
 await assert.rejects(ledger.advance('other',m.attemptId,{state:'COMPLETED'}),/NOT_OWNED/);
});
test('failure incident idempotency and PHI input rejected',async()=>{
 const m=data('visual'),uid='qa-'+m.attemptId;
 assert.throws(()=>metadata({...m,transcript:'forbidden'}),/INVALID/);
 await ledger.create(uid,m);await ledger.advance(uid,m.attemptId,{state:'FAILED',reasonCode:'PARSE_FAILURE'});
 const before=(await ledger.ref(uid,m.attemptId).get()).data();await ledger.advance(uid,m.attemptId,{state:'FAILED',reasonCode:'PARSE_FAILURE'});
 assert.deepEqual((await ledger.ref(uid,m.attemptId).get()).data(),before);
 const incident=await db.collection('admin_incidents').where('module','==','visual').where('reasonCode','==','PARSE_FAILURE').get();assert(incident.size>0);
 await assert.rejects(ledger.advance(uid,m.attemptId,{state:'FAILED',reasonCode:'raw patient text'}),/INVALID/);
});
test('Admin sees all derived kinds and refuses normal user',async()=>{
 const m=data('oral'),uid='qa-'+m.attemptId,admin='admin-'+m.attemptId;
 await db.doc('users/'+admin).set({role:'admin',status:'approved'});
 await db.doc('users/'+uid).set({role:'user',status:'approved'});
 await ledger.create(uid,m);const api=createAdminOperations({db});
 await assert.rejects(api.page(uid,{table:'jobs'}),/ADMIN_ACCESS_DENIED/);
 const page=await api.page(admin,{table:'jobs',field:'type',value:'oral',limit:100});assert(page.items.some(x=>x.owner===uid&&x.sourceId==='source-a'));
});
test('stalled client attempt closes and an eventual durable completion reconciles same id',async()=>{
 let time=100;const l=new StudyArtifactAttemptLedger({db,now:()=>time}),m=data('summary'),uid='qa-'+m.attemptId;
 await l.create(uid,m);await l.advance(uid,m.attemptId,{state:'PROVIDER'});time+=31*60*1000;
 await l.expirePending();let v=(await l.ref(uid,m.attemptId).get()).data();assert.equal(v.status,'FAILED');assert.equal(v.stage,'PROVIDER');assert.equal(v.lastErrorCode,'CLIENT_TIMEOUT');
 await l.advance(uid,m.attemptId,{state:'COMPLETED'});v=(await l.ref(uid,m.attemptId).get()).data();assert.equal(v.status,'COMPLETED');assert.equal(v.attemptId,m.attemptId);
});
test('reconciliation reaches expired attempts beyond the first page',async()=>{
 let time=100;const l=new StudyArtifactAttemptLedger({db,now:()=>time});
 const owner='qa-page-'+crypto.randomUUID(),batch=db.batch();
 for(let n=0;n<105;n++){const m=data('visual');batch.set(l.ref(owner,m.attemptId),{...m,owner,fingerprint:'fixture',status:'PARSING',stage:'PARSING',updatedAt:time,timeline:[]});}
 await batch.commit();time+=31*60*1000;await l.expirePending();
 const rows=await db.collection('adminOperationalJobs').where('owner','==',owner).get();
 assert.equal(rows.size,105);assert(rows.docs.every(d=>d.data().status==='FAILED'&&d.data().lastErrorCode==='CLIENT_TIMEOUT'));
});
test('HTTP routes require identity, reject clinical fields and isolate owners',async()=>{
 const express=require('express'),web=express();
 require('../transcription_attempt_routes').registerTranscriptionAttemptRoutes(web,{getDb:()=>db,authenticate:async req=>{const uid=req.get('x-fixture-owner');if(!uid)throw Error('AUTH_REQUIRED');return uid;}});
 const server=await new Promise(resolve=>{const s=web.listen(0,'127.0.0.1',()=>resolve(s));});
 try{
  const base=`http://127.0.0.1:${server.address().port}/api/ai/study/artifact-attempts`,m=data('visual'),owner='qa-http-'+m.attemptId;
  const post=(url,body,uid)=>fetch(url,{method:'POST',headers:{'content-type':'application/json',...(uid?{'x-fixture-owner':uid}:{})},body:JSON.stringify(body)});
  assert.equal((await post(base,m)).status,403);
  assert.equal((await post(base,{...m,transcript:'forbidden'},owner)).status,400);
  assert.equal((await post(base,m,owner)).status,200);
  assert.equal((await post(base+'/'+m.attemptId+'/events',{state:'COMPLETED'},'different-owner')).status,403);
  assert.equal((await post(base+'/'+m.attemptId+'/events',{state:'COMPLETED'},owner)).status,200);
 }finally{await new Promise(resolve=>server.close(resolve));}
});
