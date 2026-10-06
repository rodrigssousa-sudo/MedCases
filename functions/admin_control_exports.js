'use strict';
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {onSchedule}=require('firebase-functions/v2/scheduler');
const {createAdminControlCenter}=require('./admin_control_center');
module.exports=admin=>{
 const runtime=createAdminControlCenter({db:admin.firestore(),documentId:admin.firestore.FieldPath.documentId()});
 const known=new Set(['INVALID_ID','REASON_REQUIRED','UNKNOWN_TABLE','INVALID_PAGE_SIZE','INVALID_FILTER','UNKNOWN_ACTION','INVALID_CREDIT','INVALID_EXPIRY','INVALID_INCIDENT_STATE','CORRUPT_CREDIT','NOT_FOUND','IDEMPOTENCY_CONFLICT']);
 return {adminExpireManualTime:onSchedule({region:'us-central1',schedule:'every 60 minutes',timeoutSeconds:120,maxInstances:1},()=>runtime.expireDueCredits()),adminControlCenter:onCall({region:'us-central1',timeoutSeconds:30,maxInstances:5},async request=>{
  if(!request.auth)throw new HttpsError('unauthenticated','UNAUTHENTICATED');
  const data=request.data||{};
  const action=data.operation;
  if(!['list','user','dashboard','mutate'].includes(action))throw new HttpsError('invalid-argument','UNKNOWN_OPERATION');
  try{return await runtime[action](request.auth.uid,data.payload||{});}
  catch(e){const reason=e.message;
   if(['ADMIN_ACCESS_DENIED','SUPERVISOR_READ_ONLY'].includes(reason))throw new HttpsError('permission-denied',reason);
   if(known.has(reason))throw new HttpsError(reason==='NOT_FOUND'?'not-found':reason==='IDEMPOTENCY_CONFLICT'?'already-exists':'invalid-argument',reason);
   console.warn(JSON.stringify({component:'admin-control',operation:action,reasonCode:'ADMIN_OPERATION_UNAVAILABLE'}));
   throw new HttpsError('unavailable','ADMIN_OPERATION_UNAVAILABLE');
  }
 })};
};
