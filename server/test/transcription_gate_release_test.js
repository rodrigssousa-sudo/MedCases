'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const crypto=require('node:crypto'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {createRequire}=require('node:module');
const {MonthlyUsageOwner}=require('../monthly_usage_owner');
const {registerMonthlyUsageRoutes}=require('../monthly_usage_routes');
const {providerGateError,selectedProvider}=require('../transcription_profiles');
const hash=v=>crypto.createHash('sha256').update(v).digest('hex');
function database(){
 const rows=new Map([['users/owner',{plan:'premium'}],['users/free',{plan:'free'}]]);let tail=Promise.resolve();
 const snapshot=(p)=>({exists:rows.has(p),data:()=>structuredClone(rows.get(p)),id:p.split('/').at(-1)});
 function collection(p,filters=[],limit=Infinity){return {doc:id=>ref(`${p}/${id}`),where:(f,o,v)=>collection(p,[...filters,[f,v]],limit),limit:n=>collection(p,filters,n),async get(){return {docs:[...rows].filter(([k,v])=>k.startsWith(p+'/')&&!k.slice(p.length+1).includes('/')&&filters.every(([f,x])=>v[f]===x)).slice(0,limit).map(([k])=>({...snapshot(k),ref:ref(k)}))};}};}
 function ref(p){return {path:p,id:p.split('/').at(-1),collection:n=>collection(p+'/'+n),get:async()=>snapshot(p)};}
 return {rows,collection,runTransaction(fn){const next=tail.then(async()=>{const writes=[];const result=await fn({get:r=>r.get(),set:(r,v,o)=>writes.push([r.path,structuredClone(v),o])});for(const [p,v,o]of writes)rows.set(p,o?.merge?{...rows.get(p),...v}:v);return result;});tail=next.catch(()=>{});return next;}};
}
function environment(t){const keys=['ASSEMBLYAI_TRANSCRIPTION_ENABLED','ASSEMBLYAI_CLINICAL_PHI_APPROVED','ASSEMBLYAI_SYNTHETIC_OWNER_UIDS','ASSEMBLYAI_API_KEY'];const old=Object.fromEntries(keys.map(k=>[k,process.env[k]]));Object.assign(process.env,{ASSEMBLYAI_TRANSCRIPTION_ENABLED:'true',ASSEMBLYAI_CLINICAL_PHI_APPROVED:'false',ASSEMBLYAI_SYNTHETIC_OWNER_UIDS:'synthetic-only',ASSEMBLYAI_API_KEY:'test-only'});t.after(()=>{for(const k of keys)if(old[k]===undefined)delete process.env[k];else process.env[k]=old[k];});}
function response(){return {code:200,status(n){this.code=n;return this;},setHeader(){},json(body){this.body=body;return this;}};}
function usageRoutes(db){const routes=new Map();registerMonthlyUsageRoutes({app:{post(p,...args){routes.set(p,args.at(-1));}},authenticate(){},limiter(){},db});return routes;}
const request=(operationId,maximumMs=94547)=>({operationId,maximumMs,kinds:['transcription']});
const headers=r=>({'x-medcases-usage-reservation':r.id,'x-medcases-usage-attempt':r.attempt});
const jobPath=r=>'_study_background_transcription_jobs/'+hash(JSON.stringify(headers(r)));
function jobRoutes(db,{verify=async()=>({uid:'owner'}),allowed=false}={}){
 const file=path.resolve(__dirname,'../study_background_transcription_routes.js'),real=createRequire(file),routes=new Map();
 const scope={module:{exports:{}},Buffer,URL,FormData,Blob,console,process:{env:{...process.env,MEDCASES_AUDIO_GRANT_SECRET:'s'.repeat(40),ASSEMBLYAI_TRANSCRIPTION_ENABLED:'true',ASSEMBLYAI_API_KEY:'test-only',ASSEMBLYAI_SYNTHETIC_OWNER_UIDS:allowed?'owner':'synthetic-only',ASSEMBLYAI_CLINICAL_PHI_APPROVED:'false'}},setInterval(){throw Error('WORKER_NOT_EXPECTED');},require(id){
  if(id==='firebase-admin/app')return {getApps:()=>[{}]};if(id==='firebase-admin/auth')return {getAuth:()=>({verifyIdToken:verify})};if(id==='firebase-admin/firestore')return {...real(id),getFirestore:()=>db};
  if(id==='./transcription_temp_storage')return {createTranscriptionTempStorage:()=>({})};
  if(id==='./transcription_durable_queue')return {TranscriptionDurableQueue:class{},canonical:v=>v.state};
  return real(id);
 }};
 vm.runInNewContext(fs.readFileSync(file,'utf8'),scope,{filename:file});
 const app=Object.fromEntries(['get','post','put','delete'].map(m=>[m,(p,...args)=>routes.set(m+' '+p,args.at(-1))]));
 scope.module.exports.registerStudyBackgroundTranscriptionRoutes(app,{startWorker:false});return routes.get('post /api/ai/study/background-transcription/jobs');
}
test('blocked eligibility and direct reserve create no reservation; auth and body cannot forge owner',async t=>{
 environment(t);const db=database(),routes=usageRoutes(db);const before=JSON.stringify([...db.rows]);
 for(const action of ['eligibility','reserve']){const res=response();await routes.get('/api/usage/'+action)({auth:{uid:'owner'},headers:{},body:{...request('blocked'),uid:'synthetic-only',tier:'premium'}},res);assert.equal(res.code,403);assert.equal(res.body.code,'ASSEMBLYAI_PHI_PRODUCTION_BLOCKED');assert.equal(res.body.retryable,false);assert.equal(JSON.stringify([...db.rows]),before);}
 const res=response();await routes.get('/api/usage/eligibility')({body:{uid:'synthetic-only'}},res);assert.equal(res.code,401);
});
test('legacy reserved budget released idempotently by provider-block preflight',async t=>{
 environment(t);const db=database(),owner=new MonthlyUsageOwner({db}),r=await owner.reserve('owner',request('legacy'));const routes=usageRoutes(db);
 for(let i=0;i<2;i++){const res=response();await routes.get('/api/usage/eligibility')({auth:{uid:'owner'},headers:headers(r),body:{}},res);assert.equal(res.code,403);assert.equal(res.body.retryable,false);assert.equal((await owner.balance('owner')).remainingMs,5400000);}
 assert.equal(db.rows.get('usageReservations/'+r.id).state,'server_verified_failed');assert.equal((await owner.reserve('owner',request('legacy'))).state,'server_verified_failed');
});
test('job-create provider gate releases unexecuted reservation and preserves structured error',async t=>{
 environment(t);const db=database(),owner=new MonthlyUsageOwner({db}),r=await owner.reserve('owner',request('job'));const res=response();await jobRoutes(db)({headers:{authorization:'Bearer test',...headers(r)},body:{sourceId:'synthetic-session',expectedSegments:1}},res);
 assert.equal(res.code,403);assert.equal(res.body.code,'ASSEMBLYAI_PHI_PRODUCTION_BLOCKED');assert.equal(res.body.retryable,false);assert.equal(db.rows.has(jobPath(r)),false);assert.equal((await owner.balance('owner')).reservedMs,0);assert.equal((await owner.balance('owner')).usedMs,0);
});
for(const evidence of ['job','segment','logical','execution','media','charge','claimed'])test('ambiguous '+evidence+' is never released',async()=>{
 const db=database(),owner=new MonthlyUsageOwner({db}),r=await owner.reserve('owner',request(evidence)),p=jobPath(r);
 if(evidence==='job')db.rows.set(p,{uid:'owner'});
 if(evidence==='segment')db.rows.set(p+'/segments/0',{state:'queued'});
 if(evidence==='logical')db.rows.set(p+'/logical/recording',{providerTranscriptId:'synthetic'});
 if(evidence==='execution')db.rows.set('usageExecutions/e',{id:r.id,state:'completed'});
 if(evidence==='media')db.rows.set('usageMediaBindings/e',{id:r.id});
 if(evidence==='charge')db.rows.get('usageReservations/'+r.id).chargedMs=1;
 if(evidence==='claimed')db.rows.get('usageReservations/'+r.id).state='executing';
 const before=JSON.stringify([...db.rows]);await assert.rejects(owner.failBeforeExecution('owner',r),/AMBIGUOUS|BILLABLE/);assert.equal(JSON.stringify([...db.rows]),before);
});
test('five proven orphans release exact budget once and retain used totals',async()=>{
 const db=database(),owner=new MonthlyUsageOwner({db});const consumed=await owner.reserve('owner',request('used',1877296));await owner.finish('owner',{...consumed,actualMs:1877296,success:true});
 const reservations=[];for(const ms of [299849,15541,2799010,98131,94547])reservations.push(await owner.reserve('owner',request('orphan-'+ms,ms)));
 assert.equal((await owner.balance('owner')).remainingMs,215626);
 for(const r of reservations){await owner.failBeforeExecution('owner',r);await owner.failBeforeExecution('owner',r);}
 const balance=await owner.balance('owner');assert.equal(balance.remainingMs,3522704);assert.equal(balance.reservedMs,0);assert.equal(balance.usedMs,1877296);
});
test('wrong UID or stale attempt cannot refund another reservation',async()=>{
 const db=database(),owner=new MonthlyUsageOwner({db}),r=await owner.reserve('owner',request('protected'));await assert.rejects(owner.failBeforeExecution('free',r),/NOT_OWNED/);await assert.rejects(owner.failBeforeExecution('owner',{...r,attempt:'forged'}),/STALE/);assert.equal((await owner.balance('owner')).reservedMs,94547);
});
test('release winning the transaction race prevents a late job create',async()=>{
 const db=database(),owner=new MonthlyUsageOwner({db}),r=await owner.reserve('owner',request('race'));let transactions=0;const original=db.runTransaction.bind(db);
 db.runTransaction=async fn=>{if(++transactions===1)await owner.failBeforeExecution('owner',r);return original(fn);};
 const res=response();await jobRoutes(db,{allowed:true})({headers:{authorization:'Bearer test',...headers(r)},body:{sourceId:'synthetic',expectedSegments:1}},res);
 assert.equal(res.code,401);assert.equal(db.rows.has(jobPath(r)),false);assert.equal((await owner.balance('owner')).remainingMs,5400000);
});
test('job creation winning prevents release; replay never creates a second job',async()=>{
 const db=database(),owner=new MonthlyUsageOwner({db}),r=await owner.reserve('owner',request('safe'));const handler=jobRoutes(db,{allowed:true});
 for(let n=0;n<2;n++){const res=response();await handler({headers:{authorization:'Bearer test',...headers(r)},body:{sourceId:'synthetic',expectedSegments:1}},res);assert.equal(res.code,201);}
 assert.equal([...db.rows.keys()].filter(k=>k.startsWith('_study_background_transcription_jobs/')).length,1);
 await assert.rejects(owner.failBeforeExecution('owner',r),/AMBIGUOUS/);assert.equal((await owner.balance('owner')).reservedMs,94547);
});
test('provider error contract never exposes environment or raw server errors',()=>{assert.equal(providerGateError(Error('SECRET_INTERNAL_DETAIL')),null);const e=providerGateError(Error('ASSEMBLYAI_NOT_CONFIGURED'));assert.equal(e.code,'TRANSCRIPTION_UNAVAILABLE');assert.equal(e.retryable,true);});

