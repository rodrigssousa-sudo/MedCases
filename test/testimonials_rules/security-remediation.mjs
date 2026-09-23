import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,deleteDoc,runTransaction} from 'firebase/firestore';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {createRevenueCatWebhookHandler}=require('../../server/revenuecat_webhook_routes.js');
const env=await initializeTestEnvironment({projectId:'demo-medcases-remediation',firestore:{host:'127.0.0.1',port:8787,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
let passed=0;const pass=name=>{passed++;console.log('PASS',name)};
try{
 await env.clearFirestore(); // Only the named local emulator project.
 const now=Date.now();
 await env.withSecurityRulesDisabled(async c=>{
  for(const uid of ['audit-a','audit-b'])await setDoc(doc(c.firestore(),'users',uid),{role:'user',status:'approved'});
  for(const name of ['meu_plantao','my_shifts'])await setDoc(doc(c.firestore(),name,'legacy'),{uid:'audit-a'});
  await setDoc(doc(c.firestore(),'users/audit-a/clinical_histories/example'),{synthetic:true});
 });
 const billing=['billingEntitlementActive','billingEntitlementId','billingEntitlementExpiresAtMs','billingExpiration','billingStatus','billingProvider','billingProductId','billingPeriodType','billingStore','billingEnvironment','billingLastEventType','billingLastEventId','billingLastEventTimestampMs','billingUpdatedAtMs'];
 for(const uid of ['audit-a','audit-b']){
  const db=env.authenticatedContext(uid,{auth_time:Math.floor(now/1000),iat:Math.floor(now/1000)}).firestore();
  for(const name of ['meu_plantao','my_shifts']){
   const ref=doc(db,name,'legacy');
   for(const [operation,op]of [['get',()=>getDoc(ref)],['create',()=>setDoc(doc(db,name,'new-'+uid),{uid})],['update',()=>updateDoc(ref,{uid})],['delete',()=>deleteDoc(ref)]]){await assertFails(op());pass(`legacy ${uid} ${operation} denied`);}
  }
  for(const key of billing){await assertFails(updateDoc(doc(db,'users',uid),{[key]:key.endsWith('Ms')?now+1e12:true}));pass('billing update denied '+key);}
  await assertFails(setDoc(doc(db,'revenuecatEventLedger','forged'),{uid}));pass('ledger client write denied');
 }
 const a=env.authenticatedContext('audit-a',{auth_time:Math.floor(now/1000),iat:Math.floor(now/1000)}).firestore(), b=env.authenticatedContext('audit-b',{auth_time:Math.floor(now/1000),iat:Math.floor(now/1000)}).firestore();
 await assertSucceeds(getDoc(doc(a,'users/audit-a/clinical_histories/example')));pass('owner private read');
 await assertFails(getDoc(doc(b,'users/audit-a/clinical_histories/example')));pass('cross owner private read denied');
 await assertSucceeds(setDoc(doc(a,'users/audit-a/clinical_histories/new'),{synthetic:true}));pass('owner private create');
 await assertFails(setDoc(doc(b,'users/audit-a/clinical_histories/new2'),{synthetic:true}));pass('cross owner private create denied');
 for(const key of billing){const uid='create-'+key,db=env.authenticatedContext(uid).firestore();await assertFails(setDoc(doc(db,'users',uid),{[key]:true}));pass('billing create denied '+key);}
 // PF-002: retain own-session lifecycle without permitting ownership transfer.
 const legacy=doc(a,'sessions','r2-owned');
 await assertSucceeds(setDoc(legacy,{userId:'audit-a',technical:'TEST'}));pass('legacy owner create');
 await assertSucceeds(getDoc(legacy));pass('legacy owner read');
 await assertSucceeds(updateDoc(legacy,{technical:'UPDATED'}));pass('legacy update preserving owner');
 await assertFails(updateDoc(legacy,{userId:'audit-b'}));pass('legacy ownership mutation denied');
 await assertFails(getDoc(doc(b,'sessions','r2-owned')));pass('legacy cross-user injection denied');
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'sessions','r2-owned')));pass('legacy anonymous denied');
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();const adapter={collection:name=>({doc:id=>doc(db,name,id)}),runTransaction:fn=>runTransaction(db,tx=>fn({get:async ref=>{const s=await tx.get(ref);return {exists:s.exists(),data:()=>s.data()};},set:(...args)=>tx.set(...args)}))};
  const secret='synthetic-authorized-webhook-test-only-0000';
  const handler=createRevenueCatWebhookHandler({db:adapter,authorizationProvider:()=>secret,nowMsProvider:()=>now});
  const event=(uid,type,ts,id)=>({id,type,app_user_id:uid,event_timestamp_ms:ts,expiration_at_ms:now+86400000,entitlement_ids:['medcases_pro_premium']});
  const call=async (e,expectedStatus=200)=>{const res={code:200,body:null,setHeader(){},status(n){this.code=n;return this;},json(body){this.body=body;return this;}};await handler({headers:{authorization:secret},body:{event:e}},res);assert.equal(res.code,expectedStatus);return res.body;};
  for(const order of [0,1])for(const tie of [false,true]){
   const uid=`race-${order}-${tie}`;await setDoc(doc(db,'users',uid),{role:'user'});
   const renewal=event(uid,'RENEWAL',now-100,`${uid}-renewal`),refund=event(uid,'REFUND',tie?now-100:now,`${uid}-refund`);
   await Promise.all((order?[refund,renewal]:[renewal,refund]).map(e=>call(e)));
   assert.equal((await getDoc(doc(db,'users',uid))).data().billingEntitlementActive,false);pass('real transaction concurrent refund '+uid);
   assert.equal((await call(refund)).reason,'duplicate_event');
   assert.equal((await call({...refund,expiration_at_ms:refund.expiration_at_ms+1},409)).error,'REVENUECAT_EVENT_IDENTITY_CONFLICT');
   const before=(await getDoc(doc(db,'users',uid))).data();await call(event(uid,'RENEWAL',now-200,`${uid}-stale`));
   assert.deepEqual((await getDoc(doc(db,'users',uid))).data(),before);pass('duplicate and stale do not mutate '+uid);
  }
  await setDoc(doc(db,'users','tainted-profile'),{billingLastEventTimestampMs:now+1e12,billingEntitlementActive:true});
  await call(event('tainted-profile','REFUND',now,'tainted-refund'));
  assert.equal((await getDoc(doc(db,'users','tainted-profile'))).data().billingEntitlementActive,false);pass('untrusted historical profile timestamp cannot block refund');
  for(const [type,expiry,active] of [['CANCELLATION',now+10000,true],['EXPIRATION',now-1,false]]){
   const uid='status-'+type;await setDoc(doc(db,'users',uid),{});await call({...event(uid,type,now,uid),expiration_at_ms:expiry});assert.equal((await getDoc(doc(db,'users',uid))).data().billingEntitlementActive,active);pass(type);
  }
 });
 console.log('FIRESTORE_SECURITY_TESTS_PASS='+passed);
}finally{await env.cleanup();}
