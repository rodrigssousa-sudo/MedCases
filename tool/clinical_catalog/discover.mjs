// Offline inventory and dry-run only. Reads a previously captured local export.
import fs from 'node:fs';import path from 'node:path';import {createHash} from 'node:crypto';
import {normalizeLegacyContent} from './legacy_projection_adapter.mjs';import {canonical} from './publication.mjs';
const [sourceFile,out]=process.argv.slice(2);if(!sourceFile||!out)throw Error('Usage: discover.mjs SOURCE_EXPORT OUTPUT_DIRECTORY');
const bytes=fs.readFileSync(sourceFile);const source=JSON.parse(bytes);const hash=v=>createHash('sha256').update(v).digest('hex');
fs.mkdirSync(out,{recursive:true});const save=(name,value)=>fs.writeFileSync(path.join(out,name),JSON.stringify(value,null,2),{mode:0o600});
const owners=new Set(source.clinical_identity_registry.map(r=>r.canonicalKey));const byOwner=new Map();
const normalized=source.clinical_content_registry.map(row=>normalizeLegacyContent(row));
for(const n of normalized){const group=byOwner.get(n.owner)||[];group.push(n);byOwner.set(n.owner,group);}
// A shape is the sorted union of field paths and JSON types; array lengths
// and clinical values are excluded. Optional structural fields form new shapes.
function shape(value,prefix='$',out={}){
 const type=Array.isArray(value)?'array':value===null?'null':typeof value;
 const types=out[prefix]??new Set();types.add(type);out[prefix]=types;
 if(Array.isArray(value))for(const item of value)shape(item,`${prefix}[]`,out);
 else if(value&&typeof value==='object')for(const [k,v] of Object.entries(value))shape(v,`${prefix}.${k}`,out);
 return out;
}
const groups=new Map();
for(const row of source.clinical_content_registry){
 const signature=Object.fromEntries(Object.entries(shape(row)).sort(([a],[b])=>a.localeCompare(b)).map(([k,v])=>[k,[...v].sort()]));
 const id=hash(canonical(signature)).slice(0,12);const g=groups.get(id)||{SHAPE_ID:id,DOCUMENT_COUNT:0,ENABLED_COUNT:0,FIELDS:Object.keys(row).sort(),NESTED_FIELDS:signature};
 g.DOCUMENT_COUNT++;if(row.enabled===true)g.ENABLED_COUNT++;groups.set(id,g);
}
const shapes=[...groups.values()].sort((a,b)=>b.DOCUMENT_COUNT-a.DOCUMENT_COUNT);
for(const g of shapes){const fields=Object.keys(g.NESTED_FIELDS);for(const [label,re] of Object.entries({LOCALE_MODEL:/\.(pt|es|locales|locale|language)(\.|\[|$)/,STUDY_FIELDS:/study|estud/i,PLANTAO_FIELDS:/plantao|guardia/i,REFERENCE_FIELDS:/referenc|evidence/i,OWNER_LINK:/canonicalPathologyKey|protocolKey|contentKey/,VERSION_FIELDS:/version|schema/i,STATUS_FIELDS:/status|enabled|releaseActive/i}))g[label]=fields.filter(k=>re.test(k));}
save('remote-shape-inventory.json',shapes);
const ownerReport=[];const dryRun=[];let duplicatePairs=0;
for(const owner of [...owners].sort()){
 const docs=byOwner.get(owner)||[];
 const primary=docs.filter(d=>d.metadata.contentKey?.startsWith('legacy_protocol_content::'));
 const supplemental=docs.filter(d=>d.metadata.contentKey?.startsWith('legacy_classification_content::'));
 const resolved=primary.filter(d=>d.status==='RESOLVED');
 const distinctVersions=new Set(docs.map(d=>d.metadata.version));
 const candidates={};for(const mode of ['study','plantao'])for(const lang of ['pt','es']){
   const matches=primary.filter(d=>d[mode][lang]);
   candidates[`${mode}_${lang}`]=matches.length===1?'RESOLVED':matches.length>1?'AMBIGUOUS':'MISSING';
 }
 const all=Object.values(candidates).every(s=>s==='RESOLVED');
 const study=candidates.study_pt==='RESOLVED'&&candidates.study_es==='RESOLVED';
 const plantao=candidates.plantao_pt==='RESOLVED'&&candidates.plantao_es==='RESOLVED';
 const classification=all?'BOTH_PRESENT':study?'STUDY_ONLY':plantao?'PLANTAO_ONLY':primary.length?'LEGACY_SHAPE':'UNRESOLVED';
 const row={owner,contentDocumentCount:docs.length,protocolDocumentCount:primary.length,supplementalClassificationCount:supplemental.length,distinctDocumentVersions:distinctVersions.size,classification,projections:candidates,approvedHashValid:resolved.length===1};
 ownerReport.push(row);
 dryRun.push({owner,action:all&&resolved.length===1?'CREATE':'HOLD',target:'clinical_content_versions/<FUTURE_DRAFT>/owners/'+owner,sourceIds:docs.map(d=>d.metadata.sourceId),reason:all&&resolved.length===1?'LOCAL_NORMALIZED_CANDIDATE_ONLY':'UNRESOLVED_PROJECTION_OR_HASH',supplementalSourcesPreserved:supplemental.map(d=>d.metadata.sourceId),writeExecuted:false});
 const raws=source.clinical_content_registry.filter(r=>r.canonicalPathologyKey===owner);for(let i=0;i<raws.length;i++)for(let j=i+1;j<raws.length;j++)if(canonical(raws[i].payload)===canonical(raws[j].payload))duplicatePairs++;
}
for(const n of normalized)if(!owners.has(n.owner))dryRun.push({owner:n.owner,action:'HOLD',sourceId:n.metadata.sourceId,reason:'ORPHAN',writeExecuted:false});
const count=fn=>ownerReport.filter(fn).length;
const summary={REMOTE_SCHEMA_SHAPES:shapes.length,REMOTE_IDENTITIES_ENABLED:owners.size,REMOTE_CONTENT_ENABLED:normalized.length,
 ONE_TO_ONE_COUNT:count(r=>r.contentDocumentCount===1),ONE_TO_MANY_COUNT:count(r=>r.contentDocumentCount>1),OWNERS_WITHOUT_CONTENT:count(r=>r.contentDocumentCount===0),
 ORPHAN_COUNT:normalized.filter(n=>!owners.has(n.owner)).length,SUPPLEMENTAL_CLASSIFICATION_DOCS:ownerReport.reduce((n,r)=>n+r.supplementalClassificationCount,0),
 DUPLICATE_PAYLOAD_PAIRS_WITHIN_OWNER:duplicatePairs,SEPARATE_LANGUAGE_DOCUMENTS:0,
 OWNERS_WITH_MIXED_DOCUMENT_VERSION:count(r=>r.distinctDocumentVersions>1),HISTORICAL_VERSIONS_CONFIRMED:0,
 OWNER_CLASSIFICATIONS:Object.fromEntries(['BOTH_PRESENT','STUDY_ONLY','PLANTAO_ONLY','UNRESOLVED','LEGACY_SHAPE'].map(c=>[c,count(r=>r.classification===c)])),
 UNRESOLVED_COUNT:count(r=>r.classification!=='BOTH_PRESENT'||!r.approvedHashValid),
 STUDY_PT_RESOLVED:count(r=>r.projections.study_pt==='RESOLVED'),STUDY_ES_RESOLVED:count(r=>r.projections.study_es==='RESOLVED'),
 PLANTAO_PT_RESOLVED:count(r=>r.projections.plantao_pt==='RESOLVED'),PLANTAO_ES_RESOLVED:count(r=>r.projections.plantao_es==='RESOLVED'),
 FOUR_PROJECTION_COMPLETE:count(r=>r.classification==='BOTH_PRESENT'),FOUR_PROJECTION_WITH_VALID_APPROVED_HASH:count(r=>r.classification==='BOTH_PRESENT'&&r.approvedHashValid),
 DRY_RUN_ACTIONS:Object.fromEntries(['CREATE','UPDATE','SKIP','HOLD'].map(a=>[a,dryRun.filter(r=>r.action===a).length])),
 SOURCE_SHA256:hash(bytes),SOURCE_MUTATED:'NO',FIRESTORE_WRITES:0,CLINICAL_CONTENT_MUTATED:'NO',PRODUCTION_ACTIVATION_READY:'NO'};
save('normalized-local-candidates.json',normalized);save('owner-mapping.json',ownerReport);save('migration-dry-run.json',dryRun);save('discovery-summary.json',summary);
if(hash(fs.readFileSync(sourceFile))!==summary.SOURCE_SHA256)throw Error('SOURCE_CHANGED');console.log(JSON.stringify(summary,null,2));
