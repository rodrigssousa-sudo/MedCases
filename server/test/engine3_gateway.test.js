'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {createServer}=require('node:http');const {once}=require('node:events');
const {JWT}=require('google-auth-library');
const {createEngine3Gateway,runtimeIdTokenProvider,configuration,PROJECT,GATEWAY_IDENTITY,AUDIENCE,TARGET,ROUTE}=require('../engine3_gateway');
const ORIGIN='http://127.0.0.1:8895';
const env={ENGINE3_GATEWAY_ENABLED:'true',FIREBASE_PROJECT_ID:PROJECT,ENGINE3_HML_ORIGINS:ORIGIN};
const tokenExpiry=Math.floor(Date.now()/1000)+3600;
const token=(overrides={})=>'head.'+Buffer.from(JSON.stringify({aud:AUDIENCE,iss:'https://accounts.google.com',email:GATEWAY_IDENTITY,exp:tokenExpiry,...overrides})).toString('base64url')+'.signature';
const body={requestId:'local_fixture_1',question:'LOCAL_NONCLINICAL_FIXTURE',language:'pt',mode:'plantao',use:'general_education'};
const frame=(event,data)=>`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
const sse=(state='VALIDATED',event='external_evidence')=>frame('started',{requestId:body.requestId})+frame(event,{requestId:body.requestId,validation:{state,safeForDelivery:true},fixture:true})+frame('transport_done',{requestId:body.requestId,validation:{state,safeForDelivery:true}});
async function setup(t,overrides={}){
 const calls={auth:0,token:0,upstream:0,logs:[],quota:0,history:0};
 const handler=createEngine3Gateway({env,
 verifyFirebase:async (value,revoked)=>{calls.auth++;assert.equal(value,'firebase-test');assert.equal(revoked,true);return{uid:'synthetic-A',aud:PROJECT,iss:`https://securetoken.google.com/${PROJECT}`};},
 getInvokerToken:async a=>{calls.token++;assert.equal(a,AUDIENCE);return token();},
 fetchUpstream:async(url,options)=>{calls.upstream++;calls.url=url;calls.options=options;calls.quota++;calls.history++;return new Response(sse(),{headers:{'content-type':'text/event-stream'}});},
 log:x=>calls.logs.push(x),...overrides});
 const server=createServer(handler);server.listen(0,'127.0.0.1');await once(server,'listening');
 t.after(()=>{server.closeAllConnections();server.close();});
 const url=`http://127.0.0.1:${server.address().port}${ROUTE}`;
 const post=(data=body,headers={})=>fetch(url,{method:'POST',headers:{origin:ORIGIN,authorization:'Bearer firebase-test','content-type':'application/json',...headers},body:JSON.stringify(data)});
 return{calls,post,url};
}
for(const state of ['VALIDATED','LIMITED'])test(`${state}: exact SSE authenticated, no reclassification`,async t=>{
 const {calls,post}=await setup(t,{fetchUpstream:async(url,options)=>{calls.upstream++;calls.url=url;calls.options=options;return new Response(sse(state),{headers:{'content-type':'text/event-stream'}});}});
 const r=await post();assert.equal(r.status,200);assert.equal(await r.text(),sse(state));assert.equal(r.headers.get('access-control-allow-origin'),ORIGIN);
 assert.equal(calls.url,TARGET);assert.equal(calls.options.headers.Authorization,'Bearer firebase-test');assert.equal(calls.options.headers['X-Serverless-Authorization'],'Bearer '+token());
 assert.equal(JSON.parse(calls.options.body).requestId,body.requestId);assert.equal(calls.options.redirect,'manual');assert.equal(calls.upstream,1);
});
test('approved_protocol bytes preserved without manufacturing approval',async t=>{const {post}=await setup(t,{fetchUpstream:async()=>new Response(sse('VALIDATED','approved_protocol'),{headers:{'content-type':'text/event-stream'}})});assert.equal(await(await post()).text(),sse('VALIDATED','approved_protocol'));});
test('Firebase invalid or revoked never reaches invoker/upstream',async t=>{const {calls,post}=await setup(t,{verifyFirebase:async()=>{throw Error('secret-token-user-email');}});const r=await post();assert.equal(r.status,401);assert.equal(calls.token,0);assert.equal(calls.upstream,0);assert.ok(!JSON.stringify(calls.logs).includes('secret-token-user-email'));});
test('wrong Firebase project denied',async t=>{const {post,calls}=await setup(t,{verifyFirebase:async()=>({uid:'A',aud:'medcases-pro',iss:'bad'})});assert.equal((await post()).status,401);assert.equal(calls.token,0);});
test('missing Firebase token denied',async t=>{const {post,calls}=await setup(t);assert.equal((await post(body,{authorization:''})).status,401);assert.equal(calls.auth,0);});
for(const origin of ['https://medcasespro.com','http://127.0.0.1:8896','null','http://127.0.0.1:8895.evil.invalid'])test(`origin rejected ${origin}`,async t=>{const {post,calls}=await setup(t);const r=await post(body,{origin});assert.equal(r.status,403);assert.equal(r.headers.get('access-control-allow-origin'),null);assert.equal(calls.auth,0);});
test('OPTIONS exact HML preflight without authentication work',async t=>{const {url,calls}=await setup(t);const r=await fetch(url,{method:'OPTIONS',headers:{origin:ORIGIN,'access-control-request-method':'POST','access-control-request-headers':'authorization, content-type, x-request-id'}});assert.equal(r.status,204);assert.equal(r.headers.get('access-control-allow-origin'),ORIGIN);assert.equal(calls.auth,0);});
test('preflight cannot request invoker credential header',async t=>{const {url}=await setup(t);const r=await fetch(url,{method:'OPTIONS',headers:{origin:ORIGIN,'access-control-request-method':'POST','access-control-request-headers':'x-serverless-authorization'}});assert.equal(r.status,403);});
test('private invoker 403 propagated once; no fallback',async t=>{let count=0;const {post}=await setup(t,{fetchUpstream:async()=>{count++;return new Response('untrusted html',{status:403});}});const r=await post();assert.equal(r.status,403);assert.equal((await r.json()).error,'ENGINE3_UPSTREAM_HTTP_403');assert.equal(count,1);});
test('BLOCKED preserves 422 and safe code, never creates terminal',async t=>{const {post}=await setup(t,{fetchUpstream:async()=>Response.json({error:'UNVALIDATED_FINAL',validation:{state:'BLOCKED',safeForDelivery:false}},{status:422})});const r=await post();assert.equal(r.status,422);const text=await r.text();assert.ok(text.includes('UNVALIDATED_FINAL'));assert.equal(JSON.parse(text).validation.state,'BLOCKED');assert.ok(!text.includes('transport_done'));});
test('redirect is never followed',async t=>{const {post}=await setup(t,{fetchUpstream:async()=>new Response(null,{status:302,headers:{location:'https://medcasespro.com'}})});assert.equal((await post()).status,502);});
test('wrong token audience blocked before forwarding',async t=>{const {post,calls}=await setup(t,{getInvokerToken:async()=>token({aud:TARGET})});assert.equal((await post()).status,502);assert.equal(calls.upstream,0);});
test('gateway identity mismatch blocked',()=>{assert.throws(()=>runtimeIdTokenProvider({FIREBASE_SERVICE_ACCOUNT_JSON:JSON.stringify({project_id:PROJECT,client_email:'operator@example.invalid',private_key:'fixture',type:'service_account'})}),/IDENTITY/);});
test('provider reuses server identity and base audience, no impersonation',async()=>{
 const original=JWT.prototype.fetchIdToken;let called=0;
 JWT.prototype.fetchIdToken=async function(a){called++;assert.equal(this.email,GATEWAY_IDENTITY);assert.equal(a,AUDIENCE);return token();};
 try{const get=runtimeIdTokenProvider({FIREBASE_SERVICE_ACCOUNT_JSON:JSON.stringify({project_id:PROJECT,client_email:GATEWAY_IDENTITY,private_key:'SYNTHETIC_NOT_A_KEY',type:'service_account'})});await get();assert.equal(called,1);}finally{JWT.prototype.fetchIdToken=original;}
});
test('duplicate POST does not repeat synthetic quota/history effects',async t=>{const {post,calls}=await setup(t);assert.equal((await post()).status,200);assert.equal((await post()).status,409);assert.equal(calls.upstream,1);assert.equal(calls.quota,1);assert.equal(calls.history,1);});
test('concurrent duplicate rejected before token/upstream work',async t=>{let release;const wait=new Promise(r=>release=r);const {post,calls}=await setup(t,{getInvokerToken:async()=>{await wait;return token();}});const first=post();await new Promise(r=>setTimeout(r,20));const second=await post();assert.equal(second.status,409);release();assert.equal((await first).status,200);assert.equal(calls.upstream,1);});
test('SSE flushes first frame before upstream finishes',async t=>{let finish;const stream=new ReadableStream({start(c){c.enqueue(new TextEncoder().encode(frame('started',{requestId:body.requestId})));finish=()=>{c.enqueue(new TextEncoder().encode(frame('transport_done',{requestId:body.requestId})));c.close();};}});const {post}=await setup(t,{fetchUpstream:async()=>new Response(stream,{headers:{'content-type':'text/event-stream'}})});const r=await post();const reader=r.body.getReader();const first=await reader.read();assert.ok(new TextDecoder().decode(first.value).includes('started'));finish();await reader.read();});
test('upstream interruption leaves no fabricated transport_done',async t=>{let breakStream;const stream=new ReadableStream({start(c){c.enqueue(new TextEncoder().encode(frame('started',{requestId:body.requestId})));breakStream=()=>c.error(Error('fixture interruption'));}});const {post}=await setup(t,{fetchUpstream:async()=>new Response(stream,{headers:{'content-type':'text/event-stream'}})});const r=await post();const reader=r.body.getReader();const first=await reader.read();assert.ok(!new TextDecoder().decode(first.value).includes('transport_done'));breakStream();await assert.rejects(reader.read());});
test('client abort propagates upstream cancellation',async t=>{let signal;const stream=new ReadableStream({start(c){c.enqueue(new TextEncoder().encode('event: started\ndata: {}\n\n'));}});const {post}=await setup(t,{fetchUpstream:async(_url,o)=>{signal=o.signal;return new Response(stream,{headers:{'content-type':'text/event-stream'}});}});const r=await post();const reader=r.body.getReader();await reader.read();await reader.cancel();await new Promise(r=>setTimeout(r,30));assert.equal(signal.aborted,true);});
test('request identity mismatch, foreign fields and Study denied',async t=>{const {post,calls}=await setup(t);assert.equal((await post({...body,mode:'study'})).status,400);assert.equal((await post({...body,uid:'someone-else'})).status,400);assert.equal((await post({...body,target:'https://medcasespro.com'})).status,400);assert.equal((await post(body,{'x-request-id':'different'})).status,400);assert.equal(calls.upstream,0);});
test('default OFF has no identity/token/network side effects',async t=>{const {post,calls}=await setup(t,{env:{}});assert.equal((await post()).status,404);assert.equal(calls.auth,0);assert.equal(calls.token,0);assert.equal(calls.upstream,0);});
test('enabled commercial configuration fails closed',()=>{assert.throws(()=>configuration({...env,FIREBASE_PROJECT_ID:'medcases-pro'}),/CONFIGURATION/);assert.throws(()=>configuration({...env,ENGINE3_HML_ORIGINS:'*'}),/CONFIGURATION/);});

