'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('EMULATOR_REQUIRED');
const {initializeApp,deleteApp}=require('firebase-admin/app');const app=initializeApp({projectId:'demo-admin-manual-time'});
const db=require('firebase-admin/firestore').getFirestore(app);const {MonthlyUsageOwner,LIMITS}=require('../monthly_usage_owner');
const {proof}=require('./media_fixture');
const {createAdminControlCenter}=require('../../functions/admin_control_center');
const control=createAdminControlCenter({db});
const request=(operationId,maximumMs)=>({operationId,maximumMs,kinds:['transcription']});
async function setup(){const uid='qa-'+crypto.randomUUID();await db.doc('users/'+uid).set({plan:'free',role:'user',status:'approved'});await db.doc('users/qa-admin').set({role:'admin',status:'approved'});return {uid,owner:new MonthlyUsageOwner({db})};}
async function grant(uid,seconds=120){return control.mutate('qa-admin',{action:'grantCredit',requestId:crypto.randomUUID(),userId:uid,amountSeconds:seconds,category:'TESTE_INTERNO',reason:'Synthetic emulator-only test'});}
after(()=>deleteApp(app));
test('atomic mixed reserve, retries, measured claim and exactly-once consumption',async()=>{
 const {uid,owner}=await setup();const c=await grant(uid);
 const req=request('mixed',960000);const all=await Promise.all(Array.from({length:5},()=>owner.reserve(uid,req)));const r=all[0];assert(all.every(x=>x.id===r.id));
 const op=(await db.doc('usageReservations/'+r.id).get()).data();assert.equal(op.baseReservedSeconds,900);assert.equal(op.manualReservedSeconds,60);
 let b=await owner.balance(uid);assert.equal(b.baseAllowanceMs,900000);assert.equal(b.remainingMs,60000);assert.equal(b.manualReservedMs,60000);
 await assert.rejects(owner.claimExecution(uid,r,0,{durationMs:60000}),/MEDIA_PROOF_REQUIRED/);
 const claims=await Promise.all([owner.claimExecution(uid,r,0,await proof(60000)),owner.claimExecution(uid,r,0,await proof(60000))]);assert.equal(claims.filter(x=>x.claimed).length,1);
 await Promise.all([owner.completeExecution(uid,r),owner.completeExecution(uid,r)]);
 const credit=(await db.doc('adminManualCredits/'+c.creditId).get()).data();assert.equal(credit.remainingSeconds,60);assert.equal(credit.reservedSeconds,0);
 b=await owner.balance(uid);assert.equal(b.usedMs,960000);assert.equal(b.remainingMs,60000);assert.equal(b.allowanceMs-b.usedMs-b.reservedMs,b.remainingMs);
 assert.equal((await db.collection('adminCreditLedger').where('userId','==',uid).where('type','==','CONSUME').get()).size,1);
});
test('concurrent requests cannot overspend combined budget',async()=>{
 const {uid,owner}=await setup();await grant(uid,60);const results=await Promise.allSettled(Array.from({length:12},(_,i)=>owner.reserve(uid,request('job-'+i,120000))));
 assert.equal(results.filter(x=>x.status==='fulfilled').length,8);const b=await owner.balance(uid);assert.equal(b.remainingMs,0);assert.equal(b.reservedMs,960000);
});
test('pre-execution release is idempotent and owner-bound',async()=>{
 const {uid,owner}=await setup();const c=await grant(uid,60);const r=await owner.reserve(uid,request('release',960000));
 await assert.rejects(owner.failBeforeExecution('other',r),/NOT_OWNED/);
 await assert.rejects(owner.finish('other',{...r,actualMs:1,success:true}),/NOT_OWNED/);
 await Promise.all([owner.failBeforeExecution(uid,r),owner.failBeforeExecution(uid,r)]);
 assert.equal((await owner.balance(uid)).remainingMs,960000);assert.equal((await db.doc('adminManualCredits/'+c.creditId).get()).data().reservedSeconds,0);
 assert.equal((await owner.reserve(uid,request('release',960000))).state,'server_verified_failed');
});
test('revocation preserves reserved and consumed history',async()=>{
 const {uid,owner}=await setup();const c=await grant(uid,120);const r=await owner.reserve(uid,request('revoke',960000));
 const v=await control.mutate('qa-admin',{action:'revokeCredit',creditId:c.creditId,requestId:crypto.randomUUID(),reason:'Synthetic revoke unused'});assert.equal(v.revokedSeconds,60);
 await owner.claimExecution(uid,r,0,await proof(60000));await owner.completeExecution(uid,r);
 assert.equal((await db.doc('adminManualCredits/'+c.creditId).get()).data().remainingSeconds,0);
 assert.equal((await db.collection('adminCreditLedger').where('userId','==',uid).get()).size,3);
});
test('expiry excludes new use but retains in-flight reservation',async()=>{
 const {uid}=await setup();let time=Date.now();const owner=new MonthlyUsageOwner({db,now:()=>time});
 const c=await control.mutate('qa-admin',{action:'grantCredit',requestId:crypto.randomUUID(),userId:uid,amountSeconds:120,expiresAt:time+60000,category:'TESTE_INTERNO',reason:'Synthetic expiry test'});
 const r=await owner.reserve(uid,request('expire',960000));time+=120000;assert.equal((await owner.balance(uid)).remainingMs,0);
 await owner.failBeforeExecution(uid,r);const d=(await db.doc('adminManualCredits/'+c.creditId).get()).data();assert.equal(d.reservedSeconds,0);assert.equal(d.remainingSeconds,60);assert.equal((await owner.balance(uid)).manualRemainingMs,0);
});
test('duration bound and staged execution refund protections remain active',async()=>{
 const {uid,owner}=await setup();await grant(uid);const base=await owner.reserve(uid,request('base',900000));await owner.finish(uid,{...base,actualMs:900000,success:true});const r=await owner.reserve(uid,request('media',60000));
 await assert.rejects(owner.claimExecution(uid,r,0,await proof(61000)),/MEDIA_EXCEEDS_RESERVED_BUDGET/);
 await owner.authorizeMediaStage(uid,r,0,await proof(60000),'upload');
 await assert.rejects(owner.failBeforeExecution(uid,r),/BILLABLE/);
 await owner.claimExecution(uid,r,0,await proof(60000));await owner.completeExecution(uid,r);
 assert.equal((await db.collection('adminCreditLedger').where('userId','==',uid).where('type','==','CONSUME').get()).size,1);
});
test('base allowance constants unchanged',()=>assert.deepEqual(LIMITS,{free:{recording:900000,transcription:900000},premium:{recording:14400000,transcription:5400000}}));

