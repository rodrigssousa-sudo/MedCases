// Pure recovery gate: callers supply frozen evidence, never generated content.
import {hash} from './publication.mjs';
import {textHash} from './phase2_adapter.mjs';
export const slots=['study_pt','study_es','plantao_pt','plantao_es'];
export function identityMatches(owner,source){
 return source.owner===owner || (source.identityApproval==='PASS' &&
  Array.isArray(source.preservedRuntimeIds) && source.preservedRuntimeIds.includes(owner) && source.preservedRuntimeIds.includes(source.owner));
}
export function projectionHash(value){return typeof value==='string'?textHash(value):hash(value);}
export function validateCandidate(owner,c){
 const reasons=[];
 if(!identityMatches(owner,c))reasons.push('OWNER_IDENTITY_UNPROVEN');
 if(c.approvalStatus!=='PASS'||!c.approvalEvidence?.length)reasons.push('APPROVAL_UNPROVEN');
 if(!c.version||!c.referenceVersion||!c.reviewDate)reasons.push('VERSION_PROVENANCE_MISSING');
 if(c.hashStatus!=='PASS')reasons.push('SOURCE_HASH_UNVERIFIED');
 if(c.revoked||c.superseded)reasons.push('SOURCE_NOT_CURRENTLY_ELIGIBLE');
 for(const slot of slots){const p=c.projections?.[slot];
  if(!p){reasons.push('MISSING_'+slot.toUpperCase());continue;}
  if(p.sourceHash!==projectionHash(p.value))reasons.push('HASH_CONFLICT_'+slot.toUpperCase());
  if(!Array.isArray(p.references)||!p.references.length)reasons.push('MISSING_APPROVED_REFERENCES_'+slot.toUpperCase());
  if(p.version!==c.version||p.referenceVersion!==c.referenceVersion||p.reviewDate!==c.reviewDate)reasons.push('VERSION_INCOMPATIBLE_'+slot.toUpperCase());
 }
 return reasons;
}
export function resolveOwner(owner,candidates){
 const evaluated=candidates.map(c=>({candidate:c,reasons:validateCandidate(owner,c)}));
 const eligible=evaluated.filter(e=>!e.reasons.length).map(e=>e.candidate);
 // Exact duplicate mirrors may corroborate, but differing approved versions or
 // clinical projections must not be silently preferred by timestamp/filename.
 const fingerprints=new Set(eligible.map(c=>hash({version:c.version,referenceVersion:c.referenceVersion,reviewDate:c.reviewDate,projections:c.projections})));
 if(fingerprints.size>1)return {owner,recovered:false,classification:'G_CONFLICTING_APPROVED_SOURCES',reasons:['COMPETING_APPROVED_PROJECTIONS'],evaluated};
 if(eligible.length){const selected=eligible[0];return {owner,recovered:true,classification:selected.recoveryClass,selected,reasons:[],evaluated};}
 return {owner,recovered:false,classification:'F_UNRESOLVED_PROVENANCE',reasons:[...new Set(evaluated.flatMap(e=>e.reasons))],evaluated};
}
/** Explicit cross-source assembly only; no fallback or generated projection. */
export function combineApproved(owner,parts){
 if(parts.length!==4||new Set(parts.map(p=>p.slot)).size!==4||!parts.every(p=>slots.includes(p.slot)))throw Error('FOUR_EXPLICIT_SLOTS_REQUIRED');
 if(!parts.every(p=>identityMatches(owner,p)&&p.approvalStatus==='PASS'&&p.approvalEvidence?.length))throw Error('PROVENANCE_UNPROVEN');
 if(new Set(parts.map(p=>JSON.stringify([p.version,p.referenceVersion,p.reviewDate]))).size!==1)throw Error('VERSION_CONFLICT');
 return {owner,version:parts[0].version,referenceVersion:parts[0].referenceVersion,reviewDate:parts[0].reviewDate,approvalStatus:'PASS',approvalEvidence:parts.flatMap(p=>p.approvalEvidence),hashStatus:'PASS',recoveryClass:'D_APPROVED_CROSS_SOURCE_RECOVERY',projections:Object.fromEntries(parts.map(p=>[p.slot,{value:p.value,sourceHash:p.sourceHash,references:p.references,version:p.version,referenceVersion:p.referenceVersion,reviewDate:p.reviewDate}]))};
}
