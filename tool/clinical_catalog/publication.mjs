import {extraCollections,projectionMetadata,validateFunctional} from './functional_schema.mjs';
// No CLI and no implicit production connection. Callers supply an emulator or
// privileged Firestore client only after separately authorizing production.
import {createHash} from 'node:crypto';
export const collections=['clinical_identity_registry','clinical_protocols','clinical_classification_registry','clinical_management_rules','clinical_action_registry','clinical_content_registry'];
export const canonical=v=>JSON.stringify(sort(v));
function sort(v){if(Array.isArray(v))return v.map(sort);if(v&&typeof v==='object')return Object.fromEntries(Object.keys(v).sort().map(k=>[k,sort(v[k])]));return v;}
export const hash=v=>createHash('sha256').update(canonical(v),'utf8').digest('hex');
const textHash=s=>createHash('sha256').update(s,'utf8').digest('hex');
const assert=(ok,code)=>{if(!ok)throw new Error(code);};
export function prepare(version,registries,{schemaVersion=1}={}){
 assert(/^[A-Za-z0-9._-]{1,120}$/.test(version),'version');
 const encode=schemaVersion===2?JSON.stringify:canonical;
 const chunks={};const descriptors=[];const counts={};
 for(const collection of (schemaVersion===2?[...collections,...extraCollections]:collections)){
  const rows=registries[collection];assert(Array.isArray(rows),'missing_collection');counts[collection]=rows.length;
  let batch=[];let n=0;
  function flush(){const id=`${collection}.${n++}`;const json=encode(batch);chunks[id]={json};descriptors.push({id,collection,count:batch.length,sha256:textHash(json)});batch=[];}
  for(const row of rows){assert(Buffer.byteLength(encode([row]))<=700000,'row_too_large');if(Buffer.byteLength(encode([...batch,row]))>700000)flush();batch.push(row);}
  flush();
 }
 const manifest={contentVersion:version,schemaVersion,status:'DRAFT',ownerCount:counts.clinical_identity_registry,counts,chunks:descriptors};
 if(schemaVersion===2)Object.assign(manifest,{minimumClientBuild:1717,ownerSetHash:hash(registries.clinical_identity_registry.map(r=>r.canonicalKey).sort()),...projectionMetadata(registries)});
 const release={manifest,chunks};validate(release);return release;
}
export function validate({manifest:m,chunks}){
 if(m.schemaVersion===2)return validateFunctional({manifest:m,chunks},collections,rows=>validate(prepare('STRICT-AUTHORED-SUBSET',rows)));
 assert(m.schemaVersion===1 && ['DRAFT','ACTIVE'].includes(m.status),'schema_status');
 assert(/^[A-Za-z0-9._-]{1,120}$/.test(m.contentVersion),'version');
 const rows=Object.fromEntries(collections.map(c=>[c,[]]));const ids=new Set();
 assert(m.chunks.length>0&&m.chunks.length<=5000,'chunk_count');
 for(const d of m.chunks){assert(/^[A-Za-z0-9._-]{1,120}$/.test(d.id)&&!ids.has(d.id),'chunk_id');ids.add(d.id);const json=chunks[d.id]?.json;assert(typeof json==='string'&&Buffer.byteLength(json)<=800000&&textHash(json)===d.sha256,'chunk_hash');const part=JSON.parse(json);assert(Array.isArray(part)&&part.length===d.count&&rows[d.collection],'row_count');rows[d.collection].push(...part);}
 assert(ids.size===Object.keys(chunks).length,'extra_chunk');
 const owners=new Set(rows.clinical_identity_registry.map(r=>r.canonicalKey));
 assert(owners.size>0&&owners.size===m.ownerCount&&owners.size===rows.clinical_identity_registry.length,'owner_count');
 for(const c of collections){assert(rows[c].length===m.counts[c],'collection_count');for(const r of rows[c]){const key=c==='clinical_identity_registry'?r.canonicalKey:c==='clinical_action_registry'?(r.match?.canonicalPathologyKey??r.canonicalPathologyKey):r.canonicalPathologyKey;assert(owners.has(key)&&r.enabled!==false,'orphan_or_disabled');}}
 const projected=new Set();
 for(const row of rows.clinical_content_registry){
  projected.add(row.canonicalPathologyKey);const p=row.payload;
  assert(typeof p?.approvedClinicalPayloadJson==='string'&&textHash(p.approvedClinicalPayloadJson)===p.approvedClinicalPayloadSha256&&p.approvedClinicalPayloadSha256===row.approvedClinicalPayloadSha256,'approved_hash');
  for(const mode of ['study','plantao']){
   const pt=p.pt?.[`${mode}Projection`],es=p.es?.[`${mode}Projection`];
   if(pt?.format==='markdown'||es?.format==='markdown'){
    for(const x of [pt,es])assert(x?.format==='markdown'&&typeof x.markdown==='string'&&x.markdown.trim()&&Array.isArray(x.references)&&x.references.length,'markdown_projection');
    assert(canonical(pt.references)===canonical(es.references)&&canonical(pt.references)===canonical(p.references),'reference_parity');
    for(const [lang,x] of [['pt',pt],['es',es]])assert(x.markdown===p[lang]?.[`${mode}Markdown`],'markdown_source_binding');
    continue;
   }
   for(const x of [pt,es])assert(typeof x?.title==='string'&&x.title.length&&Array.isArray(x.sections)&&x.sections.length&&Array.isArray(x.references)&&x.references.length,'projection_missing');
   for(const x of [pt,es]){for(const [field,type] of [['sections','section'],['references','reference']]){const ids=new Set();for(const item of x[field]){assert(typeof item?.id==='string'&&item.id.length&&!ids.has(item.id),'item_schema');ids.add(item.id);if(type==='section')assert(typeof item.type==='string','section_type');}}}
   assert(canonical(pt.sections.map(s=>s.id))===canonical(es.sections.map(s=>s.id)),'locale_section_parity');
   assert(canonical(pt.references.map(r=>r.id))===canonical(es.references.map(r=>r.id)),'reference_parity');
  }
 }
 assert(projected.size===owners.size&&[...projected].every(o=>owners.has(o)),'mode_owner_parity');
 return {OWNER_COUNT:owners.size,READBACK:'PASS',HASHES:'PASS',SCHEMA:'PASS',PT_ES_PARITY:'PASS',STUDY_PLANTAO_PARITY:'PASS'};
}
export async function writeDraft(db,release){
 validate(release);assert(release.manifest.status==='DRAFT','draft_required');
 const root=db.doc(`clinical_content_versions/${release.manifest.contentVersion}`);
 // create-only reserves the version. Interrupted uploads remain unreadable DRAFT.
 await root.create(release.manifest);
 for(const [id,chunk] of Object.entries(release.chunks))await root.collection('chunks').doc(id).create(chunk);
 return readback(db,release.manifest.contentVersion);
}
export async function readback(db,version){
 const root=db.doc(`clinical_content_versions/${version}`);const doc=await root.get();assert(doc.exists,'version_missing');
 const manifest=doc.data(),chunks={};for(const d of manifest.chunks){const c=await root.collection('chunks').doc(d.id).get();assert(c.exists,'chunk_missing');chunks[d.id]=c.data();}

 const release={manifest,chunks};validate(release);return release;
}
export async function activate(db,version,expectedPrevious){
 const release=await readback(db,version);assert(release.manifest.status==='DRAFT','draft_required');
 const published={...release.manifest,status:'ACTIVE'};const root=db.doc(`clinical_content_versions/${version}`),pointer=db.doc('app_config/clinical_content');
 await db.runTransaction(async tx=>{
  const [current,manifest]=await Promise.all([tx.get(pointer),tx.get(root)]);
  assert((current.data()?.activeVersion??null)===expectedPrevious,'pointer_conflict');
  assert(hash(manifest.data())===hash(release.manifest),'manifest_changed');
  // Re-read every chunk in the transaction: readback cannot race mutation.
  for(const d of published.chunks){const c=await tx.get(root.collection('chunks').doc(d.id));assert(c.data()?.json===release.chunks[d.id].json,'chunk_changed');}
  tx.update(root,{status:'ACTIVE'});
  tx.set(pointer,{activeVersion:version,previousVersion:expectedPrevious,schemaVersion:published.schemaVersion,manifestSha256:hash(published),status:'ACTIVE',activatedAt:new Date().toISOString()});
 });
}
export async function rollback(db,expectedCurrent){
 const pointer=db.doc('app_config/clinical_content');const before=(await pointer.get()).data();
 assert(before?.activeVersion===expectedCurrent&&before.previousVersion,'rollback_pointer');
 const target=await readback(db,before.previousVersion);assert(target.manifest.status==='ACTIVE','rollback_target');
 await db.runTransaction(async tx=>{
  const current=(await tx.get(pointer)).data();assert(hash(current)===hash(before),'pointer_conflict');
  const root=db.doc(`clinical_content_versions/${before.previousVersion}`);
  assert(hash((await tx.get(root)).data())===hash(target.manifest),'manifest_changed');
  for(const d of target.manifest.chunks)assert((await tx.get(root.collection('chunks').doc(d.id))).data()?.json===target.chunks[d.id].json,'chunk_changed');
  tx.set(pointer,{...before,activeVersion:before.previousVersion,previousVersion:before.activeVersion,manifestSha256:hash(target.manifest),activatedAt:new Date().toISOString()});
 });
}
