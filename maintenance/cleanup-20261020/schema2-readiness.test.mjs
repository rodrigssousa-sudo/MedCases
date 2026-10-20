// Technical fixtures only. No medical approval, credentials or network.
import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=process.env.MEDCASES_CATALOG_TOOL_ROOT;
assert(root, 'Set MEDCASES_CATALOG_TOOL_ROOT to the existing catalog tool directory');
const {prepare,validate,activate,rollback,hash,collections}=await import(pathToFileURL(root+'/publication.mjs'));
const {extraCollections}=await import(pathToFileURL(root+'/functional_schema.mjs'));
const sha=s=>createHash('sha256').update(s).digest('hex');
function rows(){
  const result=Object.fromEntries([...collections,...extraCollections].map(k=>[k,[]]));
  result.clinical_identity_registry=[{canonicalKey:'synthetic_nonclinical',aliases:['Synthetic'],enabled:true}];
  const original=JSON.stringify({owner:'synthetic_nonclinical',version:'TEST',synthetic:true});
  const payload={approvedClinicalPayloadJson:original,approvedClinicalPayloadSha256:sha(original),references:[{id:'test-only'}]};
  for(const locale of ['pt','es']){
    payload[locale]={};
    for(const mode of ['plantao','study']){
      payload[locale][mode+'Markdown']='NONCLINICAL FIXTURE '+locale+' '+mode;
      payload[locale][mode+'Projection']={format:'markdown',markdown:payload[locale][mode+'Markdown'],references:payload.references};
    }
  }
  result.clinical_projection_registry=[{canonicalPathologyKey:'synthetic_nonclinical',enabled:true,approvedClinicalPayloadSha256:sha(original),payload}];
  return result;
}
const release=()=>prepare('SYNTHETIC-TEST',rows(),{schemaVersion:2});
test('schema 2 prepares DRAFT and preserves PT/ES in both modes',()=>{
  const r=release(),v=validate(r);assert.equal(r.manifest.status,'DRAFT');
  for(const key of ['plantaoPtCount','plantaoEsCount','studyPtCount','studyEsCount'])assert.equal(v[key],1);
});
test('altered chunk bytes rejected',()=>{const r=release();r.chunks[r.manifest.chunks[0].id].json+=' ';assert.throws(()=>validate(r),/chunk_hash/);});
test('payload hash mismatch rejected',()=>{const r=rows();r.clinical_projection_registry[0].payload.approvedClinicalPayloadJson+=' ';assert.throws(()=>prepare('TEST',r,{schemaVersion:2}),/approved_hash/);});
test('missing ES projection rejected',()=>{const r=rows();delete r.clinical_projection_registry[0].payload.es.plantaoProjection;assert.throws(()=>prepare('TEST',r,{schemaVersion:2}),/markdown_projection/);});
test('reference divergence rejected',()=>{const r=rows();r.clinical_projection_registry[0].payload.es.plantaoProjection.references=[];assert.throws(()=>prepare('TEST',r,{schemaVersion:2}),/markdown_projection/);});
test('duplicate identity rejected',()=>{const r=rows();r.clinical_identity_registry.push({...r.clinical_identity_registry[0]});assert.throws(()=>prepare('TEST',r,{schemaVersion:2}),/owner_count/);});
test('missing collection rejected',()=>{const r=rows();delete r.clinical_protocols;assert.throws(()=>prepare('TEST',r,{schemaVersion:2}),/missing_collection/);});
test('technical DRAFT validation is not medical authorization',()=>{
  const r=release();assert.equal(validate(r).SCHEMA,'PASS');
  assert.equal(r.manifest.clinicalReleaseRegistry,undefined);
  assert.equal(r.manifest.status,'DRAFT');
});
// This in-memory adapter tests the EXISTING transaction code, not Firestore.
function store(){
  const old=release();old.manifest.contentVersion='OLD';old.manifest.status='ACTIVE';
  const next=release();const data=new Map();
  for(const r of [old,next]){
    const base='clinical_content_versions/'+r.manifest.contentVersion;data.set(base,r.manifest);
    for(const [id,c] of Object.entries(r.chunks))data.set(base+'/chunks/'+id,c);
  }
  data.set('app_config/clinical_content',{activeVersion:'OLD',previousVersion:null,manifestSha256:hash(old.manifest),status:'ACTIVE',schemaVersion:2});
  const snapshot=path=>({exists:data.has(path),data:()=>structuredClone(data.get(path))});
  const doc=path=>({path,get:async()=>snapshot(path),collection:name=>({doc:id=>doc(path+'/'+name+'/'+id)})});
  const db={doc,runTransaction:async fn=>{
    const writes=[];
    await fn({get:async ref=>snapshot(ref.path),set:(ref,value)=>writes.push([ref.path,value]),update:(ref,value)=>writes.push([ref.path,{...data.get(ref.path),...value}])});
    for(const [p,v] of writes)data.set(p,v);
  }};
  return {db,data};
}
test('activation and rollback preserve version pointer in transaction model',async()=>{
  const {db,data}=store();await activate(db,'SYNTHETIC-TEST','OLD');
  assert.equal(data.get('app_config/clinical_content').activeVersion,'SYNTHETIC-TEST');
  await rollback(db,'SYNTHETIC-TEST');assert.equal(data.get('app_config/clinical_content').activeVersion,'OLD');
});
test('concurrent pointer conflict leaves all documents unchanged',async()=>{
  const {db,data}=store(),before=JSON.stringify([...data]);
  await assert.rejects(activate(db,'SYNTHETIC-TEST','WRONG'),/pointer_conflict/);
  assert.equal(JSON.stringify([...data]),before);
});
