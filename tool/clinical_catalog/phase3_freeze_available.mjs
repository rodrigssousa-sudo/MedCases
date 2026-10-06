// Structural recovery of the frozen container from readable ORIGINAL R2 records.
// No clinical normalization, translation or source rediscovery.
import fs from 'node:fs';import assert from 'node:assert/strict';
import {collections,hash,prepare} from './publication.mjs';import {textHash} from './phase2_adapter.mjs';
const [work]=process.argv.slice(2),read=p=>JSON.parse(fs.readFileSync(p));
const source=read(work+'/r1/source-export.json'),ns=read(work+'/r2/PHASE2_NORMALIZED_TARGET.json'),audit=read(work+'/r2/PHASE2_HASH_AUDIT.json');
assert.equal(ns.length,235);const owners=new Set(ns.map(n=>n.owner));assert.equal(owners.size,235);
const rows=Object.fromEntries(collections.map(c=>[c,source[c].filter(r=>owners.has(c==='clinical_identity_registry'?r.canonicalKey:r.match?.canonicalPathologyKey??r.canonicalPathologyKey))]));
const proofs=[];
rows.clinical_content_registry=ns.map(n=>{
 const a=audit.find(a=>a.SOURCE_ID===n.metadata.sourceId);assert.ok(a);assert.equal(hash(n),a.NORMALIZED_HASH);assert.equal(n.status,'RESOLVED');
 const original=source.clinical_content_registry.find(r=>r.id===n.metadata.sourceId);assert.equal(hash(original),a.SOURCE_HASH);assert.equal(hash(original),n.metadata.sourceSha256);
 assert.equal(hash(n.references),a.REFERENCES_HASH);
 const projectionHashes={};for(const mode of ['study','plantao'])for(const lang of ['pt','es']){const slot=mode+'_'+lang;assert.equal(n[mode][lang].format,'markdown');assert.equal(textHash(n[mode][lang].value),a.PROJECTION_HASH[slot]);projectionHashes[slot]=a.PROJECTION_HASH[slot];}
 proofs.push({owner:n.owner,source:n.metadata.sourceId,projectionHashes,referencesHash:a.REFERENCES_HASH,normalizedHash:a.NORMALIZED_HASH,sourceHash:a.SOURCE_HASH});
 const row=structuredClone(original),p=row.payload;
 if(p.approvedClinicalPayload){p.approvedClinicalPayloadJson=p.approvedClinicalPayload;p.approvedClinicalPayloadSha256=row.approvedClinicalPayloadSha256;}
 p.references=structuredClone(n.references);
 for(const mode of ['study','plantao'])for(const lang of ['pt','es']){p[lang]??={};p[lang][mode+'Markdown']=n[mode][lang].value;p[lang][mode+'Projection']={format:'markdown',markdown:n[mode][lang].value,references:structuredClone(n.references)};}
 row.migrationSourceSha256=hash(original);return row;
});
fs.writeFileSync(work+'/r2/R2-B.json',JSON.stringify(prepare('R2-B',rows)));
fs.writeFileSync(work+'/r2/PHASE2_TARGET_MANIFEST.json',JSON.stringify({ownerCount:235,owners:proofs}));
fs.writeFileSync(work+'/out/PHASE3_BASELINE_ALTERNATE_PROOF.json',JSON.stringify({R2_BASELINE_PRESERVED:'PASS',method:'ORIGINAL_NORMALIZED_R2_RECORDS_AGAINST_ORIGINAL_R2_HASH_AUDIT',originalSnapshot:'SOURCE_UNAVAILABLE_AT_CLOSURE',originalTargetManifest:'SOURCE_UNAVAILABLE_AT_CLOSURE',container:'STRUCTURAL_RECONSTRUCTION_NOT_ORIGINAL_FILE',owners:235,projections:940,normalizedSourceSha256:textHash(fs.readFileSync(work+'/r2/PHASE2_NORMALIZED_TARGET.json')),hashAuditSha256:textHash(fs.readFileSync(work+'/r2/PHASE2_HASH_AUDIT.json')),proofs},null,2));
console.log('R2_BASELINE_PRESERVED=PASS (235 normalized records, 940 projections and references matched original R2 hashes)');
