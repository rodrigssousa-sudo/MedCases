'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('EMULATOR_REQUIRED');
const functionRequire=require('node:module').createRequire(require.resolve('../functions/package.json'));
const {initializeApp,deleteApp}=functionRequire('firebase-admin/app');
const {getFirestore,FieldPath,Timestamp}=functionRequire('firebase-admin/firestore');
const app=initializeApp({projectId:'demo-admin-manual-time'},'phase2'),db=getFirestore(app);
const {createAdminOperations,SPECS}=require('../functions/admin_operations');
const {createAdminGuideOperations}=require('../functions/admin_guide_operations');
const runtime=createAdminOperations({db,documentId:FieldPath.documentId(),getAuthUser:async()=>({customClaims:{}})});
async function setup(){for(const role of ['master','admin','supervisor','user'])await db.doc('users/p2-'+role).set({role,status:'approved'});}
const request=(action,targetId,extra={})=>({action,targetId,requestId:crypto.randomUUID(),reason:'Synthetic emulator validation',...extra});
after(()=>deleteApp(app));
test('roles read; normal and unauth denied; no secrets',async()=>{
 await setup();await db.doc('users/p2-target').set({role:'user',email:'synthetic@example.invalid',name:'Fixture',password:'DO_NOT_RETURN',token:'DO_NOT_RETURN',clinicalContent:'DO_NOT_RETURN'});
 for(const role of ['master','admin','supervisor']){const r=await runtime.page('p2-'+role,{table:'users'});assert(!JSON.stringify(r).includes('DO_NOT_RETURN'));}
 for(const uid of ['p2-user',null,'absent'])await assert.rejects(runtime.page(uid,{table:'users'}));
 await assert.rejects(runtime.mutate('p2-supervisor',request('setUserStatus','p2-target',{value:'blocked'})),/SUPERVISOR_READ_ONLY/);
});
test('bounded page and exact search by all supported keys',async()=>{
 const a=await runtime.page('p2-admin',{table:'users',limit:2});assert.equal(a.items.length,2);assert(a.nextCursor);
 const b=await runtime.page('p2-admin',{table:'users',limit:2,cursor:a.nextCursor});assert(!b.items.some(x=>a.items.some(y=>x.id===y.id)));
 for(const [field,value] of [['uid','p2-target'],['email','synthetic@example.invalid'],['name','Fixture'],['status','approved']])assert((await runtime.page('p2-admin',{table:'users',field,value})).items.length>0);
 await assert.rejects(runtime.page('p2-admin',{table:'users',limit:101}),/INVALID_PAGE_SIZE/);
 await assert.rejects(runtime.page('p2-admin',{table:'users',field:'token',value:'x'}),/INVALID_FILTER/);
});
test('concurrent status request exactly once; quota and billing untouched',async()=>{
 await db.doc('users/p2-target').set({role:'user',status:'approved',plan:'premium',baseAllowance:900,subscriptionProvider:'revenuecat'});
 const r=request('setUserStatus','p2-target',{value:'blocked'});
 const outputs=await Promise.all(Array.from({length:8},()=>runtime.mutate('p2-admin',r)));assert(outputs.every(x=>x.status==='blocked'));
 assert.equal((await db.collection('adminControlAudit').where('requestId','==',r.requestId).get()).size,1);
 const d=(await db.doc('users/p2-target').get()).data();assert.equal(d.plan,'premium');assert.equal(d.baseAllowance,900);assert.equal(d.subscriptionProvider,'revenuecat');
 await assert.rejects(runtime.mutate('p2-admin',{...r,value:'pending'}),/IDEMPOTENCY_CONFLICT/);
});
test('role changes master-only; self/master/claim-managed accounts protected',async()=>{
 await assert.rejects(runtime.mutate('p2-admin',request('setUserRole','p2-target',{value:'admin'})),/MASTER_REQUIRED/);
 await assert.rejects(runtime.mutate('p2-master',request('setUserRole','p2-master',{value:'user'})),/PROTECTED_ACCOUNT/);
 const claims=createAdminOperations({db,getAuthUser:async()=>({customClaims:{admin:true}})});
 await assert.rejects(claims.mutate('p2-master',request('setUserRole','p2-target',{value:'user'})),/CLAIM_MANAGED_ACCOUNT/);
 await runtime.mutate('p2-master',request('setUserRole','p2-target',{value:'supervisor'}));assert.equal((await db.doc('users/p2-target').get()).data().role,'supervisor');
});
test('reason mandatory and no premium/billing mutation route',async()=>{
 await assert.rejects(runtime.mutate('p2-admin',{...request('setUserStatus','p2-target'),reason:''}),/REASON_REQUIRED/);
 for(const action of ['setPremium','grantVip','deleteUser','cancelJob'])await assert.rejects(runtime.mutate('p2-master',request(action,'p2-target')),/UNSUPPORTED_ACTION/);
});
test('metadata projection across all tables excludes audio, prose, credentials',async()=>{
 for(const [table,[collection]] of Object.entries(SPECS)){
  if(table==='users')continue;
  await db.collection(collection).doc('p2-metadata').set({status:'test',transcript:'NEVER_EXPOSE',audio:'NEVER_EXPOSE',token:'NEVER_EXPOSE',apiKey:'NEVER_EXPOSE',clinicalText:'NEVER_EXPOSE'});
  const r=await runtime.page('p2-supervisor',{table});assert(!JSON.stringify(r).includes('NEVER_EXPOSE'),table);
 }
});
test('unknown and stale health never become healthy',async()=>{
 await db.doc('adminServiceHealth/p2-old').set({service:'AssemblyAI',state:'HEALTHY',observedAt:1});
 const r=await runtime.overview('p2-admin');assert.equal(r.services.find(x=>x.service==='AssemblyAI').state,'UNKNOWN');assert.equal(r.services.find(x=>x.service==='Study primary').state,'UNKNOWN');
});
test('campaign requires both locales; draft cannot dispatch and cap immutable',async()=>{
 const input=request('saveCampaignDraft','p2-campaign',{eventType:'NEW_FEATURE_AVAILABLE',pt:{title:'Teste',body:'Sintético'},es:{title:'Prueba',body:'Sintético'}});
 await assert.rejects(runtime.mutate('p2-admin',{...input,es:null}),/PT_ES_REQUIRED/);
 await runtime.mutate('p2-admin',{...input,maxPerWeek:999,dispatchEnabled:true});
 const d=(await db.doc('adminEngagementDrafts/p2-campaign').get()).data();assert.equal(d.maxPerWeek,3);assert.equal(d.dispatchEnabled,false);assert(d.respectOptOut&&d.respectQuietHours&&d.respectLocale);
});
async function job(extra={},logicalExtra={},reservationExtra={}){
 const jobId=crypto.randomUUID(),rid=crypto.randomBytes(32).toString('hex');
 const ref=db.doc('_study_background_transcription_jobs/'+jobId);
 await db.doc('usageReservations/'+rid).set({uid:'p2-owner',attempt:'attempt',state:'executing',...reservationExtra});
 await ref.set({uid:'p2-owner',provider:'assemblyai',state:'retryable_error',workerPending:false,usage:{'x-medcases-usage-reservation':rid,'x-medcases-usage-attempt':'attempt'},...extra});
 await ref.collection('logical').doc('recording').set({ownerUid:'p2-owner',state:'retryable_error',providerTranscriptId:'synthetic-existing-id',...logicalExtra});return {ref,rid,jobId};
}
test('job retry concurrent/repeated only requeues existing execution; no new debit',async()=>{
 const {ref,rid,jobId}=await job();const before=(await db.doc('usageReservations/'+rid).get()).data();const r=request('retryTranscription',jobId);
 await Promise.all(Array.from({length:8},()=>runtime.mutate('p2-admin',r)));
 assert.equal((await ref.get()).data().workerPending,true);assert.deepEqual((await db.doc('usageReservations/'+rid).get()).data(),before);
 assert.equal((await db.collection('adminControlAudit').where('requestId','==',r.requestId).get()).size,1);
});
for(const [name,j,l,r] of [
 ['other owner',{}, {},{uid:'other'}],['active lease',{}, {leaseUntil:Timestamp.fromMillis(Date.now()+600000)},{}],
 ['no provider ID',{}, {providerTranscriptId:null},{}],['deleted',{deleted:true},{},{}],['terminal',{}, {state:'terminal_error'},{}],['completed reservation',{}, {},{state:'completed'}]
])test('job retry denied: '+name,async()=>{const {jobId}=await job(j,l,r);await assert.rejects(runtime.mutate('p2-admin',request('retryTranscription',jobId)),/RETRY_NOT_SUPPORTED/);});
const guide=()=>({title:'Synthetic guide',version:1,isPublished:false,searchPrefixes:['syn'],localizations:Object.fromEntries(['pt','es'].map(language=>[language,{language,title:'Synthetic fixture',summary:'Synthetic nonclinical content',bodyBlocks:[{type:'paragraph',text:'Nonclinical fixture'}],references:[]}]))});
test('guide PT/ES save/readback with simultaneous retry is one record and audit',async()=>{
 const save=createAdminGuideOperations({db}),targetId='p2-guide';const req={targetId,reason:'Synthetic draft only',data:guide()};
 await Promise.all(Array.from({length:6},()=>save('p2-admin',req)));
 const d=(await db.doc('clinical_guides/'+targetId).get()).data();assert.equal(d.status,'draft');assert.equal(d.version,1);
 assert.equal((await db.collection('adminControlAudit').where('targetId','==',targetId).get()).size,1);
 await assert.rejects(save('p2-supervisor',req),/SUPERVISOR_READ_ONLY/);
});
test('guide publish requires PT/ES review completeness and audit reviewer',async()=>{
 const save=createAdminGuideOperations({db}),data=guide();data.isPublished=true;data.localizations.es.summary='';
 await assert.rejects(save('p2-admin',{targetId:'p2-invalid-guide',reason:'Synthetic review',data}),/GUIDE_REVIEW_REQUIRED/);
 data.localizations.es.summary='Synthetic only';await save('p2-admin',{targetId:'p2-reviewed-guide',reason:'Synthetic emulator only',data});
 const d=(await db.doc('clinical_guides/p2-reviewed-guide').get()).data();assert.equal(d.reviewer,'p2-admin');assert(d.reviewDate);assert.equal(d.status,'published');
});
test('guide stale version, corrupt format and oversized payload denied',async()=>{
 const save=createAdminGuideOperations({db});const data=guide();data.version=5;await save('p2-admin',{targetId:'p2-version',reason:'Synthetic version',data});
 await assert.rejects(save('p2-admin',{targetId:'p2-version',reason:'Synthetic version',data:guide()}),/GUIDE_STALE_VERSION/);
 await assert.rejects(save('p2-admin',{targetId:'p2-corrupt',reason:'Synthetic corrupt',data:{}}),/GUIDE_VERSION_INVALID/);
 await assert.rejects(save('p2-admin',{targetId:'p2-large',reason:'Synthetic large',data:{...guide(),title:'x'.repeat(700001)}}),/GUIDE_SIZE_INVALID/);
});
test('Master configuration writes require reason; others denied; audit metadata has no message',async()=>{
 const input=request('saveMaintenance','maintenance',{value:{enabled:false,message:'Synthetic maintenance message'}});
 await assert.rejects(runtime.mutate('p2-admin',input),/MASTER_REQUIRED/);
 await runtime.mutate('p2-master',input);await runtime.mutate('p2-master',input);
 const audit=await db.collection('adminControlAudit').where('requestId','==',input.requestId).get();assert.equal(audit.size,1);assert(!JSON.stringify(audit.docs[0].data()).includes('Synthetic maintenance message'));
 await assert.rejects(runtime.mutate('p2-master',{...input,requestId:crypto.randomUUID(),targetId:'ai_control'}),/INVALID_CONFIG/);
});
test('user detail reads manual balances without secrets and leaves allowance untouched',async()=>{
 const uid='p2-detail';await db.doc('users/'+uid).set({role:'user',plan:'free',password:'NEVER_EXPOSE'});
 await db.doc('notificationDevices/p2-detail-device').set({userId:uid,token:'NEVER_EXPOSE'});
 await db.doc('adminManualCredits/p2-detail-credit').set({userId:uid,status:'ACTIVE',remainingSeconds:100,reservedSeconds:20,expiresAt:null});
 const r=await runtime.detail('p2-admin',{userId:uid});assert.equal(r.deviceCount,1);assert.equal(r.manualAvailableSeconds,80);assert.equal(r.manualReservedSeconds,20);assert(!JSON.stringify(r).includes('NEVER_EXPOSE'));
 assert.equal((await runtime.page('p2-admin',{table:'users',field:'plan',value:'free'})).items.some(x=>x.id===uid),true);
});
