'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {TranscriptFactLedger}=require('../transcript_fact_ledger');
const {DerivativeGroundingVerifier}=require('../derivative_grounding_verifier');
const {ExtractiveDerivativeEngine,candidateFor}=require('../extractive_derivative_engine');
const {StudyGroundingVerifier}=require('../study_grounding_verifier');
const {DerivativePolicy,CLINICAL,STUDY}=require('../derivative_policy');
const {hash}=require('../derivative_contract');const {corpus}=require('./derivative_r21_corpus');
const identity='critic-independent';
const supported=({claims})=>({verifierIdentity:identity,verdicts:claims.map(c=>({path:c.path,status:'SUPPORTED',sourceMisattribution:false,criticalFactDistortion:false,negationConflict:false,doseConflict:false,temporalConflict:false,allergyConflict:false}))});
for(const c of corpus) {
 test(`${c.id}: ledger has immutable exact complete evidence`,()=>{
  const l=TranscriptFactLedger.extract(c.rawTranscript);
  assert.equal(l.facts.map(f=>f.value).join(''),c.rawTranscript);
  assert.ok(TranscriptFactLedger.validate(c.rawTranscript,l));
  assert.ok(l.facts.every(f=>TranscriptFactLedger.validateFact(c.rawTranscript,f)));
  assert.ok(Object.isFrozen(l.facts[0]));
  const tampered=structuredClone(l);tampered.facts[0].value='invented';assert.equal(TranscriptFactLedger.validate(c.rawTranscript,tampered),false);
 });
 if(c.profile==='CLINICAL_DOCUMENTATION') for(const type of CLINICAL) test(`${c.id}: ${type} exact fallback`,async()=>{
  const r=await new ExtractiveDerivativeEngine().generate({...c,transcriptHash:hash(c.rawTranscript),derivativeType:type});
  assert.equal(r.grounding.supported,true);assert.equal(r.grounding.factsCovered,r.grounding.factsTotal);
 });
}
for(const type of CLINICAL) for(const change of [
 ['negação','Paciente usa losartana.'],['dose','Paciente usa Test-A 50 mg.'],['horário','A dor começou às 14:00.'],
 ['alergia','Paciente tem alergia à penicilina.'],['diagnóstico','Diagnóstico confirmado de pneumonia.'],['procedimento','Cirurgia realizada.']]) {
 test(`${type}: rejects unsupported ${change[0]}`,()=>{
  const raw='Paciente não usa losartana. Considerar pneumonia. Alergias não mencionadas.';
  const ledger=TranscriptFactLedger.extract(raw);const candidate=candidateFor(type,'pt',ledger);
  const path=candidate.claims.find(c=>!c.path.endsWith('/time')).path.split('/').slice(1);
  let target=candidate.structuredResult;for(const k of path.slice(0,-1))target=target[k];target[path.at(-1)]=change[1];
  assert.equal(new DerivativeGroundingVerifier().verify({rawTranscript:raw,ledger,derivativeType:type,locale:'pt',candidate}).supported,false);
 });
}
test('policy separates profiles and does not authorize enriched study',()=>{
 const p=new DerivativePolicy();for(const type of [...CLINICAL,...STUDY]) {
  const r=p.resolve({derivativeType:type,locale:'pt',rawTranscript:'source'});
  assert.equal(r.profile,CLINICAL.includes(type)?'CLINICAL_DOCUMENTATION':'STUDY');
  assert.equal(r.strategy,CLINICAL.includes(type)?'STRICT_EXTRACTIVE':'STUDY_GENERATIVE');
  assert.throws(()=>p.resolve({derivativeType:type,locale:'pt',rawTranscript:'source',knowledgeMode:'STUDY_ENRICHED'}),{code:'enrichment_not_authorized'});
 }
});
test('study is not forced through strict extractive engine',async()=>{
 await assert.rejects(new ExtractiveDerivativeEngine().generate({rawTranscript:'source',transcriptHash:hash('source'),locale:'pt',derivativeType:'SUMMARY'}),{code:'study_requires_generative_profile'});
});
function studyFixture(text='IECA: lembrar da tosse como efeito adverso importante.') {
 const rawTranscript='IECA podem causar tosse.';const ledger=TranscriptFactLedger.extract(rawTranscript);
 return {rawTranscript,ledger,derivativeType:'KEY_POINTS',locale:'pt',generatorIdentity:'generator',
 candidate:{structuredResult:{points:[text]},claims:[{path:'/points/0',kind:'EDUCATIONAL_TRANSFORMATION',supportingFactIds:[ledger.facts[0].factId]}]}};
}
test('supported pedagogical paraphrase is not rejected for string inequality (verifier contract fixture)',async()=>{
 const r=await new StudyGroundingVerifier({identity,independentCheck:supported}).verify(studyFixture());assert.equal(r.supported,true);
});
test('study requires independent semantic validation even with valid spans',async()=>{
 assert.equal((await new StudyGroundingVerifier({identity:'generator',independentCheck:supported}).verify(studyFixture())).supported,false);
});
test('independent checker can reject invented patient event despite valid source citation',async()=>{
 const r=await new StudyGroundingVerifier({identity,independentCheck:async i=>{
  const r=supported(i);r.verdicts[0].status='UNSUPPORTED';r.verdicts[0].sourceMisattribution=true;return r;
 }}).verify(studyFixture('Paciente teve tosse após iniciar enalapril.'));assert.equal(r.supported,false);
});
test('unsupported dose or time rejected before semantic checker',async()=>{
 let calls=0;const v=new StudyGroundingVerifier({identity,independentCheck:async i=>{calls++;return supported(i);}});
 assert.equal((await v.verify(studyFixture('IECA 50 mg às 14:00.'))).supported,false);assert.equal(calls,0);
});
test('forged ledger, missing verdict and missing citation fail closed',async()=>{
 const v=new StudyGroundingVerifier({identity,independentCheck:async()=>({verifierIdentity:identity,verdicts:[]})});
 assert.equal((await v.verify(studyFixture())).supported,false);
 const i=studyFixture();i.candidate.claims=[];assert.equal((await v.verify(i)).supported,false);
 const j=studyFixture();j.ledger={...j.ledger,transcriptHash:hash('another')};assert.equal((await v.verify(j)).supported,false);
});

