import {createHash} from 'node:crypto';
import {canonical} from './publication.mjs';
const digest=s=>createHash('sha256').update(s,'utf8').digest('hex');
const isMap=v=>v!==null&&typeof v==='object'&&!Array.isArray(v);
const nonempty=v=>typeof v==='string'&&v.trim().length>0;

/** Read-only discovery adapter. No inference, translation, clinical synthesis,
 * writes, or fallback between modes/locales. Source bytes and hashes stay intact.
 * A mapping result is NOT a publication or clinical-approval decision. */
export function normalizeLegacyContent(source){
 const p=isMap(source.payload)?source.payload:{};
 const normalized={owner:source.canonicalPathologyKey??null,study:{pt:null,es:null},plantao:{pt:null,es:null},references:p.references??null,
  metadata:{sourceId:source.id??null,contentKey:source.contentKey??null,version:source.version??null,sourceMode:source.sourceMode??null,
   enabled:source.enabled===true,sourceSha256:digest(canonical(source)),approvedClinicalPayloadSha256:source.approvedClinicalPayloadSha256??null,
   sourcePaths:{},missing:[],conflicts:[],approvedHashStatus:'NOT_PRESENT'}};
 const meta=normalized.metadata;
 if(typeof p.approvedClinicalPayloadJson==='string'){
  meta.approvedHashStatus=digest(p.approvedClinicalPayloadJson)===p.approvedClinicalPayloadSha256&&p.approvedClinicalPayloadSha256===source.approvedClinicalPayloadSha256?'PASS':'FAIL';
 }
 for(const mode of ['study','plantao'])for(const lang of ['pt','es']){
  const locale=isMap(p[lang])?p[lang]:{};
  const markdown=locale[`${mode}Markdown`];const structured=locale[`${mode}Projection`];
  const hasMarkdown=nonempty(markdown),hasStructured=isMap(structured)&&Array.isArray(structured.sections)&&structured.sections.length>0;
  if(hasMarkdown&&hasStructured){meta.conflicts.push(`${mode}.${lang}`);continue;}
  if(hasMarkdown){normalized[mode][lang]={format:'markdown',value:markdown};meta.sourcePaths[`${mode}.${lang}`]=`payload.${lang}.${mode}Markdown`;}
  else if(hasStructured){normalized[mode][lang]={format:'structured',value:JSON.parse(JSON.stringify(structured))};meta.sourcePaths[`${mode}.${lang}`]=`payload.${lang}.${mode}Projection`;}
  else meta.missing.push(`${mode}.${lang}`);
 }
 const complete=meta.missing.length===0&&meta.conflicts.length===0;
 const study=['pt','es'].every(l=>normalized.study[l]);const plantao=['pt','es'].every(l=>normalized.plantao[l]);
 normalized.classification=complete?'BOTH_PRESENT':study&&!plantao?'STUDY_ONLY':plantao&&!study?'PLANTAO_ONLY':Object.keys(p).length?'LEGACY_SHAPE':'UNRESOLVED';
 normalized.status=complete&&normalized.owner&&meta.approvedHashStatus==='PASS'&&meta.enabled?'RESOLVED':'UNRESOLVED';
 // Clone protects sources even if downstream code edits its normalized view.
 return JSON.parse(JSON.stringify(normalized));
}
