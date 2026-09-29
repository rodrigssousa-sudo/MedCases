'use strict';
const {createHash}=require('node:crypto');
const {Filter}=require('firebase-admin/firestore');
const {createAdminControlCenter}=require('./admin_control_center');
const digest=x=>createHash('sha256').update(x).digest('hex');
const SPECS=Object.freeze({
 users:['users','email name displayName status plan subscriptionStatus role locale createdAt lastSeenAt isPartner partnerTitle'],
 pathologies:['adminContentInventoryPathologies','canonicalId namePt nameEs version status lastUpdated reviewer reviewDate sourceRepository sourceRevision syncStatus'],
 drugs:['adminContentInventoryDrugs','canonicalId namePt nameEs version status gold33Status lastUpdated reviewer reviewDate sourceRepository sourceRevision syncStatus calculationAuthorized approvalState restrictions'],
 jobs:['adminOperationalJobs','type owner sourceId status createdAt startedAt completedAt attempts lastErrorCode retrySupported cancelSupported'],
 transcriptions:['_study_background_transcription_jobs','uid sourceId sessionId state status durationMs provider createdAt completedAt errorCode expectedSegments'],
 incidents:['admin_incidents','service module reasonCode errorCode version appVersion frequency count lastSeen lastSeenAt status updatedAt updatedBy'],
 audit:['adminControlAudit','actorUid action targetType targetId reason timestamp requestId'],
 legacyAudit:['admin_audit_logs','actorUid action resourceType resourceId createdAt'],
 health:['adminServiceHealth','service state observedAt reasonCode revision'],
 ai:['admin_ai_usage_events','mode provider model latencyMs durationMs success status reasonCode errorCode createdAt requestHash'],
 releases:['adminReleaseInventory','platform version build status createdAt sourceRevision'],
 deploys:['adminDeploymentInventory','service revision commit status traffic createdAt'],
 notifications:['notificationDeliveries','notificationId state createdAt updatedAt reasonCode openedAt deepLinkSuccess'],
 notificationOutbox:['notificationOutbox','userId eventType resourceId createdAt'],
 campaigns:['adminEngagementDrafts','eventType status createdAt createdBy updatedAt maxPerWeek destination audience schedule'],
 guides:['clinical_guides','title version language status isPublished updatedAt uploadedAt uploadedBy reviewer reviewDate']
});
const SERVICES=['App backend','Firebase','Functions','Study primary','Study Luna fallback','Plantão','AssemblyAI','Storage','Notifications','Guide/CMS','content sync'];
function id(x){if(typeof x!=='string'||!x.trim()||x.length>180||/[\/\x00-\x1f]/.test(x))throw Error('INVALID_ID');return x;}
function scalar(v){if(v===null||typeof v==='boolean'||typeof v==='number'&&Number.isFinite(v))return v;if(typeof v==='string')return v.slice(0,500);if(v?.toMillis)return v.toMillis();return 'UNKNOWN';}
function projection(doc,fields){const d=doc.data();const out={id:doc.id,...Object.fromEntries(fields.split(' ').filter(k=>d[k]!==undefined).map(k=>[k,scalar(d[k])]))};
 if(fields.includes('actorUid'))for(const k of ['beforeMetadata','afterMetadata'])if(d[k]&&typeof d[k]==='object')out[k]=Object.fromEntries(Object.entries(d[k]).filter(([key])=>'role status version remainingSeconds reservedSeconds amountSeconds grantedSeconds revokedSeconds maxPerWeek eventType workerPending reviewer reviewDate creditId enabled active'.split(' ').includes(key)).map(([key,v])=>[key,scalar(v)]));return out;}
