'use strict';
// Administrative metadata only. Never return arbitrary Firestore documents.
const {createHash}=require('node:crypto');
const hash=x=>createHash('sha256').update(x).digest('hex');
const CATEGORIES=Object.freeze(['SOCIO','EQUIPE','MARKETING','UNIVERSIDADE','INFLUENCER','SUPORTE','TESTE_INTERNO','OUTRO']);
const TABLES=Object.freeze({
 users:{collection:'users',fields:['email','name','displayName','status','role','plan','subscriptionStatus','createdAt','lastSeenAt','locale']},
 credits:{collection:'adminManualCredits',fields:['userId','amountSeconds','remainingSeconds','reservedSeconds','category','reason','grantedBy','grantedAt','expiresAt','status']},
 ledger:{collection:'adminCreditLedger',fields:['userId','creditId','type','amountSeconds','operationId','actorUid','timestamp']},
 transcriptions:{collection:'_study_background_transcription_jobs',fields:['uid','sourceId','sessionId','state','status','durationMs','provider','createdAt','completedAt','errorCode','expectedSegments']},
 jobs:{collection:'usageReservations',fields:['uid','month','state','maximumMs','chargedMs','createdAt','finishedAt','executionCount','completedExecutions']},
 incidents:{collection:'admin_incidents',fields:['service','reasonCode','version','frequency','lastSeen','status','updatedAt','updatedBy']},
 audit:{collection:'adminControlAudit',fields:['actorUid','action','targetType','targetId','reason','timestamp','requestId']},
 ai:{collection:'admin_ai_usage_events',fields:['mode','provider','model','latencyMs','status','reasonCode','createdAt','requestHash']},
 notifications:{collection:'notificationOutbox',fields:['userId','eventType','state','status','createdAt','sentAt','reasonCode']},
 pathologies:{collection:'adminContentInventoryPathologies',fields:['canonicalId','namePt','nameEs','version','status','reviewer','reviewDate','sourceRevision','syncStatus','lastUpdated']},
 drugs:{collection:'adminContentInventoryDrugs',fields:['canonicalId','namePt','nameEs','version','gold33Status','reviewer','reviewDate','sourceRevision','syncStatus','lastUpdated','calculationAuthorized','approvalState']},
 services:{collection:'adminServiceHealth',fields:['service','state','observedAt','reasonCode','revision']},
 releases:{collection:'adminReleaseInventory',fields:['platform','version','build','status','revision','commit','createdAt','traffic']},
 guides:{collection:'clinical_guides',fields:['title','titlePt','titleEs','version','status','locale','updatedAt','reviewer']}
});
function id(x){if(typeof x!=='string'||!x.trim()||x.length>180||/[\/\x00-\x1f]/.test(x))throw Error('INVALID_ID');return x;}
function validSeconds(x){return typeof x==='number'&&Number.isFinite(x)&&x>=0&&Number.isSafeInteger(Math.round(x*1000))&&Math.abs(Math.round(x*1000)/1000-x)<1e-9;}
function reason(x){if(typeof x!=='string'||x.trim().length<5||x.length>500)throw Error('REASON_REQUIRED');return x.trim();}
function safeValue(x){if(x===null||typeof x==='boolean'||typeof x==='number'&&Number.isFinite(x))return x;if(typeof x==='string')return x.slice(0,500);if(x&&typeof x.toMillis==='function')return x.toMillis();return null;}
function project(doc,fields){const d=doc.data();return {id:doc.id,...Object.fromEntries(fields.filter(k=>d[k]!==undefined).map(k=>[k,safeValue(d[k])]))};}
function createAdminControlCenter({db,documentId='__name__',now=()=>Date.now()}){
 async function authorize(uid,write=false,tx=null){
  if(!uid)throw Error('UNAUTHENTICATED');id(uid);
  const ref=db.collection('users').doc(uid),u=await (tx?tx.get(ref):ref.get());
  const role=u.exists?u.data().role:null;
  if(!['master','admin','supervisor'].includes(role)||['blocked','disabled'].includes(u.data()?.status))throw Error('ADMIN_ACCESS_DENIED');
  if(write&&role==='supervisor')throw Error('SUPERVISOR_READ_ONLY');
  return role;
 }
 async function list(uid,{table,cursor,limit=30,filter}={}){
  await authorize(uid);const spec=TABLES[table];if(!spec)throw Error('UNKNOWN_TABLE');
  if(!Number.isInteger(limit)||limit<1||limit>100)throw Error('INVALID_PAGE_SIZE');
  let q=db.collection(spec.collection);
  if(filter){
   const allowed=table==='users'?['email','name','status','plan','role']:table==='credits'||table==='ledger'?['userId']:[];
   if(!allowed.includes(filter.field)||typeof filter.value!=='string'||filter.value.length>180)throw Error('INVALID_FILTER');
   q=q.where(filter.field,'==',filter.value);
  }
  q=q.orderBy(documentId).limit(limit+1);if(cursor)q=q.startAfter(id(cursor));
  const page=await q.get(),docs=page.docs.slice(0,limit);
  return {items:docs.map(d=>project(d,spec.fields)),nextCursor:page.docs.length>limit?docs.at(-1).id:null,source:spec.collection};
 }
 async function user(uid,{userId}){await authorize(uid);const d=await db.collection('users').doc(id(userId)).get();if(!d.exists)throw Error('NOT_FOUND');return project(d,TABLES.users.fields);}
 async function dashboard(uid){
  await authorize(uid);
  const sources={users:'users',guides:'clinical_guides',pathologies:'adminContentInventoryPathologies',drugs:'adminContentInventoryDrugs'};
  const entries=await Promise.all(Object.entries(sources).map(async([key,c])=>{
   try{const s=await db.collection(c).count().get();return[key,{state:'KNOWN',value:s.data().count,source:c}];}
   catch(_){return[key,{state:'UNKNOWN',reasonCode:'COUNT_UNAVAILABLE',source:c}];}
  }));
  return {observedAt:now(),metrics:Object.fromEntries(entries)};
 }
 async function mutate(uid,input){
  await authorize(uid,true);
  const {action,requestId,userId,creditId,incidentId}=input;id(requestId);const why=reason(input.reason);
  if(!['grantCredit','revokeCredit','setIncidentState'].includes(action))throw Error('UNKNOWN_ACTION');
  const key=hash(`${uid}:${requestId}`),fingerprint=hash(JSON.stringify(Object.keys(input).sort().map(k=>[k,input[k]])));
  const request=db.collection('adminControlRequests').doc(key),audit=db.collection('adminControlAudit').doc(key);
  return db.runTransaction(async tx=>{
   await authorize(uid,true,tx);
   const prior=await tx.get(request);if(prior.exists){if(prior.data().fingerprint!==fingerprint)throw Error('IDEMPOTENCY_CONFLICT');return prior.data().result;}
   const time=now();let result,targetId,targetType,beforeMetadata=null;
   if(action==='grantCredit'){
    id(userId);const amount=input.amountSeconds;
    if(!Number.isSafeInteger(amount)||amount<=0||amount>31536000||!CATEGORIES.includes(input.category))throw Error('INVALID_CREDIT');
    if(input.expiresAt!=null&&(!Number.isSafeInteger(input.expiresAt)||input.expiresAt<=time))throw Error('INVALID_EXPIRY');
    const target=await tx.get(db.collection('users').doc(userId));if(!target.exists)throw Error('NOT_FOUND');
    const active=await tx.get(db.collection('adminManualCredits').where('userId','==',userId).where('status','in',['ACTIVE','REVOKED_RESERVED','EXPIRED_RESERVED']).limit(100));
    if(active.docs.length>=100)throw Error('ACTIVE_CREDIT_LIMIT');
    targetId=key;targetType='manualCredit';
    tx.create(db.collection('adminManualCredits').doc(key),{userId,amountSeconds:amount,remainingSeconds:amount,reservedSeconds:0,category:input.category,reason:why,grantedBy:uid,grantedAt:time,expiresAt:input.expiresAt??null,status:'ACTIVE'});
    tx.create(db.collection('adminCreditLedger').doc(key),{userId,creditId:key,type:'GRANT',amountSeconds:amount,actorUid:uid,timestamp:time,operationId:requestId});result={creditId:key,grantedSeconds:amount};
   }else if(action==='revokeCredit'){
    const ref=db.collection('adminManualCredits').doc(id(creditId)),snap=await tx.get(ref);if(!snap.exists)throw Error('NOT_FOUND');const c=snap.data();
    if(!validSeconds(c.remainingSeconds)||!validSeconds(c.reservedSeconds)||c.remainingSeconds<c.reservedSeconds||c.reservedSeconds<0)throw Error('CORRUPT_CREDIT');
    beforeMetadata={remainingSeconds:c.remainingSeconds,reservedSeconds:c.reservedSeconds,status:c.status};
    const unused=Math.round((c.remainingSeconds-c.reservedSeconds)*1000)/1000;targetId=creditId;targetType='manualCredit';
    tx.update(ref,{remainingSeconds:c.reservedSeconds,status:c.reservedSeconds?'REVOKED_RESERVED':'REVOKED',revokedAt:time});
    tx.create(db.collection('adminCreditLedger').doc(key),{userId:c.userId,creditId,type:'REVOKE_UNUSED',amountSeconds:unused,actorUid:uid,timestamp:time,operationId:requestId});result={creditId,revokedSeconds:unused};
   }else{
    if(!['open','acknowledged','resolved'].includes(input.status))throw Error('INVALID_INCIDENT_STATE');
    const ref=db.collection('admin_incidents').doc(id(incidentId)),d=await tx.get(ref);if(!d.exists)throw Error('NOT_FOUND');beforeMetadata={status:d.data().status??'UNKNOWN'};targetId=incidentId;targetType='incident';tx.update(ref,{status:input.status,updatedAt:time,updatedBy:uid});result={incidentId,status:input.status};
   }
   tx.create(audit,{actorUid:uid,action,targetType,targetId,reason:why,timestamp:time,requestId,beforeMetadata,afterMetadata:result});
   tx.create(request,{fingerprint,result,createdAt:time});return result;
  });
 }
 async function expireDueCredits(){
  const timestamp=now();
  const due=await db.collection('adminManualCredits').where('status','==','ACTIVE').where('expiresAt','<=',timestamp).limit(100).get();
  const results=[];
  for(const doc of due.docs){results.push(await db.runTransaction(async tx=>{
   const ref=db.collection('adminManualCredits').doc(doc.id),snap=await tx.get(ref);if(!snap.exists)return false;const c=snap.data();
   if(c.status!=='ACTIVE'||c.expiresAt==null||c.expiresAt>timestamp)return false;
   if(!validSeconds(c.remainingSeconds)||!validSeconds(c.reservedSeconds)||c.reservedSeconds>c.remainingSeconds)throw Error('CORRUPT_CREDIT');
   const amount=Math.round((c.remainingSeconds-c.reservedSeconds)*1000)/1000;
   const event=hash(`expire:${doc.id}`);
   tx.update(ref,{remainingSeconds:c.reservedSeconds,status:c.reservedSeconds?'EXPIRED_RESERVED':'EXPIRED',expiredAt:timestamp});
   tx.create(db.collection('adminCreditLedger').doc(event),{userId:c.userId,creditId:doc.id,type:'EXPIRE',amountSeconds:amount,operationId:event,actorUid:'server',timestamp});
   tx.create(db.collection('adminControlAudit').doc(event),{actorUid:'server',action:'expireCredit',targetType:'manualCredit',targetId:doc.id,reason:'CREDIT_EXPIRY_REACHED',timestamp,requestId:event,beforeMetadata:{remainingSeconds:c.remainingSeconds,reservedSeconds:c.reservedSeconds},afterMetadata:{expiredSeconds:amount,remainingSeconds:c.reservedSeconds}});
   return true;
  }));}
  return {expiredCount:results.filter(Boolean).length};
 }
 return {authorize,list,user,dashboard,mutate,expireDueCredits};
}
module.exports={createAdminControlCenter,TABLES,CATEGORIES,project};
