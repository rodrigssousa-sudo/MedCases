'use strict';
const {Worker}=require('node:worker_threads'),crypto=require('node:crypto'),path=require('node:path');
const {MAX_BYTES,MAX_DURATION_MS}=require('./audio_media_structure');
const TIMEOUT_MS=10000,proofs=new WeakSet();let active=0;
async function inspectAudio(bytes){
 if(!Buffer.isBuffer(bytes)||!bytes.length||bytes.length>MAX_BYTES)throw Error('MEDIA_SIZE_INVALID');
 if(active>=2)throw Error('MEDIA_INSPECTOR_BUSY');active++;
 const sha256=crypto.createHash('sha256').update(bytes).digest('hex');let worker,timer;
 try{return await new Promise((resolve,reject)=>{
  worker=new Worker(path.join(__dirname,'audio_media_worker.js'),{workerData:bytes,resourceLimits:{maxOldGenerationSizeMb:64,maxYoungGenerationSizeMb:16,stackSizeMb:2}});
  timer=setTimeout(()=>{worker.terminate();reject(Error('MEDIA_INSPECTION_TIMEOUT'));},TIMEOUT_MS);
  worker.once('error',()=>reject(Error('MEDIA_INSPECTION_FAILED')));worker.once('exit',()=>reject(Error('MEDIA_INSPECTION_FAILED')));
  worker.once('message',v=>{if(v.error||!Number.isSafeInteger(v.durationMs)||v.durationMs<=0||v.durationMs>MAX_DURATION_MS)return reject(Error('MEDIA_INVALID_OR_UNSUPPORTED'));const p=Object.freeze({durationMs:v.durationMs,sha256});proofs.add(p);resolve(p);});
 });}finally{clearTimeout(timer);if(worker)await worker.terminate();active--;}
}
function combineProofs(items,requestHash){if(!items.length||items.some(x=>!proofs.has(x))||! /^[a-f0-9]{64}$/.test(requestHash))throw Error('MEDIA_PROOF_REQUIRED');const p=Object.freeze({durationMs:items.reduce((a,b)=>a+b.durationMs,0),sha256:crypto.createHash('sha256').update(items.map(x=>x.sha256).join('\n')).digest('hex'),requestHash});proofs.add(p);return p;}
function validProof(p){return proofs.has(p)&&Number.isSafeInteger(p.durationMs)&&p.durationMs>0&&/^[a-f0-9]{64}$/.test(p.sha256)&&/^[a-f0-9]{64}$/.test(p.requestHash);}
// Stored records are writable only by these server routes, never client input.
function storedProof(v){if(!v||!Number.isSafeInteger(v.durationMs)||v.durationMs<=0||v.durationMs>MAX_DURATION_MS||! /^[a-f0-9]{64}$/.test(v.sha256))throw Error('MEDIA_BINDING_REQUIRED');const p=Object.freeze({durationMs:v.durationMs,sha256:v.sha256});proofs.add(p);return p;}
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
module.exports={inspectAudio,combineProofs,validProof,storedProof,digest,MAX_BYTES,MAX_DURATION_MS,TIMEOUT_MS};
