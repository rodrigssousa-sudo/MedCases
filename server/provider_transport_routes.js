const {combineProofs,digest,MAX_BYTES}=require('./audio_media_budget');
const {classifyBinary,assertBinaryBinding,serializeClassification,readStoredClassification}=require('./binary_media_classifier');
const {MonthlyUsageOwner}=require('./monthly_usage_owner');
'use strict';
const crypto=require('node:crypto');
const {assertUsageReservation,usageReceipt}=require('./usage_reservation_guard');
const {Readable}=require('node:stream');
const {pipeline}=require('node:stream/promises');
const HOST='https://generativelanguage.googleapis.com';
// This compatibility route serves the existing Flash client only. Paid model
// routing remains in the existing entitlement-aware gateway.
const models=new Set(['gemini-2.5-flash']);
function allowedPath(path,method){
 const model=/^\/v1beta\/models\/([^/:]+):(generateContent|streamGenerateContent|countTokens)$/.exec(path);
 if(model)return method==='POST'&&models.has(model[1]);
 if(path==='/v1beta/cachedContents'||path==='/upload/v1beta/files')return method==='POST';
 return /^\/v1beta\/(files|cachedContents)\/[a-zA-Z0-9_-]+$/.test(path)&&['GET','DELETE'].includes(method);
}
const canonical=value=>Array.isArray(value)?value.map(canonical):value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k])])):value;
const resourceDigest=value=>digest(JSON.stringify(canonical(value)));
const resourceKey=(uid,name)=>crypto.createHash('sha256').update(`${uid}\n${name}`).digest('hex');
function registerProviderTransport({app,express,authenticate,limiter,db,keyProvider,fetchImpl=fetch}){
 // Registered before the global 512kb JSON parser; uses the existing app/auth.
 const record=(uid,name)=>db.collection('providerResourceOwnership').doc(resourceKey(uid,name));
 const owns=async(uid,name)=>{const s=await record(uid,name).get();
  if(!s.exists||s.data().uid!==uid)return false;
  // Resource cleanup/read remains owner-bound after terminal quota settlement.
  return true;};
 async function checkReferences(uid,value,bindings,media,manifest,resourceChecks,index){
  if(!value||typeof value!=='object')return;
  for(const [key,item]of Object.entries(value)){
   let name=null;
   if(['fileUri','file_uri'].includes(key)){
    const u=new URL(item);if(u.origin!==HOST||u.search||u.hash||!/^\/v1beta\/files\/[\w-]+$/.test(u.pathname))throw Error('RESOURCE_NOT_OWNED');name=u.pathname.slice(8);
   }else if(['cachedContent','cached_content'].includes(key)){if(typeof item!=='string'||!/^cachedContents\/[\w-]+$/.test(item))throw Error('RESOURCE_NOT_OWNED');name=item;}
   if(name){
    const bound=await record(uid,name).get(),data=bound.exists?bound.data():null;
    if(!data||data.uid!==uid||!Array.isArray(data.binaryManifest)||data.binaryManifest.length>16)throw Error('RESOURCE_CLASSIFICATION_REQUIRED');
    const proofs=data.binaryManifest.map(readStoredClassification);
    if(name.startsWith('files/')&&proofs.length!==1)throw Error('RESOURCE_CLASSIFICATION_REQUIRED');
    for(const proof of proofs){manifest.push(proof);if(proof.audioProof){if(!data.usage||data.executionIndex!==index)throw Error('RESOURCE_BINDING_REQUIRED');media.push(proof.audioProof);}}
    if(data.usage)bindings.push(data.usage);
    resourceChecks.push({name,hash:resourceDigest(data)});
    if(name.startsWith('files/')){delete value.mime_type;value.mimeType=proofs[0].mimeType;}
   }else if(item&&typeof item==='object')await checkReferences(uid,item,bindings,media,manifest,resourceChecks,index);
  }
 }
 const parse=express.json({limit:'28mb'});
 app.use('/api/ai/provider',authenticate,limiter,async(req,res)=>{
  const replayCheck=/:(generateContent|streamGenerateContent)$/.test(req.path);
  const uid=req.auth?.uid;if(!uid)return res.status(401).json({error:'AUTH_REQUIRED'});
  const key=keyProvider();if(!key)return res.status(503).json({error:'PROVIDER_NOT_CONFIGURED'});
  const abort=new AbortController();const timeout=setTimeout(()=>abort.abort(),15*60*1000);
  res.on('close',()=>abort.abort());
  let execution=null;
  try{
   let target,body,usage=null;const headers={},media=[],manifest=[],binaryChecks=[],resourceChecks=[];let mediaBinding=null;let index=Number(req.headers['x-medcases-execution-index']||0);if(!Number.isSafeInteger(index)||index<0)throw Error('INVALID_EXECUTION');const inspectionStarted=Date.now();
   async function inspect(bytes){if(manifest.length>=16||Date.now()-inspectionStarted>15000)throw Error('MEDIA_REQUEST_LIMIT');return classifyBinary(bytes);}
   async function inlineMedia(value){
    if(!value||typeof value!=='object')return;
    if(['inlineData','inline_data','fileData','file_data'].filter(k=>k in value).length>1||('fileUri' in value&&'file_uri' in value)||('cachedContent' in value&&'cached_content' in value))throw Error('AMBIGUOUS_BINARY_RESOURCE');
    for(const [k,v]of Object.entries(value)){
     if(['inlineData','inline_data'].includes(k)){
      if(typeof v?.data!=='string'||v.data.length>Math.ceil(MAX_BYTES/3)*4||! /^[A-Za-z0-9+/]*={0,2}$/.test(v.data))throw Error('MEDIA_INVALID');
      const bytes=Buffer.from(v.data,'base64');v.data=bytes.toString('base64');
      const proof=await inspect(bytes);assertBinaryBinding(proof,bytes);
      delete v.mime_type;v.mimeType=proof.mimeType;
      manifest.push(proof);binaryChecks.push({proof,bytes,encoded:v.data});
      if(proof.audioProof)media.push(proof.audioProof);
     }else if(v&&typeof v==='object')await inlineMedia(v);
    }
   }
   const ticket=/^\/upload-ticket\/([a-f0-9-]+)$/.exec(req.path);
   if(ticket){
    if(req.method!=='POST')return res.status(405).end();
    const snapshot=await db.collection('providerUploadTickets').doc(ticket[1]).get();
    const data=snapshot.exists?snapshot.data():null;
    if(!data||data.uid!==uid||data.expiresAt<Date.now())return res.status(403).json({error:'UPLOAD_NOT_OWNED'});
    if(data.usage)usage=await assertUsageReservation(db,uid,data.usage);index=data.executionIndex??0;
    target=new URL(data.url);if(target.origin!==HOST||!target.pathname.startsWith('/upload/'))throw Error('INVALID_UPLOAD_TARGET');
    if(String(req.headers['x-goog-upload-offset']||'0')!=='0'||String(req.headers['x-goog-upload-command']||'').replace(/\s/g,'')!=='upload,finalize')throw Error('UPLOAD_REQUIRES_COMPLETE_MEDIA');
    let count=0;const chunks=[];const readDeadline=setTimeout(()=>req.destroy(),30000);
    try{for await(const chunk of req){count+=chunk.length;if(count>MAX_BYTES)throw Error('UPLOAD_TOO_LARGE');chunks.push(chunk);}}finally{clearTimeout(readDeadline);}
    body=Buffer.concat(chunks);
    const proof=await inspect(body);assertBinaryBinding(proof,body);manifest.push(proof);binaryChecks.push({proof,bytes:body});
    headers['content-type']=proof.mimeType;
    if(proof.audioProof){if(!usage)throw Error('SERVER_QUOTA_RESERVATION_REQUIRED');media.push(proof.audioProof);}
    headers['content-length']=String(body.length);headers['x-goog-upload-offset']='0';headers['x-goog-upload-command']='upload, finalize';
   }else{
    if(!allowedPath(req.path,req.method))return res.status(403).json({error:'PROVIDER_OPERATION_NOT_ALLOWED'});
    await new Promise((resolve,reject)=>parse(req,res,e=>e?reject(e):resolve()));
    // Freeze the forwarded logical request before any asynchronous inspection.
    req={...req,path:req.path,method:req.method,query:req.query,headers:req.headers,body:JSON.parse(JSON.stringify(req.body??{}))};
    if(/^\/v1beta\/(files|cachedContents)\//.test(req.path)&&!await owns(uid,req.path.slice(8)))return res.status(403).json({error:'RESOURCE_NOT_OWNED'});
    if(req.headers['x-medcases-usage-reservation'])
      usage=await assertUsageReservation(db,uid,req.headers,'transcription',replayCheck);
    await inlineMedia(req.body);
    if(media.length&&!usage)usage=await assertUsageReservation(db,uid,req.headers,'transcription',replayCheck);
    const bindings=[];await checkReferences(uid,req.body,bindings,media,manifest,resourceChecks,index);
    for(const bound of bindings){
      if(usage&&(usageReceipt(usage).id!==usageReceipt(bound).id||usageReceipt(usage).attempt!==usageReceipt(bound).attempt))throw Error('USAGE_BINDING_MISMATCH');
      usage=await assertUsageReservation(db,uid,bound,'transcription',replayCheck);
    }
    if(req.path==='/v1beta/cachedContents'&&req.body?.model!=='models/gemini-2.5-flash')return res.status(403).json({error:'PROVIDER_MODEL_NOT_ALLOWED'});
    target=new URL(req.path,HOST);if(req.query.alt==='sse')target.searchParams.set('alt','sse');
    if(req.method==='POST')body=JSON.stringify(req.body??{});
    headers['content-type']='application/json';
    for(const h of ['x-goog-upload-protocol','x-goog-upload-command','x-goog-upload-header-content-length','x-goog-upload-header-content-type'])if(req.headers[h])headers[h]=req.headers[h];
   }
   if(manifest.length>16)throw Error('MEDIA_REQUEST_LIMIT');
   if(media.length){
    mediaBinding=combineProofs(media,digest(Buffer.isBuffer(body)?body:Buffer.from(JSON.stringify({path:req.path,body:req.body}))));
    const snap=await db.collection('usageReservations').doc(usageReceipt(usage).id).get();
    if(mediaBinding.durationMs>snap.data().maximumMs)throw Error('MEDIA_EXCEEDS_RESERVED_BUDGET');
   }
   if(req.path==='/upload/v1beta/files'){
    const size=Number(req.headers['x-goog-upload-header-content-length']);
    if(!Number.isSafeInteger(size)||size<=0||size>MAX_BYTES)throw Error('MEDIA_SIZE_INVALID');
   }
   headers['x-goog-api-key']=key;
   if(usage && /:(generateContent|streamGenerateContent)$/.test(req.path)){
    const owner=new MonthlyUsageOwner({db}),receipt=usageReceipt(usage);
    const claim=await owner.claimExecution(uid,receipt,index,mediaBinding);
    if(!claim.claimed)return res.status(409).json({error:'EXECUTION_ALREADY_CLAIMED',state:claim.state});
    execution={owner,receipt,index};
   }
   if(mediaBinding&&!replayCheck){
    const stage=ticket?'upload':req.path==='/v1beta/cachedContents'?'cache':req.path.endsWith(':countTokens')?'countTokens':null;
    if(!stage)throw Error('BINARY_OPERATION_NOT_SUPPORTED');
    const claim=await new MonthlyUsageOwner({db}).authorizeMediaStage(uid,usageReceipt(usage),index,mediaBinding,stage);
    if(!claim.claimed)return res.status(409).json({error:'MEDIA_STAGE_ALREADY_CLAIMED'});
   }
   // Stored provider files are immutable; recheck the server-owned certificate
   // and ownership after all awaits, then verify exact submitted byte hashes.
   for(const check of resourceChecks){const fresh=await record(uid,check.name).get();if(!fresh.exists||resourceDigest(fresh.data())!==check.hash)throw Error('RESOURCE_BINDING_CHANGED');}
   if(Buffer.isBuffer(body)){for(const check of binaryChecks)assertBinaryBinding(check.proof,body);}
   else if(body){
    const sent=[];function collect(v){if(!v||typeof v!=='object')return;for(const[k,x]of Object.entries(v)){if(['inlineData','inline_data'].includes(k))sent.push(Buffer.from(x.data,'base64'));else collect(x);}}
    collect(JSON.parse(body));if(sent.length!==binaryChecks.length)throw Error('MEDIA_BINDING_COUNT_MISMATCH');
    sent.forEach((bytes,i)=>assertBinaryBinding(binaryChecks[i].proof,bytes));
   }
   if(mediaBinding&&digest(Buffer.isBuffer(body)?body:JSON.stringify({path:req.path,body:JSON.parse(body)}))!==mediaBinding.requestHash)throw Error('MEDIA_REQUEST_BINDING_MISMATCH');
   const response=await fetchImpl(target,{method:req.method,headers,body,duplex:'half',signal:abort.signal,redirect:'error'});
   res.status(response.status);
   const uploadUrl=response.headers.get('x-goog-upload-url');
   if(uploadUrl&&response.ok){
    const u=new URL(uploadUrl);if(u.origin!==HOST||!u.pathname.startsWith('/upload/'))throw Error('INVALID_UPLOAD_TARGET');
    const id=crypto.randomUUID();await db.collection('providerUploadTickets').doc(id).set({uid,url:uploadUrl,usage,executionIndex:index,contentType:String(req.headers['x-goog-upload-header-content-type']||''),expiresAt:Date.now()+30*60*1000});
    // Relative API URL: caller binds it to the configured MedCases origin.
    res.setHeader('x-goog-upload-url',`/api/ai/provider/upload-ticket/${id}`);
   }
   if(!response.ok){await response.body?.cancel();return res.status(response.status).json({error:'PROVIDER_REQUEST_REJECTED'});}
   const type=response.headers.get('content-type')||'application/json';res.setHeader('Content-Type',type);res.setHeader('Cache-Control','no-store');
   if(type.includes('text/event-stream'))return await pipeline(Readable.fromWeb(response.body),res);
   const text=await response.text();
   if(response.ok&&req.method==='POST'){try{const payload=JSON.parse(text);const name=payload.file?.name??payload.name;if(typeof name==='string'&&/^(files|cachedContents)\/[\w-]+$/.test(name))await record(uid,name).set({uid,name,usage,executionIndex:index,binaryManifest:manifest.map(serializeClassification),media:mediaBinding?{durationMs:mediaBinding.durationMs,sha256:mediaBinding.sha256}:null,createdAt:Date.now()});}catch(e){if(e instanceof SyntaxError){}else throw e;}}
   res.send(text);
  }catch(_){if(!res.headersSent)res.status(502).json({error:'PROVIDER_TRANSPORT_FAILED'});else res.end();}
  finally{clearTimeout(timeout);if(execution)await execution.owner.completeExecution(uid,execution.receipt,execution.index).catch(()=>{});}
 });
}
module.exports={allowedPath,resourceKey,registerProviderTransport};
