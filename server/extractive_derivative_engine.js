'use strict';
const {CLINICAL}=require('./derivative_policy');
const {hash,DerivativeError}=require('./derivative_contract');
const {TranscriptFactLedger}=require('./transcript_fact_ledger');
const {DerivativeGroundingVerifier,LABELS}=require('./derivative_grounding_verifier');
const {fieldFor,FIELD_LABELS}=require('./clinical_field_evidence');
const VERSION='extractive_r21_v1';
function candidateFor(type,locale,ledger) {
  const l=LABELS[locale];if(!l) throw new DerivativeError('invalid_locale');
  const claims=[];const facts=ledger.facts;
  const claim=(path,selected)=>{claims.push({path,supportingFactIds:selected.map(f=>f.factId)});return selected.map(f=>f.value).join('');};
  const sections=()=>facts.map((f,i)=>({title:`${l.section} ${i+1}`,body:claim(`/sections/${i}/body`,[f])}));
  let structuredResult;let questionProvenance;
  switch(type) {
    case 'SUMMARY': structuredResult={title:l.title,sections:sections()};break;
    case 'ORGANIZATION': structuredResult={sections:sections()};break;
    case 'KEY_POINTS': structuredResult={points:facts.map((f,i)=>claim(`/points/${i}`,[f]))};break;
    case 'VISUAL_SUMMARY': structuredResult={title:l.title,overview:claim('/overview',[facts[0]]),sections:sections(),
      keyPoints:facts.map((f,i)=>claim(`/keyPoints/${i}`,[f])),takeaway:claim('/takeaway',[facts.at(-1)])};break;
    case 'ANAMNESIS':
      // Do not infer patient identity or field assignment from lecture text.
      // Evidence stays visible in the source-information field; absence is null.
      structuredResult=Object.fromEntries([...Object.keys(FIELD_LABELS),'otherRelevantInformation'].map(field=>{
        const selected=facts.filter(f=>fieldFor(f.value)===field);
        return [field,selected.length?claim(`/${field}`,selected):null];
      }));break;
    case 'EVOLUTION':structuredResult={entries:facts.map((f,i)=>{
      if(f.timestampIfExplicit) claims.push({path:`/entries/${i}/time`,supportingFactIds:[f.factId]});
      return {time:f.timestampIfExplicit,findings:claim(`/entries/${i}/findings`,[f]),actions:null};})};break;
    case 'ORAL_EXAM':
      structuredResult={questions:facts.map((f,i)=>({question:`${l.question} ${i+1}?`,
        expectedAnswer:claim(`/questions/${i}/expectedAnswer`,[f]),keyPoints:[claim(`/questions/${i}/keyPoints/0`,[f])],
        difficulty:'easy',sourceSection:`${l.reference} ${i+1}`}))};
      questionProvenance=facts.map(f=>({supportingFactIds:[f.factId],expectedAnswerFactIds:[f.factId]}));break;
    default:throw new DerivativeError('invalid_derivative_type');
  }
  return {structuredResult,claims,...(questionProvenance?{questionProvenance}:{})};
}
class ExtractiveDerivativeEngine {
  async generate(input) {
    if(input.transcriptHash!==hash(input.rawTranscript)) throw new DerivativeError('source_hash_mismatch');
    if(!CLINICAL.includes(input.derivativeType)) throw new DerivativeError('study_requires_generative_profile');
    const started=performance.now();const ledger=TranscriptFactLedger.extract(input.rawTranscript);
    const extractionMs=performance.now()-started;
    const candidate=candidateFor(input.derivativeType,input.locale,ledger);
    const verificationStart=performance.now();
    const grounding=new DerivativeGroundingVerifier().verify({rawTranscript:input.rawTranscript,ledger,
      derivativeType:input.derivativeType,locale:input.locale,candidate});
    if(!grounding.supported) throw new DerivativeError('grounding_rejected');
    return {status:'COMPLETED',provider:'deterministic',model:null,strategy:'EXTRACTIVE_DERIVATIVE_MODE',version:VERSION,
      ...candidate,grounding,ledgerHash:ledger.ledgerHash,transcriptHash:ledger.transcriptHash,
      extractionMs,verificationMs:performance.now()-verificationStart,latency:performance.now()-started,
      estimatedCost:0,inputTokens:0,outputTokens:0,qualityGate:'EXTRACTIVE_PROVENANCE_ONLY',
      limitations:['No translation or generative condensation','Oral questions are source-recall templates','Unclassified clinical fields remain null']};
  }
}
module.exports={ExtractiveDerivativeEngine,candidateFor,VERSION};
