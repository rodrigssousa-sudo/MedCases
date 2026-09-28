'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {studyQaCanaryAllowed} = require('../lib/study_qa_canary');
const start='2026-09-28T00:00:00Z', until='2026-09-28T02:00:00Z';
const now=Date.parse('2026-09-28T00:30:00Z');
const qaUid='Wa1AQN8hvCdewLiR2drd01rQo9G3';
const body={mode:'estudo',lang:'es', studyCanonicalVersion:'study_paid_snapshot_v2', systemPrompt:'STUDY PAID CANONICAL v2'};
const valid={uid:qaUid,endpoint:'geminiPaidProxy',body,start,until,now};
test('QA is scoped to one verified UID, endpoint, mode, provider and bounded window',()=>{
 assert.equal(studyQaCanaryAllowed(valid),true);
 for(const bad of [{uid:'ordinary'},{uid:''},{endpoint:'admin'},{endpoint:'plantaoProxyStream'},
 {body:{...body,mode:'plantao'}},{body:{...body,provider:'openai'}},{body:{...body,studyCanonicalVersion:'other'}},
 {body:{...body,systemPrompt:'ordinary'}},{start:undefined},{until:undefined},
 {until:'2026-09-28T02:00:01Z'},{now:Date.parse(until)},{now:Date.parse(start)-1}])
  assert.equal(studyQaCanaryAllowed({...valid,...bad}),false);
});
// Exercise the unchanged token verification and approved-user branch from the
// real handler. No provider call, account write or real credential is used.
const source=fs.readFileSync(require.resolve('../index'),'utf8');
const begin=source.indexOf("    const authHeader = req.headers.authorization || '';");
const end=source.indexOf('      // AI_CONTROL_PLANE_V2_SHADOW_EXEC',begin);
assert(begin>0 && end>begin);
const authSource=source.slice(begin,end);
async function authorize({uid=qaUid,approved=false,exists=true,invalid=false,token=true,requestBody=body,window=true}={}){
 let status=null;let verified=false;
 const data={status:approved?'approved':'pending',role:'user'};
 const before=JSON.stringify(data);
 const context={req:{headers:token?{authorization:'Bearer synthetic-token'}:{},body:requestBody},
 res:{status(n){status=n;return this;},json(){}}, console:{warn(){},error(){}},
 admin:{auth:()=>({verifyIdToken:async(_token,revocation)=>{assert.equal(revocation,true);verified=true;if(invalid)throw {code:'invalid'};return {uid};}}),
 firestore:()=>({collection:(name)=>{assert.equal(name,'users');return {doc:(id)=>{assert.equal(id,uid);return {get:async()=>({exists,data:()=>data})};}};}})},
 require:(name)=>{assert.equal(name,'./lib/study_qa_canary');return {studyQaCanaryAllowed:(input)=>{assert(verified);return studyQaCanaryAllowed({...input,now});}}},
 process:{env:window?{STUDY_QA_WINDOW_START:start,STUDY_QA_WINDOW_UNTIL:until}:{}}};
 const f=vm.runInNewContext('(async()=>{'+authSource+'; return "authorized";})',context);
 const result=await f();assert.equal(JSON.stringify(data),before);
 return {status,authorized:result==='authorized',verified};
}
test('actual handler accepts QA only within the restricted Study window',async()=>assert.equal((await authorize()).authorized,true));
test('actual handler denies ordinary pending user',async()=>assert.equal((await authorize({uid:'ordinary'})).status,403));
test('actual handler preserves approved ordinary/owner authorization and data',async()=>assert.equal((await authorize({uid:'approved-owner',approved:true,window:false})).authorized,true));
test('actual handler denies invalid token before grant evaluation',async()=>assert.equal((await authorize({invalid:true})).status,401));
test('actual handler denies absent token',async()=>assert.equal((await authorize({token:false})).status,401));
test('actual handler denies QA after window removal',async()=>assert.equal((await authorize({window:false})).status,403));
test('actual handler denies QA OpenAI/Plantao even on same URL',async()=>{
 assert.equal((await authorize({requestBody:{...body,provider:'openai'}})).status,403);
 assert.equal((await authorize({requestBody:{...body,mode:'plantao'}})).status,403);
});
test('actual handler cannot approve a missing user document',async()=>assert.equal((await authorize({exists:false})).status,403));
