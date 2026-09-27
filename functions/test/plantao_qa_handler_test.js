'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const {createRequire}=require('node:module');
const {EventEmitter}=require('node:events');
const indexPath=path.resolve(__dirname,'../index.js');
const realRequire=createRequire(indexPath),source=fs.readFileSync(indexPath,'utf8');
const plain=x=>JSON.parse(JSON.stringify(x));
// Historical Phase14 bytes are unavailable. This differential test exercises
// identical real handler source under fulfilled/rejected/pending observer promises
// versus the actual disabled adapter. It never supplies a fabricated registry.
function harness(observerMode,fixture={}){
 const calls=[],reads=[],writes=[],auth=[];
 const doc=name=>({async get(){reads.push(name);return {exists:true,data:()=>name.startsWith('users/')?{status:fixture.status||'pending'}:{}};},async set(data){writes.push({name,data:plain(data)});},async update(data){writes.push({name,data:plain(data)});}});
 const db={doc,collection(name){return{doc:id=>doc(name+'/'+id),async add(data){writes.push({name,data:plain(data)});return {id:'synthetic-record'};}}}};
 function firestore(){return db;}
 firestore.FieldValue={serverTimestamp:()=> 'FIXED_SERVER_TIMESTAMP'};
 firestore.Timestamp={fromMillis:ms=>({milliseconds:ms}),now:()=>({seconds:1700000000,nanoseconds:0}),fromDate:()=>({seconds:1700000000,nanoseconds:0})};
 const admin={initializeApp(){},firestore,auth:()=>({async verifyIdToken(token,checkRevoked){auth.push({token,checkRevoked});if(fixture.revoked)throw Object.assign(Error('revoked'),{code:'auth/id-token-revoked'});return {uid:'fixture-user',...(fixture.qa?{medcasesQaPlantao:{uid:'fixture-user',endpoint:'plantaoProxyStream',syntheticOnly:true,expiresAtMs:1700003600000}}:{})};}})};
 const register=(_options,handler)=>handler;
 class HttpsError extends Error{constructor(code,message){super(message);this.code=code;}}
 class FixedDate extends Date{constructor(...args){super(...(args.length?args:[1700000000000]));}static now(){return 1700000000000;}}
 const context={module:{exports:{}},exports:{},Buffer,URL,AbortController,Date:FixedDate,setTimeout,clearTimeout,setInterval:()=>1,clearInterval:()=>{},process:{env:{NODE_ENV:'test'}},__dirname:path.dirname(indexPath),__filename:indexPath};context.exports=context.module.exports;
 context.require=id=>{
  if(id==='firebase-admin')return admin;
  if(id==='./plantao_qa_authorization') {const policy=realRequire(id);return {isScopedPlantaoQaAuthorized:(t,e)=>policy.isScopedPlantaoQaAuthorized(t,e,1700000000000)};}
  if(id==='./plantao_canonical_stream')return {runPlantaoCanonicalStream:async()=>{calls.push({provider:'canonical'});return {text:'Synthetic response',model:'gpt-5.6-luna',fallbackUsed:false};}};
  if(id==='firebase-functions/v2/firestore')return{onDocumentCreated:register,onDocumentUpdated:register,onDocumentDeleted:register};
  if(id==='firebase-functions/v2/https')return{onCall:register,onRequest:register,HttpsError};
  if(id==='firebase-functions/v2/scheduler')return{onSchedule:register};
  if(id==='firebase-functions/params')return{defineSecret:()=>({value:()=> 'synthetic-secret'})};
  if(id==='./private_logger')return{log(){},info(){},warn(){},error(){},debug(){}};
  if(id==='https'||id==='http')return{request(){throw Error('UNEXPECTED_NETWORK')}};
  if(id==='./clinical_context/clinical_shadow_observation_s1_runtime' && observerMode!=='disabled')return{createClinicalShadowObservationS1Runtime:()=>({observeFromRequest:()=>observerMode==='rejected'?Promise.reject(Error('synthetic observer failure')):observerMode==='pending'?new Promise(()=>{}):Promise.resolve({observed:true,observation:{diagnosticOnly:true},providerCalls:0,visibleMutation:false})})};
  return realRequire(id);
 };
 const result={text:'Synthetic response',model:'gpt-5.6',provider:'gpt_5_6',inputTokensApprox:7,outputTokensApprox:11,structuredOutput:null};
 context.__gemini=async (...args)=>{calls.push({provider:'gemini',args:plain(args)});if(fixture.providerError)throw Error('gemini_api_error');return result;};
 context.__openai=async options=>{const {onDelta,abortSignal,...args}=options;calls.push({provider:'openai',args:plain(args),aborted:abortSignal.aborted});if(fixture.providerError)throw Error('openai_http_503');onDelta({text:'Synthetic response'});return result;};
 vm.createContext(context);vm.runInContext(source+'\n_callGeminiRestAIRaw=__gemini; _callOpenAiResponsesStreamRaw=__openai;',context,{filename:indexPath,timeout:2000});
 return{handlers:context.module.exports,calls,reads,writes,auth};
}
async function execute(endpoint,observerMode,fixture){
 const h=harness(observerMode,fixture);
 const data={uid:fixture.wrongUid?'other-user':'fixture-user',userMessage:' synthetic request ',systemPrompt:' synthetic safety instructions ',history:[{role:'user',content:'synthetic history'}],longResponse:fixture.study||false,mode:fixture.study?'study':'plantao',requestId:'fixed-request'};
 let output;
 if(endpoint==='gemini'){
  try{output=await h.handlers.atenderConsultaIA({auth:fixture.noAuth?null:{uid:'fixture-user'},data});}catch(e){output={error:e.code,message:e.message};}
 }else{
  const req=Object.assign(new EventEmitter(),{method:'POST',headers:{authorization:'Bearer fixture-token','content-type':'application/json'},body:data});
  const res=Object.assign(new EventEmitter(),{headers:{},chunks:[],code:200,writableEnded:false,status(n){this.code=n;return this;},setHeader(k,v){this.headers[k]=v;},flushHeaders(){},flush(){},write(x){this.chunks.push(x);},end(){this.writableEnded=true;return this;},json(x){this.payload=plain(x);this.end();return this;}});
  await h.handlers[endpoint==='plantao'?'plantaoProxyStream':'gptProxyStream'](req,res);output={status:res.code,headers:res.headers,chunks:res.chunks,payload:res.payload};
 }
 await Promise.resolve();
 return plain({output,calls:h.calls,reads:h.reads,writes:h.writes,auth:h.auth});
}

test('real handler admits scoped QA only in Plantao',async()=>{
 const p=await execute('plantao','disabled',{qa:true});assert.equal(p.output.status,200);
 const other=await execute('openai','disabled',{qa:true,study:true});assert.equal(other.output.status,403);assert.equal(other.calls.length,0);
});
test('real handler denies ordinary and invalid token/UID before provider',async()=>{
 for(const f of [{},{qa:true,revoked:true},{qa:true,wrongUid:true}]){const r=await execute('plantao','disabled',f);assert.ok([401,403].includes(r.output.status));assert.equal(r.calls.length,0);}
});
