'use strict';
// Called only after the existing inventory's Admin authorization. Read-only;
// returns catalog metadata, never clinical bodies, patients or Guide documents.
async function readClinicalCatalog(db,params={}) {
 const {validate,hash}=await import('./clinical_publication.mjs');
 const pointerDoc=await db.doc('app_config/clinical_content').get();const pointer=pointerDoc.exists?pointerDoc.data():null;
 const requested=params.contentVersion??pointer?.activeVersion??null;
 if(requested!==null && !/^[A-Za-z0-9._-]{1,120}$/.test(requested))throw Error('INVALID_CONTENT_VERSION');
 const versions=await db.collection('clinical_content_versions').limit(20).get();
 const drafts=versions.docs.map(d=>({contentVersion:d.id,status:d.data().status,ownerCount:d.data().ownerCount}));
 const result={activeVersion:pointer?.activeVersion??null,contentVersion:requested,ownerCount:null,manifestSha256:null,status:'NO_ACTIVE_VERSION',coverage:'UNKNOWN',hashGate:'NOT_CHECKED',parity:'NOT_CHECKED',minimumOwnerCount:577,versions:drafts};
 if(!requested)return result;
 const root=await db.doc('clinical_content_versions/'+requested).get();if(!root.exists)throw Error('CONTENT_VERSION_NOT_FOUND');const manifest=root.data();
 Object.assign(result,{status:manifest.status,ownerCount:manifest.ownerCount,manifestSha256:hash(manifest),coverage:manifest.ownerCount>=577?'PASS':'BLOCKED',hashGate:'BLOCKED',parity:'BLOCKED'});
 try{
  if(!Array.isArray(manifest.chunks)||manifest.chunks.length>5000)throw Error('chunk_count');
  const chunks={};for(let offset=0;offset<manifest.chunks.length;offset+=8){await Promise.all(manifest.chunks.slice(offset,offset+8).map(async d=>{if(!/^[A-Za-z0-9._-]{1,120}$/.test(d.id))throw Error('chunk_id');const c=await db.doc('clinical_content_versions/'+requested+'/chunks/'+d.id).get();if(!c.exists)throw Error('chunk_missing');chunks[d.id]=c.data();}));}
  const ownerRows=manifest.chunks.filter(d=>d.collection==='clinical_identity_registry').flatMap(d=>JSON.parse(chunks[d.id].json));
  const contentRows=manifest.chunks.filter(d=>d.collection==='clinical_content_registry').flatMap(d=>JSON.parse(chunks[d.id].json));
  // Per-owner availability is metadata, not a count-based publication claim.
  const declared=new Map((manifest.owners??[]).map(x=>[x.ownerId,x]));
  result.owners=ownerRows.map(row=>{
   const ownerId=row.canonicalKey;const documents=contentRows.filter(r=>r.canonicalPathologyKey===ownerId);const availableModes={},referenceState={};
   for(const mode of ['study','plantao']){availableModes[mode]={};referenceState[mode]={};
    for(const locale of ['pt','es']){
     const projections=documents.map(r=>r.payload?.[locale]?.[mode+'Projection']).filter(Boolean);
     const explicit=declared.get(ownerId);
     availableModes[mode][locale]=explicit?.availableModes?.[mode]?.[locale]??projections.length>0;
     referenceState[mode][locale]=explicit?.referenceState?.[mode]?.[locale]??(!projections.length?'not_available':projections.every(p=>Array.isArray(p.references)&&p.references.length>0)?'present':'unspecified_missing');
    }
   }
   return {ownerId,availableModes,referenceState};
  });
  result.functionalCoverage='NOT_VERIFIED_AGAINST_CURRENT_SOURCE_SETS';
  result.coverageModel='LEGACY_COUNT_FLOOR_ONLY';
  validate({manifest,chunks});
  if(pointer?.activeVersion===requested && (pointer.status!=='ACTIVE'||pointer.schemaVersion!==1||manifest.status!=='ACTIVE'||pointer.manifestSha256!==result.manifestSha256))throw Error('pointer_manifest_mismatch');
  Object.assign(result,{hashGate:'PASS',parity:'PASS'});
 }catch(e){delete result.owners;delete result.functionalCoverage;result.validationError=/^[a-z_]+$/.test(e.message)?e.message:'catalog_validation_failed';}
 return result;
}
module.exports={readClinicalCatalog};
