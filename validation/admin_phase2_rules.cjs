'use strict';
const {test,after}=require('node:test'),fs=require('node:fs'),assert=require('node:assert/strict');
const req=require('node:module').createRequire(require.resolve('../test/testimonials_rules/package.json'));
const {initializeTestEnvironment,assertFails,assertSucceeds}=req('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc}=req('firebase/firestore');
if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('EMULATOR_REQUIRED');
let env;
const ready=async()=>env??=await initializeTestEnvironment({projectId:'demo-admin-manual-time',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
after(async()=>env?.cleanup());
test('new Admin collections deny direct clients including privileged clients; callable Admin SDK is required',async()=>{
 const e=await ready();
 for(const uid of ['normal','supervisor','admin','master'])await e.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'users',uid),{role:uid==='normal'?'user':uid,status:'approved'}));
 for(const uid of [null,'normal','supervisor','admin','master']){
  const db=uid?e.authenticatedContext(uid).firestore():e.unauthenticatedContext().firestore();
  for(const c of ['adminOperationRequests','adminControlAudit','adminEngagementDrafts','adminContentInventoryDrugs','adminContentInventoryPathologies','adminServiceHealth','adminReleaseInventory','adminDeploymentInventory']){
   await assertFails(setDoc(doc(db,c,'synthetic'),{status:'test'}));await assertFails(getDoc(doc(db,c,'synthetic')));
  }
 }
});
test('normal and Supervisor cannot write clinical guides or maintenance',async()=>{
 const e=await ready();for(const uid of ['normal','supervisor']){
  const db=e.authenticatedContext(uid).firestore();for(const path of ['clinical_guides/synthetic','app_config/maintenance'])await assertFails(setDoc(doc(db,path),{enabled:true,isPublished:true}));
 }
});
