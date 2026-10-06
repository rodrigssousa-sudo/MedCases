'use strict';
const {events,hash,payload,eligible}=require('./native_notification_contract');
function sendReason(code) {
 return ({'messaging/registration-token-not-registered':'FCM_UNREGISTERED',
 'messaging/invalid-registration-token':'DEVICE_TOKEN_INVALID',
 'messaging/third-party-auth-error':'APNS_AUTH_FAILED',
 'messaging/authentication-error':'FCM_AUTH_FAILED',
 'messaging/mismatched-credential':'FCM_AUTH_FAILED',
 'messaging/message-rate-exceeded':'PUSH_RATE_LIMITED',
 'messaging/quota-exceeded':'PUSH_RATE_LIMITED',
 'messaging/invalid-argument':'PUSH_INVALID_PAYLOAD',
 'messaging/server-unavailable':'PUSH_PROVIDER_UNAVAILABLE'})[code] || 'PUSH_SEND_UNCERTAIN';
}
/** Server-owned device registry and outbox. No clinical content is copied. */
function createNativeNotifications({db,messaging,serverTimestamp}) {
 async function register(uid,input) {
  if(!uid) throw Error('UNAUTHENTICATED');
  if(!/^[a-f0-9]{64}$/.test(input.installationId||'') || !['ios','android'].includes(input.platform) ||
     !['pt','es'].includes(input.activeAppLocale) || typeof input.token!=='string' || input.token.length<20 || input.token.length>4096) throw Error('INVALID_DEVICE');
  const id=hash(input.token),ref=db.collection('notificationDevices').doc(id);
  const install=db.collection('notificationInstallations').doc(input.installationId);
  const prefs=input.preferences || {};
  const preferences={productUpdates:prefs.productUpdates===true,marketingEngagement:prefs.marketingEngagement===true,
   reminders:prefs.reminders!==false,quietStart:21,quietEnd:8};
  await db.runTransaction(async tx=>{
   const old=await tx.get(install),previous=old.data()?.deviceId;
   const previousDevice=previous && previous!==id ? await tx.get(db.collection('notificationDevices').doc(previous)) : null;
   if(previous && previous!==id) tx.set(db.collection('notificationDevices').doc(previous),{enabled:false,token:null,updatedAt:serverTimestamp()},{merge:true});
   tx.set(ref,{userId:uid,installationId:input.installationId,token:input.token,platform:input.platform,
    activeAppLocale:input.activeAppLocale,lastAppLocale:input.activeAppLocale,
    initialAppLocale:input.activeAppLocale,preferences,enabled:true,
    ...(previousDevice?.exists ? {engagementSentAt:previousDevice.data().engagementSentAt||[]} : {}),
    utcOffsetMinutes:Number.isInteger(input.utcOffsetMinutes)?input.utcOffsetMinutes:0,
    updatedAt:serverTimestamp(),lastActiveAt:serverTimestamp()},{merge:true});
   tx.set(install,{userId:uid,deviceId:id,updatedAt:serverTimestamp()});
  });
  // Outbox creation can precede APNs/FCM registration. Recover only recent
  // durable result notices; dispatch receipts keep repeated registrations safe.
  const pending=await db.collection('notificationOutbox').where('userId','==',uid).get();
  for(const item of pending.docs) {
   const event=item.data(),created=event.createdAt?.toMillis?.() ?? event.createdAt;
   if(!['TRANSCRIPTION_COMPLETED','CONSULTATION_SUMMARY_READY','ANALYSIS_COMPLETED','CONTENT_PROCESSED'].includes(event.eventType) ||
      !Number.isFinite(created) || created<Date.now()-24*3600000 ||
      (event.targetInstallationId && event.targetInstallationId!==input.installationId))continue;
   await dispatch({...event,targetInstallationId:input.installationId});
  }
  return {registered:true};
 }
 async function unregister(uid,installationId) {
  if(!uid) throw Error('UNAUTHENTICATED');
  if(!/^[a-f0-9]{64}$/.test(installationId||'')) throw Error('INVALID_DEVICE');
  await db.runTransaction(async tx=>{
   const ref=db.collection('notificationInstallations').doc(installationId),s=await tx.get(ref);
   if(!s.exists || s.data().userId!==uid) return;
   tx.set(db.collection('notificationDevices').doc(s.data().deviceId),{enabled:false,token:null,updatedAt:serverTimestamp()},{merge:true});
   tx.delete(ref);
  });
 }
 async function enqueue(event) {
  if(!events[event.eventType] || !event.userId || !event.resourceId || event.durable!==true) throw Error('DURABLE_EVENT_REQUIRED');
  const id=hash(`${event.userId}:${event.eventType}:${event.resourceId}`);
  const ref=db.collection('notificationOutbox').doc(id);
  try {await ref.create({userId:event.userId,eventType:event.eventType,resourceId:event.resourceId,
    notificationId:id,...(event.targetInstallationId ? {targetInstallationId:event.targetInstallationId} : {}),createdAt:serverTimestamp()});} catch(e){if(e.code!==6&&e.code!=='already-exists')throw e;}
  return id;
 }
 async function dispatch(event) {
  const devices=await db.collection('notificationDevices').where('userId','==',event.userId).where('enabled','==',true).get();
  for(const device of devices.docs) {
   const receipt=db.collection('notificationDeliveries').doc(hash(`${event.notificationId}:${device.id}`));
   const claimed=await db.runTransaction(async tx=>{
    const [r,d]=await Promise.all([tx.get(receipt),tx.get(device.ref)]);
    if(r.exists || !d.exists || d.data().userId!==event.userId ||
       (event.targetInstallationId && d.data().installationId!==event.targetInstallationId) || !eligible(event,d.data()))return null;
    tx.create(receipt,{state:'sending',notificationId:event.notificationId,deviceId:device.id,createdAt:serverTimestamp()});
    if(event.eventType==='GLOBAL_ENGAGEMENT_REMINDER')tx.update(device.ref,{engagementSentAt:[...(d.data().engagementSentAt||[]).filter(t=>t>Date.now()-7*86400000),Date.now()]});
    return d.data();
   });
   if(!claimed)continue;
   try {
    const messageId=await messaging.send(payload(event,claimed));
    await receipt.update({state:'sent',reasonCode:'SEND_ACCEPTED',...(typeof messageId==='string'?{providerMessageId:messageId}:{}),updatedAt:serverTimestamp()});
   }catch(e){
    // Ambiguous sends are not blindly retried: prevents duplicate delivery.
    const invalid=['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(e.code);
    await receipt.update({state:invalid?'invalid_token':'send_uncertain',reasonCode:sendReason(e.code),updatedAt:serverTimestamp()});
    if(invalid)await device.ref.update({enabled:false,token:null,updatedAt:serverTimestamp()});
   }
  }
 }
 return {register,unregister,enqueue,dispatch};
}
module.exports={createNativeNotifications,sendReason};
