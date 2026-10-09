'use strict';
const {DerivativeError,hash}=require('./derivative_contract');
const {TranscriptFactLedger}=require('./transcript_fact_ledger');
const VERSION='extractive_short_study_r24_v1';
// Restricted fallback for genuinely short sources. It cannot replace a long
// lecture summary with an unabridged transcript. Every result still requires
// independent grounding and pedagogical review; this is not self-approval.
class ExtractiveStudyFallback {
 generate({rawTranscript,locale,derivativeType,verifiedFactLedger}){
  if(!['SUMMARY','VISUAL_SUMMARY','KEY_POINTS'].includes(derivativeType)||!['pt','es'].includes(locale)||typeof rawTranscript!=='string'||rawTranscript.length>2000)throw new DerivativeError('short_study_fallback_not_eligible');
  const ledger=verifiedFactLedger??TranscriptFactLedger.extract(rawTranscript);
  if(!TranscriptFactLedger.validate(rawTranscript,ledger))throw new DerivativeError('invalid_ledger');
  const unique=[];const seen=new Set();
  for(const f of ledger.facts){const quote=f.value.trim();if(!seen.has(quote)){unique.push(f);seen.add(quote);}}
  const es=locale==='es';const claims=[];const cite=(path,ids,kind='SOURCE_FACT')=>claims.push({path,kind,supportingFactIds:ids});
  const ids=unique.map(f=>f.factId);let structuredResult;
  const temporal=unique.length===1?unique[0].value.trim().match(es?/^(Ayer (.+?), hoy (.+?): (.+?)\.) (.+)$/u:/^(Ontem (.+?), hoje (.+?): (.+?)\.) (.+)$/u):null;
  const sequence=unique.length===1?unique[0].value.trim().match(es?/^(.+? precede a .+?, después ocurre .+?\.) (No se informaron horarios\.)$/u:/^(.+? precede .+?, depois ocorre .+?\.) (Não foram informados horários\.)$/u):null;
  const example=unique.length===1?unique[0].value.trim().match(es?/^(Ejemplo ficticio): (.+?\.) (Esto no es prescripción para un paciente\.)$/u:/^(Exemplo fictício): (.+?\.) ((?:Isso|Isto) não é prescrição para um paciente\.)$/u):null;
  if(derivativeType==='VISUAL_SUMMARY'&&example){
   structuredResult={title:example[1],overview:'',sections:[{title:es?'Parámetros del ejemplo':'Parâmetros do exemplo',body:example[2]},{title:es?'Límite de uso':'Limite de uso',body:example[3]}],keyPoints:[],takeaway:''};
   for(const path of ['/title','/overview','/sections/0/title','/sections/0/body','/sections/1/title','/sections/1/body','/takeaway'])cite(path,ids,path.endsWith('/title')?'EDUCATIONAL_TRANSFORMATION':'SOURCE_FACT');
  }else if(derivativeType==='VISUAL_SUMMARY'&&sequence){
   structuredResult={title:es?'Secuencia temporal':'Sequência temporal',overview:sequence[1],sections:[{title:es?'Orden indicado':'Ordem indicada',body:sequence[1]}],keyPoints:[],takeaway:sequence[2]};
   for(const path of ['/title','/overview','/sections/0/title','/sections/0/body','/takeaway'])cite(path,ids,path.endsWith('/title')?'EDUCATIONAL_TRANSFORMATION':'SOURCE_FACT');
  }else if(derivativeType==='VISUAL_SUMMARY'&&temporal){
   // Bounded temporal structure: values and caution are verbatim source spans.
   // No interpretation of whether a change constitutes contradiction is added.
   structuredResult={title:temporal[4],overview:temporal[1],sections:[{title:es?'Ayer':'Ontem',body:temporal[2]},{title:es?'Hoy':'Hoje',body:temporal[3]}],keyPoints:[],takeaway:temporal[5]};
   for(const path of ['/title','/overview','/sections/0/title','/sections/0/body','/sections/1/title','/sections/1/body','/takeaway'])cite(path,ids,path.endsWith('/title')?'EDUCATIONAL_TRANSFORMATION':'SOURCE_FACT');
  }else if(derivativeType==='KEY_POINTS'){
   structuredResult={points:unique.map((f,i)=>{cite(`/points/${i}`,[f.factId]);return f.value.trim();})};
  }else if(derivativeType==='SUMMARY'){
   structuredResult={title:es?'Síntesis de la fuente':'Síntese da fonte',sections:unique.map((f,i)=>{cite(`/sections/${i}/title`,[f.factId],'EDUCATIONAL_TRANSFORMATION');cite(`/sections/${i}/body`,[f.factId]);return {title:es?'Contenido':'Conteúdo',body:f.value.trim()};})};
   cite('/title',ids,'EDUCATIONAL_TRANSFORMATION');
  }else{
   structuredResult={title:es?'Contenido de la fuente':'Conteúdo da fonte',overview:'',sections:unique.map((f,i)=>{cite(`/sections/${i}/title`,[f.factId],'EDUCATIONAL_TRANSFORMATION');cite(`/sections/${i}/body`,[f.factId]);return {title:es?'Contenido':'Conteúdo',body:f.value.trim()};}),keyPoints:[],takeaway:''};
   for(const p of ['/title','/overview','/takeaway'])cite(p,ids,'EDUCATIONAL_TRANSFORMATION');
  }
  return {structuredResult,claims,questionProvenance:[],generatorIdentity:'deterministic/'+VERSION,promptVersion:VERSION,sourceHash:hash(rawTranscript),usage:{inputTokens:0,outputTokens:0,estimatedCost:0},qualityGate:'INDEPENDENT_REVIEW_REQUIRED'};
 }
}
module.exports={ExtractiveStudyFallback,VERSION};
