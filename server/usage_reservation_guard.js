'use strict';
async function assertUsageReservation(db,uid,headers,kind='transcription') {
 const id=headers['x-medcases-usage-reservation'];const attempt=headers['x-medcases-usage-attempt'];
 if(typeof id!=='string'||! /^[a-f0-9]{64}$/.test(id)||typeof attempt!=='string'||!attempt)throw Error('SERVER_QUOTA_RESERVATION_REQUIRED');
 const snapshot=await db.collection('usageReservations').doc(id).get();
 const value=snapshot.exists?snapshot.data():null;
 if(!value || value.uid!==uid || value.state!=='reserved' || value.attempt!==attempt ||
   !Array.isArray(value.kinds) || !value.kinds.includes(kind) || !Number.isSafeInteger(value.maximumMs) || value.maximumMs<=0)throw Error('SERVER_QUOTA_RESERVATION_INVALID');
 return {'x-medcases-usage-reservation':id,'x-medcases-usage-attempt':attempt};
}
function containsAudio(value){
 if(!value||typeof value!=='object')return false;
 for(const [key,item]of Object.entries(value)) {
  if(['mimeType','mime_type'].includes(key)&&typeof item==='string'&&item.startsWith('audio/'))return true;
  if(item&&typeof item==='object'&&containsAudio(item))return true;
 }
 return false;
}
module.exports={assertUsageReservation,containsAudio};
