'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),http=require('node:http');
const {callableCorsOrigins,requireCallableRevocation}=require('../callable_security');
const {onCall}=require('firebase-functions/v2/https');
const source=fs.readFileSync(require.resolve('../index.js'),'utf8');
const names=[...source.matchAll(/exports\.(\w+)\s*=\s*onCall\(/g)].map(m=>m[1]);
function captured(name,auth){const start=source.indexOf(`exports.${name} = onCall(`),end=source.indexOf('\n);',start)+3;let captured;
 const context={exports:{},onCall:(options,handler)=>{captured={options,handler};return captured},callableCorsOrigins,requireCallableRevocation,admin:{auth:()=>auth,firestore:()=>{throw Error('SENSITIVE_WORK_AFTER_DENY')}},GEMINI_AI_KEY:{},GPT_ADMIN_UNLOCK_CODE:{}};
 vm.runInNewContext(source.slice(start,end),context);return captured;
}
const request=()=>({auth:{uid:'TEST_A',token:{sub:'TEST_A'}},rawRequest:{headers:{authorization:'Bearer TECHNICAL_TOKEN'}}});
test('inventory covers every exported callable with explicit CORS and first revocation boundary',()=>{assert.deepEqual(names,['atenderConsultaIA','adminSetGptOperationalState']);for(const n of names){const c=captured(n,{});assert.deepEqual(c.options.cors,callableCorsOrigins());assert.match(c.handler.toString(),/^async \(request\) => \{\s*await requireCallableRevocation\(request, admin.auth\(\)\);/);}});
for(const name of names)for(const kind of ['revoked','disabled','expired','wrongUid','wrongContext','missingAuth','missingToken'])test(`${name} ${kind} denies before sensitive work`,async()=>{
 let calls=0;const auth={verifyIdToken:async(token,checkRevoked)=>{calls++;assert.equal(checkRevoked,true);assert.equal(token,'TECHNICAL_TOKEN');if(['revoked','disabled','expired'].includes(kind))throw Error('auth/'+kind);return {uid:kind==='wrongUid'?'TEST_B':'TEST_A'};}};
 const r=request();if(kind==='missingAuth')delete r.auth;if(kind==='missingToken')delete r.rawRequest.headers.authorization;if(kind==='wrongContext')r.auth.token.sub='TEST_B';
 await assert.rejects(captured(name,auth).handler(r),e=>e.code==='unauthenticated');assert.equal(calls,['missingAuth','missingToken'].includes(kind)?0:1);
});
test('valid verification returns verified identity; role/status still owned by callbacks',async()=>{const v=await requireCallableRevocation(request(),{verifyIdToken:async(_t,check)=>{assert.equal(check,true);return {uid:'TEST_A'}}});assert.equal(v.uid,'TEST_A');assert.ok(source.includes("userStatus !== 'approved'"));assert.ok(source.includes('const actor = await _requireMasterForAiControl(request)'));});
for(const env of [undefined,'production','staging','test','development','local'])test(`real callable CORS preflight ${env}`,async()=>{
 const origins=callableCorsOrigins(env);const server=http.createServer(onCall({cors:origins},()=>{throw Error('NO_BACKEND_WORK_ON_PREFLIGHT')}));await new Promise(r=>server.listen(0,'127.0.0.1',r));
 try{for(const origin of ['http://localhost:43210','http://127.0.0.1:43210','https://untrusted.invalid','https://medcasespro.com','https://www.medcasespro.com','http://localhost:3000']){const r=await fetch('http://127.0.0.1:'+server.address().port,{method:'OPTIONS',headers:{origin,'access-control-request-method':'POST','access-control-request-headers':'authorization'}});await r.text();assert.equal(r.headers.get('access-control-allow-origin'),origins.includes(origin)?origin:null);}}finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
});
