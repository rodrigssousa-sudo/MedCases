'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {StudyQualityGate,METRICS}=require('../study_quality_gate');
const {GroundedStudyEngine}=require('../grounded_study_engine');
const {DerivativePolicy}=require('../derivative_policy');
const {hash}=require('../derivative_contract');
for(const type of Object.keys(METRICS))test(`${type}: all pedagogical criteria mandatory; unsupported and partial reviews rejected`,async()=>{
 const candidate={structuredResult:{test:'synthetic'}};
 const input={rawTranscript:'synthetic',derivativeType:type,locale:'pt',candidate,generatorIdentity:'generator',grounding:{supported:true,outputHash:hash(JSON.stringify(candidate.structuredResult))}};
 let metrics=METRICS[type].map(name=>({name,status:'PASS'}));
 const v=new StudyQualityGate({identity:'independent',independentCheck:async()=>({verifierIdentity:'independent',metrics})});
 assert.equal((await v.verify(input)).passed,true);
 metrics[0].status='FAIL';assert.equal((await v.verify(input)).passed,false);
 metrics[0].status='UNVERIFIED';assert.equal((await v.verify(input)).passed,false);
 metrics=[];assert.equal((await v.verify(input)).passed,false);
 input.grounding.supported=false;assert.equal((await v.verify(input)).passed,false);
});
test('quality reviewer cannot be generator or review a different output',async()=>{
 const input={derivativeType:'SUMMARY',candidate:{structuredResult:{}},generatorIdentity:'same',grounding:{supported:true,outputHash:hash('{}')}};
 const v=new StudyQualityGate({identity:'same',independentCheck:async()=>{throw Error('must not call');}});
 assert.equal((await v.verify(input)).code,'INDEPENDENT_QUALITY_CHECK_REQUIRED');
 input.candidate.structuredResult={changed:true};assert.equal((await v.verify(input)).code,'GROUNDED_OUTPUT_REQUIRED');
});
test('Study cannot complete on grounding alone without pedagogical review',async()=>{
 const e=new GroundedStudyEngine({generator:{generate:async()=>({structuredResult:{},generatorIdentity:'g'})},verifier:{verify:async()=>({supported:true,normalizedClaims:[]})}});
 await assert.rejects(e.generate({rawTranscript:'source',transcriptHash:hash('source'),derivativeType:'SUMMARY',locale:'pt'}),{code:'pedagogical_review_required'});
});
test('router selects by derivative, locale, length and isolates model caches',()=>{
 const input={rawTranscript:'x'.repeat(21000),derivativeType:'SUMMARY',locale:'es',transcriptHash:hash('x'.repeat(21000)),ownerUid:'u'};
 const policy=new DerivativePolicy({SUMMARY:{provider:'default',variants:[{locale:'es',lengthBucket:'LONG',provider:'candidate',model:'m1',revision:'r'}]}});
 const route=policy.resolve(input);assert.equal(route.provider,'candidate');assert.equal(route.lengthBucket,'LONG');assert.equal(route.routeApproved,false);
 assert.equal(policy.resolve({...input,locale:'pt'}).provider,'default');
 assert.notEqual(DerivativePolicy.cacheKey(input,route),DerivativePolicy.cacheKey(input,{...route,model:'m2'}));
});
