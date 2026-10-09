'use strict';
const {CONTRACTS,validateSchema,hash} = require('./derivative_contract');
const {TranscriptFactLedger}=require('./transcript_fact_ledger');
const {fieldFor}=require('./clinical_field_evidence');
const VERSION='extractive_grounding_r1';
const LABELS={pt:{title:'Registro da transcrição',section:'Trecho',question:'O que foi registrado no trecho',reference:'Trecho'},
 es:{title:'Registro de la transcripción',section:'Fragmento',question:'¿Qué se registró en el fragmento',reference:'Fragmento'}};
function leaves(value,path='') {
  if(value===null) return [];
  if(typeof value==='string') return [{path,value}];
  if(Array.isArray(value)) return value.flatMap((v,i)=>leaves(v,`${path}/${i}`));
  if(value && typeof value==='object') return Object.entries(value).flatMap(([k,v])=>leaves(v,`${path}/${k}`));
  return [];
}
function neutral(path,value,type,locale,facts) {
  const l=LABELS[locale];
  if(path==='/title') return value===l.title;
  if(/^\/sections\/\d+\/title$/.test(path)) return value===`${l.section} ${Number(path.split('/')[2])+1}`;
  if(type==='ORAL_EXAM') {
    const m=path.match(/^\/questions\/(\d+)\/(question|sourceSection|difficulty)$/);
    if(m){const n=Number(m[1])+1;
      if(!facts[n-1]) return false;
      if(m[2]==='difficulty') return value==='easy';
      if(m[2]==='sourceSection') return value===`${l.reference} ${n}`;
      return value===`${l.question} ${n}?`;
    }
  }
  return false;
}
class DerivativeGroundingVerifier {
  verify({rawTranscript,ledger,derivativeType,locale,candidate}) {
    const errors=[];const reject=(code,path)=>errors.push({code,path});
    if(!LABELS[locale]||!CONTRACTS[derivativeType]||!TranscriptFactLedger.validate(rawTranscript,ledger)) {
      return {status:'UNSUPPORTED_CLAIMS',supported:false,errors:[{code:'INVALID_LEDGER_OR_CONTRACT'}]};
    }
    if(!candidate||!validateSchema(candidate.structuredResult,CONTRACTS[derivativeType].schema)||!Array.isArray(candidate.claims)) {
      return {status:'UNSUPPORTED_CLAIMS',supported:false,errors:[{code:'INVALID_SCHEMA'}]};
    }
    const facts=new Map(ledger.facts.map((f,i)=>[f.factId,{...f,index:i}]));
    const claims=new Map();const used=new Set();const output=leaves(candidate.structuredResult);
    for(const claim of candidate.claims) {
      if(!claim||typeof claim.path!=='string'||claims.has(claim.path)||!Array.isArray(claim.supportingFactIds)||!claim.supportingFactIds.length) {reject('INVALID_PROVENANCE',claim?.path);continue;}
      claims.set(claim.path,claim);
    }
    let checked=0;
    for(const leaf of output) {
      const claim=claims.get(leaf.path);
      if(!claim) {if(!neutral(leaf.path,leaf.value,derivativeType,locale,ledger.facts)) reject('UNSUPPORTED_CLAIM',leaf.path);continue;}
      checked++;
      const linked=claim.supportingFactIds.map(id=>facts.get(id));
      if(linked.some(f=>!f)||linked.some((f,i)=>i>0&&f.index<=linked[i-1].index)) {reject('INVALID_FACT_REFERENCE',leaf.path);continue;}
      if(derivativeType==='ANAMNESIS' && linked.some(f=>`/${fieldFor(f.value)}`!==leaf.path)) {reject('UNSUPPORTED_FIELD_ASSIGNMENT',leaf.path);continue;}
      let expected=linked.map(f=>f.value).join('');
      if(derivativeType==='EVOLUTION' && /\/time$/.test(leaf.path)) expected=linked.length===1?linked[0].timestampIfExplicit:null;
      if(expected!==leaf.value) {reject('UNSUPPORTED_CLAIM',leaf.path);continue;}
      linked.forEach(f=>used.add(f.factId));
    }
    for(const path of claims.keys()) if(!output.some(l=>l.path===path)) reject('ORPHAN_PROVENANCE',path);
    // Extractive fallback promises full source coverage, not merely a valid
    // citation on one cherry-picked sentence. No clinical fact can disappear.
    if(used.size!==ledger.facts.length) reject('SOURCE_OMISSION','/');
    if(derivativeType==='ORAL_EXAM') {
      const q=candidate.questionProvenance;
      if(!Array.isArray(q)||q.length!==candidate.structuredResult.questions.length) reject('UNSUPPORTED_QUESTION','/questions');
      else q.forEach((p,i)=>{
        const expected=ledger.facts[i]?.factId;
        if(!expected||JSON.stringify(p.supportingFactIds)!==JSON.stringify([expected])||JSON.stringify(p.expectedAnswerFactIds)!==JSON.stringify([expected])||
          JSON.stringify(claims.get(`/questions/${i}/expectedAnswer`)?.supportingFactIds)!==JSON.stringify([expected])) reject('UNSUPPORTED_QUESTION',`/questions/${i}`);
      });
    }
    return {version:VERSION,status:errors.length?'UNSUPPORTED_CLAIMS':'SUPPORTED',supported:errors.length===0,
      errors,claimsChecked:checked,factsCovered:used.size,factsTotal:ledger.facts.length,
      ledgerHash:ledger.ledgerHash,outputHash:hash(JSON.stringify(candidate.structuredResult)),
      limitation:'EXACT_EXTRACTIVE_ONLY; arbitrary paraphrases and translation rejected'};
  }
}
module.exports={DerivativeGroundingVerifier,LABELS};