function userProjection(doc){const x=projection(doc,SPECS.users[1]);const d=doc.data();x.entitlementLabel=d.isPartner===true?'VIP':['internal','special'].includes(d.plan)?d.plan.toUpperCase():['premium','pro','paid'].includes(d.plan)||d.billingEntitlementActive===true?'PREMIUM':d.plan==='free'?'FREE':'UNKNOWN';return x;}
function createAdminOperations({db,documentId='__name__',now=()=>Date.now(),getAuthUser=async()=>{throw Error('AUTH_IDENTITY_UNAVAILABLE');}}){
 const auth=createAdminControlCenter({db,documentId,now});
 async function page(uid,{table,limit=30,cursor,field,value}={}){
  await auth.authorize(uid);const spec=SPECS[table];if(!spec)throw Error('UNKNOWN_TABLE');if(!Number.isInteger(limit)||limit<1||limit>100)throw Error('INVALID_PAGE_SIZE');
  if(table==='users'&&field==='auto'&&value){field=value.includes('@')?'email':'name';}
  let q=db.collection(spec[0]);
  if(value){const allowed=table==='users'?['uid','email','name','status','plan']:table==='ai'?['mode']:table==='jobs'?['type']:[];if(!allowed.includes(field)||typeof value!=='string'||value.length>180)throw Error('INVALID_FILTER');q=field==='name'?q.where(Filter.or(Filter.where('name','==',value),Filter.where('displayName','==',value))):q.where(field==='uid'?documentId:field,'==',value);}
  q=q.orderBy(documentId).limit(limit+1);if(cursor)q=q.startAfter(id(cursor));
  const result=await q.get(),docs=result.docs.slice(0,limit);
  const count=await db.collection(spec[0]).count().get();
  let metrics;
  if(table==='notifications'){const entries=await Promise.all(['sent','invalid_token','send_uncertain','sending'].map(async state=>[state,(await db.collection('notificationDeliveries').where('state','==',state).count().get()).data().count]));metrics={...Object.fromEntries(entries),devices:(await db.collection('notificationDevices').count().get()).data().count,opened:'UNKNOWN',deepLinkSuccess:'UNKNOWN'};}
  const items=docs.map(d=>table==='users'?userProjection(d):projection(d,spec[1]));
  if(table==='audit'){
   const ids=[...new Set(items.flatMap(r=>[r.actorUid,r.targetType==='user'?r.targetId:null]).filter(Boolean))];
   const chunks=await Promise.all([ids.slice(0,100),ids.slice(100)].filter(x=>x.length).map(ids=>identities(uid,{ids})));const map=new Map(chunks.flatMap(x=>x.items).map(u=>[u.id,u]));
   for(const row of items){row.actorName=map.get(row.actorUid)?.name??null;row.targetName=map.get(row.targetId)?.name??null;}
  }
  return {...(metrics?{metrics}:{}),total:count.data().count,items,nextCursor:result.docs.length>limit?docs.at(-1).id:null,source:spec[0],sourceState:result.empty?'NO_RECORDS_SOURCE_UNVERIFIED':'AVAILABLE'};
 }
 async function identities(uid,{ids}={}){
  await auth.authorize(uid);if(!Array.isArray(ids)||ids.length>100)throw Error('INVALID_IDS');const unique=[...new Set(ids.map(id))];
  const docs=unique.length?await db.getAll(...unique.map(x=>db.collection('users').doc(x))):[];
  return {items:docs.filter(d=>d.exists).map(d=>({id:d.id,name:d.data().name||d.data().displayName||'Usuário',email:d.data().email||null}))};
 }
 async function detail(uid,{userId}){
  await auth.authorize(uid);id(userId);const ref=db.collection('users').doc(userId),snap=await ref.get();if(!snap.exists)throw Error('NOT_FOUND');
  const month=new Date(now()).toISOString().slice(0,7),key=digest(`${userId}\n${month}`);
  const [devices,usage,credits]=await Promise.all([db.collection('notificationDevices').where('userId','==',userId).count().get(),db.collection('monthlyUsage').doc(key).get(),db.collection('adminManualCredits').where('userId','==',userId).where('status','in',['ACTIVE','REVOKED_RESERVED','EXPIRED_RESERVED']).limit(101).get()]);
  if(credits.size>100)throw Error('CREDIT_READ_LIMIT');let available=0,reserved=0;
  for(const doc of credits.docs){const c=doc.data();if(!Number.isFinite(c.remainingSeconds)||!Number.isFinite(c.reservedSeconds)||c.remainingSeconds<c.reservedSeconds)throw Error('CORRUPT_CREDIT');reserved+=c.reservedSeconds;if(c.status==='ACTIVE'&&(c.expiresAt==null||c.expiresAt>now()))available+=c.remainingSeconds-c.reservedSeconds;}
  const u=usage.exists?usage.data():{};
  return {...userProjection(snap),deviceCount:devices.data().count,month,baseTranscriptionAllocatedMs:u.totals?.transcription??'UNKNOWN',baseRecordingAllocatedMs:u.totals?.recording??'UNKNOWN',manualConsumedMs:u.manualUsedMs??0,manualAvailableSeconds:Math.round(available*1000)/1000,manualReservedSeconds:Math.round(reserved*1000)/1000,baseAllowance:'UNCHANGED — authoritative gateway contract',premiumWrite:'READ_ONLY — billing contract preserved'};
 }
 async function overview(uid){
  await auth.authorize(uid);const [users,health]=await Promise.all([db.collection('users').count().get(),db.collection('adminServiceHealth').limit(30).get()]);
  const rows=health.docs.map(d=>projection(d,SPECS.health[1]));return {users:users.data().count,observedAt:now(),services:SERVICES.map(service=>{const r=rows.find(r=>r.service===service);return r&&Number.isFinite(r.observedAt)&&now()-r.observedAt>=0&&now()-r.observedAt<900000?{...r,state:['HEALTHY','DEGRADED','FAIL'].includes(r.state)?r.state:'UNKNOWN'}:{service,state:'UNKNOWN',reasonCode:'NO_RECENT_VERIFIED_SIGNAL'};})};
 }
 async function mutate(uid,input){
  await auth.authorize(uid,true);const {action,requestId,targetId,reason}=input;id(requestId);id(targetId);if(typeof reason!=='string'||reason.trim().length<5||reason.length>500)throw Error('REASON_REQUIRED');
  if(!['setUserStatus','setUserRole','setIncidentState','saveCampaignDraft','retryTranscription','saveMaintenance','saveAppUpdate'].includes(action))throw Error('UNSUPPORTED_ACTION');
  const targetIdentity=action.startsWith('setUser')?await getAuthUser(targetId):null;
  if(targetIdentity&&Object.entries(targetIdentity.customClaims||{}).some(([k,v])=>['admin','master','supervisor','role'].includes(k)&&v))throw Error('CLAIM_MANAGED_ACCOUNT');
  const key=digest(`${uid}:${requestId}`),fingerprint=digest(JSON.stringify(Object.keys(input).sort().map(k=>[k,input[k]])));
  return db.runTransaction(async tx=>{
   const role=await auth.authorize(uid,true,tx),req=db.collection('adminOperationRequests').doc(key),prior=await tx.get(req);if(prior.exists){if(prior.data().fingerprint!==fingerprint)throw Error('IDEMPOTENCY_CONFLICT');return prior.data().result;}
   const time=now();let before={},after={},targetType,ref;
   if(action.startsWith('setUser')){
    ref=db.collection('users').doc(targetId);const s=await tx.get(ref);if(!s.exists)throw Error('NOT_FOUND');const d=s.data();if(targetId===uid||d.role==='master')throw Error('PROTECTED_ACCOUNT');
    if(action==='setUserRole'){if(role!=='master')throw Error('MASTER_REQUIRED');if(!['user','supervisor','admin'].includes(input.value))throw Error('INVALID_ROLE');before={role:d.role??'user'};after={role:input.value};}
    else {if(d.role==='admin'&&role!=='master')throw Error('MASTER_REQUIRED');if(!['approved','blocked','pending'].includes(input.value))throw Error('INVALID_STATUS');before={status:d.status??'UNKNOWN'};after={status:input.value};}
    targetType='user';
   }else if(action==='setIncidentState'){
    ref=db.collection('admin_incidents').doc(targetId);const s=await tx.get(ref);if(!s.exists)throw Error('NOT_FOUND');if(!['open','acknowledged','resolved'].includes(input.value))throw Error('INVALID_STATUS');before={status:s.data().status??'UNKNOWN'};after={status:input.value,updatedAt:time,updatedBy:uid};targetType='incident';
   }else if(action==='saveMaintenance'||action==='saveAppUpdate'){
    if(role!=='master')throw Error('MASTER_REQUIRED');
    const value=input.value;if(!value||typeof value!=='object')throw Error('INVALID_CONFIG');
    const collection=action==='saveMaintenance'?'app_config':'app_updates',expectedId=action==='saveMaintenance'?'maintenance':'current';
    if(targetId!==expectedId)throw Error('INVALID_CONFIG');
    ref=db.collection(collection).doc(targetId);const snapshot=await tx.get(ref);const previous=snapshot.data()||{};
    if(action==='saveMaintenance'){
     if(typeof value.enabled!=='boolean'||typeof value.message!=='string'||value.message.length>2000)throw Error('INVALID_CONFIG');
     after={enabled:value.enabled,message:value.message};before={enabled:previous.enabled??null};
    }else{
     if(typeof value.active!=='boolean'||typeof value.version!=='string'||!value.version.trim()||value.version.length>30||typeof value.title!=='string'||!value.title.trim()||value.title.length>200||typeof value.date!=='string'||value.date.length>40||!Array.isArray(value.items)||value.items.length>30||value.items.some(v=>typeof v!=='string'||v.length>500)||(value.active&&!value.items.length))throw Error('INVALID_CONFIG');
     after={active:value.active,version:value.version,title:value.title,date:value.date,items:value.items};before={active:previous.active??null,version:previous.version??null};
    }
    after.updatedBy=uid;after.updatedAt=new Date(time).toISOString();targetType='configuration';
   }else if(action==='retryTranscription'){
    ref=db.collection('_study_background_transcription_jobs').doc(targetId);
    const jobSnap=await tx.get(ref),logicalSnap=await tx.get(ref.collection('logical').doc('recording'));
    if(!jobSnap.exists||!logicalSnap.exists)throw Error('NOT_FOUND');
    const job=jobSnap.data(),logical=logicalSnap.data(),receipt=job.usage||{};
    const reservationId=receipt['x-medcases-usage-reservation'];
    if(typeof reservationId!=='string'||! /^[a-f0-9]{64}$/.test(reservationId))throw Error('RETRY_NOT_SUPPORTED');
    const reservation=await tx.get(db.collection('usageReservations').doc(reservationId));
    const lease=logical.leaseUntil?.toMillis?.()??logical.leaseUntil??0;
    if(job.deleted||job.provider!=='assemblyai'||job.state!=='retryable_error'||logical.state!=='retryable_error'||logical.retryable===false||!logical.providerTranscriptId||logical.providerDeleted||lease>time||logical.ownerUid!==job.uid||!reservation.exists||reservation.data().uid!==job.uid||reservation.data().attempt!==receipt['x-medcases-usage-attempt']||!['executing','reserved'].includes(reservation.data().state))throw Error('RETRY_NOT_SUPPORTED');
    before={state:job.state,workerPending:job.workerPending===true};
    after={workerPending:true,adminRetryRequestedAt:time};targetType='transcriptionJob';
   }else{
    if(!['NEW_FEATURE_AVAILABLE','GLOBAL_ENGAGEMENT_REMINDER'].includes(input.eventType))throw Error('INVALID_EVENT');
    for(const lang of ['pt','es']){const text=input[lang];if(!text||typeof text.title!=='string'||!text.title.trim()||text.title.length>120||typeof text.body!=='string'||!text.body.trim()||text.body.length>500)throw Error('PT_ES_REQUIRED');}
    for(const field of ['destination','audience','schedule'])if(input[field]!==undefined&&(typeof input[field]!=='string'||input[field].length>500))throw Error('INVALID_DRAFT_FIELD');
    ref=db.collection('adminEngagementDrafts').doc(targetId);const s=await tx.get(ref);if(s.exists&&s.data().status!=='DRAFT')throw Error('CAMPAIGN_NOT_DRAFT');before={status:s.exists?s.data().status:'ABSENT'};
    after={destination:input.destination||'Home',audience:input.audience||'',schedule:input.schedule||'',eventType:input.eventType,pt:{title:input.pt.title,body:input.pt.body},es:{title:input.es.title,body:input.es.body},status:'DRAFT',maxPerWeek:3,respectOptOut:true,respectQuietHours:true,respectLocale:true,dispatchEnabled:false,createdAt:s.exists?s.data().createdAt:time,createdBy:s.exists?s.data().createdBy:uid,updatedAt:time};targetType='campaign';
   }
   const result={targetId,action,status:after.status??'UPDATED'};
   tx.set(ref,after,{merge:true});tx.create(db.collection('adminControlAudit').doc(key),{actorUid:uid,action,targetType,targetId,reason:reason.trim(),beforeMetadata:before,afterMetadata:targetType==='configuration'?{enabled:after.enabled??null,active:after.active??null,version:after.version??null}:action==='saveCampaignDraft'?{status:'DRAFT',eventType:after.eventType,maxPerWeek:3}:after,timestamp:time,requestId});tx.create(req,{fingerprint,result,createdAt:time});return result;
  });
 }
 return {page,detail,overview,mutate,identities};
}
module.exports={createAdminOperations,SPECS,SERVICES,projection,userProjection};
