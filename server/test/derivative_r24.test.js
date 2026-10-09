'use strict';
const test=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');
const {corpus}=require('./oral_exam_r23_corpus');const {TranscriptFactLedger}=require('../transcript_fact_ledger');const {OralBlueprintEngine,validateBlueprint}=require('../oral_blueprint_engine');
for(const c of corpus)test(`R24 source coverage ${c.id}`,()=>{
 const ledger=TranscriptFactLedger.extract(c.rawTranscript);const bank=new OralBlueprintEngine().generate({...c,verifiedFactLedger:ledger});
 if(c.scenario===8){assert.equal(bank.questions.length,0);return;}
 assert.ok(bank.questions.length>0,'Teachable source must have a compatible template');
 for(const q of bank.questions){assert.ok(validateBlueprint(q,ledger));assert.equal(q.expectedAnswer,q.supportingFactIds.map(id=>ledger.facts.find(f=>f.factId===id).value.trim()).join('\n\n'));if(q.difficulty==='HARD')assert.equal(q.supportingFactIds.length,2);}
});
test('R24 preserves every previously approved question and answer without freeing generator',()=>{
 const old=fs.readFileSync('audit/derivative_r23/oral-blueprint-v4.jsonl','utf8').trim().split('\n').map(JSON.parse);
 let count=0;for(const row of old){const c=corpus.find(c=>c.id===row.caseId);const bank=new OralBlueprintEngine().generate({...c,verifiedFactLedger:TranscriptFactLedger.extract(c.rawTranscript)});for(const q of row.result.questions){assert.ok(bank.questions.some(n=>n.question===q.question&&n.expectedAnswer===q.expectedAnswer&&n.difficulty===q.difficulty));count++;}}
 assert.equal(count,33);
});
for(const scenario of [1,2,5,7,11,12,13])test(`R24 new family rejects changed grounding ${scenario}`,()=>{
 const c=corpus.find(c=>c.scenario===scenario&&c.locale==='pt');const ledger=TranscriptFactLedger.extract(c.rawTranscript);const bank=new OralBlueprintEngine().generate({...c,verifiedFactLedger:ledger});
 for(const q of bank.questions){assert.equal(validateBlueprint({...q,expectedAnswer:q.expectedAnswer+' sempre'},ledger),false);assert.equal(validateBlueprint({...q,requiredQualifiers:[]},ledger),q.requiredQualifiers.length===0);assert.equal(validateBlueprint({...q,sourceHashes:['invalid']},ledger),false);assert.equal(validateBlueprint({...q,question:'O que é importante?'},ledger),false);}
});
test('Unknown grammar remains unresolved and is never labelled insufficient automatically',()=>{
 const rawTranscript='A fotossíntese transforma energia luminosa em energia química.';const bank=new OralBlueprintEngine().generate({rawTranscript,locale:'pt',verifiedFactLedger:TranscriptFactLedger.extract(rawTranscript)});
 assert.equal(bank.status,'NO_SUPPORTED_TEMPLATE');
});
for(const locale of ['pt','es'])test(`R24 temporal visual keeps all values and not-necessarily qualifier ${locale}`,()=>{
 const rawTranscript=locale==='pt'?'Ontem sem febre, hoje com febre: evolução temporal. Isso não é necessariamente uma contradição.':'Ayer sin fiebre, hoy con fiebre: evolución temporal. Esto no es necesariamente una contradicción.';
 const {ExtractiveStudyFallback}=require('../extractive_study_fallback');const r=new ExtractiveStudyFallback().generate({rawTranscript,locale,derivativeType:'VISUAL_SUMMARY'});
 assert.equal(r.structuredResult.sections.length,2);for(const x of r.structuredResult.sections)assert.ok(rawTranscript.toLowerCase().includes(x.body.toLowerCase()));assert.match(r.structuredResult.takeaway,/n(?:ão|o) (?:é|es) neces?s?ariamente/u);assert.ok(rawTranscript.includes(r.structuredResult.takeaway));
});
test('Pedagogical gate uses a dedicated source-and-output review, not grounding metrics',async()=>{
 const {StudyPedagogicalReviewer}=require('../study_pedagogical_reviewer');const {StudyQualityGate,METRICS}=require('../study_quality_gate');const {hash}=require('../derivative_contract');let calls=0;
 const candidate={structuredResult:{points:['source point']}};
 const reviewer=new StudyPedagogicalReviewer({identity:'independent',complete:async request=>{calls++;assert.equal(request.data.rawTranscript,'source point');assert.deepEqual(request.data.structuredResult,candidate.structuredResult);assert.equal(request.data.claims,undefined);return {identity:'independent',value:{metrics:METRICS.KEY_POINTS.map(name=>({name,status:name==='RELEVANCE'?'FAIL':'PASS',reason:'Specific source-based finding'}))}};}});
 const result=await new StudyQualityGate({identity:reviewer.identity,independentCheck:c=>reviewer.review(c)}).verify({rawTranscript:'source point',derivativeType:'KEY_POINTS',locale:'pt',candidate,generatorIdentity:'generator',grounding:{supported:true,outputHash:hash(JSON.stringify(candidate.structuredResult)),metrics:METRICS.KEY_POINTS.map(name=>({name,status:'PASS'}))}});
 assert.equal(calls,1);assert.equal(result.passed,false);
});
test('Pedagogical reviewer does not accept another provider identity',async()=>{
 const {StudyPedagogicalReviewer}=require('../study_pedagogical_reviewer');const reviewer=new StudyPedagogicalReviewer({identity:'certified',complete:async()=>({identity:'other',value:{metrics:[]}})});
 await assert.rejects(reviewer.review({derivativeType:'SUMMARY'}),{code:'invalid_pedagogical_review'});
});
test('Temporal example visual preserves dose unit and non-prescription warning',()=>{
 const {ExtractiveStudyFallback}=require('../extractive_study_fallback');const rawTranscript='Ejemplo ficticio: Test-A 5 mg una vez al día. Esto no es prescripción para un paciente.';
 const r=new ExtractiveStudyFallback().generate({rawTranscript,locale:'es',derivativeType:'VISUAL_SUMMARY'});assert.equal(r.structuredResult.sections[0].body,'Test-A 5 mg una vez al día.');assert.equal(r.structuredResult.sections[1].body,'Esto no es prescripción para un paciente.');assert.equal(r.structuredResult.overview,'');assert.equal(r.structuredResult.takeaway,'');assert.equal(r.structuredResult.sections.length,2);
});
test('Semantic reviewer rejects missing per-claim verdicts even if provider returned successfully',async()=>{
 const {StudySemanticReviewer}=require('../study_semantic_reviewer');const reviewer=new StudySemanticReviewer({identity:'certified',complete:async()=>({identity:'certified',value:{verdicts:[]},usage:{inputTokens:10,outputTokens:2}})});
 await assert.rejects(reviewer.review({claims:[{path:'/title'}],candidate:{structuredResult:{title:'x'}}}),error=>error.code==='incomplete_semantic_review'&&error.metadata.expectedVerdicts===1&&error.metadata.usage.inputTokens===10);
});
test('Semantic reviewer rejects duplicate verdict paths and preserves cost evidence',async()=>{
 const {StudySemanticReviewer}=require('../study_semantic_reviewer');const v={path:'/title',reason:'source supported',status:'SUPPORTED',sourceMisattribution:false,criticalFactDistortion:false,negationConflict:false,doseConflict:false,temporalConflict:false,allergyConflict:false};
 const reviewer=new StudySemanticReviewer({identity:'certified',complete:async()=>({identity:'certified',value:{verdicts:[v,v]},usage:{estimatedCost:0.01}})});
 await assert.rejects(reviewer.review({claims:[{path:'/title'},{path:'/body'}],candidate:{structuredResult:{title:'x',body:'y'}}}),{code:'incomplete_semantic_review'});
});
for(const locale of ['pt','es'])test(`Inline concepts retain parent ledger and decimal values ${locale}`,()=>{
 const lead=(locale==='pt'?'Contexto da aula sem instruções. ':'Contexto de la clase sin instrucciones. ').repeat(100);
 const sentence=locale==='pt'?'A solução didática é uma mistura fictícia com 0.5 mg por 2.5 mL, não uma prescrição.':'La solución didáctica es una mezcla ficticia con 0.5 mg por 2.5 mL, no una prescripción.';
 const raw=lead+sentence+' '+(locale==='pt'?'Não aplicar a pacientes.':'No aplicar a pacientes.');const ledger=TranscriptFactLedger.extract(raw);assert.equal(ledger.facts.length,1);
 const bank=new OralBlueprintEngine().generate({rawTranscript:raw,verifiedFactLedger:ledger,locale,questionCount:10});assert.equal(bank.questions.length,1);const q=bank.questions[0];assert.ok(validateBlueprint(q,ledger));assert.ok(q.expectedAnswer.includes(sentence));assert.match(q.expectedAnswer,/0\.5 mg por 2\.5 mL/u);assert.ok(q.expectedAnswer.includes(locale==='pt'?'Não aplicar':'No aplicar'));assert.equal(q.parentSourceHashes[0],ledger.facts[0].sourceQuoteHash);
 assert.equal(validateBlueprint({...q,expectedAnswer:q.expectedAnswer.replace('0.5','5')},ledger),false);
});
test('Inline source language is independent of question locale',()=>{
 const raw='Contexto ficticio. '.repeat(220)+'La trazabilidad documental es la vinculación explícita entre una afirmación y su fuente. No implica validar la verdad externa.';const ledger=TranscriptFactLedger.extract(raw);const b=new OralBlueprintEngine().generate({rawTranscript:raw,verifiedFactLedger:ledger,locale:'pt'});assert.equal(b.questions.length,1);assert.match(b.questions[0].question,/Como a fonte/u);assert.ok(b.questions[0].expectedAnswer.includes('No implica'));
});
test('Inline generic pronouns do not manufacture teachable subjects',()=>{
 const raw='Contexto ficticio. '.repeat(220)+'Esto es lo que ocurrió después. El paciente es el ejemplo de la clase.';const b=new OralBlueprintEngine().generate({rawTranscript:raw,verifiedFactLedger:TranscriptFactLedger.extract(raw),locale:'es'});assert.equal(b.questions.length,0);
});
test('Inline review sees full context including a distant correction outside cited excerpt',async()=>{
 const {OralBlueprintReview}=require('../oral_blueprint_review');const {GROUNDING}=require('../oral_exam_engine');
 const raw='Contexto fictício. '.repeat(220)+'A rastreabilidade documental é a confirmação da verdade externa. '+'Discussão metodológica sem nova definição. '.repeat(50)+'Correção: a rastreabilidade documental não confirma a verdade externa; indica a ligação entre afirmação e fonte.';
 let calls=0;const reviewer={identity:'independent-test',complete:async args=>{calls++;assert.ok(args.data.verifiedFactLedger.facts[0].value.endsWith('indica a ligação entre afirmação e fonte.'));assert.ok(args.data.questions[0].citedSource[0].text.length<raw.length);return {identity:'independent-test',value:{verdicts:args.data.questions.map(q=>({questionId:q.questionId,...Object.fromEntries(GROUNDING.map(k=>[k,false]))}))}};}};
 const result=await new OralBlueprintReview({semanticReviewer:reviewer,pedagogicalReviewer:reviewer}).generate({rawTranscript:raw,locale:'pt',questionCount:10});assert.equal(calls,1);assert.equal(result.questions.length,0);assert.equal(result.status,'INSUFFICIENT_APPROVED_QUESTIONS');
});
test('Inline expansion preserves all 41 approved R24 corpus questions',()=>{
 const rows=fs.readFileSync('audit/derivative_r24/oral-blueprint-v4.jsonl','utf8').trim().split('\n').map(JSON.parse);let count=0;
 for(const r of rows){const c=corpus.find(c=>c.id===r.caseId);const bank=new OralBlueprintEngine().generate({...c,verifiedFactLedger:TranscriptFactLedger.extract(c.rawTranscript)});for(const q of r.result.questions){assert.ok(bank.questions.some(n=>JSON.stringify(n)===JSON.stringify(q)));count++;}}assert.equal(count,41);
});
test('Source-term preservation restores only a source-supported label, not other numbers',()=>{
 const {preserveSourceTerms}=require('../study_source_term_preserver');const candidate={structuredResult:{title:'COVID-19',points:['COVID 19: observação da aula','Exemplo 19 mg']},claims:[{path:'/title'}]};const snapshot=JSON.stringify(candidate);
 const r=preserveSourceTerms({rawTranscript:'A aula menciona covid sem informação adicional.',derivativeType:'KEY_POINTS',candidate});assert.equal(JSON.stringify(candidate),snapshot);assert.equal(r.changes.length,2);assert.equal(r.candidate.structuredResult.title,'covid');assert.equal(r.candidate.structuredResult.points[1],'Exemplo 19 mg');assert.deepEqual(r.candidate.claims,candidate.claims);
});
for(const [rawTranscript,derivativeType] of [['Sem esse termo.','SUMMARY'],['A aula menciona COVID-19.','SUMMARY'],['COVID na fonte.','ANAMNESIS'],['COVID na fonte.','EVOLUTION'],['COVID na fonte.','ORGANIZATION']])test(`Source-term scope remains strict ${rawTranscript} ${derivativeType}`,()=>{
 const {preserveSourceTerms}=require('../study_source_term_preserver');const candidate={structuredResult:{title:'COVID-19'}};const r=preserveSourceTerms({rawTranscript,derivativeType,candidate});assert.deepEqual(r.candidate,candidate);assert.equal(r.changes.length,0);
});
test('Source-term guard preserves all 60 approved corpus candidates byte for byte',()=>{
 const {preserveSourceTerms}=require('../study_source_term_preserver');const cases=require('./derivative_r21_corpus').corpus;const gate=JSON.parse(fs.readFileSync('audit/derivative_r24/study-quality-gate.json','utf8'));let checked=0;
 for(const row of gate.rows){const rows=fs.readFileSync(row.evidence,'utf8').trim().split('\n').map(JSON.parse);const item=rows.find(r=>`${r.caseId}/${r.type}`===row.key);assert.ok(item,row.key);const source=cases.find(c=>c.id===item.caseId);const r=preserveSourceTerms({rawTranscript:source.rawTranscript,derivativeType:item.type,candidate:item.candidate});assert.deepEqual(r.candidate,item.candidate);assert.equal(r.changes.length,0);checked++;}assert.equal(checked,60);
});
test('Key points template requires independently approved summary and preserves decimals/qualifiers',()=>{
 const {keyPointsFromApprovedSummary}=require('../study_summary_key_points');const {hash}=require('../derivative_contract');const candidate={structuredResult:{title:'Fonte fictícia',sections:[{title:'Exemplo',body:'A mistura contém 0.5 mg por 2.5 mL. Não é uma prescrição.'}]},claims:['/title','/sections/0/title','/sections/0/body'].map(path=>({path,kind:'SOURCE_FACT',supportingFactIds:['fact']}))};
 const input={candidate,locale:'pt',grounding:{supported:true,outputHash:hash(JSON.stringify(candidate.structuredResult))},pedagogicalQuality:{passed:true}};const r=keyPointsFromApprovedSummary(input);assert.equal(require('../derivative_contract').isCompleteResult('KEY_POINTS',r.candidate.structuredResult),true);assert.equal(r.generationProviderCalls,0);assert.equal(r.requiresIndependentReview,true);assert.equal(r.candidate.structuredResult.points.length,2);assert.match(r.candidate.structuredResult.points[0],/0\.5 mg por 2\.5 mL/u);assert.match(r.candidate.structuredResult.points[1],/Não é uma prescrição/u);assert.throws(()=>keyPointsFromApprovedSummary({...input,pedagogicalQuality:{passed:false}}),{code:'approved_summary_required'});
});
test('Batched reviewer retains full source and output, rejects incomplete batches, totals cost once',async()=>{
 const {StudyBatchedSemanticReviewer}=require('../study_batched_semantic_reviewer');const claims=Array.from({length:23},(_,i)=>({path:'/points/'+i}));let calls=0;const client={identity:'reviewer',complete:async args=>{calls++;assert.equal(args.data.sourceTranscript,'FULL SOURCE WITH LATE CORRECTION');assert.deepEqual(args.data.outputStructure,{points:['complete output']});return {identity:'reviewer',usage:{inputTokens:100,outputTokens:10,estimatedCost:.01},value:{verdicts:Object.fromEntries(args.data.claimsToReview.map((c,i)=>['v'+i,{path:c.path,reason:'checked against full source',status:'SUPPORTED',sourceMisattribution:false,criticalFactDistortion:false,negationConflict:false,doseConflict:false,temporalConflict:false,allergyConflict:false}]))}};}};
 const context={rawTranscript:'FULL SOURCE WITH LATE CORRECTION',ledger:{facts:['all']},candidate:{structuredResult:{points:['complete output']}},claims};const r=await new StudyBatchedSemanticReviewer(client).review(context);assert.equal(calls,5);assert.equal(r.verdicts.length,23);assert.equal(r.usage.estimatedCost,.05);
 await assert.rejects(new StudyBatchedSemanticReviewer({identity:'reviewer',complete:async()=>({identity:'reviewer',value:{verdicts:[]}})}).review(context),{code:'incomplete_semantic_review'});
});
