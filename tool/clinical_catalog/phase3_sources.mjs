import fs from 'node:fs';import assert from 'node:assert/strict';
import {hash,canonical} from './publication.mjs';import {textHash} from './phase2_adapter.mjs';import {slots,projectionHash} from './phase3_resolver.mjs';
const [remotePath,auditRoot,out]=process.argv.slice(2);assert.ok(remotePath&&auditRoot&&out);
const read=p=>JSON.parse(fs.readFileSync(p));
const base=auditRoot+'/pathology-intestinal-group07-2026-10-04';
const approvalPath=base+'/batch-01-human-approval.json',activationPath=base+'/release-batch-01/activation-manifest.json',nativePath=base+'/release-batch-01/native-projections.json',policyPath=base+'/batch-01-publication-policy.json';
const approval=read(approvalPath),activation=read(activationPath),native=read(nativePath),policy=read(policyPath),remote=read(remotePath);
const evidence=[approvalPath,activationPath,nativePath,policyPath].map(path=>({path,sha256:textHash(fs.readFileSync(path))}));
const candidates=[];
for(const r of remote.filter(r=>r.enabled===false)){
 const p=r.payload,q=JSON.parse(p.approvedClinicalPayloadJson),n=native.find(n=>n.owner===r.canonicalPathologyKey);
 const a=approval.approved_payloads.find(a=>a.group===r.approvedSourceGroup);
 const reasons=[];
 if(!a||!a.matches_review_manifest||a.approved_clinical_payload_sha256!==r.approvedClinicalPayloadSha256)reasons.push('EXACT_HUMAN_APPROVAL_MISSING');
 if(approval.version!==r.version||activation.version!==r.version||policy.version!==r.version||q.version!==r.version)reasons.push('VERSION_CONFLICT');
 if(policy.HUMAN_APPROVAL!=='PASS'||policy.CLINICAL_APPROVAL!=='PASS')reasons.push('APPROVAL_UNPROVEN');
 if(activation.approvedHashes[r.canonicalPathologyKey]!==r.approvedClinicalPayloadSha256)reasons.push('APPROVED_OWNER_MAPPING_MISSING');
 if(textHash(p.approvedClinicalPayloadJson)!==r.approvedClinicalPayloadSha256||p.approvedClinicalPayloadSha256!==r.approvedClinicalPayloadSha256)reasons.push('HASH_CONFLICT');
 if(!n||n.approved_source_sha256!==r.approvedClinicalPayloadSha256||canonical(n.selected_fact_ids)!==canonical(r.selectedApprovedFactIds))reasons.push('VARIANT_FACT_BINDING_UNPROVEN');
 const projections={};
 for(const slot of slots){const [mode,locale]=slot.split('_'),value=p[locale]?.[mode+'Projection'];
  if(!value){reasons.push('MISSING_'+slot);continue;}
  if(!n||canonical(value)!==canonical(n.projections?.[mode]?.[locale]))reasons.push('PROJECTION_SOURCE_MISMATCH_'+slot);
  projections[slot]={value,sourceHash:projectionHash(value),references:value.references,version:value.version,referenceVersion:r.version,reviewDate:value.review_date};
 }
 candidates.push({owner:r.canonicalPathologyKey,version:r.version,referenceVersion:r.version,reviewDate:r.clinicalReviewDate,sourceType:'REMOTE_DISABLED_APPROVED',sourcePath:remotePath,sourceDocumentId:r.id,sourceHash:hash(r),approvedPayloadHash:r.approvedClinicalPayloadSha256,sourceEnabled:r.enabled,sourceReleaseActive:r.releaseActive,approvalStatus:reasons.length?'UNVERIFIED':'PASS',approvalEvidence:evidence,hashStatus:reasons.some(r=>r.includes('HASH'))?'FAIL':'PASS',recoveryClass:'A_APPROVED_REMOTE_RECOVERY',projections,sourceGateReasons:reasons});
}
fs.writeFileSync(out,JSON.stringify(candidates),{mode:0o600});console.log(JSON.stringify({candidates:candidates.length,approved:candidates.filter(c=>c.approvalStatus==='PASS').length,reasonCounts:candidates.reduce((a,c)=>{for(const r of c.sourceGateReasons)a[r]=(a[r]??0)+1;return a;},{}),productionWrites:0}));
