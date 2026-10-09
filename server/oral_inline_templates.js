'use strict';
const {hash}=require('./derivative_contract');
const VERSION='oral_inline_characterization_r24_v1';
const normalize=s=>s.normalize('NFD').replace(/\p{M}/gu,'').toLowerCase().trim();
function sentences(value){const out=[];let start=0;for(const m of value.matchAll(/[.!?](?=\s|$)/gu)){const end=m.index+1;if(value.slice(start,end).trim())out.push({text:value.slice(start,end),start,end});start=end;}if(value.slice(start).trim())out.push({text:value.slice(start),start,end:value.length});return out;}
function inlineBlueprints(fact,locale,sourceHash){
 if(fact.value.length<=3000)return [];
 const spans=sentences(fact.value);const output=[];const seen=new Set();
 for(let i=0;i<spans.length;i++){
  const current=spans[i];const s=current.text.trim();
  const m=s.match(/^(.{3,100}?)\s+(?:(no|não)\s+)?(es|son|é|são)\s+(.{8,450}?)[.!?]?$/u);
  if(!m)continue;
  const target=m[1].replace(/^(?:Entonces,? |Bueno,? |Por tanto,? |Então,? |Bom,? )/u,'').trim();
  const n=normalize(target).replace(/^(?:el|la|los|las|o|a|os|as|un|una|um|uma)\s+/u,'');
  if(!n||/\d|[,;:?!]/u.test(target)||/^(?:esto|eso|esa|ese|estos|esas|isso|isto|ele|ela|ellos|ellas|nosotros|nosotras|vosotros|ustedes|voce|voces|yo|eu|nos|lo|que|porque|como|cuando|si|se|en|em|para|por|de|con|com|pero|mas)\b/u.test(n)||/^(?:tratamiento|tratamento|paciente|pacientes|caso|ejemplo|exemplo|medicamento|farmaco|concepto|conceito|tema|cosa|coisa|situacion|situacao|problema|respuesta|resposta|idea|ideia|proceso|processo|gente|pessoa|persona|punto|ponto|parte|vez)(?:\s|$)/u.test(n)||target.split(/\s+/u).length>12)continue;
  if(seen.has(n))continue;
  // Preserve neighboring sentences, not an isolated predicate. The full
  // original ledger is also supplied to independent reviewers for corrections.
  const begin=spans[Math.max(0,i-1)].start;const end=spans[Math.min(spans.length-1,i+1)].end;
  if(end-begin>2000)continue;
  const quote=fact.value.slice(begin,end);const qualifiers=[...quote.matchAll(/\b(?:no|não|puede|pueden|pode|podem|solo|somente|algunos|alguns|posible|possível|siempre|sempre|necesariamente|necessariamente)\b/giu)].map(x=>x[0]);
  const bp={conceptId:hash(JSON.stringify([VERSION,fact.factId,begin,end,target])),locale,difficulty:'EASY',questionFamily:'IDENTIFY_FEATURE',targetFacts:[target],supportingFactIds:[fact.factId],answerFacts:[quote],requiredQualifiers:qualifiers,relationType:'EXPLICIT_INLINE_CHARACTERIZATION',sourceOffsets:[{start:fact.sourceStartOffset+begin,end:fact.sourceStartOffset+end}],sourceHashes:[hash(quote)],sourceHash,parentSourceHashes:[fact.sourceQuoteHash],question:locale==='es'?`¿Cómo caracteriza la fuente «${target}»? Conserve las condiciones, negaciones y matices del fragmento.`:`Como a fonte caracteriza «${target}»? Preserve as condições, negações e ressalvas do trecho.`,expectedAnswer:quote.trim(),answerSpan:m[4].replace(/[.!?]$/u,'').trim()};
  seen.add(n);output.push({questionId:hash(JSON.stringify([VERSION,bp])),...bp});
 }
 return output;
}
module.exports={inlineBlueprints,VERSION};
