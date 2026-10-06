// Offline structural adapter. No network, writes, translation or mode inference.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {canonical, hash} from './publication.mjs';
import {normalizeLegacyContent} from './legacy_projection_adapter.mjs';
export const mappings=JSON.parse(fs.readFileSync(new URL('./phase2_shapes.json',import.meta.url)));
export const textHash=s=>createHash('sha256').update(s,'utf8').digest('hex');
export function fingerprint(value){
 const out={};function visit(v,p='$'){(out[p]??=new Set()).add(Array.isArray(v)?'array':v===null?'null':typeof v);if(Array.isArray(v))v.forEach(x=>visit(x,p+'[]'));else if(v&&typeof v==='object')for(const [k,x] of Object.entries(v))visit(x,p+'.'+k);}
 visit(value);return hash(Object.fromEntries(Object.entries(out).sort(([a],[b])=>a.localeCompare(b)).map(([k,v])=>[k,[...v].sort()]))).slice(0,12);
}
export function normalizePhase2(source){
 const n=normalizeLegacyContent(source),shape=mappings.find(m=>m.fingerprint===fingerprint(source));
 if(!shape){n.status='UNRESOLVED';n.metadata.conflicts.push('UNKNOWN_SHAPE');return n;}
 if(shape.policy!=='ENCODED_APPROVED_JSON')return n;
 let q;try{q=JSON.parse(source.payload.approvedClinicalPayload);}catch{n.metadata.conflicts.push('ENCODED_JSON_INVALID');return n;}
 const m=n.metadata;
 m.approvedHashStatus=textHash(source.payload.approvedClinicalPayload)===source.approvedClinicalPayloadSha256?'PASS':'FAIL';
 if(q.owner!==n.owner){
  if(Array.isArray(q.preservedRuntimeIds)&&q.preservedRuntimeIds.includes(q.owner)&&q.preservedRuntimeIds.includes(n.owner)&&m.approvedHashStatus==='PASS')m.nonclinicalResolution='APPROVED_PRESERVED_RUNTIME_ID';
  else m.conflicts.push('OWNER_ID_CONFLICT');
 }
 if(q.version!==source.version)m.conflicts.push('VERSION_CONFLICT');
 if(n.references!==null&&canonical(n.references)!==canonical(q.references))m.conflicts.push('REFERENCE_SET_MISMATCH');
 n.references=q.references??null;m.missing=[];
 for(const mode of ['study','plantao'])for(const lang of ['pt','es']){
  const v=q?.[lang]?.[mode], key=`${mode}.${lang}`;
  if(typeof v==='string'&&v.trim()){
   if(n[mode][lang]){m.conflicts.push(`MULTIPLE_${key}`);continue;}
   n[mode][lang]={format:'markdown',value:v};m.sourcePaths[key]=`payload.approvedClinicalPayload::${lang}.${mode}`;
  }else m.missing.push(key);
 }
 n.classification=m.missing.length?'UNRESOLVED':'BOTH_PRESENT';
 n.status=!m.missing.length&&!m.conflicts.length&&m.approvedHashStatus==='PASS'&&m.enabled&&Array.isArray(n.references)&&n.references.length?'RESOLVED':'UNRESOLVED';
 return n;
}
