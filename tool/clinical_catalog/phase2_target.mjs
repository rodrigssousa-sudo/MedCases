import fs from 'node:fs';import assert from 'node:assert/strict';
import {collections,prepare,hash} from './publication.mjs';
import {normalizePhase2} from './phase2_adapter.mjs';
export function target(source, normalized, version){
 const owners=new Set(normalized.map(n=>n.owner));
 const registries=Object.fromEntries(collections.map(c=>[c,source[c].filter(r=>owners.has(c==='clinical_identity_registry'?r.canonicalKey:r.match?.canonicalPathologyKey??r.canonicalPathologyKey))]));
 registries.clinical_content_registry=normalized.map(n=>{
  const original=source.clinical_content_registry.find(r=>r.id===n.metadata.sourceId);
  assert.equal(hash(original),n.metadata.sourceSha256);assert.equal(hash(normalizePhase2(original)),hash(n));assert.equal(n.status,'RESOLVED');
  const row=structuredClone(original),p=row.payload;
  if(p.approvedClinicalPayload){p.approvedClinicalPayloadJson=p.approvedClinicalPayload;p.approvedClinicalPayloadSha256=row.approvedClinicalPayloadSha256;}
  p.references=structuredClone(n.references);
  for(const mode of ['study','plantao'])for(const lang of ['pt','es']){
   assert.equal(n[mode][lang].format,'markdown');p[lang]??={};
   p[lang][`${mode}Markdown`]=n[mode][lang].value;
   p[lang][`${mode}Projection`]={format:'markdown',markdown:n[mode][lang].value,references:structuredClone(n.references)};
  }
  row.migrationSourceSha256=hash(original);return row;
 });
 return prepare(version,registries);
}
if(process.argv[1]?.endsWith('phase2_target.mjs')){
 const [sourcePath,dir]=process.argv.slice(2),source=JSON.parse(fs.readFileSync(sourcePath)),normalized=JSON.parse(fs.readFileSync(`${dir}/PHASE2_NORMALIZED_TARGET.json`));
 const frozen=new Set(JSON.parse(fs.readFileSync(`${dir}/PHASE2_BASELINE_MANIFEST.json`)).map(x=>x.OWNER_ID));
 for(const [v,ns] of [['R2-A',normalized.filter(n=>frozen.has(n.owner))],['R2-B',normalized]]){
  const release=target(source,ns,v);fs.writeFileSync(`${dir}/${v}.json`,JSON.stringify(release),{mode:0o600});console.log(`${v}_OWNERS=${release.manifest.ownerCount}`);
 }
}