test('ledger readback accepts reordered document keys, rejects changed evidence',()=>{
 const raw='Alergias: não mencionadas.';const ledger=TranscriptFactLedger.extract(raw);
 const reordered=Object.fromEntries(Object.entries(ledger).reverse());assert.equal(TranscriptFactLedger.validate(raw,reordered),true);
});
test('explicit anamnesis labels populate fields; absence never becomes denial',async()=>{
 const raw='Alergias: alergia a Test-B.\n\nMedicações: não usa Test-A.\n\nRefere dor desde ontem.';
 const result=await new ExtractiveDerivativeEngine().generate({rawTranscript:raw,transcriptHash:hash(raw),locale:'pt',derivativeType:'ANAMNESIS'});
 assert.match(result.structuredResult.allergies,/Test-B/);assert.match(result.structuredResult.medications,/não usa/);
 assert.equal(result.structuredResult.pastMedicalHistory,null);assert.equal(result.structuredResult.familyHistory,null);
});
test('correct quote in wrong clinical field is rejected',()=>{
 const raw='Medicações: Test-A 5 mg.';const ledger=TranscriptFactLedger.extract(raw);const c=candidateFor('ANAMNESIS','pt',ledger);
 c.structuredResult.allergies=c.structuredResult.medications;c.structuredResult.medications=null;c.claims[0].path='/allergies';
 assert.equal(new DerivativeGroundingVerifier().verify({rawTranscript:raw,ledger,derivativeType:'ANAMNESIS',locale:'pt',candidate:c}).supported,false);
});
test('time is never inherited or inferred from yesterday or narrative clauses',()=>{
 for(const raw of ['Dor desde ontem.','Às 09:00 falou A. B relatou dor.','[09:00] Observação. Às 10:00 houve mudança.'])assert.equal(TranscriptFactLedger.extract(raw).facts[0].timestampIfExplicit,null);
 assert.equal(TranscriptFactLedger.extract('[09:00] Relato registrado.').facts[0].timestampIfExplicit,'09:00');
});

