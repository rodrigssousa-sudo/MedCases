'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {OralBlueprintEngine,validateBlueprint}=require('../oral_blueprint_engine');
const {TranscriptFactLedger}=require('../transcript_fact_ledger');
const {corpus}=require('./oral_exam_r22_corpus');
const {retryAfterMs,withProviderLimitRetry}=require('../provider_limit_retry');
const {DerivativeStageRunner}=require('../derivative_stage_runner');
const {EvidenceModelClient}=require('../evidence_model_client');
const {DerivativeError}=require('../derivative_contract');
for(const c of corpus)test(`R23 blueprint ${c.id} preserves source and honest omission`,()=>{
 const ledger=TranscriptFactLedger.extract(c.rawTranscript);const r=new OralBlueprintEngine().generate({...c,verifiedFactLedger:ledger});
 for(const q of r.questions){assert.ok(validateBlueprint(q,ledger));assert.equal(q.expectedAnswer,q.supportingFactIds.map(id=>ledger.facts.find(f=>f.factId===id).value.trim()).join('\n\n'));assert.equal(q.sourceHash,ledger.transcriptHash);assert.ok(q.questionId);}
 assert.equal(r.providerCalls,0);assert.ok(r.questions.length<=c.questionCount);
 if(c.expectedInsufficient)assert.equal(r.questions.length,0);
 if([3,4,6,9,10].includes(c.scenario))assert.ok(r.questions.length>0);
});
test('R23 known generic/leaking list becomes bounded list question without categories in premise',()=>{
 const c=corpus.find(c=>c.id==='ORAL_6_ES');const ledger=TranscriptFactLedger.extract(c.rawTranscript);const [q]=new OralBlueprintEngine().generate({...c,verifiedFactLedger:ledger}).questions;
 assert.equal(q.questionFamily,'LIST_SUPPORTED');assert.doesNotMatch(q.question,/Alfa|Beta|Gamma|qué se enseñó/);assert.match(q.expectedAnswer,/No se definió/);
 for(const property of ['question','expectedAnswer','sourceHash','relationType','difficulty']){assert.equal(validateBlueprint({...q,[property]:'forged'},ledger),false);}
 assert.equal(validateBlueprint({...q,requiredQualifiers:[]},ledger),false);
});
for(const locale of ['pt','es'])test(`R23 definition ${locale} is bounded, answer first`,()=>{
 const rawTranscript=locale==='pt'?'Nexo é definido como um registro provisório, não uma conclusão.':'Nexo se define como un registro provisional, no una conclusión.';
 const ledger=TranscriptFactLedger.extract(rawTranscript);const [q]=new OralBlueprintEngine().generate({rawTranscript,verifiedFactLedger:ledger,locale}).questions;
 assert.equal(q.questionFamily,'DEFINITION');assert.equal(q.expectedAnswer,rawTranscript);assert.ok(validateBlueprint(q,ledger));
});
test('Retry-After seconds, HTTP date, invalid values',()=>{
 assert.equal(retryAfterMs('2'),2000);assert.equal(retryAfterMs('Wed, 21 Oct 2015 07:28:00 GMT',1445412479000),1000);assert.equal(retryAfterMs('garbage'),null);assert.equal(retryAfterMs(null),null);
});
test('429 client preserves typed retry metadata without body',async()=>{
 const c=new EvidenceModelClient({apiKey:'secret',model:'test',fetchImpl:async()=>({ok:false,status:429,headers:{get:()=> '7'},json:async()=>{throw Error('must not read body');}})});
 await assert.rejects(c.complete({}),e=>e.code==='RETRYABLE_PROVIDER_LIMIT'&&e.metadata.retryAfterMs===7000&&!JSON.stringify(e).includes('secret'));
});
test('bounded retry obeys Retry-After and backoff; never retries unknown accepted requests',async()=>{
 let n=0;const waits=[];const limited=new DerivativeError('RETRYABLE_PROVIDER_LIMIT',true,{httpStatus:429,retryAfterMs:1500});
 assert.equal(await withProviderLimitRetry(async()=>{if(++n<3)throw limited;return 'ok';},{sleep:async x=>waits.push(x),random:()=>0}), 'ok');assert.deepEqual(waits,[1500,2000]);
 n=0;await assert.rejects(withProviderLimitRetry(async()=>{n++;throw new DerivativeError('generation_timeout',true);}),{code:'generation_timeout'});assert.equal(n,1);
 n=0;await assert.rejects(withProviderLimitRetry(async()=>{n++;throw limited;},{maxAttempts:2,sleep:async()=>{},random:()=>0}),{code:'RETRYABLE_PROVIDER_LIMIT'});assert.equal(n,2);
});
class Store{constructor(){this.rows=new Map();this.tail=Promise.resolve();}transaction(k,fn){const p=this.tail.then(()=>fn({read:async()=>structuredClone(this.rows.get(k)),write:async v=>this.rows.set(k,structuredClone(v))}));this.tail=p.catch(()=>{});return p;}}
const context=store=>({store,ownerUid:'owner-a',operationId:'operation-a',revision:'r23'});
test('durable stage restart reuses concepts and semantic output, retries only missing reviewer',async()=>{
 const store=new Store();let now=0;const calls=[];let limited=true;
 const client={identity:'independent-reviewer',complete:async args=>{calls.push(args.name);if(args.name==='pedagogy'&&limited)throw new DerivativeError('RETRYABLE_PROVIDER_LIMIT',true,{httpStatus:429,retryAfterMs:1000});return {identity:'independent-reviewer',value:{stage:args.name},usage:{}};}};
 const runner=new DerivativeStageRunner({...context(store),now:()=>now});
 await runner.complete(client,{name:'concepts'});await runner.complete(client,{name:'semantic'});await assert.rejects(runner.complete(client,{name:'pedagogy'}),{code:'RETRYABLE_PROVIDER_LIMIT'});
 limited=false;now=1001;const restarted=new DerivativeStageRunner({...context(store),now:()=>now});
 await restarted.complete(client,{name:'concepts'});await restarted.complete(client,{name:'semantic'});await restarted.complete(client,{name:'pedagogy'});
 assert.deepEqual(calls,['concepts','semantic','pedagogy','pedagogy']);
});
test('stage cache is owner, schema, provider and revision bound',async()=>{
 const store=new Store();let n=0;const client={identity:'a',complete:async()=>({value:++n})};
 await new DerivativeStageRunner(context(store)).complete(client,{name:'test',schema:'a'});
 await new DerivativeStageRunner({...context(store),ownerUid:'b'}).complete(client,{name:'test',schema:'a'});
 await new DerivativeStageRunner({...context(store),revision:'r24'}).complete(client,{name:'test',schema:'a'});
 await new DerivativeStageRunner(context(store)).complete({...client,identity:'b'},{name:'test',schema:'a'});
 await new DerivativeStageRunner(context(store)).complete(client,{name:'test',schema:'b'});assert.equal(n,5);
});
test('unknown provider result cannot cause silent duplicate bill after restart',async()=>{
 const store=new Store();let calls=0;const client={identity:'a',complete:async()=>{calls++;throw new DerivativeError('generation_timeout',true);}};
 await assert.rejects(new DerivativeStageRunner(context(store)).complete(client,{name:'stage'}),{code:'generation_timeout'});
 await assert.rejects(new DerivativeStageRunner(context(store)).complete(client,{name:'stage'}),{code:'provider_outcome_unknown'});assert.equal(calls,1);
});
test('concurrent stages have a single provider request',async()=>{
 const store=new Store();let calls=0;let release;const barrier=new Promise(r=>release=r);const client={identity:'a',complete:async()=>{calls++;await barrier;return {value:'ok'};}};
 const runner=new DerivativeStageRunner(context(store));const first=runner.complete(client,{name:'stage'});await new Promise(r=>setImmediate(r));
 await assert.rejects(runner.complete(client,{name:'stage'}),{code:'provider_outcome_unknown'});release();await first;assert.equal(calls,1);
});
test('no recognized grammar does not assert that source itself is insufficient',()=>{
 const rawTranscript='Fonte detalhada cujo formato não tem um template autorizado.';
 const r=new OralBlueprintEngine().generate({rawTranscript,verifiedFactLedger:TranscriptFactLedger.extract(rawTranscript),locale:'pt'});
 assert.equal(r.status,'NO_SUPPORTED_TEMPLATE');assert.equal(r.questions.length,0);
});
test('persisted stage attempt budget survives multiple restarts',async()=>{
 const store=new Store();let calls=0,now=0;
 const client={identity:'reviewer',complete:async()=>{calls++;throw new DerivativeError('RETRYABLE_PROVIDER_LIMIT',true,{httpStatus:429,retryAfterMs:0});}};
 for(let i=0;i<3;i++){await assert.rejects(new DerivativeStageRunner({...context(store),now:()=>now}).complete(client,{name:'stage'}),{code:'RETRYABLE_PROVIDER_LIMIT'});now+=10000;}
 await assert.rejects(new DerivativeStageRunner({...context(store),now:()=>now}).complete(client,{name:'stage'}),{code:'provider_retry_exhausted'});assert.equal(calls,3);
});
test('corrupt completed stage is rejected without paid regeneration',async()=>{
 const store=new Store();let calls=0;const client={identity:'reviewer',complete:async()=>({value:++calls})};
 const runner=new DerivativeStageRunner(context(store));await runner.complete(client,{name:'stage'});
 const row=[...store.rows.values()][0];row.response.value='changed';
 await assert.rejects(runner.complete(client,{name:'stage'}),{code:'stage_integrity_error'});assert.equal(calls,1);
});
test('provider success followed by persistence failure never resends automatically',async()=>{
 const store=new Store();const original=store.transaction.bind(store);let writes=0;
 store.transaction=(key,fn)=>original(key,tx=>fn({...tx,write:async v=>{if(++writes===2)throw Error('simulated storage loss');await tx.write(v);}}));
 let calls=0;const client={identity:'reviewer',complete:async()=>({value:++calls})};const runner=new DerivativeStageRunner(context(store));
 await assert.rejects(runner.complete(client,{name:'stage'}),/simulated storage loss/);
 await assert.rejects(runner.complete(client,{name:'stage'}),{code:'provider_outcome_unknown'});assert.equal(calls,1);
});
const {OralBlueprintReview}=require('../oral_blueprint_review');
const {GROUNDING,PEDAGOGY}=require('../oral_exam_engine');
function reviewer(overrides={}){return {identity:'independent',complete:async args=>({identity:'independent',usage:{},value:{verdicts:args.data.questions.map(q=>({questionId:q.questionId,...Object.fromEntries((args.name.endsWith('semantic')?GROUNDING:PEDAGOGY).map(k=>[k,true])),...(!args.name.endsWith('semantic')?{reason:'Fictitious test: bounded and source supported.',duplicateGroup:q.questionId,rank:80}:{}),...overrides}))}})};}
test('R23 review cannot approve unknown templates or an invalid source ledger',async()=>{
 const engine=new OralBlueprintReview({semanticReviewer:reviewer(),pedagogicalReviewer:reviewer()});
 const input=corpus.find(c=>c.id==='ORAL_6_PT');
 await assert.rejects(engine.generate({...input,verifiedFactLedger:{}}),{code:'invalid_oral_input'});
 const r=await engine.generate({rawTranscript:'Não há um template conhecido.',locale:'pt'});assert.equal(r.status,'NO_SUPPORTED_TEMPLATE');assert.equal(r.usage,undefined);
});
test('R23 semantic fail prevents pedagogical approval from overriding it',async()=>{
 let calls=0;const engine=new OralBlueprintReview({semanticReviewer:reviewer({QUALIFIER_PRESERVED:false}),pedagogicalReviewer:{identity:'other',complete:async()=>{calls++;throw Error('must not run');}}});
 const r=await engine.generate(corpus.find(c=>c.id==='ORAL_6_PT'));assert.equal(r.questions.length,0);assert.equal(calls,0);assert.deepEqual(r.rejected[0].failures,['QUALIFIER_PRESERVED']);
});
test('R23 pedagogy rejection is not padded with unapproved questions',async()=>{
 const r=await new OralBlueprintReview({semanticReviewer:reviewer(),pedagogicalReviewer:reviewer({NOT_TRIVIAL:false})}).generate(corpus.find(c=>c.id==='ORAL_6_PT'));
 assert.equal(r.questions.length,0);assert.equal(r.status,'INSUFFICIENT_APPROVED_QUESTIONS');
});
test('R23 HARD integrates two source facts without losing restrictions',async()=>{
 const input=corpus.find(c=>c.id==='ORAL_10_ES');const ledger=TranscriptFactLedger.extract(input.rawTranscript);
 const r=await new OralBlueprintReview({semanticReviewer:reviewer(),pedagogicalReviewer:reviewer()}).generate(input);
 assert.equal(r.questions.length,1);const q=r.questions[0];assert.equal(q.difficulty,'HARD');assert.equal(q.supportingFactIds.length,2);assert.match(q.expectedAnswer,/Sin X/);assert.ok(validateBlueprint(q,ledger));assert.doesNotMatch(q.question,/etapa A/);
});
test('R23 mismatched review IDs cannot authorize a bank',async()=>{
 await assert.rejects(new OralBlueprintReview({semanticReviewer:reviewer({questionId:'foreign'}),pedagogicalReviewer:reviewer()}).generate(corpus.find(c=>c.id==='ORAL_6_ES')),{code:'invalid_oral_review'});
});
for(const locale of ['pt','es'])test(`R23 list asks about order only when source discusses order ${locale}`,()=>{
 const rawTranscript=locale==='pt'?'A lista da aula contém três itens: registro, revisão e incerteza. Não completar dados ausentes.':'La lista de la clase contiene tres elementos: registro, revisión e incertidumbre. No completar datos ausentes.';
 const r=new OralBlueprintEngine().generate({rawTranscript,verifiedFactLedger:TranscriptFactLedger.extract(rawTranscript),locale});
 assert.equal(r.questions.length,1);assert.doesNotMatch(r.questions[0].question,/ordem|orden/);
});
test('R23 review reports actual provider calls separately from zero generation calls',async()=>{
 const r=await new OralBlueprintReview({semanticReviewer:reviewer(),pedagogicalReviewer:reviewer()}).generate(corpus.find(c=>c.id==='ORAL_6_PT'));
 assert.equal(r.generationProviderCalls,0);assert.equal(r.reviewProviderCalls,2);assert.equal(r.providerCalls,2);
});
const {ValidatedReviewerRouter}=require('../validated_reviewer_router');
const certificate={identity:'fallback',revision:'r23',passed:true,corpusSha256:'a'.repeat(64)};
test('reviewer fallback must have a server-owned matching validation certificate',()=>{
 const primary={identity:'primary'},fallback={identity:'fallback'};
 assert.throws(()=>new ValidatedReviewerRouter({primary,fallback,revision:'r23'}),{code:'unvalidated_reviewer_fallback'});
 assert.throws(()=>new ValidatedReviewerRouter({primary,fallback,revision:'different',certificates:[certificate]}),{code:'unvalidated_reviewer_fallback'});
});
test('reviewer uses a single validated fallback after bounded explicit rejection',async()=>{
 let primaryCalls=0,fallbackCalls=0;const routes=[];
 const router=new ValidatedReviewerRouter({primary:{identity:'primary',complete:async()=>{primaryCalls++;throw new DerivativeError('RETRYABLE_PROVIDER_LIMIT',true,{httpStatus:429,retryAfterMs:0});}},fallback:{identity:'fallback',complete:async()=>{fallbackCalls++;return {identity:'fallback',value:{}};}},certificates:[certificate],revision:'r23',retryPolicy:{sleep:async()=>{},random:()=>0},onRoute:async e=>routes.push(e)});
 const result=await router.complete({name:'oral_semantic'});assert.equal(primaryCalls,3);assert.equal(fallbackCalls,1);assert.equal(result.identity,'fallback');assert.equal(routes.length,1);
 await assert.rejects(router.complete({name:'generate_concepts'}),{code:'reviewer_route_cannot_generate'});
});
test('unknown reviewer outcome never silently invokes paid fallback',async()=>{
 let fallbackCalls=0;
 const router=new ValidatedReviewerRouter({primary:{identity:'primary',complete:async()=>{throw new DerivativeError('generation_timeout',true);}},fallback:{identity:'fallback',complete:async()=>{fallbackCalls++;}},certificates:[certificate],revision:'r23'});
 await assert.rejects(router.complete({name:'oral_semantic'}),{code:'generation_timeout'});assert.equal(fallbackCalls,0);
});
const {ExtractiveStudyFallback}=require('../extractive_study_fallback');
const {StudyGroundingVerifier}=require('../study_grounding_verifier');
for(const locale of ['pt','es'])for(const derivativeType of ['SUMMARY','VISUAL_SUMMARY','KEY_POINTS'])test(`short Study fallback ${derivativeType} ${locale} preserves qualifier without free generation`,async()=>{
 const rawTranscript=locale==='pt'?'Ontem sem febre, hoje com febre. Isso não é necessariamente uma contradição.':'Ayer sin fiebre, hoy con fiebre. Esto no es necesariamente una contradicción.';
 const ledger=TranscriptFactLedger.extract(rawTranscript);const candidate=new ExtractiveStudyFallback().generate({rawTranscript,locale,derivativeType,verifiedFactLedger:ledger});
 const verifier=new StudyGroundingVerifier({identity:'independent',independentCheck:async context=>({verifierIdentity:'independent',verdicts:context.claims.map(c=>({path:c.path,status:'SUPPORTED',sourceMisattribution:false,criticalFactDistortion:false,negationConflict:false,doseConflict:false,temporalConflict:false,allergyConflict:false}))})});
 assert.equal((await verifier.verify({rawTranscript,ledger,derivativeType,locale,candidate,generatorIdentity:candidate.generatorIdentity})).supported,true);
 assert.ok(JSON.stringify(candidate.structuredResult).includes(rawTranscript));assert.equal(candidate.usage.estimatedCost,0);assert.equal(candidate.qualityGate,'INDEPENDENT_REVIEW_REQUIRED');
});
test('short Study fallback cannot copy an entire long lecture instead of summarizing',()=>{
 assert.throws(()=>new ExtractiveStudyFallback().generate({rawTranscript:'a'.repeat(2001),locale:'pt',derivativeType:'SUMMARY'}),{code:'short_study_fallback_not_eligible'});
 assert.throws(()=>new ExtractiveStudyFallback().generate({rawTranscript:'História.',locale:'pt',derivativeType:'ANAMNESIS'}),{code:'short_study_fallback_not_eligible'});
});
const {GoogleEvidenceModelClient}=require('../google_evidence_model_client');
test('Google verifier client rejects incomplete 200 and protects retry metadata',async()=>{
 const c=new GoogleEvidenceModelClient({apiKey:'secret',fetchImpl:async()=>({ok:true,json:async()=>({candidates:[{finishReason:'MAX_TOKENS'}]})})});
 await assert.rejects(c.complete({}),{code:'output_truncated'});
 const limited=new GoogleEvidenceModelClient({apiKey:'secret',fetchImpl:async()=>({ok:false,status:429,headers:{get:()=> '3'}})});
 await assert.rejects(limited.complete({}),e=>e.code==='RETRYABLE_PROVIDER_LIMIT'&&e.metadata.retryAfterMs===3000);
});
test('Google verifier client excludes thought content and counts thinking cost',async()=>{
 const c=new GoogleEvidenceModelClient({apiKey:'secret',prices:{inputPerMillion:2,outputPerMillion:12},fetchImpl:async()=>({ok:true,json:async()=>({modelVersion:'verified-model',usageMetadata:{promptTokenCount:100,candidatesTokenCount:20,thoughtsTokenCount:30},candidates:[{finishReason:'STOP',content:{parts:[{thought:true,text:'private reasoning'},{text:'{"ok":true}'}]}}]})})});
 const r=await c.complete({});assert.deepEqual(r.value,{ok:true});assert.equal(r.identity,'google/verified-model');assert.equal(r.usage.estimatedCost,0.0008);
});