test('actual Express mount stays ahead of legacy CORS and preserves legacy route',async t=>{
 const express=require('express');const app=express();let legacyCors=0;
 const h=createEngine3Gateway({env,verifyFirebase:async()=>({uid:'A',aud:PROJECT,iss:`https://securetoken.google.com/${PROJECT}`}),getInvokerToken:async()=>token(),fetchUpstream:async()=>new Response(sse(),{headers:{'content-type':'text/event-stream'}})});
 app.use(ROUTE,h);app.use((_q,_r,next)=>{legacyCors++;next();});app.post('/api/ai/stream/estudo',(_q,r)=>r.json({legacy:'unchanged'}));
 const server=app.listen(0,'127.0.0.1');await once(server,'listening');t.after(()=>{server.closeAllConnections();server.close();});const base=`http://127.0.0.1:${server.address().port}`;
 const r=await fetch(base+ROUTE,{method:'POST',headers:{origin:ORIGIN,authorization:'Bearer fixture','content-type':'application/json'},body:JSON.stringify(body)});assert.equal(r.status,200);assert.equal(await r.text(),sse());assert.equal(legacyCors,0);
 const legacy=await fetch(base+'/api/ai/stream/estudo',{method:'POST'});assert.deepEqual(await legacy.json(),{legacy:'unchanged'});assert.equal(legacyCors,1);
});
test('real JWT exchange transport has explicit no-retry and correct target audience',async()=>{
 const {generateKeyPairSync}=require('node:crypto');
 const {privateKey}=generateKeyPairSync('rsa',{modulusLength:2048});
 const probe=new JWT();const proto=Object.getPrototypeOf(probe.transporter);const original=proto.request;let calls=0;
 proto.request=async function(options){calls++;assert.equal(options.retry,false);assert.equal(options.retryConfig.retry,0);assert.equal(options.timeout,10000);
  const form=new URLSearchParams(options.data);const jwt=form.get('assertion');const payload=JSON.parse(Buffer.from(jwt.split('.')[1],'base64url').toString());assert.equal(payload.target_audience,AUDIENCE);assert.equal(payload.iss,GATEWAY_IDENTITY);
  return{data:{id_token:token(),expires_in:3600}};
 };
 try{const get=runtimeIdTokenProvider({FIREBASE_SERVICE_ACCOUNT_JSON:JSON.stringify({type:'service_account',project_id:PROJECT,client_email:GATEWAY_IDENTITY,private_key:privateKey.export({type:'pkcs8',format:'pem'})})});assert.equal(await get(),token());assert.equal(calls,1);}finally{proto.request=original;}
});

// Exact HML Flutter capability handshake: no new clinical authority.
test('HML drug capability is preserved through gateway',async t=>{const {post,calls}=await setup(t);const b={...body,responseCapabilities:['DRUG_RECORD_RESPONSE_V1']};const r=await post(b);assert.equal(r.status,200);assert.deepEqual(JSON.parse(calls.options.body),b);});
for(const responseCapabilities of [null,'DRUG_RECORD_RESPONSE_V1',[],['UNKNOWN'],['DRUG_RECORD_RESPONSE_V1','DRUG_RECORD_RESPONSE_V1'],['DRUG_RECORD_RESPONSE_V1','UNKNOWN']])test('malformed or unknown capability denied '+JSON.stringify(responseCapabilities),async t=>{const {post,calls}=await setup(t);assert.equal((await post({...body,responseCapabilities})).status,400);assert.equal(calls.upstream,0);assert.equal(calls.token,0);});
