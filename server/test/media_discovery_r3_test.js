'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {Readable}=require('node:stream');
const {classifyBinary,assertBinaryBinding,serializeClassification}=require('../binary_media_classifier');
const {scanMp4,MAX_TOP_LEVEL_BOXES,MAX_DISCOVERY_BYTES,MAX_PARSE_OPERATIONS}=require('../iso_bmff_boxes');
const {MonthlyUsageOwner}=require('../monthly_usage_owner');
const {registerProviderTransport,resourceKey}=require('../provider_transport_routes');
const {wav,database}=require('./media_fixture');
const original=()=>fs.readFileSync(path.join(__dirname,'fixtures/silence-4s-aac.m4a'));
function box(type,payload=Buffer.alloc(0),extended=false){const b=Buffer.alloc((extended?16:8)+payload.length);b.writeUInt32BE(extended?1:b.length);b.write(type,4);if(extended)b.writeBigUInt64BE(BigInt(b.length),8);payload.copy(b,extended?16:8);return b;}
function prepend(types){const prefix=Buffer.concat(types.map(t=>typeof t==='string'?box(t):t));const b=Buffer.concat([prefix,original()]);const stco=b.indexOf(Buffer.from('stco')),n=b.readUInt32BE(stco+8);for(let i=0;i<n;i++){const p=stco+12+i*4;b.writeUInt32BE(b.readUInt32BE(p)+prefix.length,p);}return b;}
function response(){return {code:200,status(n){this.code=n;return this},json(x){this.body=x;return this},send(x){this.body=x;return this},on(){},end(){},setHeader(){}};}
function harness(db=database()){
 let handler;const calls=[];
 registerProviderTransport({app:{use:(_p,_a,_l,h)=>handler=h},express:{json:()=> (_q,_s,n)=>n()},authenticate(){},limiter(){},db,keyProvider:()=> 'TECHNICAL_TEST_KEY',fetchImpl:async(url,options)=>{calls.push({url:String(url),options});const payload=String(url).includes('/upload/')?{file:{name:'files/r3'}}:String(url).endsWith('cachedContents')?{name:'cachedContents/r3'}:{candidates:[]};return new Response(JSON.stringify(payload),{headers:{'content-type':'application/json'}})}});
 return {db,calls,handler,async invoke(body,headers={},route='/v1beta/models/gemini-2.5-flash:generateContent',uid='A'){const res=response();await handler({auth:{uid},method:'POST',path:route,query:{},headers,body},res);return res;}};
}
async function reservation(h,ms=5000,slots=1){const r=await new MonthlyUsageOwner({db:h.db}).reserve('A',{operationId:'technical-'+ms,maximumMs:ms,kinds:['transcription'],executionCount:slots});return {'x-medcases-usage-reservation':r.id,'x-medcases-usage-attempt':r.attempt};}
const inline=(bytes,mime='application/octet-stream')=>({contents:[{parts:[{inlineData:{mimeType:mime,data:bytes.toString('base64')}}]}]});
for(const [name,bytes]of [['ftyp-first',original()],['free-before-ftyp',prepend(['free'])],['free-skip-wide-before-ftyp',prepend(['free','skip','wide'])],['unknown-framed-box',prepend(['abcd'])],['extended-free-box',prepend([box('free',Buffer.alloc(0),true)])]]){
 test('MP4 structure '+name,async()=>{assert.ok(scanMp4(bytes).some(b=>b.type==='ftyp'));const p=await classifyBinary(bytes);assert.equal(p.classification,'SUPPORTED_AUDIO');assert.equal(p.durationMs,4064);});
 for(const budget of [null,1,5000])test(`real handler ${name} budget=${budget}`,async()=>{const h=harness(),headers=budget===null?{}:await reservation(h,budget);const res=await h.invoke(inline(bytes),headers);assert.equal(h.calls.length,budget===5000?1:0);assert.equal(res.code,budget===5000?200:502);if(budget===5000){const sent=JSON.parse(h.calls[0].options.body).contents[0].parts[0].inlineData;assert.equal(sent.mimeType,'audio/mp4');assert.ok(Buffer.from(sent.data,'base64').equals(bytes));const op=[...h.db.data.values()].find(v=>v.authorizedMediaMs);assert.equal(op.authorizedMediaMs,4064);}});
}
const broken=[];
broken.push(['fake-ftyp-in-mdat',box('mdat',Buffer.from('ftyp M4A arbitrary'))]);
broken.push(['truncated',original().subarray(0,-3)]);
for(const size of [4,0xffffffff]){const b=original();b.writeUInt32BE(size);broken.push(['bad-size-'+size,b]);}
const ext=box('free',Buffer.alloc(0),true);ext.writeBigUInt64BE(0xffffffffffffffffn,8);broken.push(['extended-overflow',ext],['extended-truncated',ext.subarray(0,12)]);
broken.push(['too-many-boxes',prepend(Array(MAX_TOP_LEVEL_BOXES+1).fill('free'))]);
const missing=original();missing.write('free',4);broken.push(['missing-ftyp',missing]);
const duplicate=prepend([original().subarray(0,original().readUInt32BE(0))]);broken.push(['duplicate-ftyp',duplicate]);
const unsupported=original();unsupported.write('alac',unsupported.indexOf(Buffer.from('mp4a')));broken.push(['unsupported-codec',unsupported]);
const corrupt=original(),mdat=corrupt.indexOf(Buffer.from('mdat'));corrupt.fill(255,mdat+4,mdat+36);broken.push(['corrupt-aac',corrupt]);
const badBrand=original();const first=badBrand.readUInt32BE(0);for(let p=8;p<first;p+=4)badBrand.write('zzzz',p);broken.push(['unsupported-brands',badBrand]);
broken.push(['random',Buffer.from('arbitrary ftyp random bytes')],['empty',Buffer.alloc(0)]);
for(const[name,bytes]of broken)test('DENY real handler '+name,async()=>{const h=harness(),headers=await reservation(h);await h.invoke(inline(bytes,'audio/mp4'),headers);assert.equal(h.calls.length,0);});
test('bounded parser constants and size-zero semantics',async()=>{
 assert.equal(MAX_DISCOVERY_BYTES,25*1024*1024);assert.ok(MAX_TOP_LEVEL_BOXES<=1000);assert.ok(MAX_PARSE_OPERATIONS<=10000);
 const b=original(),boxes=scanMp4(b),last=boxes.at(-1);assert.equal(last.type,'mdat');b.writeUInt32BE(0,last.start);assert.equal((await classifyBinary(b)).durationMs,4064);
 const invalid=original();invalid.writeUInt32BE(0,0);await assert.rejects(classifyBinary(invalid));
});
for(const mime of ['application/octet-stream','image/png','audio/mp4',''])test('MIME cannot bypass byte classification '+mime,async()=>{const h=harness();await h.invoke(inline(prepend(['free']),mime));assert.equal(h.calls.length,0);});
test('PCM 4000ms cannot use 1ms budget, including generic MIME',async()=>{const h=harness();await h.invoke(inline(wav()),await reservation(h,1));assert.equal(h.calls.length,0);});
test('invalid audio/wav and random generic binary denied',async()=>{for(const mime of ['audio/wav','application/octet-stream']){const h=harness();await h.invoke(inline(Buffer.from('not wave'),mime));assert.equal(h.calls.length,0);}});
test('hash certificate cannot inspect A and send B',async()=>{const a=wav(),p=await classifyBinary(a);assertBinaryBinding(p,a);a[a.length-1]^=1;assert.throws(()=>assertBinaryBinding(p,a),/HASH_BINDING/);assert.throws(()=>assertBinaryBinding({...p},wav()),/HASH_BINDING/);});
test('real handler owns immutable request snapshot across awaits',async()=>{const h=harness(),headers=await reservation(h),request=inline(wav());const done=h.invoke(request,headers);await new Promise(resolve=>setImmediate(resolve));request.contents[0].parts[0].inlineData.data=original().toString('base64');await done;assert.equal(h.calls.length,1);assert.ok(Buffer.from(JSON.parse(h.calls[0].options.body).contents[0].parts[0].inlineData.data,'base64').equals(wav()));});
for(const budget of [null,1,5000])test('upload actual generic free-before-ftyp budget='+budget,async()=>{
 const h=harness(),usage=budget===null?null:await reservation(h,budget),id='12345678-1234-1234-1234-123456789012';h.db.data.set('providerUploadTickets/'+id,{uid:'A',usage,executionIndex:0,url:'https://generativelanguage.googleapis.com/upload/fixture',contentType:'application/octet-stream',expiresAt:Date.now()+60000});
 const req=Readable.from([prepend(['free'])]);Object.assign(req,{auth:{uid:'A'},path:'/upload-ticket/'+id,method:'POST',headers:{'x-goog-upload-command':'upload, finalize'},query:{}});await h.handler(req,response());assert.equal(h.calls.length,budget===5000?1:0);
 if(budget===5000){assert.equal(h.calls[0].options.headers['content-type'],'audio/mp4');const body={contents:[{parts:[{fileData:{mimeType:'image/png',fileUri:'https://generativelanguage.googleapis.com/v1beta/files/r3'}}]}]};const res=await h.invoke(body);assert.equal(res.code,200);assert.equal(h.calls.length,2);assert.equal(JSON.parse(h.calls[1].options.body).contents[0].parts[0].fileData.mimeType,'audio/mp4');}
});
test('unclassified legacy file and cache, wrong UID and mutated stored certificate denied',async()=>{
 for(const name of ['files/legacy','cachedContents/legacy']){const h=harness();h.db.data.set('providerResourceOwnership/'+resourceKey('A',name),{uid:'A',name});const body=name.startsWith('files')?{contents:[{parts:[{fileData:{fileUri:'https://generativelanguage.googleapis.com/v1beta/'+name}}]}]}:{cachedContent:name};await h.invoke(body);assert.equal(h.calls.length,0);}
 const h=harness(),usage=await reservation(h),p=await classifyBinary(wav());h.db.data.set('providerResourceOwnership/'+resourceKey('A','files/valid'),{uid:'A',name:'files/valid',usage,executionIndex:0,binaryManifest:[serializeClassification(p)]});
 await h.invoke({contents:[{parts:[{fileData:{fileUri:'https://generativelanguage.googleapis.com/v1beta/files/valid'}}]}]}, {},undefined,'B');assert.equal(h.calls.length,0);
});
module.exports={prepend,harness,inline,reservation};
function technicalPng(){
 const zlib=require('node:zlib');function crc(b){let c=0xffffffff;for(const x of b){c^=x;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;}
 const chunk=(t,data)=>{const b=Buffer.alloc(data.length+12);b.writeUInt32BE(data.length);b.write(t,4);data.copy(b,8);b.writeUInt32BE(crc(b.subarray(4,-4)),b.length-4);return b;};
 const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(1);ihdr.writeUInt32BE(1,4);ihdr[8]=8;ihdr[9]=6;
 return Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),chunk('IHDR',ihdr),chunk('IDAT',zlib.deflateSync(Buffer.from([0,0,0,0,255]))),chunk('IEND',Buffer.alloc(0))]);
}
function technicalPdf(){let s='%PDF-1.4\n';const offsets=[0];for(const x of ['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [] /Count 0 >>']){offsets.push(s.length);s+=`${offsets.length-1} 0 obj\n${x}\nendobj\n`;}const start=s.length;s+='xref\n0 3\n0000000000 65535 f \n'+offsets.slice(1).map(x=>String(x).padStart(10,'0')+' 00000 n \n').join('')+'trailer\n<< /Size 3 /Root 1 0 R >>\nstartxref\n'+start+'\n%%EOF\n';return Buffer.from(s);}
for(const[name,bytes,type]of [['PNG',technicalPng(),'image/png'],['PDF',technicalPdf(),'application/pdf'],['JPEG',fs.readFileSync(path.join(__dirname,'../../assets/public_landing/assets/phone.jpg')),'image/jpeg']])test('supported non-audio '+name+' classified and preserved at real boundary',async()=>{const h=harness();const result=await h.invoke(inline(bytes));assert.equal(result.code,200);assert.equal(h.calls.length,1);const sent=JSON.parse(h.calls[0].options.body).contents[0].parts[0].inlineData;assert.equal(sent.mimeType,type);assert.ok(Buffer.from(sent.data,'base64').equals(bytes));});
test('invalid non-audio and unknown binaries never forwarded',async()=>{for(const bytes of [technicalPng().subarray(0,-1),Buffer.concat([technicalPng(),original()]),Buffer.from('%PDF-1.4\nrandom fake %%EOF'),Buffer.from([255,216,255,217]),Buffer.from('RIFF0000WEBPfake'),Buffer.from('GIF89a fake')]){const h=harness();await h.invoke(inline(bytes,'image/png'));assert.equal(h.calls.length,0);}});
test('classified audio cache remains quota-bound; unclassified cache is never promoted',async()=>{const h=harness(),headers=await reservation(h);const request={...inline(prepend(['free'])),model:'models/gemini-2.5-flash'};assert.equal((await h.invoke(request,headers,'/v1beta/cachedContents')).code,200);assert.equal(h.calls.length,1);const data=h.db.data.get('providerResourceOwnership/'+resourceKey('A','cachedContents/r3'));assert.equal(data.binaryManifest[0].durationMs,4064);assert.equal((await h.invoke({cached_content:'cachedContents/r3'})).code,200);assert.equal(h.calls.length,2);await h.invoke({cachedContent:'cachedContents/r3'});assert.equal(h.calls.length,2);});

