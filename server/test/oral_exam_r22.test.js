'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {TranscriptFactLedger}=require('../transcript_fact_ledger');
const {OralExamEngine,VERSION,verifyConcept,assembleQuestion,GROUNDING,PEDAGOGY}=require('../oral_exam_engine');
const {corpus}=require('./oral_exam_r22_corpus');
function fixture(raw='Alfa pode aumentar Z em alguns casos.',locale='pt'){
 const ledger=TranscriptFactLedger.extract(raw);const facts=ledger.facts;const concept={conceptId:'c',conceptText:'Alfa',supportingFactIds:facts.map(f=>f.factId),sourceEvidence:facts.map(f=>({factId:f.factId,quote:f.value})),eligibleDifficultyRange:['EASY','MEDIUM','HARD']};
 return {rawTranscript:raw,verifiedFactLedger:ledger,locale,difficultyTarget:'EASY',questionCount:3,promptVersion:VERSION,concept,selection:{conceptId:'c',questionType:'RECALL',difficulty:'EASY',anchorTexts:['Alfa'],answerFactIds:facts.map(f=>f.factId)}};
}
function makeEngine(f,{semanticFail=null,pedagogicalFail=null,count=2}={}){
 const generator={identity:'generator',complete:async a=>({identity:'generator',usage:{},value:a.name==='oral_concepts_r22'?{concepts:[f.concept]}:{candidates:Array.from({length:count},()=>f.selection)}})};
 const client=(identity,pedagogy)=>({identity,complete:async a=>({identity,usage:{},value:{verdicts:a.data.questions.map((q,i)=>({questionId:q.questionId,...Object.fromEntries((pedagogy?PEDAGOGY:GROUNDING).map(k=>[k,k!==(pedagogy?pedagogicalFail:semanticFail)])),...(pedagogy?{duplicateGroup:'same-concept',rank:90-i}:{})}))}})});
 return new OralExamEngine({generator,semanticReviewer:client('critic',false),pedagogicalReviewer:client('teacher',true)});
}
for(const locale of ['pt','es'])test(`${locale}: selected facts build answer before neutral localized question; preserve exact qualifiers`,async()=>{
 const f=fixture(locale==='pt'?'Alfa pode aumentar Z em alguns casos.':'Alfa puede aumentar Z en algunos casos.',locale);const r=await makeEngine(f).generate(f);
 assert.equal(r.generated,2);assert.equal(r.questions.length,1);assert.equal(r.questions[0].expectedAnswer,f.rawTranscript);assert.equal(r.questions[0].sourceEvidence[0].sourceStartOffset,0);assert.equal(r.questions[0].sourceEvidence[0].sourceEndOffset,f.rawTranscript.length);assert.match(r.questions[0].question,locale==='pt'?/fonte/:/fuente/);
});
for(const c of corpus)test(`${c.id}: quotes preserve all content and source offsets`,()=>{
 const f=fixture(c.rawTranscript,c.locale);f.concept.conceptText=c.rawTranscript.match(/[\p{L}]{5,}/u)[0];f.selection.anchorTexts=[f.concept.conceptText];assert.equal(verifyConcept(f.concept,f.verifiedFactLedger),true);
 const q=assembleQuestion(f.concept,f.selection,f.verifiedFactLedger,c.locale,0,'EASY');assert.ok(!q.rejected);assert.equal(q.expectedAnswer,f.verifiedFactLedger.facts.map(f=>f.value.trim()).join('\n\n'));
});
test('forged concepts and altered source quote cannot become questions',()=>{
 const f=fixture();f.concept.sourceEvidence[0].quote='Alfa aumenta Z sempre.';assert.equal(verifyConcept(f.concept,f.verifiedFactLedger),false);
 f.concept.sourceEvidence[0].quote=f.rawTranscript;f.concept.supportingFactIds=['missing'];assert.equal(verifyConcept(f.concept,f.verifiedFactLedger),false);
});
test('unreferenced answer and invented premise rejected before critic',()=>{
 const f=fixture();for(const change of [{answerFactIds:['bad']},{anchorTexts:['Alfa aumenta sempre']},{anchorTexts:['14:00']},{anchorTexts:['50 mg']}])assert.ok(assembleQuestion(f.concept,{...f.selection,...change},f.verifiedFactLedger,'pt',0,'MIXED').rejected);
});
test('causality cannot be inferred from co-occurrence',()=>{
 const f=fixture('Alfa aparece com Beta. Não se afirmou que Alfa causa Beta.');assert.equal(assembleQuestion(f.concept,{...f.selection,questionType:'CAUSE_EFFECT',difficulty:'MEDIUM'},f.verifiedFactLedger,'pt',0,'MIXED').rejected,'UNSUPPORTED_RELATIONSHIP');
});
test('HARD requires multiple distinct facts and relation instead of recall',()=>{
 const f=fixture();assert.equal(assembleQuestion(f.concept,{...f.selection,difficulty:'HARD'},f.verifiedFactLedger,'pt',0,'HARD').rejected,'DIFFICULTY_TYPE_MISMATCH');
 const g=fixture('Alfa depende de Beta.');assert.equal(assembleQuestion(g.concept,{...g.selection,difficulty:'HARD',questionType:'EXPLANATION'},g.verifiedFactLedger,'pt',0,'HARD').rejected,'HARD_REQUIRES_MULTIPLE_DISTINCT_FACTS');
});
test('failed semantic review never reaches pedagogy',async()=>{
 const f=fixture();const e=makeEngine(f,{semanticFail:'QUALIFIER_PRESERVED'});e.pedagogicalReviewer.complete=async()=>{throw Error('must not call');};const r=await e.generate(f);assert.equal(r.questions.length,0);assert.equal(r.groundingPassed,0);
});
test('grounding pass is insufficient when pedagogy fails; no padding',async()=>{
 const f=fixture();const r=await makeEngine(f,{pedagogicalFail:'DIFFICULTY_MATCH'}).generate(f);assert.equal(r.groundingPassed,2);assert.equal(r.pedagogicalPassed,0);assert.equal(r.questions.length,0);
});
test('same generator cannot self-certify either review',async()=>{
 const f=fixture();const e=makeEngine(f);e.semanticReviewer.identity='generator';await assert.rejects(e.generate(f),{code:'independent_oral_review_required'});
});
test('missing source ledger and incompatible prompt fail before provider',async()=>{
 const f=fixture();const e=makeEngine(f);await assert.rejects(e.generate({...f,promptVersion:'old'}),{code:'invalid_oral_input'});await assert.rejects(e.generate({...f,verifiedFactLedger:{}}),{code:'invalid_oral_input'});
});
test('independent semantic dedup collapses differing concept IDs',async()=>{
 const f=fixture('Alfa pode aumentar Z. Beta pode aumentar Z.');const e=makeEngine(f);e.generator.complete=async a=>({identity:'generator',value:a.name==='oral_concepts_r22'?{concepts:[f.concept,{...f.concept,conceptId:'other',conceptText:'Beta'}]}:{candidates:[f.selection,{...f.selection,conceptId:'other',anchorTexts:['Beta']}]}});
 const r=await e.generate(f);assert.equal(r.pedagogicalPassed,2);assert.equal(r.questions.length,1);assert.ok(r.rejections.some(r=>r.stage==='dedup'));
});
test('a malformed dedup group rejects that question rather than accepting it or losing valid siblings',async()=>{
 const f=fixture('Alfa pode aumentar Z. Beta pode reduzir Y.');const e=makeEngine(f);const old=e.pedagogicalReviewer.complete;
 e.pedagogicalReviewer.complete=async a=>{const r=await old(a);r.value.verdicts[0].duplicateGroup='';r.value.verdicts[1].duplicateGroup='valid';return r;};
 const r=await e.generate(f);assert.equal(r.questions.length,1);assert.equal(r.pedagogicalPassed,1);assert.ok(r.rejections.some(x=>x.failures?.includes('MISSING_DEDUP_GROUP')));
});
test('explicit negative causal statements cannot authorize a positive causal question',()=>{
 const f=fixture('Alfa não causa Beta.');assert.equal(assembleQuestion(f.concept,{...f.selection,questionType:'CAUSE_EFFECT',difficulty:'MEDIUM'},f.verifiedFactLedger,'pt',0,'MIXED').rejected,'UNSUPPORTED_RELATIONSHIP');
});
test('HARD selection request is supplied before concepts are generated',async()=>{
 const f=fixture();f.difficultyTarget='HARD';const e=makeEngine(f);let seen=false;const old=e.generator.complete;e.generator.complete=async a=>{if(a.name==='oral_concepts_r22'){assert.match(a.system,/Requested difficulty is HARD/);seen=true;}return old(a);};
 const r=await e.generate(f);assert.equal(seen,true);assert.equal(r.questions.length,0);
});
test('different client aliases cannot bypass actual generator identity isolation',async()=>{
 const f=fixture();const e=makeEngine(f);const old=e.semanticReviewer.complete;e.semanticReviewer.complete=async a=>({...await old(a),identity:'generator'});await assert.rejects(e.generate(f),{code:'independent_oral_review_required'});
});
test('comparison does not presume similarities absent from the source or reveal the taught answer',()=>{
 const f=fixture('Alfa é reversível, enquanto Beta não é reversível.');const select={...f.selection,questionType:'COMPARISON',difficulty:'MEDIUM',anchorTexts:['Alfa','Beta']};
 const q=assembleQuestion(f.concept,select,f.verifiedFactLedger,'pt',0,'MEDIUM');assert.ok(!q.rejected);assert.doesNotMatch(q.question,/semelhanças|reversível/);assert.equal(q.expectedAnswer,f.rawTranscript);
 assert.equal(assembleQuestion(f.concept,{...select,anchorTexts:['Alfa é reversível','Beta']},f.verifiedFactLedger,'pt',0,'MEDIUM').rejected,'ANSWER_REVEALING_ANCHOR');
 assert.equal(assembleQuestion(f.concept,{...select,anchorTexts:['Alfa','Beta','reversível']},f.verifiedFactLedger,'pt',0,'MEDIUM').rejected,'COMPARISON_REQUIRES_TWO_ANCHORS');
});
test('a genuine one-letter source topic is allowed without inventing a replacement name',()=>{
 const f=fixture('Primeiro registrar X, depois revisar Y.');f.concept.conceptText='X';const q=assembleQuestion(f.concept,{...f.selection,questionType:'SEQUENCE',difficulty:'MEDIUM',anchorTexts:['X','Y']},f.verifiedFactLedger,'pt',0,'MEDIUM');assert.ok(!q.rejected);assert.match(q.question,/«X»/);
});
