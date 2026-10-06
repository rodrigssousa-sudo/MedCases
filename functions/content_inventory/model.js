'use strict';
// A read projection only. No clinical body is returned, stored, or modified.
const crypto = require('node:crypto');
const UNKNOWN = 'UNKNOWN';
const hash = x => crypto.createHash('sha256').update(typeof x === 'string' ? x : JSON.stringify(x)).digest('hex');
const normalize = x => String(x || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[_\s–—-]+/g, ' ').trim();
const text = x => typeof x === 'string' && x.trim() ? x.trim().slice(0, 240) : UNKNOWN;
const bool = x => typeof x === 'boolean' ? x : UNKNOWN;
const statuses = new Set(['DRAFT','PENDING_REVIEW','APPROVED','PUBLISHED','OUTDATED','SYNC_ERROR','UNKNOWN']);
const state = x => statuses.has(x) ? x : UNKNOWN;
const validId = x => typeof x === 'string' && /^[A-Za-z0-9_-]{1,180}$/.test(x);
function base(kind, id, source, path, blob) {
  if (!validId(id)) throw Error('INVALID_CANONICAL_ID');
  if (!/^[a-f0-9]{40}$/.test(source.revision)) throw Error('INVALID_SOURCE_REVISION');
  return {kind, canonicalId:id, [kind === 'drugs' ? 'drugId' : 'pathologyId']:id,
    recordId:hash(`${kind}:${path}:${id}`).slice(0,40), sourcePath:path, sourceBlob:blob || UNKNOWN,
    sourceRepository:source.repository, sourceRevision:source.revision, sourceVersion:source.revision,
    sourceUrl:`${source.repository}/blob/${source.revision}/${path}`, syncStatus:'SYNCED',
    missingInSource:false, status:UNKNOWN, publishedState:UNKNOWN, reviewer:UNKNOWN,
    reviewDate:UNKNOWN, reviewResult:UNKNOWN, lastUpdated:UNKNOWN, schemaVersion:2};
}
function drug(d, source, path, blob, catalogIds) {
  const r = base('drugs',d.id,source,path,blob), g=d.mc_gold_standard_v1 || {};
  r.namePt=text(d.name?.pt || d.pt?.name); r.nameEs=text(d.name?.es || d.es?.name);
  r.ptAvailable=Boolean(d.pt && Object.keys(d.pt).some(k=>k!=='name' && d.pt[k]));
  r.esAvailable=Boolean(d.es && Object.keys(d.es).some(k=>k!=='name' && d.es[k]));
  r.version=text(d.dataVersion || d.version); r.gold33Status=text(g.status);
  r.gold33Complete=g.status==='PASS_CLINICAL_HOMOLOGATION';
  r.homologationStatus=text(g.status); r.calculationAuthorized=bool(g.calculationAuthorized);
  r.publicationAuthorized=bool(g.publicationAuthorized);
  // A publication authorization is NOT a published artifact or human approval.
  r.publishedState=text(g.clinicalPackagePublicationState || d.publishedState);
  r.humanApproved=bool(d.humanApproved); r.clinicalContentApproved=bool(d.clinicalContentApproved);
  r.approvalState=text(d.approvalState); r.status=state(d.status);
  r.reviewer=text(d.reviewer); r.reviewDate=text(d.reviewDate); r.reviewResult=text(d.reviewResult);
  r.lastUpdated=text(d.lastUpdated); r.restrictions=text(typeof d.restrictions==='string'?d.restrictions:undefined);
  r.technicalMapping=text(g.sourceOwner || d.sourceModule); r.inCatalog=catalogIds.has(d.id);
  r.aliases=Array.isArray(d.aliases)?d.aliases.filter(x=>typeof x==='string').map(text).slice(0,80):[];
  return r;
}
function pathology(identity, registry, source, path, blob) {
  const r=base('pathologies',identity.canonicalKey,source,path,blob);
  const rules=registry.managementRules.filter(x=>x.canonicalPathologyKey===identity.canonicalKey);
  const rule=rules[0] || {};
  const contents=registry.content.filter(x=>x.canonicalPathologyKey===identity.canonicalKey);
  r.namePt=text(rule.labels?.pt || rule.pt?.label); r.nameEs=text(rule.labels?.es || rule.es?.label);
  const hasValue=v=>typeof v==='string'?v.trim().length>0:Array.isArray(v)?v.some(hasValue):v && typeof v==='object'?Object.values(v).some(hasValue):typeof v==='number'&&Number.isFinite(v);
  const localeMetadata=new Set(['name','title','language','locale','version','clinicalVersion','reviewer','reviewDate','clinicalReviewDate']);
  const directLocale=v=>typeof v==='string'?v.trim().length>0:v && typeof v==='object'&&!Array.isArray(v)?Object.entries(v).some(([key,value])=>!localeMetadata.has(key)&&hasValue(value)):false;
  const hasLocale=(v,locale)=>v && typeof v==='object' && (Boolean(v.locales?.[locale]) || directLocale(v[locale]) || Object.values(v).some(x=>x && typeof x==='object' && hasLocale(x,locale)));
  r.ptAvailable=contents.some(x=>hasLocale(x.payload,'pt'));
  r.esAvailable=contents.some(x=>hasLocale(x.payload,'es'));
  r.version=text(identity.version); r.managementVersion=text(rule.version);
  r.sourceMode=text(registry.mode); r.authoringStatus=text(rule.authoringStatus);
  r.status=rule.authoringStatus==='AUTHORITATIVE_CURRENT_ENABLED_LOCAL_DRAFT'?'DRAFT':state(rule.status);
  r.reviewDate=text(rule.clinicalReviewDate); r.reviewer=text(rule.reviewer);
  r.reviewResult=text(rule.reviewResult); r.publishedState=text(rule.publishedState);
  r.aliases=[...(identity.aliases||[]),...(identity.strongAliases||[])].filter(x=>typeof x==='string').map(text).slice(0,80);
  r.contentRecordCount=contents.length;
  return r;
}
function classify(rows) {
  const ids=new Map(),names=new Map(),aliases=new Map();
  const add=(m,k,id)=>{if(k && k!==normalize(UNKNOWN)){if(!m.has(k))m.set(k,new Set());m.get(k).add(id);}};
  for(const r of rows){add(ids,r.canonicalId,r.recordId);for(const s of [r.namePt,r.nameEs])add(names,normalize(s),r.recordId);for(const s of [r.namePt,r.nameEs,...r.aliases])add(aliases,normalize(s),r.recordId);}
  const others=(map,keys,id)=>[...new Set(keys.flatMap(k=>[...(map.get(k)||[])])).values()].filter(x=>x!==id).sort();
  return rows.map(row=>{
    const r={...row};
    r.exactIdDuplicates=others(ids,[r.canonicalId],r.recordId);
    r.exactNameDuplicates=others(names,[normalize(r.namePt),normalize(r.nameEs)],r.recordId);
    r.possibleAliasDuplicates=others(aliases,[r.namePt,r.nameEs,...r.aliases].map(normalize),r.recordId).filter(x=>!r.exactNameDuplicates.includes(x));
    r.localeState=r.ptAvailable?(r.esAvailable?'PT_ES_COMPLETE':'PT_ONLY'):(r.esAvailable?'ES_ONLY':'NO_LOCALIZED_CONTENT');
    r.withoutReview=r.reviewer===UNKNOWN || r.reviewDate===UNKNOWN;
    r.outdated=r.status==='OUTDATED';
    r.possibleDuplicate=Boolean(r.exactIdDuplicates.length+r.exactNameDuplicates.length+r.possibleAliasDuplicates.length);
    const reasons=[];
    if(!r.ptAvailable)reasons.push('NEEDS_PT'); if(!r.esAvailable)reasons.push('NEEDS_ES');
    if(r.withoutReview)reasons.push('NEEDS_REVIEW'); if(r.outdated)reasons.push('NEEDS_UPDATE');
    if(r.possibleDuplicate)reasons.push('POSSIBLE_DUPLICATE');
    if(r.syncStatus!=='SYNCED')reasons.push('SYNC_ERROR');
    if(r.kind==='drugs'){if(!r.gold33Complete)reasons.push('GOLD33_INCOMPLETE');if(r.calculationAuthorized===false)reasons.push('CALCULATION_BLOCKED');}
    r.queueReasons=reasons;
    r.filters=['ALL',...reasons];
    if(reasons.length)r.filters.push('HAS_GAPS');
    if(r.localeState==='PT_ES_COMPLETE')r.filters.push('PT_ES_COMPLETE');
    if(r.gold33Complete)r.filters.push('GOLD33_COMPLETE');
    if(r.status==='APPROVED')r.filters.push('APPROVED');
    if(r.status==='PUBLISHED'||r.publishedState==='PUBLISHED')r.filters.push('PUBLISHED');
    if(['DRAFT','PENDING_REVIEW','UNKNOWN'].includes(r.status))r.filters.push('PENDING');
    if(r.kind==='drugs' && r.clinicalContentApproved!==true)r.filters.push('CLINICAL_CONTENT_PENDING');
    const terms=new Set([normalize(r.canonicalId),normalize(r.namePt),normalize(r.nameEs)].filter(x=>x && x!=='unknown'));
    const prefixes=new Set(['']);for(const s of terms)for(let i=1;i<=Math.min(s.length,100);i++)prefixes.add(s.slice(0,i));
    r.searchFacets=r.filters.flatMap(f=>[...prefixes].map(p=>`${f}:${p}`));
    r.displayName=r.namePt!==UNKNOWN?r.namePt:r.nameEs!==UNKNOWN?r.nameEs:'Nome não informado';
    r.sortName=normalize(r.displayName);return r;
  });
}
function summary(rows) {
  const count=p=>rows.filter(p).length;
  return {total:rows.length,canonicalIds:count(r=>validId(r.canonicalId)),pt:count(r=>r.ptAvailable),es:count(r=>r.esAvailable),ptEs:count(r=>r.ptAvailable&&r.esAvailable),withoutReview:count(r=>r.withoutReview),outdated:count(r=>r.outdated),syncErrors:count(r=>r.syncStatus!=='SYNCED'),gold33Complete:count(r=>r.gold33Complete),approved:count(r=>r.status==='APPROVED'),pending:count(r=>r.filters.includes('PENDING')),possibleDuplicates:count(r=>r.possibleDuplicate),exactIdDuplicates:count(r=>r.exactIdDuplicates.length),exactNameDuplicates:count(r=>r.exactNameDuplicates.length),possibleAliasDuplicates:count(r=>r.possibleAliasDuplicates.length),candidateListState:'NOT_VERIFIED',newCandidates:0};
}
module.exports={drug,pathology,classify,summary,hash,normalize,validId};
