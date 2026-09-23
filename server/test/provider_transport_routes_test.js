'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {allowedPath,resourceKey,registerProviderTransport}=require('../provider_transport_routes');
test('provider transport allowlist rejects arbitrary URL, models, paths and verbs',()=>{
 assert.equal(allowedPath('/v1beta/models/gemini-2.5-flash:generateContent','POST'),true);
 for(const [p,m]of [['https://evil.invalid/','POST'],['/v1beta/models/invented:generateContent','POST'],['/v1beta/files','GET'],['/v1beta/files/../../private','GET'],['/v1beta/models/gemini-2.5-flash:generateContent','GET']])assert.equal(allowedPath(p,m),false);
 assert.notEqual(resourceKey('A','files/one'),resourceKey('B','files/one'));
});
test('existing-app registration retains Firebase middleware and UID resource boundary',async()=>{
 let handler;const auth=()=>{},limiter=()=>{};const upstream=[];const rows=new Map();
 const db={collection:c=>({doc:id=>({get:async()=>({exists:rows.has(c+'/'+id),data:()=>rows.get(c+'/'+id)}),set:async v=>rows.set(c+'/'+id,v)})})};
 registerProviderTransport({app:{use:(path,a,l,h)=>{assert.equal(path,'/api/ai/provider');assert.equal(a,auth);assert.equal(l,limiter);handler=h;}},express:{json:()=> (req,res,next)=>next()},authenticate:auth,limiter,db,keyProvider:()=> 'server-test-secret',fetchImpl:async(url,options)=>{upstream.push({url:String(url),options});return new Response(JSON.stringify({name:'files/example',uri:'https://generativelanguage.googleapis.com/v1beta/files/example'}),{status:200,headers:{'content-type':'application/json'}});}});
 async function invoke(uid,path,body={},method='POST'){
  const res={code:200,headers:{},status(c){this.code=c;return this;},json(v){this.body=v;return this;},send(v){this.body=v;return this;},end(){},on(){},setHeader(k,v){this.headers[k]=v;}};
  await handler({auth:uid?{uid}:undefined,path,method,headers:{},query:{},body},res);return res;
 }
 assert.equal((await invoke(null,'/v1beta/models/gemini-2.5-flash:generateContent')).code,401);
 assert.equal((await invoke('A','/v1beta/files/not-owned',{},'GET')).code,403);assert.equal(upstream.length,0);
 const created=await invoke('A','/upload/v1beta/files');assert.equal(created.code,200);assert.equal(upstream[0].options.headers['x-goog-api-key'],'server-test-secret');assert.ok(!JSON.stringify(created.body).includes('server-test-secret'));
 assert.equal((await invoke('B','/v1beta/files/example',{},'GET')).code,403);
 assert.equal((await invoke('B','/v1beta/models/gemini-2.5-flash:generateContent',{contents:[{parts:[{fileData:{fileUri:'https://generativelanguage.googleapis.com/v1beta/files/example'}}]}]})).code,502);
 assert.equal((await invoke('A','/v1beta/files/example',{},'GET')).code,200);
});

test('audio generation claims once across direct requests and bound uploaded references',async()=>{
 const {MonthlyUsageOwner}=require('../monthly_usage_owner');
 const rows=new Map([['users/A',{plan:'free'}]]);let queue=Promise.resolve();
 const ref=path=>({path,get:async()=>({exists:rows.has(path),data:()=>structuredClone(rows.get(path))}),set:async v=>rows.set(path,structuredClone(v))});
 const db={collection:c=>({doc:id=>ref(c+'/'+id)}),runTransaction(action){const run=queue.then(async()=>{const staged=new Map();const value=await action({get:r=>r.get(),set:(r,v)=>staged.set(r.path,structuredClone(v))});for(const [k,v]of staged)rows.set(k,v);return value;});queue=run.catch(()=>{});return run;}};
 const reservation=await new MonthlyUsageOwner({db}).reserve('A',{operationId:'audio',kinds:['transcription'],maximumMs:60000});
 const usage={'x-medcases-usage-reservation':reservation.id,'x-medcases-usage-attempt':reservation.attempt};
 let handler,generations=0;
 registerProviderTransport({app:{use:(_p,_a,_l,h)=>handler=h},express:{json:()=> (req,res,next)=>next()},authenticate:()=>{},limiter:()=>{},db,keyProvider:()=> 'synthetic-server-only',fetchImpl:async url=>{if(String(url).includes('generateContent'))generations++;return new Response('{"candidates":[]}',{status:200,headers:{'content-type':'application/json'}});}});
 async function call(body,headers=usage,path='/v1beta/models/gemini-2.5-flash:generateContent',method='POST'){
  const res={code:200,status(c){this.code=c;return this;},json(v){this.body=v;return this;},send(v){this.body=v;return this;},end(){},on(){},setHeader(){}};
  await handler({auth:{uid:'A'},path,method,headers,query:{},body},res);return res;
 }
 const audio={contents:[{parts:[{inlineData:{mimeType:'audio/mp4',data:'synthetic'}}]}]};
 const result=await Promise.all([call(audio),call(audio)]);assert.equal(result.filter(r=>r.code===200).length,1);assert.equal(generations,1);
 await db.collection('providerResourceOwnership').doc(resourceKey('A','files/audio')).set({uid:'A',usage});
 const replay=await call({contents:[{parts:[{fileData:{fileUri:'https://generativelanguage.googleapis.com/v1beta/files/audio'}}]}]},{});
 assert.notEqual(replay.code,200);assert.equal(generations,1);
 assert.equal((await call({}, {}, '/v1beta/files/audio','DELETE')).code,200);
 assert.equal(generations,1);
});
