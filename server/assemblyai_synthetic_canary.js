'use strict';
// Explicit synthetic-only harness. Never accepts arbitrary/user recording paths.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {Timestamp}=require('firebase-admin/firestore');
const {AssemblyAiProvider}=require('./assemblyai_provider');
const {MedCasesTranscriptionService}=require('./medcases_transcription_service');
const privateEnv='/private/tmp/medcases-assemblyai-private/runtime.env';
const line=fs.readFileSync(privateEnv,'utf8').split(/\r?\n/).find(x=>x.startsWith('ASSEMBLYAI_API_KEY='));
const apiKey=line?.slice(line.indexOf('=')+1).trim().replace(/^['"]|['"]$/g,'');
const provider=new AssemblyAiProvider({apiKey});
const service=new MedCasesTranscriptionService({providers:{assemblyai:provider}});
const root='/private/tmp/medcases-assemblyai-synthetic/results';fs.mkdirSync(root,{recursive:true,mode:0o700});
function ref(name) {
  const file=path.join(root,name+'.json');fs.mkdirSync(path.dirname(file),{recursive:true,mode:0o700});
  return {async get(){return {data:()=>JSON.parse(fs.readFileSync(file,'utf8'))};},
    async set(v,{merge=false}={}) {const prior=merge&&fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{};
      fs.writeFileSync(file+'.tmp',JSON.stringify({...prior,...v}),{mode:0o600});fs.renameSync(file+'.tmp',file);},
    collection(c){return {doc:id=>ref(name+'/'+c+'/'+id)};}};
}
(async()=>{
 const durations=process.argv.slice(2).map(Number);if(!durations.length||durations.some(v=>![15,30,60,300,900,1800,3600].includes(v)))throw Error('SYNTHETIC_DURATION_REQUIRED');
 for(const seconds of durations) {
  const input=`/private/tmp/medcases-assemblyai-synthetic/synthetic-${seconds}s.wav`;
  const resultRef=ref(`${seconds}s`),resultPath=path.join(root,`${seconds}s.json`);
  if(fs.existsSync(resultPath)) {console.log(JSON.stringify({seconds,state:'EXISTING_RESULT_NOT_RESUBMITTED'}));continue;}
  const start=Date.now(),job={provider:'assemblyai',mode:'lecture',locale:'mixed',ownerUid:'synthetic-local-only',sessionId:`synthetic-${seconds}s`};
  await resultRef.set({state:'queued',createdAt:Timestamp.now()});
  let value;
  do {
   value=await service.advance({job,ref:resultRef,readAudio:async()=>fs.readFileSync(input)});
   if(['done','terminal_error','retryable_error'].includes(value.state))break;
   if(Date.now()-start>20*60000)throw Error('CANARY_DEADLINE');
   await new Promise(r=>setTimeout(r,3000));
  } while(true);
  const metrics={seconds,bytes:fs.statSync(input).size,totalMs:Date.now()-start,state:value.state,
    transcriptDurable:value.state==='done'&&Boolean(value.transcript),utteranceCount:value.utteranceCount || 0,
    providerIdHash:value.providerTranscriptId?crypto.createHash('sha256').update(value.providerTranscriptId).digest('hex').slice(0,12):null,
    errorCategory:value.errorCategory || null,storage:'LOCAL_DURABLE_TEST_ADAPTER_NOT_S3_FIRESTORE'};
  if(value.state==='done'){
    const utterances=[];for(let i=0;i<value.utterancePages;i++)utterances.push(...JSON.parse(fs.readFileSync(path.join(root,`${seconds}s/utterances/${i}.json`))).items);
    metrics.speakerCount=new Set(utterances.map(v=>v.speakerLabel)).size;
    metrics.timestampsPresent=utterances.every(v=>Number.isFinite(v.startMs)&&Number.isFinite(v.endMs));
    metrics.utterancesOrdered=utterances.every((v,i)=>!i||v.startMs>=utterances[i-1].startMs);
    await provider.remove(value.providerTranscriptId);metrics.providerDeleteRequested=true;
  }
  fs.writeFileSync(path.join(root,`${seconds}s.metrics.json`),JSON.stringify(metrics,null,2));console.log(JSON.stringify(metrics));
  if(value.state!=='done')process.exit(2);
 }
})().catch(error=>{console.error(JSON.stringify({code:error.code || error.message || 'CANARY_FAILED',httpStatus:error.httpStatus || null}));process.exitCode=1;});