test('real valid ALAC fixture is unsupported before provider',async()=>{const h=harness();await h.invoke(inline(fs.readFileSync(path.join(__dirname,'fixtures/silence-4s-alac.m4a'))),await reservation(h));assert.equal(h.calls.length,0);});
test('ambiguous binary aliases and multiple part alternatives denied',async()=>{for(const part of [{inlineData:{data:wav().toString('base64')},inline_data:{data:original().toString('base64')}},{fileData:{fileUri:'https://generativelanguage.googleapis.com/v1beta/files/r3',file_uri:'https://generativelanguage.googleapis.com/v1beta/files/other'}}]){const h=harness();await h.invoke({contents:[{parts:[part]}]},await reservation(h));assert.equal(h.calls.length,0);}});
for(const budget of [null,1,5000])test('background production segment handler central classifier budget='+budget,async()=>{
 const vm=require('node:vm'),{createRequire}=require('node:module'),crypto=require('node:crypto');
 const file=path.resolve(__dirname,'../study_background_transcription_routes.js'),real=createRequire(file),db=database();
 const baseCollection=db.collection.bind(db);db.collection=name=>({doc:id=>{const ref=baseCollection(name).doc(id);ref.id=id;ref.collection=child=>db.collection(name+'/'+id+'/'+child);ref.set=async(v,opt)=>db.data.set(ref.path,opt?.merge?{...db.data.get(ref.path),...v}:v);return ref;}});
 const h={db},usage=budget===null?null:await reservation(h,budget),jobId='technical_job_123456';
 db.data.set('_study_background_transcription_jobs/'+jobId,{uid:'A',expectedSegments:1,usage});
 const secret='TECHNICAL_GRANT_SECRET_abcdefghijklmnopqrstuvwxyz',encoded=Buffer.from(JSON.stringify({scope:'study-background-transcription-v1',uid:'A',jobId,expectedSegments:1,exp:Date.now()+60000})).toString('base64url'),token=encoded+'.'+crypto.createHmac('sha256',secret).update(encoded).digest('base64url');
 const objects=new Map();const storage={key:(j,i,t)=>`transcription/${j}/${i}/${t}`,async put(k,b){objects.set(k,Buffer.from(b));},async get(k){return Buffer.from(objects.get(k));},async remove(k){objects.delete(k);}};
 let handler,calls=0;const bytes=prepend(['free']),expected=Buffer.from(bytes);
 const scope={module:{exports:{}},Buffer,FormData,Blob,AbortController,AbortSignal,Date,setTimeout,clearTimeout,setInterval:()=>({unref(){}}),process:{env:{MEDCASES_AUDIO_GRANT_SECRET:secret,OPENAI_API_KEY:'TECHNICAL_TEST_KEY_123456789'}},fetch:async(_u,opt)=>{calls++;assert.ok(Buffer.from(await opt.body.get('file').arrayBuffer()).equals(expected));return new Response('{"text":"TECHNICAL_TRANSCRIPT"}')},require:id=>id==='./transcription_temp_storage'?{createTranscriptionTempStorage:()=>storage}:id==='firebase-admin/app'?{getApps:()=>[{}]}:id==='firebase-admin/firestore'?{getFirestore:()=>db,Timestamp:{now:()=>123,fromMillis:ms=>ms}}:real(id)};
 vm.runInNewContext(fs.readFileSync(file,'utf8'),scope,{filename:file});const queue=scope.module.exports.registerStudyBackgroundTranscriptionRoutes({get(){},post(){},delete(){},put:(_p,...handlers)=>handler=handlers.at(-1)},{startWorker:false});
 const out=response();await handler({params:{jobId,index:'0'},headers:{authorization:'Study '+token,'x-medcases-audio-mime':'image/png'},body:bytes},out);
 assert.equal(calls,0,'upload acknowledgement cannot synchronously call provider');assert.equal(out.code,budget===null?403:202,JSON.stringify(out.body));assert.ok(bytes.every(x=>x===0));
 if(budget!==null){const jobRef=db.collection('_study_background_transcription_jobs').doc(jobId);await queue.process(jobRef,db.data.get(jobRef.path),jobRef.collection('segments').doc('0'));assert.equal(calls,budget===5000?1:0);const result=db.data.get(jobRef.path+'/segments/0');assert.equal(result.state,budget===5000?'done':'terminal_error');if(budget===5000)assert.equal(objects.size,0);}
 else assert.equal(objects.size,0,'unauthorized upload must never persist');
});
test('stored certificate changed during claim is denied at final provider boundary',async()=>{
 const h=harness(),usage=await reservation(h),p=await classifyBinary(wav()),key='providerResourceOwnership/'+resourceKey('A','files/mutable');
 h.db.data.set(key,{uid:'A',name:'files/mutable',usage,executionIndex:0,binaryManifest:[serializeClassification(p)]});
 const originalTransaction=h.db.runTransaction.bind(h.db);h.db.runTransaction=async fn=>{const result=await originalTransaction(fn);const old=h.db.data.get(key);h.db.data.set(key,{...old,binaryManifest:[{...old.binaryManifest[0],sha256:'0'.repeat(64)}]});return result;};
 await h.invoke({contents:[{parts:[{fileData:{fileUri:'https://generativelanguage.googleapis.com/v1beta/files/mutable'}}]}]});assert.equal(h.calls.length,0);
});
test('wrong image MIME cannot change audio identity even with sufficient reservation',async()=>{const h=harness();assert.equal((await h.invoke(inline(prepend(['free']),'image/png'),await reservation(h))).code,200);assert.equal(h.calls.length,1);assert.equal(JSON.parse(h.calls[0].options.body).contents[0].parts[0].inlineData.mimeType,'audio/mp4');});
test('preparation stages bind once; countTokens then execution never double-charges duration',async()=>{
 const h=harness(),headers=await reservation(h,4000),body=inline(wav());
 assert.equal((await h.invoke(body,headers,'/v1beta/models/gemini-2.5-flash:countTokens')).code,200);assert.equal(h.calls.length,1);
 assert.equal((await h.invoke(body,headers,'/v1beta/models/gemini-2.5-flash:countTokens')).code,409);assert.equal(h.calls.length,1);
 assert.equal((await h.invoke(body,headers)).code,200);assert.equal(h.calls.length,2);
 const op=[...h.db.data.values()].find(x=>x.authorizedMediaMs);assert.equal(op.authorizedMediaMs,4000);assert.equal(op.chargedMs,4000);
});
test('parallel preparatory slots cannot overspend or later substitute media',async()=>{
 const h=harness(),headers=await reservation(h,4000,2),body=inline(wav());const route='/v1beta/models/gemini-2.5-flash:countTokens';
 const results=await Promise.all([h.invoke(body,headers,route),h.invoke(body,{...headers,'x-medcases-execution-index':'1'},route)]);assert.equal(results.filter(x=>x.code===200).length,1);assert.equal(h.calls.length,1);
 const winner=results[0].code===200?0:1;await h.invoke(inline(wav(2000)),{...headers,'x-medcases-execution-index':String(winner)});assert.equal(h.calls.length,1);
 const owner=new MonthlyUsageOwner({db:h.db});await assert.rejects(owner.failBeforeExecution('A',{id:headers['x-medcases-usage-reservation'],attempt:headers['x-medcases-usage-attempt']}));
});
test('real Express HTTP parser and route enforce residual fixture before provider',async()=>{
 const express=require('express'),http=require('node:http');
 for(const budget of [null,1,5000]){
  const app=express(),db=database(),headers=budget===null?{}:await reservation({db},budget);let calls=0;
  registerProviderTransport({app,express,authenticate:(req,_res,next)=>{req.auth={uid:'A'};next()},limiter:(_q,_s,n)=>n(),db,keyProvider:()=> 'TECHNICAL_TEST_KEY',fetchImpl:async()=>{calls++;return new Response('{"candidates":[]}',{headers:{'content-type':'application/json'}})}});
  const server=http.createServer(app);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  try{const result=await fetch(`http://127.0.0.1:${server.address().port}/api/ai/provider/v1beta/models/gemini-2.5-flash:generateContent`,{method:'POST',headers:{...headers,'content-type':'application/json'},body:JSON.stringify(inline(prepend(['free'])))});await result.text();assert.equal(calls,budget===5000?1:0);assert.equal(result.status,budget===5000?200:502);}finally{await new Promise(resolve=>server.close(resolve));}
 }
});
test('stored receipt/certificate field order cannot change identity',async()=>{
 const h=harness(),usage=await reservation(h),p=await classifyBinary(wav()),name='files/ordered';
 h.db.data.set('providerResourceOwnership/'+resourceKey('A',name),{uid:'A',name,usage:Object.fromEntries(Object.entries(usage).reverse()),executionIndex:0,binaryManifest:[serializeClassification(p)]});
 const collection=h.db.collection.bind(h.db);let reads=0;h.db.collection=c=>({doc:id=>{const ref=collection(c).doc(id),get=ref.get;ref.get=async()=>{const snap=await get();if(c==='providerResourceOwnership'&&snap.exists&&++reads%2===0)return {exists:true,data:()=>Object.fromEntries(Object.entries(snap.data()).reverse())};return snap};return ref;}});
 assert.equal((await h.invoke({contents:[{parts:[{fileData:{fileUri:'https://generativelanguage.googleapis.com/v1beta/'+name}}]}]},usage)).code,200);assert.equal(h.calls.length,1);
});
