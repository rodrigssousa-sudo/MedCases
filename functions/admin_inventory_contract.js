'use strict';
// Metadata-only handoff for a future trusted repository synchronizer. This is
// deliberately not a callable/upload endpoint and cannot publish clinical data.
const STATES=new Set(['DRAFT','PENDING_REVIEW','APPROVED','PUBLISHED','SYNC_ERROR','UNKNOWN']);
function inventoryRecord(kind,source,record){
 if(!['pathologies','drugs'].includes(kind))throw Error('INVALID_INVENTORY_KIND');
 if(!source||typeof source.repository!=='string'||!/^https:\/\//.test(source.repository)||typeof source.revision!=='string'||! /^[a-f0-9]{40,64}$/.test(source.revision))throw Error('SOURCE_PROVENANCE_REQUIRED');
 if(typeof record?.canonicalId!=='string'||! /^[A-Za-z0-9_-]{1,180}$/.test(record.canonicalId))throw Error('INVALID_CANONICAL_ID');
 const allowed='canonicalId namePt nameEs version status reviewer reviewDate lastUpdated syncStatus gold33Status calculationAuthorized approvalState restrictions'.split(' ');
 if(Object.keys(record).some(k=>!allowed.includes(k)))throw Error('METADATA_ONLY');
 if(record.status!==undefined&&!STATES.has(record.status))throw Error('INVALID_CONTENT_STATE');
 if(record.calculationAuthorized!==undefined&&typeof record.calculationAuthorized!=='boolean')throw Error('INVALID_CALCULATION_STATE');
 for(const [k,v]of Object.entries(record))if(k!=='calculationAuthorized'&&typeof v!=='string'&&typeof v!=='number'&&v!==null)throw Error('INVALID_METADATA');
 return {...record,status:record.status??'UNKNOWN',syncStatus:record.syncStatus??'UNKNOWN',sourceRepository:source.repository,sourceRevision:source.revision,schemaVersion:1};
}
module.exports={inventoryRecord};
