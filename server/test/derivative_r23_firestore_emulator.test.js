'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8186')throw Error('LOCAL_EMULATOR_REQUIRED');
const {initializeApp,deleteApp}=require('firebase-admin/app');const {getFirestore}=require('firebase-admin/firestore');
const {DerivativeR21FirestoreStore}=require('../derivative_r21_firestore_store');
const {DerivativeR21Operations,DerivativeR21Worker,createDerivativeHandlers}=require('../derivative_r21_operations');
const {DerivativeStageRunner}=require('../derivative_stage_runner');
const {ExtractiveDerivativeEngine}=require('../extractive_derivative_engine');
const {hash,DerivativeError}=require('../derivative_contract');
const projectId='demo-derivative-r23';const app=initializeApp({projectId});const db=getFirestore(app);const store=new DerivativeR21FirestoreStore(db);
const source='Fonte fictícia: nenhum medicamento foi prescrito.';
const request=id=>({sourceId:id,operationId:id,derivativeType:'ORGANIZATION',locale:'pt',rawTranscript:`${source} Registro ${id}.`,transcriptHash:hash(`${source} Registro ${id}.`)});
const ops=engine=>new DerivativeR21Operations({store,clinicalEngine:engine||new ExtractiveDerivativeEngine(),enabled:true});
test.after(async()=>{await db.terminate();await deleteApp(app);});
test('emulator create, durable worker restart and completion readback',async()=>{
 const a=await ops().create('owner-a',request('restart'));assert.equal(a.status,'READY');
 await new DerivativeR21Worker(ops()).tick();const b=await ops().status('owner-a',a.operationKey);assert.equal(b.status,'COMPLETED');assert.ok(b.result);assert.equal(b.input,undefined);
 await assert.rejects(ops().status('owner-b',a.operationKey),{code:'not_found'});
});
test('emulator concurrent operation deliveries and cache generate once',async()=>{
 let calls=0;const o=ops({generate:async i=>{calls++;return new ExtractiveDerivativeEngine().generate(i);}});
 const a=await o.create('owner-a',request('concurrency'));
 await Promise.all([o.process(a.operationKey),o.process(a.operationKey)]);assert.equal(calls,1);
 const b=await o.create('owner-a',{...request('concurrency'),operationId:'other'});assert.equal(b.status,'COMPLETED');await o.process(b.operationKey);assert.equal(calls,1);
});
test('emulator stage checkpoints survive runner restart and preserve missing-review retry',async()=>{
 let now=0,calls=0,fail=true;const context={store,ownerUid:'owner-a',operationId:'stage-checkpoint',revision:'r23',now:()=>now};
 const client={identity:'reviewer',complete:async a=>{calls++;if(a.name==='pedagogy'&&fail)throw new DerivativeError('RETRYABLE_PROVIDER_LIMIT',true,{httpStatus:429,retryAfterMs:5000});return {value:{stage:a.name},identity:'reviewer'};}};
 await new DerivativeStageRunner(context).complete(client,{name:'semantic'});
 await assert.rejects(new DerivativeStageRunner(context).complete(client,{name:'pedagogy'}),{code:'RETRYABLE_PROVIDER_LIMIT'});
 await assert.rejects(new DerivativeStageRunner(context).complete(client,{name:'pedagogy'}),{code:'RETRYABLE_PROVIDER_LIMIT'});assert.equal(calls,2);
 fail=false;now=5001;await new DerivativeStageRunner(context).complete(client,{name:'semantic'});await new DerivativeStageRunner(context).complete(client,{name:'pedagogy'});assert.equal(calls,3);
});
test('emulator authenticated HTTP owner overrides forged UID',async()=>{
 const o=ops();let body,code;const res={status:v=>{code=v;return res;},json:v=>body=v};
 await createDerivativeHandlers({operations:o,authenticate:async()=> 'trusted'}).create({body:{...request('auth'),ownerUid:'forged'}},res);
 assert.equal(code,202);await assert.rejects(o.status('forged',body.operationKey),{code:'not_found'});
});
test('deployed rules file denies direct client reads and writes to server-only stages and jobs',async()=>{
 const uid='owner-a',now=Math.floor(Date.now()/1000);const token=[{alg:'none',typ:'JWT'},{iss:`https://securetoken.google.com/${projectId}`,aud:projectId,sub:uid,user_id:uid,iat:now,exp:now+3600,auth_time:now,firebase:{sign_in_provider:'custom',identities:{}}}].map(x=>Buffer.from(JSON.stringify(x)).toString('base64url')).join('.')+'.';
 const url=`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${projectId}/databases/(default)/documents/_derivative_engine_r21/job_${hash('unknown')}`;
 for(const method of ['GET','PATCH']){
  const r=await fetch(url,{method,headers:{authorization:`Bearer ${token}`,'content-type':'application/json'},...(method==='PATCH'?{body:JSON.stringify({fields:{ownerUid:{stringValue:uid}}})}:{})});
  assert.equal(r.status,403,await r.text());
 }
});
