'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {runPlantaoCanonicalStream,MODELS}=require('../plantao_canonical_stream');
const base={query:'Encefalopatía hepática',language:'es',internalContext:'Clinical context',openAiKey:'fixture',geminiKey:'fixture',requestId:'test',grounding:false};
function setup({complex=false,failPrimary=false,refusal=false,partialFailure=false}={}){
 const calls=[],events=[];
 const fetchImpl=async(url,options)=>{
  const b=JSON.parse(options.body);const model=b.model||MODELS.fallback;calls.push(model);
  if(model===MODELS.router)return {ok:true,json:async()=>({output:[{content:[{type:'output_text',text:JSON.stringify({complexity:complex?'complex':'standard',answer:'MUST_NOT_SHOW'})}]}]})};
  if(failPrimary && model!==MODELS.fallback)return {ok:false,status:503};
  const messages=model===MODELS.fallback?[{candidates:[{content:{parts:[{text:'Respuesta clínica segura.'}]},finishReason:'STOP'}]}]:refusal?[{type:'response.refusal.done'}]:[{type:'response.output_text.delta',delta:'Respuesta clínica segura.'},...(partialFailure?[]:[{type:'response.completed',response:{usage:{input_tokens:2,output_tokens:5}}}])];
  return {ok:true,body:(async function*(){for(const m of messages)yield Buffer.from('data: '+JSON.stringify(m)+'\n\n');})()};
 };
 return {calls,events,options:{...base,fetchImpl,onEvent:(name,data)=>events.push({name,data})}};
}
test('nano routes only, Luna answers with real incremental events',async()=>{
 const h=setup();const result=await runPlantaoCanonicalStream(h.options);
 assert.deepEqual(h.calls,[MODELS.router,MODELS.primary]);assert.equal(result.model,MODELS.primary);
 assert.equal(h.events.filter(e=>e.name==='text_delta').length,1);assert.ok(!JSON.stringify(h.events).includes('MUST_NOT_SHOW'));
 assert.equal(h.events[0].data.pipeline,'plantao_canonical_v1');
});
test('technical failure before text invokes only paid Gemini sequentially',async()=>{
 const h=setup({failPrimary:true});const r=await runPlantaoCanonicalStream(h.options);
 assert.deepEqual(h.calls,[MODELS.router,MODELS.primary,MODELS.fallback]);assert.equal(r.fallbackUsed,true);
 assert.equal(h.events.at(-1).data.sequence,1);
});
test('complexity alone never activates Terra',async()=>{
 const h=setup({complex:true});await runPlantaoCanonicalStream(h.options);assert.equal(h.calls[1],MODELS.primary);
});
test('server authorization plus complexity selects Terra, never technical escalation',async()=>{
 const h=setup({complex:true});const r=await runPlantaoCanonicalStream({...h.options,escalationPolicy:{enabled:true,terraAllowed:true}});
 assert.deepEqual(h.calls,[MODELS.router,MODELS.escalation]);assert.equal(r.escalationUsed,true);
});
test('standard case stays Luna even when escalation is authorized',async()=>{
 const h=setup();await runPlantaoCanonicalStream({...h.options,escalationPolicy:{enabled:true,terraAllowed:true}});assert.equal(h.calls[1],MODELS.primary);
});
test('partial stream never restarts on another provider',async()=>{
 const h=setup({partialFailure:true});await assert.rejects(runPlantaoCanonicalStream(h.options),/incomplete/);
 assert.deepEqual(h.calls,[MODELS.router,MODELS.primary]);assert.equal(h.events.filter(e=>e.name==='text_delta').length,1);
});
test('refusal never triggers a provider safety bypass',async()=>{
 const h=setup({refusal:true});await assert.rejects(runPlantaoCanonicalStream(h.options),/refusal/);assert.equal(h.calls.length,2);
});
test('cancelled turn does not call an answer provider',async()=>{
 const h=setup();const c=new AbortController();c.abort();await assert.rejects(runPlantaoCanonicalStream({...h.options,signal:c.signal}),/cancel/);assert.ok(!h.calls.includes(MODELS.primary));
});
test('classifier unavailable is not an answer gate',async()=>{
 const h=setup();const original=h.options.fetchImpl;h.options.fetchImpl=(u,o)=>JSON.parse(o.body).model===MODELS.router?Promise.reject(Error('offline')):original(u,o);
 const r=await runPlantaoCanonicalStream(h.options);assert.equal(r.model,MODELS.primary);
});
test('missing internal context is not an answer gate',async()=>{const h=setup();assert.equal((await runPlantaoCanonicalStream({...h.options,internalContext:''})).model,MODELS.primary);});
test('credentials and clinical prompt do not enter event metadata',async()=>{const h=setup();await runPlantaoCanonicalStream(h.options);const metadata=JSON.stringify(h.events.filter(e=>e.name!=='text_delta'));assert.ok(!metadata.includes('fixture'));assert.ok(!metadata.includes(base.query));});

const {fetchWithConnectRetry}=require('../plantao_canonical_stream');
const connectError=()=>Object.assign(new TypeError('fetch failed'),{cause:{code:'ETIMEDOUT',errors:[{code:'ETIMEDOUT',syscall:'connect'}]}});
test('proven connect failure retries once within the same deadline',async()=>{
 let calls=0,waits=0;const signal=new AbortController().signal;
 const result=await fetchWithConnectRetry(async(_,o)=>{assert.equal(o.signal,signal);if(++calls===1)throw connectError();return 'ok';},'fixture',{signal},async(ms)=>{assert.ok(ms>=200&&ms<300);waits++;});
 assert.equal(result,'ok');assert.equal(calls,2);assert.equal(waits,1);
});
test('connect retry is bounded to two attempts',async()=>{let calls=0;await assert.rejects(fetchWithConnectRetry(async()=>{calls++;throw connectError();},'fixture',{},async()=>{}));assert.equal(calls,2);});
test('ambiguous timeout or read error cannot replay a request',async()=>{for(const cause of [{code:'ETIMEDOUT'},{code:'ECONNRESET',syscall:'read'}]){let calls=0;await assert.rejects(fetchWithConnectRetry(async()=>{calls++;throw Object.assign(Error('failure'),{cause});},'fixture',{},async()=>{}));assert.equal(calls,1);}});
test('cancelled connect failure cannot retry',async()=>{let calls=0;const c=new AbortController();c.abort();await assert.rejects(fetchWithConnectRetry(async()=>{calls++;throw connectError();},'fixture',{signal:c.signal},async()=>{}));assert.equal(calls,1);});
