'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict');
if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('EMULATOR_REQUIRED');
const req=require('node:module').createRequire(require.resolve('../functions/package.json'));
const {initializeApp,deleteApp}=req('firebase-admin/app');
const {getFirestore,Timestamp,FieldPath}=req('firebase-admin/firestore');
const app=initializeApp({projectId:'demo-admin-visual'},'visual'),db=getFirestore(app);
const {createAdminVisualMetrics}=require('../functions/admin_visual_metrics');
const {createAdminOperations}=require('../functions/admin_operations');
const now=Date.UTC(2026,8,29,15),today=Date.UTC(2026,8,29);
const api=createAdminVisualMetrics({db,now:()=>now});
const ops=createAdminOperations({db,documentId:FieldPath.documentId()});
after(()=>deleteApp(app));
test('aggregate metrics use actual facts, exclude incomplete consumption, and distinguish unavailable history',async()=>{
 await db.doc('users/admin').set({role:'admin',status:'approved',plan:'free',createdAt:Timestamp.fromMillis(today),lastSeenAt:Timestamp.fromMillis(now)});
 await db.doc('users/person').set({name:'Synthetic QA',email:'qa@example.invalid',plan:'premium',createdAt:Timestamp.fromMillis(today),password:'NEVER_RETURN'});
 await db.doc('admin_ai_usage_events/a').set({mode:'study',success:true,durationMs:1000,createdAt:Timestamp.fromMillis(now),clinicalText:'NEVER_RETURN'});
 await db.doc('admin_ai_usage_events/b').set({mode:'plantao',success:false,durationMs:3000,createdAt:Timestamp.fromMillis(now)});
 for(const [id,state,chargedMs] of [['a','completed',120000],['b','executing',300000]])await db.doc('usageReservations/'+id).set({kinds:['transcription'],state,chargedMs,createdAt:now});
 await db.doc('adminManualCredits/a').set({amountSeconds:600,grantedAt:now});
 const m=await api.metrics('admin');
 assert.equal(m.total,2);assert.equal(m.free,1);assert.equal(m.premium,1);assert.equal(m.aiToday,2);assert.equal(m.modes.study,1);assert.equal(m.errorsToday,1);assert.equal(m.aiLatencyMs,2000);
 assert.equal(m.transcriptionsToday,1);assert.equal(m.consumedMinutes,2);assert.equal(m.extraMinutes,10);assert.equal(m.series.at(-1).consumedMinutes,2);assert.equal(m.series.length,7);
 assert.deepEqual(m.costSeries,[]);assert.equal(m.rolling24h,null);assert(!JSON.stringify(m).includes('NEVER_RETURN'));
});
test('cached aggregates still enforce auth and validate windows',async()=>{
 await assert.rejects(api.metrics('person'));await assert.rejects(api.metrics(null));await assert.rejects(api.metrics('admin',{days:100}));await assert.rejects(api.metrics('admin',{offsetMinutes:900}));
});
test('timezone boundary includes only the requested calendar day',async()=>{
 const m=await createAdminVisualMetrics({db,now:()=>today+60000}).metrics('admin',{days:7,offsetMinutes:-180});
 assert.equal(m.series.at(-1).date,'2026-09-28');assert.equal(m.aiToday,0);
});
test('auto name/email search and batched identity lookup expose no credentials',async()=>{
 for(const value of ['Synthetic QA','qa@example.invalid'])assert.equal((await ops.page('admin',{table:'users',field:'auto',value})).items[0].id,'person');
 const r=await ops.identities('admin',{ids:['person','person','missing']});assert.equal(r.items.length,1);assert.equal(r.items[0].name,'Synthetic QA');assert(!JSON.stringify(r).includes('NEVER_RETURN'));
 await assert.rejects(ops.identities('person',{ids:['admin']}));await assert.rejects(ops.identities('admin',{ids:Array(101).fill('person')}));
});
test('campaign destination/schedule remain bounded draft metadata without dispatch',async()=>{
 const input={action:'saveCampaignDraft',targetId:'draft',requestId:'visual-draft',reason:'Synthetic test only',eventType:'NEW_FEATURE_AVAILABLE',pt:{title:'Teste',body:'Mensagem'},es:{title:'Prueba',body:'Mensaje'},destination:'Home',audience:'QA',schedule:'2026-10-01'};
 await ops.mutate('admin',input);const d=(await db.doc('adminEngagementDrafts/draft').get()).data();assert.equal(d.destination,'Home');assert.equal(d.audience,'QA');assert.equal(d.dispatchEnabled,false);assert.equal(d.status,'DRAFT');
 await assert.rejects(ops.mutate('admin',{...input,requestId:'invalid',audience:42}),/INVALID_DRAFT_FIELD/);
});
