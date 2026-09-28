"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {studyCanonicalTransport, VERSION} = require("../lib/study_canonical_transport");
const request = {mode:"estudo",lang:"es", studyCanonicalVersion:VERSION,
 systemPrompt:"STUDY PAID CANONICAL v2\nClinical policy"};
test("Study native canonical contract is explicit, complete, and scoped", () => {
 const config=studyCanonicalTransport(request);
 assert.equal(config.maxOutputTokens,12288);
 assert.equal(config.generationConfig.responseMimeType,"application/json");
 assert.equal(config.generationConfig.responseJsonSchema.type,"object");
 assert.deepEqual(Object.keys(config).sort(),["generationConfig","maxOutputTokens","version"]);
});
for(const [name,body] of Object.entries({
 plantao:{...request,mode:"plantao"}, plainStudy:{mode:"estudo",lang:"es",systemPrompt:"educational"},
 wrongVersion:{...request,studyCanonicalVersion:"other"}, missingMarker:{...request,systemPrompt:"ordinary"},
 utility:{...request,studyCanonicalVersion:undefined}, legacyOpenAI:{...request,provider:"openai"}
})) test(`${name} retains existing transport`,()=>assert.equal(studyCanonicalTransport(body),null));
test("canonical helper has no authorization, routing, quota, or model fields",()=>{
 const config=studyCanonicalTransport(request);
 for(const key of ["auth","uid","role","quota","model","temperature","provider"])
  assert.equal(Object.hasOwn(config,key),false);
});
const {studyCanonicalCompletion}=require('../lib/study_canonical_transport');
function fixture(){return {clinical:[{id:'f1',s:'treatment',c:'synthetic',a:'consider',p:'conditional',when:['c1'],items:[{id:'c1',k:'condition',c:'if_indicated'},{id:'a1',k:'action',c:'synthetic_drug'},{id:'q1',k:'quantity',n:500,hi:null,op:'',u:'mg'},{id:'r1',k:'route',v:'VO'},{id:'m1',k:'monitoring',c:'monitor_response'}]}],presentation:{title:'Sintético',labels:[{id:'c1',text:'Si indicado'},{id:'a1',text:'Agente sintético'},{id:'m1',text:'monitorizar respuesta'}]},complete:true};}
test('complete single-locale snapshot with quantities and monitoring is accepted',()=>assert.equal(studyCanonicalCompletion(JSON.stringify(fixture()),'STOP'),null));
for(const reason of ['MAX_TOKENS','SAFETY','OTHER',''])test(`reject terminal ${reason} without hiding metadata`,()=>assert.equal(studyCanonicalCompletion('{}',reason),'canonical_incomplete_termination'));
for(const [name,mutate] of Object.entries({
 incomplete:d=>d.complete=false,
 duplicate:d=>d.presentation.labels.push(d.presentation.labels[0]),
 unbound:d=>d.presentation.labels.pop(),
 unboundDose:d=>d.presentation.labels[0].text='500 mg',
 badReference:d=>d.presentation.labels[0].text='https://invented.invalid',
 extraClinical:d=>d.clinical[0].extra='prose',
 invalidRoute:d=>d.clinical[0].items[3].v='fake',
 invalidQuantity:d=>d.clinical[0].items[2].n=NaN,
 invalidInfinity:d=>d.clinical[0].items[2].n=Infinity,
 invalidCondition:d=>d.clinical[0].when=['missing']
}))test(`reject ${name}`,()=>{const d=fixture();mutate(d);assert.notEqual(studyCanonicalCompletion(JSON.stringify(d),'STOP'),null);});
test('localization cannot emit a clinical snapshot; independently bounded budget',()=>{
 const config=studyCanonicalTransport({...request,studyCanonicalOperation:'localize'});
 assert.equal(config.maxOutputTokens,4096);
 assert.equal(studyCanonicalCompletion(JSON.stringify(fixture().presentation),'STOP',true),null);
 assert.notEqual(studyCanonicalCompletion(JSON.stringify(fixture()),'STOP',true),null);
});
test('requested-language contract rejects unknown locale and operation',()=>{
 for(const bad of [{lang:'en'},{studyCanonicalOperation:'reroute'}])assert.equal(studyCanonicalTransport({...request,...bad}),null);
});
