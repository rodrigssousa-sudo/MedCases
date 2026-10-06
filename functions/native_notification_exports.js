'use strict';
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {onDocumentCreated,onDocumentWritten}=require('firebase-functions/v2/firestore');
const {onSchedule}=require('firebase-functions/v2/scheduler');
const {createNativeNotifications}=require('./native_notifications');
module.exports=function(admin){
 const db=admin.firestore();
 const runtime=createNativeNotifications({db,messaging:{send:message=>admin.messaging().send(message)},serverTimestamp:()=>admin.firestore.FieldValue.serverTimestamp()});
 const call=fn=>onCall(async req=>{
  if(!req.auth)throw new HttpsError('unauthenticated','Authentication required');
  try{return await fn(req.auth.uid,req.data||{});}catch(_){throw new HttpsError('invalid-argument','Invalid notification registration');}
 });
 return {
  registerNotificationDevice:call((uid,data)=>runtime.register(uid,data)),
  unregisterNotificationDevice:call((uid,data)=>runtime.unregister(uid,data.installationId)),
  publishDurableNotice:call(async(uid,data)=>{
   const allowed=['CONSULTATION_SUMMARY_READY','ANALYSIS_COMPLETED','CONTENT_PROCESSED'];
   if(!allowed.includes(data.eventType)||!/^[A-Za-z0-9_-]{1,180}$/.test(data.resourceId||'')||
      !/^[a-f0-9]{64}$/.test(data.installationId||'')||Object.keys(data).some(k=>!['eventType','resourceId','installationId'].includes(k)))throw Error('INVALID_NOTICE');
   const install=await db.collection('notificationInstallations').doc(data.installationId).get();
   if(!install.exists||install.data().userId!==uid)throw Error('INVALID_DEVICE');
   await runtime.enqueue({userId:uid,eventType:data.eventType,resourceId:data.resourceId,
      targetInstallationId:data.installationId,durable:true});
   return {persisted:true};
  }),
  getNativeNotificationResource:call(async(uid,data)=>{
   if(!/^[A-Za-z0-9_-]{1,180}$/.test(data.resourceId||''))throw Error('INVALID_RESOURCE');
   const snap=await db.collection('users').doc(uid).collection('notificationResources').doc(data.resourceId).get();
   if(!snap.exists || snap.data().ownerUid!==uid || snap.data().eventType!==data.eventType)throw Error('NOT_FOUND');
   const resource=snap.data();
   if(resource.eventType==='TRANSCRIPTION_COMPLETED'){
    const ref=db.collection('_study_background_transcription_jobs').doc(resource.jobId),job=await ref.get();
    if(!job.exists||job.data().uid!==uid)throw Error('NOT_FOUND');
    const parts=await ref.collection('segments').orderBy('index').get();
    if(parts.size!==job.data().expectedSegments || parts.docs.some(s=>s.data().state!=='done'))throw Error('NOT_READY');
    return {text:parts.docs.map(s=>s.data().transcript).join('\n\n')};
   }
   if(typeof resource.text!=='string')throw Error('NOT_READY');
   return {text:resource.text};
  }),
  notifyDurableResource:onDocumentCreated('users/{uid}/notificationResources/{resourceId}',async e=>{
   const d=e.data.data();
   if(d.ownerUid!==e.params.uid || d.state!=='completed')return;
   await runtime.enqueue({userId:e.params.uid,eventType:d.eventType,resourceId:e.params.resourceId,durable:true});
  }),
  deliverNativeNotification:onDocumentCreated('notificationOutbox/{id}',e=>runtime.dispatch(e.data.data())),
  notifyStudyTranscript:onDocumentWritten('_study_background_transcription_jobs/{jobId}/segments/{segmentId}',async e=>{
   const value=e.data?.after?.data();if(value?.state!=='done')return;
   const ref=db.collection('_study_background_transcription_jobs').doc(e.params.jobId),job=await ref.get();
   if(!job.exists)return;const j=job.data();
   const segments=await ref.collection('segments').get();
   if(!j.uid || !j.sourceId || !Number.isInteger(j.expectedSegments) || j.expectedSegments<1 ||
      segments.size!==j.expectedSegments || segments.docs.some(s=>s.data().state!=='done'||typeof s.data().transcript!=='string'||!s.data().transcript.trim()))return;
   const resource=db.collection('users').doc(j.uid).collection('notificationResources').doc(j.sourceId);
   try {await resource.create({ownerUid:j.uid,eventType:'TRANSCRIPTION_COMPLETED',state:'completed',jobId:e.params.jobId});}
   catch(error){if(error.code!==6&&error.code!=='already-exists')throw error;}
  }),
  notificationEngagement:onSchedule('every 24 hours',async()=>{
   // Opt-in only; locale/quiet-hours/recent-use/cap checked per device at send.
   let last=null;
   do {
    let q=db.collection('notificationDevices').where('enabled','==',true).orderBy(admin.firestore.FieldPath.documentId()).limit(200);
    if(last)q=q.startAfter(last);
    const page=await q.get();if(page.empty)break;
    for(const uid of new Set(page.docs.map(d=>d.data().userId))){
     const day=new Date().toISOString().slice(0,10);
     await runtime.enqueue({userId:uid,eventType:'GLOBAL_ENGAGEMENT_REMINDER',resourceId:`home-${day}`,durable:true});
    }
    last=page.docs.at(-1);if(page.size<200)break;
   }while(last);
  }),
 };
};
