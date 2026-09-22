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
