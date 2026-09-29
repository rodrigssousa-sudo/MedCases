'use strict';
const {createHash}=require('node:crypto');
const {createAdminControlCenter}=require('./admin_control_center');
const hash=v=>createHash('sha256').update(v).digest('hex');
const FIELDS='title description summary subtitle category specialty authors year version heroImageUrl coverUrl pdfUrl bodyBlocks references language localizations hasEditorialContent status isPublished searchPrefixes searchIndexVersion'.split(' ');
function validateGuide(raw){
 if(!raw||typeof raw!=='object'||Array.isArray(raw)||Buffer.byteLength(JSON.stringify(raw))>700000)throw Error('GUIDE_SIZE_INVALID');
 if(!Number.isSafeInteger(raw.version)||raw.version<1||typeof raw.isPublished!=='boolean')throw Error('GUIDE_VERSION_INVALID');
 for(const lang of ['pt','es']){
  const l=raw.localizations?.[lang];
  if(!l||l.language!==lang||typeof l.title!=='string'||typeof l.summary!=='string'||!Array.isArray(l.bodyBlocks)||!Array.isArray(l.references))throw Error('GUIDE_LOCALE_INVALID');
  if(Object.keys(l).some(k=>!['language','title','subtitle','summary','bodyBlocks','references','pdfUrl'].includes(k)))throw Error('GUIDE_LOCALE_INVALID');
  if(l.bodyBlocks.some(b=>!b||typeof b!=='object'||!['heading','paragraph','bullets','callout','warning','note'].includes(b.type)||Object.keys(b).some(k=>!['type','title','text','items'].includes(k))||['title','text'].some(k=>b[k]!==undefined&&typeof b[k]!=='string')||(b.items!==undefined&&(!Array.isArray(b.items)||b.items.some(i=>typeof i!=='string')))))throw Error('GUIDE_BLOCK_INVALID');
  if(l.references.some(r=>typeof r!=='string'))throw Error('GUIDE_REFERENCE_INVALID');
  const hasBody=l.bodyBlocks.some(b=>(b.title||'').trim()||(b.text||'').trim()||(b.items||[]).some(i=>i.trim()));
  if(raw.isPublished&&(!l.title.trim()||!l.summary.trim()||!hasBody))throw Error('GUIDE_REVIEW_REQUIRED');
 }
 if(!raw.localizations.pt.title.trim()&&!raw.localizations.es.title.trim())throw Error('GUIDE_TITLE_REQUIRED');
 if(!Array.isArray(raw.searchPrefixes)||raw.searchPrefixes.length>420||raw.searchPrefixes.some(x=>typeof x!=='string'||x.length>20))throw Error('GUIDE_INDEX_INVALID');
 const data=Object.fromEntries(FIELDS.filter(k=>raw[k]!==undefined).map(k=>[k,raw[k]]));
 data.status=raw.isPublished?'published':'draft';data.language='multilingual';return data;
}
function createAdminGuideOperations({db,now=()=>Date.now()}){
 const auth=createAdminControlCenter({db,now});
 return async function save(uid,{targetId,reason,data:raw}){
  await auth.authorize(uid,true);
  if(typeof targetId!=='string'||! /^[A-Za-z0-9_-]{1,180}$/.test(targetId))throw Error('INVALID_ID');
  if(typeof reason!=='string'||reason.trim().length<5||reason.length>500)throw Error('REASON_REQUIRED');
  const data=validateGuide(raw),fingerprint=hash(JSON.stringify(data)),key=hash(`${uid}:guide:${targetId}:${fingerprint}`);
  const ref=db.collection('clinical_guides').doc(targetId),request=db.collection('adminOperationRequests').doc(key);
  await db.runTransaction(async tx=>{
   await auth.authorize(uid,true,tx);const previous=await tx.get(request);if(previous.exists)return;
   const existing=await tx.get(ref),before=existing.data()||{};
   if(before.version>data.version)throw Error('GUIDE_STALE_VERSION');
   const time=now(),iso=new Date(time).toISOString();
   const metadata={updatedAt:iso,uploadedAt:before.uploadedAt||iso,uploadedBy:uid,reviewer:data.isPublished?uid:before.reviewer??null,reviewDate:data.isPublished?iso:before.reviewDate??null,adminRequestId:key,...(data.isPublished?{publishedAt:iso}:{})};
   tx.set(ref,{...data,...metadata},{merge:true});
   tx.create(db.collection('adminControlAudit').doc(key),{actorUid:uid,action:data.isPublished?'guidePublish':'guideSave',targetType:'guide',targetId,reason:reason.trim(),timestamp:time,requestId:key,beforeMetadata:{version:before.version??null,status:before.status??'ABSENT'},afterMetadata:{version:data.version,status:data.status,locales:['pt','es'],reviewer:metadata.reviewer,reviewDate:metadata.reviewDate}});
   tx.create(request,{fingerprint,createdAt:time,result:{targetId,version:data.version}});
  });
  const saved=await ref.get();if(!saved.exists)throw Error('GUIDE_READBACK_FAILED');
  // Return metadata only, never put guide prose in operational logs/audit.
  return {targetId,version:saved.data().version,status:saved.data().status,readback:true};
 };
}
module.exports={createAdminGuideOperations,validateGuide};
