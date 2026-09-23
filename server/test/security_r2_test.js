'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {inspectAudio,combineProofs,digest,MAX_BYTES,MAX_DURATION_MS}=require('../audio_media_budget');
const {MonthlyUsageOwner}=require('../monthly_usage_owner');
const {registerProviderTransport}=require('../provider_transport_routes');
const {createRevenueCatWebhookHandler,MAX_FUTURE_EVENT_SKEW_MS}=require('../revenuecat_webhook_routes');
const {wav,proof,database}=require('./media_fixture');
function res(){return {code:200,status(n){this.code=n;return this},json(v){this.body=v;return this},send(v){this.body=v;return this},on(){},end(){},setHeader(){}}}
test('inspector real PCM and AAC, corruption and strict bounds',async()=>{
 assert.equal((await inspectAudio(wav())).durationMs,4000);
 const aac=fs.readFileSync(path.join(__dirname,'fixtures/silence-4s-aac.m4a'));const a=await inspectAudio(aac),b=await inspectAudio(aac);assert.deepEqual(a,b);assert.ok(a.durationMs>=4000&&a.durationMs<4100);
 for(const bytes of [Buffer.alloc(0),Buffer.from('INVALID'),wav(0),Buffer.alloc(MAX_BYTES+1),aac.subarray(0,aac.length-5)])await assert.rejects(inspectAudio(bytes));
 const corrupt=wav();corrupt.writeUInt32LE(0,24);await assert.rejects(inspectAudio(corrupt));
 assert.ok(MAX_DURATION_MS<=90*60000);assert.equal(require('../package.json').dependencies['@audio/decode-aac'],'1.5.0');
});
for(const reserve of [1,1000,4000])test(`provider media 4000ms vs reservation ${reserve}`,async()=>{
 const db=database(),owner=new MonthlyUsageOwner({db}),r=await owner.reserve('A',{operationId:'r2',maximumMs:reserve,kinds:['transcription']});let handler,calls=0;
 registerProviderTransport({app:{use:(_p,_a,_l,h)=>handler=h},express:{json:()=> (_q,_s,n)=>n()},authenticate(){},limiter(){},db,keyProvider:()=> 'TEST_ONLY',fetchImpl:async()=>{calls++;return new Response('{"candidates":[]}',{headers:{'content-type':'application/json'}})}});
 const req={auth:{uid:'A'},method:'POST',path:'/v1beta/models/gemini-2.5-flash:generateContent',query:{},headers:{'x-medcases-usage-reservation':r.id,'x-medcases-usage-attempt':r.attempt},body:{declaredDurationMs:1000,contents:[{parts:[{inlineData:{mimeType:'audio/wav',data:wav().toString('base64')}}]}]}};
 const result=res();await handler(req,result);assert.equal(calls,reserve<4000?0:1);assert.equal(result.code,reserve<4000?502:200);
 if(reserve===4000){const again=res();await handler(req,again);assert.equal(again.code,409);assert.equal(calls,1);}
});
test('atomic parallel slot sum, retry identity, and refund cannot mint budget',async()=>{
 const db=database(),owner=new MonthlyUsageOwner({db});const r=await owner.reserve('A',{operationId:'parallel',maximumMs:4000,kinds:['transcription'],executionCount:2}),p=await proof(4000);
 const results=await Promise.allSettled([owner.claimExecution('A',r,0,p),owner.claimExecution('A',r,1,p)]);assert.equal(results.filter(x=>x.status==='fulfilled').length,1);
 const i=results[0].status==='fulfilled'?0:1;await owner.completeExecution('A',r,i);assert.equal((await owner.claimExecution('A',r,i,p)).claimed,false);
 await assert.rejects(owner.claimExecution('A',r,i,await proof(4000,'CHANGED_REQUEST')),/BINDING_CONFLICT/);
 for(let n=0;n<2;n++){await owner.finish('A',{...r,actualMs:0,success:false});await assert.rejects(owner.failBeforeExecution('A',r));}
 assert.equal(db.data.get('usageReservations/'+r.id).authorizedMediaMs,4000);assert.equal(db.data.get('usageReservations/'+r.id).chargedMs,4000);
 await assert.rejects(owner.claimExecution('A',r,1-i,{durationMs:1,sha256:'0'.repeat(64),requestHash:'0'.repeat(64)}),/PROOF_REQUIRED/);
 for(const n of [-1,0])await assert.rejects(owner.reserve('A',{operationId:'invalid'+n,maximumMs:n,kinds:['transcription']}));
});
test('future authenticated webhook cannot poison watermark, refund remains effective',async()=>{
 const db=database(),now=Date.now(),secret='TECHNICAL_TEST_WEBHOOK_SECRET_0000000000';const h=createRevenueCatWebhookHandler({db,nowMsProvider:()=>now,authorizationProvider:()=>secret});
 const base={id:'initial',type:'RENEWAL',app_user_id:'A',event_timestamp_ms:now,expiration_at_ms:now+86400000,entitlement_ids:['medcases_pro_premium']};
 const send=async e=>{const r=res();await h({headers:{authorization:secret},body:{event:e}},r);return r;};assert.equal((await send(base)).code,200);
 const before=JSON.stringify([...db.data.entries()]);assert.equal((await send({...base,id:'future',event_timestamp_ms:now+10*86400000})).code,422);assert.equal(JSON.stringify([...db.data.entries()]),before);
 assert.equal((await send({...base,id:'edge',event_timestamp_ms:now+MAX_FUTURE_EVENT_SKEW_MS+1})).code,422);
 assert.equal((await send({...base,id:'refund',type:'REFUND',event_timestamp_ms:now+1})).code,200);assert.equal(db.data.get('users/A').billingEntitlementActive,false);
 assert.equal((await send({...base,id:'refund',type:'REFUND',event_timestamp_ms:now+1})).body.reason,'duplicate_event');
 assert.equal((await send({...base,id:'old',event_timestamp_ms:now-1000})).body.reason,'stale_event');assert.equal(db.data.get('users/A').billingEntitlementActive,false);
});
test('Android variant resource overlay denies release cleartext, permits only debug loopback',()=>{
 const root=path.resolve(__dirname,'../..'),main=fs.readFileSync(path.join(root,'android/app/src/main/res/xml/network_security_config.xml'),'utf8'),debug=fs.readFileSync(path.join(root,'android/app/src/debug/res/xml/network_security_config.xml'),'utf8');
 assert.match(main,/<base-config cleartextTrafficPermitted="false">/);assert.doesNotMatch(main,/cleartextTrafficPermitted="true"/);assert.match(debug,/<base-config cleartextTrafficPermitted="false">/);assert.match(debug,/<domain includeSubdomains="false">localhost<\/domain>/);assert.match(debug,/<domain includeSubdomains="false">10\.0\.2\.2<\/domain>/);
 assert.ok(!fs.existsSync(path.join(root,'android/app/src/release/res/xml/network_security_config.xml')));const gradle=fs.readFileSync(path.join(root,'android/app/build.gradle.kts'),'utf8');assert.doesNotMatch(gradle,/sourceSets/);
});
test('parallel slots can consume exactly the measured budget and never exceed it',async()=>{
 const owner=new MonthlyUsageOwner({db:database()}),r=await owner.reserve('A',{operationId:'sum',maximumMs:4000,kinds:['transcription'],executionCount:3}),p=await proof(2000);
 const results=await Promise.allSettled([0,1,2].map(i=>owner.claimExecution('A',r,i,p)));assert.equal(results.filter(x=>x.status==='fulfilled').length,2);assert.equal(results.filter(x=>x.status==='rejected').length,1);
});
test('declared container duration is not the decoded AAC duration',async()=>{
 const b=fs.readFileSync(path.join(__dirname,'fixtures/silence-4s-aac.m4a'));const expected=await inspectAudio(b);const changed=Buffer.from(b);const pos=changed.indexOf(Buffer.from('mdhd'));assert.ok(pos>0);const body=pos+4;assert.equal(changed[body],0);changed.writeUInt32BE(1,body+16);assert.equal((await inspectAudio(changed)).durationMs,expected.durationMs);
 const corrupted=Buffer.from(b);const data=corrupted.indexOf(Buffer.from('mdat'));assert.ok(data>0);corrupted.fill(255,data+4,Math.min(data+36,corrupted.length));await assert.rejects(inspectAudio(corrupted));
});
test('complete uploaded audio measured before upstream; stored media proof binds file references',async()=>{
 const {Readable}=require('node:stream');const {resourceKey}=require('../provider_transport_routes');
 for(const budget of [1,4000]){
  const db=database(),owner=new MonthlyUsageOwner({db}),r=await owner.reserve('A',{operationId:'upload',maximumMs:budget,kinds:['transcription']});
  const usage={'x-medcases-usage-reservation':r.id,'x-medcases-usage-attempt':r.attempt},id='12345678-1234-1234-1234-123456789012';
  db.data.set('providerUploadTickets/'+id,{uid:'A',url:'https://generativelanguage.googleapis.com/upload/fixture',usage,contentType:'audio/wav',expiresAt:Date.now()+10000});
  let handler,uploads=0,generations=0;registerProviderTransport({app:{use:(_p,_a,_l,h)=>handler=h},express:{json:()=> (_q,_s,n)=>n()},authenticate(){},limiter(){},db,keyProvider:()=> 'TEST_ONLY',fetchImpl:async(url)=>{const upload=String(url).includes('/upload/');if(upload)uploads++;else generations++;return new Response(upload?'{"file":{"name":"files/fixture"}}':'{}',{headers:{'content-type':'application/json'}})}});
  const request=Readable.from([wav()]);Object.assign(request,{auth:{uid:'A'},path:'/upload-ticket/'+id,method:'POST',headers:{'x-goog-upload-offset':'0','x-goog-upload-command':'upload, finalize'},query:{}});const result=res();await handler(request,result);assert.equal(uploads,budget===1?0:1);
  if(budget===4000){assert.equal(db.data.get('providerResourceOwnership/'+resourceKey('A','files/fixture')).media.durationMs,4000);const req={auth:{uid:'A'},path:'/v1beta/models/gemini-2.5-flash:generateContent',method:'POST',headers:{},query:{},body:{contents:[{parts:[{file_data:{mime_type:'audio/wav',file_uri:'https://generativelanguage.googleapis.com/v1beta/files/fixture'}}]}]}};
   // A receipt remains mandatory when an explicit audio MIME is submitted.
   req.headers=usage;const out=res();await handler(req,out);assert.equal(out.code,200);assert.equal(generations,1);
  }
 }
});
test('resource bombs are rejected before decode; inspector remains usable',async()=>{
 await assert.rejects(inspectAudio(wav(MAX_DURATION_MS+1)));
 const b=fs.readFileSync(path.join(__dirname,'fixtures/silence-4s-aac.m4a'));
 const huge=Buffer.from(b),pos=huge.indexOf(Buffer.from('stsz'));assert.ok(pos>0);huge.writeUInt32BE(0xffffffff,pos+12);await assert.rejects(inspectAudio(huge));
 const nested=Buffer.alloc(8*12);for(let i=0;i<12;i++){nested.writeUInt32BE(nested.length-i*8,i*8);nested.write('moov',i*8+4);}await assert.rejects(inspectAudio(nested));
 assert.equal((await inspectAudio(wav(1000))).durationMs,1000);
});
test('worker watchdog, concurrency and cleanup are mandatory on timeout',async()=>{
 const vm=require('node:vm'),{EventEmitter}=require('node:events'),{createRequire}=require('node:module');
 const file=path.resolve(__dirname,'../audio_media_budget.js'),real=createRequire(file),workers=[],timers=[];
 class StalledWorker extends EventEmitter{constructor(file,options){super();this.options=options;this.stopped=0;workers.push(this)}async terminate(){this.stopped++}}
 const scope={module:{exports:{}},Buffer,__dirname:path.dirname(file),require:id=>id==='node:worker_threads'?{Worker:StalledWorker}:real(id),setTimeout:(fn,ms)=>{assert.equal(ms,10000);timers.push(fn);return fn},clearTimeout:()=>{}};
 vm.runInNewContext(fs.readFileSync(file,'utf8'),scope);const inspect=scope.module.exports.inspectAudio;
 const a=inspect(wav()),b=inspect(wav());const ar=assert.rejects(a,/TIMEOUT/),br=assert.rejects(b,/TIMEOUT/);await assert.rejects(inspect(wav()),/BUSY/);
 timers.forEach(fn=>fn());await Promise.all([ar,br]);assert.ok(workers.every(w=>w.stopped>0));assert.equal(workers[0].options.resourceLimits.maxOldGenerationSizeMb,64);
 const next=inspect(wav());workers[2].emit('message',{durationMs:4000});assert.equal((await next).durationMs,4000);assert.ok(workers[2].stopped>0);
});
