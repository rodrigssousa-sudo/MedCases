'use strict';
const {createAdminVisualMetrics}=require('./admin_visual_metrics');
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {createAdminNotificationReads}=require('./admin_notification_reads');
const {createAdminGuideOperations}=require('./admin_guide_operations');
const {createAdminOperations}=require('./admin_operations');
module.exports=admin=>{let runtime,saveGuide,notifications,visual;return {adminOperations:onCall({region:'us-central1',timeoutSeconds:30,maxInstances:5},async request=>{
 if(!request.auth)throw new HttpsError('unauthenticated','UNAUTHENTICATED');
 const {operation,payload}=request.data||{};if(!['page','detail','overview','mutate','saveGuide','notificationPage','notificationRead','metrics','identities'].includes(operation))throw new HttpsError('invalid-argument','UNKNOWN_OPERATION');
 runtime??=createAdminOperations({db:admin.firestore(),documentId:admin.firestore.FieldPath.documentId(),getAuthUser:uid=>admin.auth().getUser(uid)});
 saveGuide??=createAdminGuideOperations({db:admin.firestore()});
 try{
 if(operation==='metrics'){visual??=createAdminVisualMetrics({db:admin.firestore()});return await visual.metrics(request.auth.uid,payload||{});}
 if(operation==='notificationPage'||operation==='notificationRead'){notifications??=createAdminNotificationReads({db:admin.firestore(),documentId:admin.firestore.FieldPath.documentId()});return await notifications[operation==='notificationPage'?'page':'mark'](request.auth.uid,payload||{});}
 return operation==='saveGuide'?await saveGuide(request.auth.uid,payload||{}):await runtime[operation](request.auth.uid,payload||{});}catch(e){
  const code=['ADMIN_ACCESS_DENIED','SUPERVISOR_READ_ONLY','MASTER_REQUIRED','PROTECTED_ACCOUNT','CLAIM_MANAGED_ACCOUNT'].includes(e.message)?'permission-denied':e.message==='NOT_FOUND'?'not-found':e.message==='IDEMPOTENCY_CONFLICT'?'already-exists':/^(INVALID_|UNKNOWN_|UNSUPPORTED_|REASON_REQUIRED|PT_ES_REQUIRED|CAMPAIGN_NOT_DRAFT|RETRY_NOT_SUPPORTED|GUIDE_)/.test(e.message)?'invalid-argument':'unavailable';
  throw new HttpsError(code,code==='unavailable'?'ADMIN_OPERATION_UNAVAILABLE':e.message);
 }
})};};
