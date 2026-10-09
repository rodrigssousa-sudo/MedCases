'use strict';
const {hash}=require('./derivative_contract');
const VERSION='study_source_term_preserver_r24_v1';
// This narrow lexical correction never supplies clinical knowledge. A generator
// may expand an unqualified source label into a more specific numeric name.
// Restore only this proven source label, keep the rejected original, and require
// both grounding and pedagogical reviews on the resulting candidate as usual.
function preserveSourceTerms({rawTranscript,derivativeType,candidate}){
 const originalHash=hash(JSON.stringify(candidate));const changes=[];const output=structuredClone(candidate);
 if(!['SUMMARY','VISUAL_SUMMARY','KEY_POINTS'].includes(derivativeType)||typeof rawTranscript!=='string')return {candidate:output,changes,revision:VERSION,originalHash,outputHash:originalHash};
 const literal=rawTranscript.match(/\bcovid\b/iu)?.[0];
 if(!literal||/covid[\s-]*19/iu.test(rawTranscript))return {candidate:output,changes,revision:VERSION,originalHash,outputHash:originalHash};
 function visit(value,path){
  if(typeof value==='string'){const corrected=value.replace(/\bcovid[ -]19\b/giu,literal);if(corrected!==value)changes.push({path,rule:'restore_literal_source_term',beforeHash:hash(value),afterHash:hash(corrected)});return corrected;}
  if(Array.isArray(value))return value.map((x,i)=>visit(x,path+'/'+i));
  if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,visit(v,path+'/'+k)]));return value;
 }
 output.structuredResult=visit(output.structuredResult,'/structuredResult');
 return {candidate:output,changes,revision:VERSION,originalHash,outputHash:hash(JSON.stringify(output))};
}
module.exports={preserveSourceTerms,VERSION};
