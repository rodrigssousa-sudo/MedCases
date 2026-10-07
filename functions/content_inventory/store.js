'use strict';
const {hash,classify,summary,normalize}=require('./model');
const {createAdminControlCenter}=require('../admin_control_center');
const {readClinicalCatalog}=require('./clinical_catalog');
const {loadActivePathologies,readActivePathologyInventory}=require('./active_pathologies');
const ROOT='adminContentInventoryV2';
const FILTERS=new Set(['ALL','HAS_GAPS','PT_ES_COMPLETE','GOLD33_COMPLETE','APPROVED','PUBLISHED','PENDING','NEEDS_PT','NEEDS_ES','NEEDS_REVIEW','NEEDS_UPDATE','SYNC_ERROR','POSSIBLE_DUPLICATE','CALCULATION_BLOCKED','CLINICAL_CONTENT_PENDING','GOLD33_INCOMPLETE','NEW']);
function createInventory({db,loadSource,now=()=>Date.now(),documentId='__name__'}) {
 const authorize=createAdminControlCenter({db}).authorize;
 const root=kind=>{if(!['drugs','pathologies'].includes(kind))throw Error('INVALID_INVENTORY_KIND');return db.collection(ROOT).doc(kind);};
 async function sync(kind) {
  const ref=root(kind),startedAt=now(),lease=hash(`${kind}:${startedAt}:${Math.random()}`).slice(0,24);
  const prior=await db.runTransaction(async tx=>{const d=await tx.get(ref),old=d.data()||{};if(old.leaseUntil>startedAt)throw Error('SYNC_ALREADY_RUNNING');tx.set(ref,{lease,leaseUntil:startedAt+20*60*1000},{merge:true});return old;});
  const runRef=ref.collection('runs').doc(lease);
  await runRef.set({syncId:lease,type:kind,startedAt,state:'RUNNING'});
  let stage='READ_CURRENT';
  try {
   const oldRows=prior.generation?(await ref.collection('generations').doc(prior.generation).collection('items').get()).docs.map(d=>d.data()):[];
   stage='READ_SOURCE';
   const loaded=kind==='pathologies'?await loadActivePathologies(db,{previous:oldRows}):await loadSource(kind,{previous:oldRows}),oldMap=new Map(oldRows.map(x=>[x.recordId,x]));
   const seen=new Set(loaded.rows.map(x=>x.recordId));
   const missing=oldRows.filter(x=>!seen.has(x.recordId)).map(x=>({...x,missingInSource:true,syncStatus:'MISSING_IN_SOURCE'}));
   stage='PROJECT_METADATA';
   const rows=classify([...loaded.rows,...(loaded.retainMissingRows===false?[]:missing)]).map(x=>({...x,firstIndexedAt:oldMap.get(x.recordId)?.firstIndexedAt||startedAt,lastSeenSourceVersion:x.missingInSource?x.lastSeenSourceVersion:loaded.source.revision,lastSyncAt:startedAt}));
   const fingerprint=hash(rows.map(({lastSyncAt,firstIndexedAt,...r})=>r));
   const generation=hash(`${loaded.source.revision}:${fingerprint}`).slice(0,40);
   const items=ref.collection('generations').doc(generation).collection('items');
   stage='WRITE_STAGING';
   if(generation!==prior.generation){
    // Firestore transaction accounting includes index entries for prefix facets.
    // Keep staging batches small; the published generation remains atomic.
    for(let i=0;i<rows.length;i+=10){const batch=db.batch();for(const row of rows.slice(i,i+10))batch.set(items.doc(row.recordId),row);await batch.commit();}
   }
   stage='PUBLISH_POINTER';
   const completedAt=now(),counts=summary(rows);
   await db.runTransaction(async tx=>{const cur=(await tx.get(ref)).data();if(cur.lease!==lease)throw Error('SYNC_LEASE_LOST');tx.set(ref,{generation,fingerprint,source:loaded.source,sourceMode:loaded.sourceMode,sourceVersion:loaded.sourceVersion,counts,sourceCount:loaded.itemsRead,lastSyncAt:completedAt,syncState:'SYNCED',lease:null,leaseUntil:0},{merge:true});
    tx.set(runRef,{completedAt,state:'COMPLETE',sourceVersion:loaded.source.revision,itemsRead:loaded.itemsRead,itemsCreatedInReadModel:rows.filter(x=>!oldMap.has(x.recordId)).length,itemsUpdatedInReadModel:generation===prior.generation?0:rows.filter(x=>oldMap.has(x.recordId)&&!x.missingInSource).length,mismatches:missing.length,comparison:{MISSING_IN_ADMIN:rows.filter(x=>!oldMap.has(x.recordId)).length,MISSING_IN_SOURCE:missing.length,VERSION_MISMATCH:loaded.rows.filter(x=>oldMap.has(x.recordId)&&oldMap.get(x.recordId).version!==x.version).length,SYNC_MISMATCH:oldRows.filter(x=>x.syncStatus!=='SYNCED').length},errors:0,generation},{merge:true});});
   return {kind,generation,...counts};
  }catch(e){const code=/^[A-Z_0-9]+$/.test(e.message)?e.message:Number.isInteger(e.code)?`SYNC_STORAGE_${e.code}`:'SYNC_FAILED';console.error(JSON.stringify({event:'CONTENT_INVENTORY_SYNC_FAILED',kind,stage,reasonCode:code,errorClass:e instanceof TypeError?'TypeError':e instanceof RangeError?'RangeError':'Error',errorFingerprint:hash(e.message||'').slice(0,16),storageDiagnostics:{requestTooLarge:/request.*(large|size)|maximum.*request/i.test(e.message||''),indexEntries:/index.*entr/i.test(e.message||''),indexSize:/index.*(size|bytes)/i.test(e.message||''),documentSize:/document.*(size|large)/i.test(e.message||''),nestedArray:/nested.*array/i.test(e.message||''),invalidField:/field.*(invalid|path)/i.test(e.message||''),transactionSize:/transaction.*(size|large)/i.test(e.message||'')}}));await db.runTransaction(async tx=>{const cur=(await tx.get(ref)).data();if(cur.lease===lease)tx.set(ref,{syncState:'SYNC_ERROR',lastErrorCode:code,lastErrorStage:stage,lease:null,leaseUntil:0},{merge:true});tx.set(runRef,{completedAt:now(),state:'FAILED',errors:1,reasonCode:code,stage},{merge:true});});throw Error(code);}
 }
 const publicRow=({searchFacets,aliases,sortName,...r})=>r;
 async function read(uid,p={}) {
  await authorize(uid);if(p.action==='clinicalCatalog'){if(p.kind!=='pathologies')throw Error('INVALID_INVENTORY_KIND');return readClinicalCatalog(db,p);}if(p.action&&!['page','detail','history','queue'].includes(p.action))throw Error('INVALID_INVENTORY_ACTION');const ref=root(p.kind),meta=(await ref.get()).data()||{};
  if(p.action==='history'){const docs=await ref.collection('runs').orderBy('startedAt','desc').limit(20).get();return {runs:docs.docs.map(d=>d.data())};}
  if(p.kind==='pathologies')return readActivePathologyInventory(db,p,meta);
  if(!meta.generation)return {meta:{syncState:meta.syncState||'NOT_SYNCED'},rows:[],nextCursor:null};
  const generation=p.generation||meta.generation;if(!/^[a-f0-9]{40}$/.test(generation))throw Error('INVALID_GENERATION');
  const items=ref.collection('generations').doc(generation).collection('items');
  if(p.action==='detail'){if(!/^[a-f0-9]{40}$/.test(p.recordId||''))throw Error('INVALID_RECORD_ID');const d=await items.doc(p.recordId).get();if(!d.exists)throw Error('NOT_FOUND');return {row:publicRow(d.data()),meta};}
  const filter=p.filter||(p.action==='queue'?'HAS_GAPS':'ALL'),term=normalize(p.search||'');
  if(!FILTERS.has(filter)||term.length>100)throw Error('INVALID_FILTER');
  const limit=p.limit??30;if(!Number.isInteger(limit)||limit<1||limit>100)throw Error('INVALID_LIMIT');
  let q=items.where('searchFacets','array-contains',`${filter}:${term}`).orderBy(documentId);
  if(p.cursor){if(!/^[a-f0-9]{40}$/.test(p.cursor))throw Error('INVALID_CURSOR');q=q.startAfter(p.cursor);}
  const docs=(await q.limit(limit+1).get()).docs;
  const {lease,leaseUntil,...safeMeta}=meta;
  const pageRows=docs.slice(0,limit).map(d=>publicRow(d.data()));
  const workItems=pageRows.flatMap(r=>r.queueReasons.map(reason=>({queueId:hash(`${r.kind}:${r.recordId}:${reason}`).slice(0,40),canonicalId:r.canonicalId,name:r.displayName,reason,sourceVersion:r.sourceVersion,currentStatus:r.status,lastUpdated:r.lastUpdated,recordId:r.recordId})));
  return {meta:safeMeta,generation,rows:pageRows,workItems,nextCursor:docs.length>limit?docs[limit-1].id:null};
 }
 return {sync,read};
}
module.exports={ROOT,FILTERS,createInventory};
