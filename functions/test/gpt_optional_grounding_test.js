'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {searchTopic, sourcesFromResponse, prepareGroundedRequest, generationPrompt} = require('../gpt_optional_grounding');
const base = {query: 'Guías actuales de encefalopatía hepática 2026', language: 'es', mode: 'plantao', internalContext: '', model: 'fixture-model', apiKey: 'test-only'};
const body = {status: 'completed', output: [{type: 'message', content: [{type: 'output_text', text: 'Retrieved evidence notes', annotations: [{type: 'url_citation', title: 'Guideline', url: 'https://easl.eu/example', published_date: '2026-01-01'}]}]}]};
const response = async () => ({ok: true, json: async () => body});
test('simple disease and pharmacology do not search', () => {
 for(const q of ['Encefalopatía hepática', 'Hiperkalemia', 'Metformina mecanismo de acción']) assert.equal(searchTopic(q, 'plantao'), null);
});
test('current PT/ES topic requests trigger; Study remains untouched', () => {
 assert.equal(searchTopic('Diretriz atual de sepse', 'plantao'), 'sepsis');
 assert.equal(searchTopic(base.query, 'plantao'), 'hepatic encephalopathy');
 assert.equal(searchTopic(base.query, 'estudo'), null);
});
test('unsupported topic uses no-web fallback', () => assert.equal(searchTopic('Guia atual de doença desconhecida', 'plantao'), null));
test('retrieval payload never includes raw query, internal context or history', async () => {
 let request;
 await prepareGroundedRequest({...base, query: base.query+' PATIENT_PRIVATE', internalContext:'PRIVATE_CONTEXT', history:[{content:'PRIVATE_HISTORY'}], fetchImpl: async (_, options) => {request=JSON.parse(options.body); return response();}});
 const serialized=JSON.stringify(request);
 for(const s of ['PATIENT_PRIVATE','PRIVATE_CONTEXT','PRIVATE_HISTORY']) assert.equal(serialized.includes(s),false);
 assert.equal(request.model,'fixture-model');
 assert.equal(request.tools[0].type,'web_search');
 assert.equal(request.input[1].content,'Current official clinical guidelines: hepatic encephalopathy');
});
test('real metadata is preserved without invented date', () => {
 const [s]=sourcesFromResponse(body); assert.equal(s.date,'2026-01-01'); assert.equal(s.domain,'easl.eu');
 const noDate=structuredClone(body); delete noDate.output[0].content[0].annotations[0].published_date;
 assert.equal('date' in sourcesFromResponse(noDate)[0],false);
});
test('unsafe URLs are discarded and URLs deduplicated', () => {
 const fixture=structuredClone(body); fixture.output[0].content[0].annotations.push(...[
 {type:'url_citation',url:'javascript:bad'}, {type:'url_citation',url:'https://user:secret@bad.example'}, fixture.output[0].content[0].annotations[0]]);
 assert.equal(sourcesFromResponse(fixture).length,1);
});
test('generated citation text alone is not provenance', async () => {
 const result=await prepareGroundedRequest({...base,fetchImpl:async()=>({ok:true,json:async()=>({status:'completed',output:[{content:[{type:'output_text',text:'https://fabricated.example'}]}]})})});
 assert.equal(result.sources.length,0); assert.equal(result.externalContext,'');
});
test('disabled retrieval preserves query and internal context', async () => {
 const result=await prepareGroundedRequest({...base,enabled:false,internalContext:'local',fetchImpl:()=>{throw Error('must not call');}});
 assert.equal(result.query,base.query); assert.equal(generationPrompt(result),'local');
});
test('provider failure is optional and does not block generation input', async () => {
 const result=await prepareGroundedRequest({...base,fetchImpl:async()=>{throw Error('unavailable');}});
 assert.equal(result.query,base.query); assert.equal(result.sources.length,0);
});
test('bounded timeout ignores late retrieval', async () => {
 let resolve;
 const pending=new Promise(r=>resolve=r);
 const result=await prepareGroundedRequest({...base,timeoutMs:5,fetchImpl:()=>pending});
 resolve(await response()); await new Promise(r=>setImmediate(r));
 assert.equal(result.groundingStatus,'unavailable_or_timeout'); assert.equal(result.sources.length,0); assert.equal(result.externalContext,'');
});
test('context and history freeze before generation', async () => {
 const history=[{role:'user',content:'original'}];
 const result=await prepareGroundedRequest({...base,history,fetchImpl:response});
 history[0].content='late mutation';
 assert.equal(result.history[0].content,'original'); assert.ok(Object.isFrozen(result)); assert.ok(Object.isFrozen(result.sources[0]));
});
for(const lang of ['pt','es']) test('grounded prompt preserves language '+lang, async () => {
 const result=await prepareGroundedRequest({...base,language:lang,fetchImpl:response});
 assert.match(generationPrompt(result),new RegExp(lang==='pt'?'Portuguese':'Spanish'));
});
test('internal context absent or present both produce generation snapshot', async () => {
 for(const internalContext of ['', 'local evidence']) {
  const result=await prepareGroundedRequest({...base,internalContext,fetchImpl:response});
  assert.equal(result.query,base.query); assert.equal(result.sources.length,1);
 }
});
test('cancelled request is not resumed as fallback', async () => {
 const c=new AbortController(); c.abort();
 await assert.rejects(prepareGroundedRequest({...base,signal:c.signal,fetchImpl:response}),/aborted/);
});
test('canonical handler freezes context before provenance and answer stream', () => {
 const fs=require('node:fs'),path=require('node:path');
 const source=fs.readFileSync(path.join(__dirname,'../plantao_canonical_stream.js'),'utf8');
 const a=source.indexOf('prepareGroundedRequest({query');
 const b=source.indexOf("onEvent('sources'",a);
 const c=source.indexOf('return streamAnswer({model,snapshot',b);
 assert.ok(a>0 && b>a && c>b);
 assert.ok(source.includes('const system=generationPrompt(snapshot)'));
 const handler=fs.readFileSync(path.join(__dirname,'../index.js'),'utf8');
 assert.ok(handler.includes('await runPlantaoCanonicalStream({'));
 assert.ok(!handler.includes('const contextSnapshot = await prepareGroundedRequest'));
});
