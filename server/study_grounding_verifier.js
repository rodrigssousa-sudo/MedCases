'use strict';
const {normalizeCandidate}=require('./study_provenance_codec');
const {CONTRACTS,validateSchema,isCompleteResult,hash}=require('./derivative_contract');
const {TranscriptFactLedger}=require('./transcript_fact_ledger');
const {STUDY}=require('./derivative_policy');
function leaves(v,p='') {
 if(v===null)return [];
 if(typeof v==='string')return [{path:p,text:v}];
 if(Array.isArray(v))return v.flatMap((x,i)=>leaves(x,`${p}/${i}`));
 if(v&&typeof v==='object')return Object.entries(v).flatMap(([k,x])=>leaves(x,`${p}/${k}`));
 return [];
}
function numericTokens(text) {
 // Decimal separator normalization only; no unit conversion or arithmetic.
 return [...text.matchAll(/(?<![\p{L}\d])\d+(?:[.,:]\d+)*(?![\p{L}\d])/gu)].map(m=>m[0].replace(',','.'));
}
// Narrow regression guard for qualified contradiction statements in PT/ES.
// This does not replace independent semantic review or claim general NLI coverage.
function losesContradictionQualifier(evidence, claim) {
 const normalize=s=>s.normalize('NFD').replace(/\p{M}/gu,'').toLowerCase();
 const source=normalize(evidence);const output=normalize(claim);
 const topic=/(?:contradicao|contradiccion|inconsistencia)/;
 const qualified=/(?:nao|no)\s+(?:(?:e|es)\s+)?necess?ariamente/;
 if(!topic.test(source)||!qualified.test(source))return false;
 const sentences=output.split(/[.!?;\n]+/).filter(s=>topic.test(s));
 return sentences.some(s=>
  /(?:nao|no)\s+(?:e|es|sao|son|constitui|constituem|constituye|constituyen|representa|representam|representan|ha|hay)\b/.test(s)
  && !/(?:necess?ariamente|obrigatoriamente|obligatoriamente|forcosamente|sempre|siempre|por si so|por si sola|por si solo)/.test(s));
}
class StudyGroundingVerifier {
 constructor({independentCheck,identity}) {this.independentCheck=independentCheck;this.identity=identity;}
 async verify({rawTranscript,ledger,derivativeType,locale,candidate,generatorIdentity}) {
  const fail=(errors,stage='deterministic')=>({supported:false,status:'UNSUPPORTED_CLAIMS',stage,errors});
  if(!STUDY.includes(derivativeType)||!['pt','es'].includes(locale)||!TranscriptFactLedger.validate(rawTranscript,ledger)) return fail([{code:'INVALID_LEDGER_OR_PROFILE'}]);
  if(!candidate||!isCompleteResult(derivativeType,candidate.structuredResult)||!Array.isArray(candidate.claims))return fail([{code:'INVALID_SCHEMA'}]);
  candidate=normalizeCandidate(candidate);
  const output=leaves(candidate.structuredResult).filter(l=>!/^\/questions\/\d+\/difficulty$/.test(l.path));
  const map=new Map();const facts=new Map(ledger.facts.map(f=>[f.factId,f]));const errors=[];
  for(const original of candidate.claims) {
   const c=original&&{...original,path:typeof original.path==='string'?original.path.replace(/^\/structuredResult(?=\/)/u,''):original.path};
   if(!c||typeof c.path!=='string'||map.has(c.path)||!['SOURCE_FACT','EDUCATIONAL_TRANSFORMATION'].includes(c.kind)||!Array.isArray(c.supportingFactIds)||!c.supportingFactIds.length||c.supportingFactIds.some(id=>!facts.has(id))) {errors.push({code:'INVALID_PROVENANCE',path:c?.path});continue;}
   map.set(c.path,c);
  }
  for(const l of output) {
   const c=map.get(l.path);if(!c){errors.push({code:'MISSING_CLAIM_PROVENANCE',path:l.path});continue;}
   const evidence=c.supportingFactIds.map(id=>facts.get(id).value).join('\n');
   const allowed=new Set(numericTokens(evidence));
   const referenceIndex=ledger.facts.findIndex(f=>f.factId===c.supportingFactIds[0])+1;
   const isReference=/\/sourceSection$/.test(l.path)&&new RegExp(`^(Trecho|Fragmento|Seção|Sección) ${referenceIndex}$`,'u').test(l.text);
   if(losesContradictionQualifier(evidence,l.text))errors.push({code:'CRITICAL_QUALIFIER_LOSS',path:l.path});
   if(!isReference&&numericTokens(l.text).some(n=>!allowed.has(n)))errors.push({code:'UNSUPPORTED_NUMBER_OR_TIME',path:l.path});
  }
  for(const path of map.keys())if(!output.some(l=>l.path===path))errors.push({code:'ORPHAN_PROVENANCE',path});
  if(derivativeType==='ORAL_EXAM') {
   if(!Array.isArray(candidate.questionProvenance)||candidate.questionProvenance.length!==candidate.structuredResult.questions.length)errors.push({code:'MISSING_QUESTION_PROVENANCE'});
   else candidate.questionProvenance.forEach((q,i)=>{
    for(const [key,path] of [['supportingFactIds',`/questions/${i}/question`],['expectedAnswerFactIds',`/questions/${i}/expectedAnswer`]]) {
     if(!Array.isArray(q[key])||!q[key].length||q[key].some(id=>!facts.has(id))||JSON.stringify(q[key])!==JSON.stringify(map.get(path)?.supportingFactIds))errors.push({code:'INVALID_QUESTION_REFERENCE',path});
    }
   });
  }
  if(errors.length)return fail(errors);
  // Paraphrases are allowed. Semantic verification is mandatory and separate;
  // never mistake string inequality for a hallucination or let a model self-certify.
  if(!this.independentCheck||!this.identity||this.identity===generatorIdentity)return fail([{code:'INDEPENDENT_CHECK_REQUIRED'}]);
  const checked=await this.independentCheck({rawTranscript,ledger,derivativeType,locale,candidate,
   claims:output.map(l=>({...l,...map.get(l.path)}))});
  if(checked?.verifierIdentity!==this.identity||!Array.isArray(checked.verdicts))return fail([{code:'INVALID_VERIFIER_RESPONSE'}],'independent');
  const verdicts=new Map();
  for(const v of checked.verdicts) {
   if(!v||verdicts.has(v.path)||!output.some(l=>l.path===v.path)){errors.push({code:'INVALID_VERDICT'});continue;}
   verdicts.set(v.path,v);
  }
  for(const l of output) {
   const v=verdicts.get(l.path);
   for(const [field,code] of [['negationConflict','NEGATION_CONFLICTS'],['doseConflict','DOSE_CONFLICTS'],['temporalConflict','TEMPORAL_CONFLICTS'],['allergyConflict','ALLERGY_CONFLICTS'],['sourceMisattribution','SOURCE_MISATTRIBUTION'],['criticalFactDistortion','CRITICAL_FACT_DISTORTION']])if(v?.[field]===true)errors.push({code,path:l.path});
   if(v?.status!=='SUPPORTED'||v?.sourceMisattribution!==false||v?.criticalFactDistortion!==false||v?.negationConflict!==false||v?.doseConflict!==false||v?.temporalConflict!==false||v?.allergyConflict!==false) errors.push({code:'UNSUPPORTED_OR_CONFLICTING_CLAIM',path:l.path});
  }
  return {supported:errors.length===0,status:errors.length?'UNSUPPORTED_CLAIMS':'SUPPORTED',stage:'independent',errors,
   claimsChecked:output.length,normalizedClaims:candidate.claims,ledgerHash:ledger.ledgerHash,outputHash:hash(JSON.stringify(candidate.structuredResult)),
   verifierIdentity:this.identity,verificationUsage:checked.usage??null,
   limitation:'Independent semantic review is empirical, not a mathematical proof; corpus gate remains required'};
 }
}
module.exports={StudyGroundingVerifier,numericTokens,losesContradictionQualifier};
