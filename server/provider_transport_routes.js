const {MonthlyUsageOwner}=require('./monthly_usage_owner');
'use strict';
const crypto=require('node:crypto');
const {assertUsageReservation,containsAudio,usageReceipt}=require('./usage_reservation_guard');
const {Readable,Transform}=require('node:stream');
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
const resourceKey=(uid,name)=>crypto.createHash('sha256').update(`${uid}\n${name}`).digest('hex');
function registerProviderTransport({app,express,authenticate,limiter,db,keyProvider,fetchImpl=fetch}){
 // Registered before the global 512kb JSON parser; uses the existing app/auth.
 const record=(uid,name)=>db.collection('providerResourceOwnership').doc(resourceKey(uid,name));
 const owns=async(uid,name)=>{const s=await record(uid,name).get();
  if(!s.exists||s.data().uid!==uid)return false;
  // Resource cleanup/read remains owner-bound after terminal quota settlement.
  return true;};
 async function checkReferences(uid,value,bindings){
  if(!value||typeof value!=='object')return;
  for(const [key,item]of Object.entries(value)){
   if(['fileUri','file_uri'].includes(key)){
    const u=new URL(item);if(u.origin!==HOST||!/^\/v1beta\/files\/[\w-]+$/.test(u.pathname)||!await owns(uid,u.pathname.slice(8)))throw Error('RESOURCE_NOT_OWNED');
    const bound=await record(uid,u.pathname.slice(8)).get();if(bound.data().usage)bindings.push(bound.data().usage);
   }else if(key==='cachedContent') {if(typeof item!=='string'||!await owns(uid,item))throw Error('RESOURCE_NOT_OWNED');const bound=await record(uid,item).get();if(bound.data().usage)bindings.push(bound.data().usage);}
   else if(item&&typeof item==='object')await checkReferences(uid,item,bindings);
  }
 }
 const parse=express.json({limit:'28mb'});
 app.use('/api/ai/provider',authenticate,limiter,async(req,res)=>{
  const uid=req.auth?.uid;if(!uid)return res.status(401).json({error:'AUTH_REQUIRED'});
  const key=keyProvider();if(!key)return res.status(503).json({error:'PROVIDER_NOT_CONFIGURED'});
  const abort=new AbortController();const timeout=setTimeout(()=>abort.abort(),15*60*1000);
  res.on('close',()=>abort.abort());
  let execution=null;
  try{
   let target,body,usage=null;const headers={};
   const ticket=/^\/upload-ticket\/([a-f0-9-]+)$/.exec(req.path);
   if(ticket){
    if(req.method!=='POST')return res.status(405).end();
    const snapshot=await db.collection('providerUploadTickets').doc(ticket[1]).get();
    const data=snapshot.exists?snapshot.data():null;
    if(!data||data.uid!==uid||data.expiresAt<Date.now())return res.status(403).json({error:'UPLOAD_NOT_OWNED'});
    if(data.usage)usage=await assertUsageReservation(db,uid,data.usage);
    target=new URL(data.url);if(target.origin!==HOST||!target.pathname.startsWith('/upload/'))throw Error('INVALID_UPLOAD_TARGET');
    let count=0;const max=2*1024*1024*1024;
    const bounded=new Transform({transform(chunk,_,cb){count+=chunk.length;cb(count>max?Error('UPLOAD_TOO_LARGE'):null,chunk);}});
    req.pipe(bounded);body=bounded;
    for(const h of ['content-type','content-length','x-goog-upload-offset','x-goog-upload-command'])if(req.headers[h])headers[h]=req.headers[h];
   }else{
    if(!allowedPath(req.path,req.method))return res.status(403).json({error:'PROVIDER_OPERATION_NOT_ALLOWED'});
    await new Promise((resolve,reject)=>parse(req,res,e=>e?reject(e):resolve()));
    if(/^\/v1beta\/(files|cachedContents)\//.test(req.path)&&!await owns(uid,req.path.slice(8)))return res.status(403).json({error:'RESOURCE_NOT_OWNED'});
    if(containsAudio(req.body)||String(req.headers['x-goog-upload-header-content-type']||'').startsWith('audio/')||req.headers['x-medcases-usage-reservation'])
      usage=await assertUsageReservation(db,uid,req.headers);
    const bindings=[];await checkReferences(uid,req.body,bindings);
    for(const bound of bindings){
      if(usage&&JSON.stringify(usage)!==JSON.stringify(bound))throw Error('USAGE_BINDING_MISMATCH');
      usage=await assertUsageReservation(db,uid,bound);
    }
    if(req.path==='/v1beta/cachedContents'&&req.body?.model!=='models/gemini-2.5-flash')return res.status(403).json({error:'PROVIDER_MODEL_NOT_ALLOWED'});
    target=new URL(req.path,HOST);if(req.query.alt==='sse')target.searchParams.set('alt','sse');
    if(req.method==='POST')body=JSON.stringify(req.body??{});
    headers['content-type']='application/json';
    for(const h of ['x-goog-upload-protocol','x-goog-upload-command','x-goog-upload-header-content-length','x-goog-upload-header-content-type'])if(req.headers[h])headers[h]=req.headers[h];
   }
   headers['x-goog-api-key']=key;
   if(usage && /:(generateContent|streamGenerateContent)$/.test(req.path)){
    const owner=new MonthlyUsageOwner({db}),receipt=usageReceipt(usage);
    const index=Number(req.headers['x-medcases-execution-index']||0);
    const claim=await owner.claimExecution(uid,receipt,index);
    if(!claim.claimed)return res.status(409).json({error:'EXECUTION_ALREADY_CLAIMED',state:claim.state});
    execution={owner,receipt,index};
   }
   const response=await fetchImpl(target,{method:req.method,headers,body,duplex:'half',signal:abort.signal,redirect:'error'});
   res.status(response.status);
   const uploadUrl=response.headers.get('x-goog-upload-url');
   if(uploadUrl&&response.ok){
    const u=new URL(uploadUrl);if(u.origin!==HOST||!u.pathname.startsWith('/upload/'))throw Error('INVALID_UPLOAD_TARGET');
    const id=crypto.randomUUID();await db.collection('providerUploadTickets').doc(id).set({uid,url:uploadUrl,usage,expiresAt:Date.now()+30*60*1000});
    // Relative API URL: caller binds it to the configured MedCases origin.
    res.setHeader('x-goog-upload-url',`/api/ai/provider/upload-ticket/${id}`);
   }
   if(!response.ok){await response.body?.cancel();return res.status(response.status).json({error:'PROVIDER_REQUEST_REJECTED'});}
   const type=response.headers.get('content-type')||'application/json';res.setHeader('Content-Type',type);res.setHeader('Cache-Control','no-store');
   if(type.includes('text/event-stream'))return await pipeline(Readable.fromWeb(response.body),res);
   const text=await response.text();
   if(response.ok){try{const payload=JSON.parse(text);const name=payload.file?.name??payload.name;if(typeof name==='string'&&/^(files|cachedContents)\/[\w-]+$/.test(name))await record(uid,name).set({uid,name,usage,createdAt:Date.now()});}catch(e){if(e instanceof SyntaxError){}else throw e;}}
   res.send(text);
  }catch(_){if(!res.headersSent)res.status(502).json({error:'PROVIDER_TRANSPORT_FAILED'});else res.end();}
  finally{clearTimeout(timeout);if(execution)await execution.owner.completeExecution(uid,execution.receipt,execution.index).catch(()=>{});}
 });
}
module.exports={allowedPath,resourceKey,registerProviderTransport};
