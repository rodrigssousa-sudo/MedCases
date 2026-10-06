'use strict';
const {VERIFIED_PROVIDER_BINDINGS: bindings} = require('./lib/ai_control_plane_v2/model_registry');
const MODELS = Object.freeze({router:bindings.gpt_5_nano.apiModelName, primary:bindings.gpt_56_luna.apiModelName, fallback:bindings.gemini_31_flash_lite_paid.apiModelName, escalation:bindings.gpt_56_terra.apiModelName});
const CONTRACT = 'plantao_canonical_v1';
const {setTimeout: delay} = require('node:timers/promises');
const {prepareGroundedRequest, generationPrompt} = require('./gpt_optional_grounding');
// Retry only a proven connection failure: no request body reached the provider.
// The same AbortSignal retains the original total budget across both attempts.
function isConnectFailure(error) {
  const cause = error?.cause || error;
  if (cause?.code === 'UND_ERR_CONNECT_TIMEOUT') return true;
  const errors = Array.isArray(cause?.errors) ? cause.errors : [cause];
  return errors.length > 0 && errors.every(e => e?.syscall === 'connect' &&
    ['ETIMEDOUT', 'ECONNREFUSED', 'ENETUNREACH', 'EHOSTUNREACH'].includes(e?.code));
}
async function fetchWithConnectRetry(fetchImpl, url, options, wait = delay) {
  try { return await fetchImpl(url, options); }
  catch (error) {
    if (options.signal?.aborted || !isConnectFailure(error)) throw error;
    await wait(200 + Math.floor(Math.random() * 100), undefined, {signal:options.signal});
    return fetchImpl(url, options);
  }
}
async function readEvents(response, visit) {
  if (!response.ok) throw Error(`provider_http_${response.status}`);
  const decoder=new TextDecoder(); let buffer='';
  for await (const bytes of response.body) {
    buffer+=decoder.decode(bytes,{stream:true});
    buffer=buffer.replace(/\r\n/g,'\n');
    let end;
    while((end=buffer.indexOf('\n\n'))>=0) {
      const frame=buffer.slice(0,end);buffer=buffer.slice(end+2);
      const data=frame.split('\n').filter(l=>l.startsWith('data:')).map(l=>l.slice(5).trimStart()).join('\n');
      if(data && data!=='[DONE]') visit(JSON.parse(data));
    }
  }
}
async function classify({query, key, signal, fetchImpl}) {
  try {
    const r=await fetchWithConnectRetry(fetchImpl,'https://api.openai.com/v1/responses',{
      method:'POST',signal:AbortSignal.any([signal,AbortSignal.timeout(3000)]),
      headers:{'Content-Type':'application/json',Authorization:`Bearer ${key}`},
      body:JSON.stringify({model:MODELS.router,store:false,max_output_tokens:256,
        input:[{role:'system',content:'Classify clinical reasoning complexity only. Never answer the clinical question. Output JSON with complexity: standard or complex. A disease name or emergency keyword alone does not establish complexity.'},{role:'user',content:query}],
        text:{format:{type:'json_schema',name:'route',strict:true,schema:{type:'object',properties:{complexity:{type:'string',enum:['standard','complex']}},required:['complexity'],additionalProperties:false}}}})});
    if(!r.ok) return 'standard';
    const body=await r.json();
    const text=(body.output||[]).flatMap(i=>i.content||[]).filter(c=>c.type==='output_text').map(c=>c.text).join('');
    return JSON.parse(text).complexity==='complex'?'complex':'standard';
  } catch (_) { if(signal.aborted) throw Error('client_cancelled'); return 'standard'; }
}
async function streamAnswer({model, snapshot, openAiKey, geminiKey, signal, fetchImpl, onText, maxOutputTokens}) {
  const google=model===MODELS.fallback;
  const system=generationPrompt(snapshot);
  const history=snapshot.history.slice(-8).map(h=>({role:h.role==='model'||h.role==='assistant'?'assistant':'user',content:String(h.content||h.text||'')}));
  const body=google?{systemInstruction:{parts:[{text:system}]},contents:[...history.map(h=>({role:h.role==='assistant'?'model':'user',parts:[{text:h.content}]})),{role:'user',parts:[{text:snapshot.query}]}],generationConfig:{maxOutputTokens}}:
    {model,store:false,stream:true,max_output_tokens:maxOutputTokens,input:[{role:'system',content:system},...history,{role:'user',content:snapshot.query}]};
  const url=google?`https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse`:'https://api.openai.com/v1/responses';
  let complete=false;let chars=0;let usage={};
  try {
    const response=await fetchWithConnectRetry(fetchImpl,url,{method:'POST',signal:AbortSignal.any([signal,AbortSignal.timeout(60000)]),headers:{'Content-Type':'application/json',...(google?{'x-goog-api-key':geminiKey}:{Authorization:`Bearer ${openAiKey}`})},body:JSON.stringify(body)});
    await readEvents(response,event=>{
      if(signal.aborted) throw Error('client_cancelled');
      if(google){
        const candidate=event.candidates?.[0];
        if(event.promptFeedback?.blockReason || (candidate?.finishReason && !['STOP','MAX_TOKENS'].includes(candidate.finishReason))) throw Error('provider_refusal');
        const text=(candidate?.content?.parts||[]).filter(p=>!p.thought).map(p=>p.text||'').join('');
        if(text){chars+=text.length;onText(text);}
        if(candidate?.finishReason==='STOP') complete=true;
        if(event.usageMetadata) usage=event.usageMetadata;
      } else {
        if(event.type?.startsWith('response.refusal'))throw Error('provider_refusal');
        if(event.type==='response.output_text.delta' && event.delta){chars+=event.delta.length;onText(event.delta);}
        if(event.type==='response.completed'){complete=true;usage=event.response?.usage||{};}
        if(event.type==='response.failed' || event.type==='error')throw Error('provider_failed');
      }
    });
  } catch(error){
    if(signal.aborted)throw Error('client_cancelled');
    if(error.name==='TimeoutError'||error.name==='AbortError')throw Error('provider_timeout');
    if(error instanceof TypeError)throw Error('provider_network');
    throw error;
  }
  if(!complete)throw Error('provider_incomplete');
  if(!chars)throw Error('provider_empty');
  return {model,provider:google?'google':'openai',inputTokensApprox:usage.input_tokens||usage.promptTokenCount||0,outputTokensApprox:usage.output_tokens||usage.candidatesTokenCount||0};
}
async function runPlantaoCanonicalStream({query,language,internalContext,history=[],openAiKey,geminiKey,signal,
  escalationPolicy,requestId,maxOutputTokens=3200,onEvent,fetchImpl=globalThis.fetch,grounding=true}) {
  if(!signal) signal=new AbortController().signal;
  // Classification and optional retrieval have bounded independent budgets.
  const [complexity,snapshot]=await Promise.all([
    classify({query,key:openAiKey,signal,fetchImpl}),
    prepareGroundedRequest({query,language,mode:'plantao',internalContext,history,model:MODELS.primary,apiKey:openAiKey,signal,fetchImpl,enabled:grounding})]);
  if(signal.aborted)throw Error('client_cancelled');
  // Server-owned eligibility only, never sourced from request body/classifier alone.
  const escalate=complexity==='complex' && escalationPolicy?.enabled===true && escalationPolicy?.terraAllowed===true;
  const selected=escalate?MODELS.escalation:MODELS.primary;
  let sequence=0;let emitted=false;let fallbackUsed=false;
  if(snapshot.sources.length)onEvent('sources',{requestId,sources:snapshot.sources});
  async function attempt(model){
    onEvent('started',{requestId,attempt:2,model,provider:model===MODELS.fallback?'google':'openai',pipeline:CONTRACT,
      routerModel:MODELS.router,answerModel:model,fallbackUsed,escalationUsed:escalate,renderer:'PREMIUM_CURRENT',language,mode:'plantao'});
    return streamAnswer({model,snapshot,openAiKey,geminiKey,signal,fetchImpl,maxOutputTokens,
      onText:delta=>{emitted=true;onEvent('text_delta',{requestId,attempt:2,sequence:++sequence,delta});}});
  }
  let result;
  try {result=await attempt(selected);}
  catch(error){
    // Once visible content exists, never restart/replace it with another model.
    const technical=/^provider_(http_(429|5\d\d)|timeout|network|failed|empty|incomplete)$/.test(error.message);
    if(emitted||signal.aborted||!technical||!geminiKey)throw error;
    fallbackUsed=true;result=await attempt(MODELS.fallback);
  }
  return {...result,pipeline:CONTRACT,routerModel:MODELS.router,fallbackUsed,escalationUsed:escalate,sequenceCount:sequence};
}
module.exports={MODELS,CONTRACT,runPlantaoCanonicalStream,readEvents,fetchWithConnectRetry,isConnectFailure};
