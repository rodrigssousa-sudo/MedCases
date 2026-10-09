'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8186'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9098')throw Error('LOCAL_EMULATORS_REQUIRED');
const express=require('express');
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');const {getAuth}=require('firebase-admin/auth');
const {createDerivativeRuntime,mountDerivativeRuntime,DerivativeRollout}=require('../derivative_r24_runtime');
const {ExtractiveDerivativeEngine}=require('../extractive_derivative_engine');
const {DerivativeR21FirestoreStore}=require('../derivative_r21_firestore_store');
const {hash,DerivativeError}=require('../derivative_contract');
const app=initializeApp({projectId:'demo-derivative-r23'}),db=getFirestore(app);
const store=new DerivativeR21FirestoreStore(db);
store.collection=db.collection('_derivative_r24_runtime_integration_test');
let server,base,uid,token,otherToken,runtime,calls=0,failNext=false,unblock,started;
async function signup(){const r=await fetch('http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-emulator-key',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({returnSecureToken:true})});assert.equal(r.status,200);return r.json();}
const request=(id,type='ORGANIZATION')=>({sourceId:id,operationId:id,derivativeType:type,locale:'pt',rawTranscript:'Queixa principal: Texto fictício.\nMedicamentos: Test-A.',transcriptHash:hash('Queixa principal: Texto fictício.\nMedicamentos: Test-A.')});
async function send(method,path,body,auth=token){const r=await fetch(base+path,{method,headers:{authorization:'Bearer '+auth,'content-type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});return {code:r.status,body:await r.json()};}
test.before(async()=>{
 const first=await signup(),second=await signup();uid=first.localId;token=first.idToken;otherToken=second.idToken;
 const clinicalEngine={generate:async input=>{calls++;if(started)started();if(unblock)await unblock.promise;if(failNext){failNext=false;throw new DerivativeError('provider_unavailable',true);}return new ExtractiveDerivativeEngine().generate(input);}};
 runtime=createDerivativeRuntime({db,store,clinicalEngine,rollout:new DerivativeRollout({approvedTypes:['ANAMNESIS','EVOLUTION','ORGANIZATION'],routes:Object.fromEntries(['ANAMNESIS','EVOLUTION','ORGANIZATION'].map(t=>[t,{stage:'full'}]))})});
 const http=express();http.use(express.json());http.use(async(req,res,next)=>{try{const id=await getAuth(app).verifyIdToken((req.headers.authorization??'').replace(/^Bearer /,''));req.auth={uid:id.uid};next();}catch{res.status(401).json({error:'unauthenticated'});}});
 mountDerivativeRuntime(http,runtime);server=http.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));base='http://127.0.0.1:'+server.address().port;
});
test.after(async()=>{await new Promise(resolve=>server.close(resolve));await db.terminate();await deleteApp(app);});
test('real HTTP + Firebase Auth + Firestore: create, processing, complete, source binding, isolated readback',async()=>{
 const r=await send('POST','/api/ai/derivatives',{...request('runtime-http'),ownerUid:'forged'});assert.equal(r.code,202);assert.equal(r.body.status,'READY');
 let release;unblock={promise:new Promise(resolve=>release=resolve)};let mark;const start=new Promise(resolve=>mark=resolve);started=mark;
 const ticking=runtime.tick();await start;
 const pending=await send('GET','/api/ai/derivatives/'+r.body.operationKey);assert.equal(pending.body.status,'PROCESSING');
 release();unblock=null;started=null;await ticking;
 const done=await send('GET','/api/ai/derivatives/'+r.body.operationKey);assert.equal(done.body.status,'COMPLETED');assert.equal(done.body.transcriptHash,request('runtime-http').transcriptHash);
 assert.equal((await send('GET','/api/ai/derivatives/'+r.body.operationKey,null,otherToken)).code,404);
 assert.equal((await send('POST','/api/ai/derivatives',request('bad-token'),'invalid')).code,401);
});
test('real failed state and explicit retry preserve source and recover without duplicate delivery',async()=>{
 const r=await send('POST','/api/ai/derivatives',request('runtime-failure','EVOLUTION'));
 failNext=true;await runtime.tick();assert.equal((await send('GET','/api/ai/derivatives/'+r.body.operationKey)).body.status,'FAILED_RETRYABLE');
 await runtime.operations.update(r.body.operationKey,j=>({...j,nextAttemptAt:0}));
 const retry=await send('POST','/api/ai/derivatives/'+r.body.operationKey+'/retry',{});assert.equal(retry.code,202);
 await Promise.all([runtime.tick(),runtime.tick()]);assert.equal((await send('GET','/api/ai/derivatives/'+r.body.operationKey)).body.status,'COMPLETED');
 const row=await runtime.operations.store.transaction(r.body.operationKey,tx=>tx.read());assert.equal(row.input.rawTranscript,request('runtime-failure').rawTranscript);
});
test('new runtime sees durable results; repeated operation and content cache do not generate again',async()=>{
 const before=calls,r=await send('POST','/api/ai/derivatives',request('runtime-http'));
 assert.equal(r.body.status,'COMPLETED');
 const restarted=createDerivativeRuntime({db,store});
 const saved=await restarted.operations.status(uid,r.body.operationKey);assert.equal(saved.status,'COMPLETED');
 const sameSource=await send('POST','/api/ai/derivatives',{...request('runtime-http'),operationId:'new-operation-same-source'});
 assert.equal(sameSource.body.status,'COMPLETED');await runtime.tick();assert.equal(calls,before);
});
