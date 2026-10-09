'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {R24StudyRuntime}=require('../derivative_r24_study_runtime');
const {DerivativePolicy}=require('../derivative_policy');
const {hash}=require('../derivative_contract');
const {METRICS}=require('../study_quality_gate');
const {ExtractiveStudyFallback}=require('../extractive_study_fallback');
class Store {constructor(){this.rows=new Map();this.tail=Promise.resolve();}transaction(k,fn){const p=this.tail.then(()=>fn({read:async()=>this.rows.get(k),write:async v=>this.rows.set(k,v)}));this.tail=p.catch(()=>{});return p;}async getCache(){return null;}}
const input=type=>({ownerUid:'u',operationId:'op-'+type,sourceId:'source',rawTranscript:'Texto fictício literal.',transcriptHash:hash('Texto fictício literal.'),locale:'pt',derivativeType:type});
const policy=new DerivativePolicy(Object.fromEntries(['SUMMARY','KEY_POINTS','VISUAL_SUMMARY','ORAL_EXAM'].map(t=>[t,{qualityApproved:true,revision:'synthetic-test-only'}])));
function reviewer({reject=false}={}){return {identity:'qa/reviewer',complete:async args=>({identity:'qa/reviewer',value:args.name.includes('semantic')?{verdicts:args.data.claimsToReview.map(c=>({path:c.path,reason:'Synthetic review fixture',status:reject?'UNSUPPORTED':'SUPPORTED',sourceMisattribution:false,criticalFactDistortion:false,negationConflict:false,doseConflict:false,temporalConflict:false,allergyConflict:false}))}:{metrics:METRICS[args.data.derivativeType].map(name=>({name,status:'PASS',reason:'Synthetic review fixture'}))}})};}
for(const type of ['SUMMARY','KEY_POINTS','VISUAL_SUMMARY']){
 test(type+' runtime composes actual deterministic extraction, grounding, quality and durable stage replay',async()=>{
  const store=new Store();let calls=0;const raw=reviewer();const client={identity:raw.identity,complete:async args=>{calls++;return raw.complete(args);}};
  const engine=new R24StudyRuntime({store,policy,primaryReviewer:client});
  const a=await engine.generate(input(type));assert.equal(a.grounding.supported,true);assert.equal(a.pedagogicalQuality.passed,true);
  const b=await new R24StudyRuntime({store,policy,primaryReviewer:client}).generate(input(type));
  assert.deepEqual(b.structuredResult,a.structuredResult);assert.equal(calls,2);
  assert.equal(hash(input(type).rawTranscript),input(type).transcriptHash);
 });
}
test('unapproved route performs no provider call',async()=>{
 let calls=0;const engine=new R24StudyRuntime({store:new Store(),policy:new DerivativePolicy(),primaryReviewer:{identity:'qa',complete:async()=>calls++}});
 await assert.rejects(engine.generate(input('SUMMARY')),{code:'study_route_not_approved'});assert.equal(calls,0);
});
test('semantic failure cannot be overridden by pedagogical success',async()=>{
 const engine=new R24StudyRuntime({store:new Store(),policy,primaryReviewer:reviewer({reject:true})});
 await assert.rejects(engine.generate(input('SUMMARY')),{code:'grounding_rejected'});
});
test('long key points requests a shared summary operation instead of a second provider generation',async()=>{
 const raw='Texto fictício. '.repeat(200);const source={...input('KEY_POINTS'),rawTranscript:raw,transcriptHash:hash(raw)};
 let generatorCalls=0,dependencies=0;
 const engine=new R24StudyRuntime({store:new Store(),policy,generator:{identity:'generator',complete:async()=>generatorCalls++}});
 engine.resolveSummary=async s=>{dependencies++;assert.equal(s.derivativeType,'SUMMARY');assert.equal(s.rawTranscript,source.rawTranscript);throw Object.assign(Error('pending'),{code:'derivative_dependency_pending'});};
 await assert.rejects(engine.generate(source),{code:'derivative_dependency_pending'});
 assert.equal(generatorCalls,0);assert.equal(dependencies,1);
});