test('temporary homologation is exact UID only and expires fail-closed',()=>{
 const now=Date.parse('2026-09-26T17:00:00Z'),env={ASSEMBLYAI_TRANSCRIPTION_ENABLED:'true',ASSEMBLYAI_CLINICAL_PHI_APPROVED:'false',ASSEMBLYAI_API_KEY:'test-only',ASSEMBLYAI_HOMOLOGATION_OWNER_UID:'owner',ASSEMBLYAI_HOMOLOGATION_UNTIL:'2026-09-26T19:00:00Z'};
 assert.equal(selectedProvider(env,'owner',now),'assemblyai');
 for(const uid of ['other','owner-extra',' owner','',undefined])assert.throws(()=>selectedProvider(env,uid,now),/PHI_PRODUCTION_BLOCKED/);
 for(const until of ['',undefined,'not-a-date','2026-09-26T17:00:00Z','2026-09-26T16:59:59Z'])assert.throws(()=>selectedProvider({...env,ASSEMBLYAI_HOMOLOGATION_UNTIL:until},'owner',now),/PHI_PRODUCTION_BLOCKED/);
 assert.throws(()=>selectedProvider(env,'owner',Date.parse(env.ASSEMBLYAI_HOMOLOGATION_UNTIL)),/PHI_PRODUCTION_BLOCKED/);
 assert.throws(()=>selectedProvider({...env,ASSEMBLYAI_API_KEY:''},'owner',now),/NOT_CONFIGURED/);
 assert.equal(selectedProvider({...env,ASSEMBLYAI_TRANSCRIPTION_ENABLED:'false'},'owner',now),'legacy');
});
test('homologation uses authenticated UID before quota; cannot bypass limits or forge owner',async t=>{
 environment(t);const keys=['ASSEMBLYAI_HOMOLOGATION_OWNER_UID','ASSEMBLYAI_HOMOLOGATION_UNTIL'],prior=Object.fromEntries(keys.map(k=>[k,process.env[k]]));t.after(()=>{for(const k of keys)if(prior[k]===undefined)delete process.env[k];else process.env[k]=prior[k];});
 Object.assign(process.env,{ASSEMBLYAI_HOMOLOGATION_OWNER_UID:'owner',ASSEMBLYAI_HOMOLOGATION_UNTIL:new Date(Date.now()+60000).toISOString()});
 const db=database(),routes=usageRoutes(db);let res=response();await routes.get('/api/usage/eligibility')({auth:{uid:'owner'},headers:{},body:{}},res);assert.equal(res.code,200);
 res=response();await routes.get('/api/usage/reserve')({auth:{uid:'free'},headers:{},body:{...request('forged'),uid:'owner'}},res);assert.equal(res.code,403);assert.equal([...db.rows.keys()].filter(k=>k.startsWith('usageReservations/')).length,0);
 for(let n=0;n<2;n++){res=response();await routes.get('/api/usage/reserve')({auth:{uid:'owner'},headers:{},body:request('same-test',5400000)},res);assert.equal(res.code,200);}
 assert.equal([...db.rows.keys()].filter(k=>k.startsWith('usageReservations/')).length,1);
 res=response();await routes.get('/api/usage/reserve')({auth:{uid:'owner'},headers:{},body:request('over-quota',1)},res);assert.equal(res.code,429);
 process.env.ASSEMBLYAI_HOMOLOGATION_UNTIL=new Date(Date.now()-1).toISOString();res=response();await routes.get('/api/usage/eligibility')({auth:{uid:'owner'},headers:{},body:{}},res);assert.equal(res.code,403);assert.equal(res.body.retryable,false);
});
