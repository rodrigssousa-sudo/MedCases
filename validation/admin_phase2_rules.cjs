'use strict';
const {test,after}=require('node:test'),fs=require('node:fs'),assert=require('node:assert/strict');
const req=require('node:module').createRequire(require.resolve('../test/testimonials_rules/package.json'));
const {initializeTestEnvironment,assertFails,assertSucceeds}=req('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc}=req('firebase/firestore');
if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('EMULATOR_REQUIRED');
let env;
const ready=async()=>env??=await initializeTestEnvironment({projectId:'demo-admin-manual-time',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
after(async()=>env?.cleanup());
test('new Admin collections deny direct clients including privileged clients; callable Admin SDK is required',async()=>{
 const e=await ready();
 for(const uid of ['normal','supervisor','admin','master'])await e.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'users',uid),{role:uid==='normal'?'user':uid,status:'approved'}));
 for(const uid of [null,'normal','supervisor','admin','master']){
  const db=uid?e.authenticatedContext(uid).firestore():e.unauthenticatedContext().firestore();
  for(const c of ['adminNotificationReads','adminOperationRequests','adminControlAudit','adminEngagementDrafts','adminContentInventoryDrugs','adminContentInventoryPathologies','adminServiceHealth','adminReleaseInventory','adminDeploymentInventory']){
   await assertFails(setDoc(doc(db,c,'synthetic'),{status:'test'}));await assertFails(getDoc(doc(db,c,'synthetic')));
  }
 }
});
test('normal and Supervisor cannot write clinical guides or maintenance',async()=>{
 const e=await ready();for(const uid of ['normal','supervisor']){
  const db=e.authenticatedContext(uid).firestore();for(const path of ['clinical_guides/synthetic','app_config/maintenance'])await assertFails(setDoc(doc(db,path),{enabled:true,isPublished:true}));
 }
});

test('legacy read updates append only own UID; stale array cannot erase confirmed read',async()=>{
 const e=await ready();await e.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'users','other-admin'),{role:'admin',status:'approved'});await setDoc(doc(c.firestore(),'admin_notifications','read-test'),{readBy:[],title:'Fixture'});});
 const a=doc(e.authenticatedContext('admin').firestore(),'admin_notifications','read-test');
 const b=doc(e.authenticatedContext('other-admin').firestore(),'admin_notifications','read-test');
 await assertSucceeds(updateDoc(a,{readBy:['admin']}));
 await assertFails(updateDoc(b,{readBy:['other-admin']}));
 await assertSucceeds(updateDoc(b,{readBy:['admin','other-admin']}));
 await assertFails(updateDoc(a,{readBy:['admin','other-admin','someone-else']}));
 await assertFails(updateDoc(a,{readBy:[]}));
});
test('manual entitlement fields cannot be forged by normal or Supervisor clients',async()=>{
 const e=await ready();
 for(const uid of ['normal','supervisor'])await assertFails(updateDoc(doc(e.authenticatedContext(uid).firestore(),'users',uid),{entitlements:{adminPremium:{active:true,source:'admin_manual_v1',expiresAt:null}}}));
 await assertFails(setDoc(doc(e.authenticatedContext('fresh-user').firestore(),'users','fresh-user'),{plan:'free',role:'user',entitlements:{adminVip:{active:true,source:'admin_manual_v1',expiresAt:null}}}));
});