test('rooted JSON pointers normalize deterministically without duplicate bypass',async()=>{
 const fixture=studyFixture();fixture.candidate.claims[0].path='/structuredResult/points/0';
 const verifier=new StudyGroundingVerifier({identity,independentCheck:supported});
 assert.equal((await verifier.verify(fixture)).supported,true);
 fixture.candidate.claims.push({...fixture.candidate.claims[0],path:'/points/0'});
 assert.equal((await verifier.verify(fixture)).supported,false);
});
test('study cache policy includes profile and route revision',()=>{
 const input={ownerUid:'u',transcriptHash:hash('source'),promptVersion:'r21',derivativeType:'SUMMARY',locale:'pt',rawTranscript:'source'};
 const a=new DerivativePolicy({SUMMARY:{revision:'a'}}).resolve(input);
 const b=new DerivativePolicy({SUMMARY:{revision:'b'}}).resolve(input);
 assert.notEqual(DerivativePolicy.cacheKey(input,a),DerivativePolicy.cacheKey(input,b));
 assert.notEqual(DerivativePolicy.cacheKey(input,a),DerivativePolicy.cacheKey({...input,ownerUid:'other'},a));
});
test('missing source spans, changed doses and deleted negations cannot enter fact ledger',()=>{
 const raw='Paciente não usa Test-A 5 mg.';const ledger=TranscriptFactLedger.extract(raw);
 for(const changes of [{value:'Paciente usa Test-A 5 mg.'},{value:'Paciente não usa Test-A 50 mg.'},{sourceStartOffset:-1},{sourceEndOffset:999},{sourceQuoteHash:hash('elsewhere')},{timestampIfExplicit:'14:00'},{speaker:'Paciente'}])assert.equal(TranscriptFactLedger.validateFact(raw,{...ledger.facts[0],...changes}),false);
});

test('JSONPath evidence syntax is normalized without executing expressions',async()=>{
 const fixture=studyFixture();fixture.candidate.claims[0].path='$.structuredResult.points[0]';
 const v=new StudyGroundingVerifier({identity,independentCheck:supported});assert.equal((await v.verify(fixture)).supported,true);
 fixture.candidate.claims[0].path='$.points[process.exit()]';assert.equal((await v.verify(fixture)).supported,false);
});
test('heading references derived from body still require semantic review',async()=>{
 const rawTranscript='IECA podem causar tosse.';const ledger=TranscriptFactLedger.extract(rawTranscript);
 const fixture={rawTranscript,ledger,derivativeType:'SUMMARY',locale:'pt',generatorIdentity:'generator',candidate:{structuredResult:{title:'Diagnóstico de pneumonia',sections:[{title:'Tosse',body:'IECA podem causar tosse.'}]},claims:[{path:'/sections/0/body',kind:'SOURCE_FACT',supportingFactIds:[ledger.facts[0].factId]}]}};
 let checked=false;const r=await new StudyGroundingVerifier({identity,independentCheck:async i=>{
  checked=true;assert.ok(i.claims.find(c=>c.path==='/title'));const r=supported(i);r.verdicts.find(v=>v.path==='/title').status='UNSUPPORTED';return r;
 }}).verify(fixture);assert.equal(checked,true);assert.equal(r.supported,false);
});

for(const [locale,source,bad,good] of [
 ['pt','Ontem sem febre, hoje com febre. Isso não é necessariamente uma contradição.','A mudança não constitui contradição.','A mudança não é obrigatoriamente uma contradição.'],
 ['es','Ayer sin fiebre, hoy con fiebre. Esto no es necesariamente una contradicción.','El cambio no representa una contradicción.','El cambio no es necesariamente una contradicción.'],
]) test(`${locale}: qualified conclusion cannot become absolute even when critic accepts`,async()=>{
 const ledger=TranscriptFactLedger.extract(source);const fixture=studyFixture();
 Object.assign(fixture,{rawTranscript:source,ledger,locale});fixture.candidate.claims[0].supportingFactIds=[ledger.facts[0].factId];
 let calls=0;const v=new StudyGroundingVerifier({identity,independentCheck:async i=>{calls++;return supported(i);}});
 fixture.candidate.structuredResult.points=[bad];let r=await v.verify(fixture);
 assert.equal(r.supported,false);assert.equal(calls,0);assert.ok(r.errors.some(e=>e.code==='CRITICAL_QUALIFIER_LOSS'));
 fixture.candidate.structuredResult.points=[good];r=await v.verify(fixture);assert.equal(r.supported,true);assert.equal(calls,1);
});
test('qualifier guard permits original absolute source and pedagogical topic headings',()=>{
 const {losesContradictionQualifier:check}=require('../study_grounding_verifier');
 assert.equal(check('Não há contradição.','Não há contradição.'),false);
 assert.equal(check('Não é necessariamente uma contradição.','Evolução temporal e contradição'),false);
 assert.equal(check('Não é necessariamente uma contradição.','Não é necessariamente uma contradição. Outra frase: não constitui contradição.'),true);
});