test('concurrent expiry workers keep reservation and create one expiry audit',async()=>{
 const {uid,owner}=await setup();const time=Date.now();
 const c=await control.mutate('qa-admin',{action:'grantCredit',requestId:crypto.randomUUID(),userId:uid,amountSeconds:120,expiresAt:time+60000,category:'TESTE_INTERNO',reason:'Synthetic expiry worker'});
 const r=await owner.reserve(uid,request('scheduled',960000));
 const expirer=createAdminControlCenter({db,now:()=>time+120000});
 await Promise.all([expirer.expireDueCredits(),expirer.expireDueCredits()]);
 let d=(await db.doc('adminManualCredits/'+c.creditId).get()).data();assert.equal(d.remainingSeconds,60);assert.equal(d.reservedSeconds,60);assert.equal(d.status,'EXPIRED_RESERVED');
 await owner.claimExecution(uid,r,0,await proof(60000));await owner.completeExecution(uid,r);
 d=(await db.doc('adminManualCredits/'+c.creditId).get()).data();assert.equal(d.remainingSeconds,0);
 assert.equal((await db.collection('adminCreditLedger').where('creditId','==',c.creditId).where('type','==','EXPIRE').get()).size,1);
});
test('millisecond precision and concurrent revoke versus reserve preserve invariants',async()=>{
 const {uid,owner}=await setup();const c=await grant(uid,60);
 const r=await owner.reserve(uid,request('fraction',900001));
 const op=(await db.doc('usageReservations/'+r.id).get()).data();assert.equal(op.manualReservedSeconds,0.001);
 const v=await control.mutate('qa-admin',{action:'revokeCredit',creditId:c.creditId,requestId:crypto.randomUUID(),reason:'Synthetic fractional revoke'});assert.equal(v.revokedSeconds,59.999);
 await owner.failBeforeExecution(uid,r);assert.equal((await db.doc('adminManualCredits/'+c.creditId).get()).data().remainingSeconds,0);
});

test('real concurrent grant retries create one grant and one audit',async()=>{
 const {uid}=await setup();const input={action:'grantCredit',requestId:crypto.randomUUID(),userId:uid,amountSeconds:60,category:'TESTE_INTERNO',reason:'Synthetic concurrent grant'};
 const result=await Promise.all(Array.from({length:8},()=>control.mutate('qa-admin',input)));assert(result.every(r=>r.creditId===result[0].creditId));
 assert.equal((await db.collection('adminManualCredits').where('userId','==',uid).get()).size,1);
 assert.equal((await db.collection('adminControlAudit').where('requestId','==',input.requestId).get()).size,1);
});
test('real revoke versus reserve race cannot revoke in-flight time',async()=>{
 const {uid,owner}=await setup();const c=await grant(uid,120);
 const results=await Promise.allSettled([owner.reserve(uid,request('race',960000)),control.mutate('qa-admin',{action:'revokeCredit',creditId:c.creditId,requestId:crypto.randomUUID(),reason:'Synthetic concurrent revoke'})]);
 const d=(await db.doc('adminManualCredits/'+c.creditId).get()).data();assert(d.remainingSeconds>=d.reservedSeconds);assert(d.reservedSeconds>=0);
 assert.equal(results[1].status,'fulfilled');
 if(results[0].status==='fulfilled'){assert.equal(d.remainingSeconds,60);assert.equal(d.reservedSeconds,60);await owner.failBeforeExecution(uid,results[0].value);assert.equal((await db.doc('adminManualCredits/'+c.creditId).get()).data().remainingSeconds,0);}
 else {assert.match(results[0].reason.message,/MONTHLY_USAGE_LIMIT/);assert.equal(d.remainingSeconds,0);}
});
