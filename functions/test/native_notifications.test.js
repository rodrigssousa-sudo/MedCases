'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {events,payload,eligible}=require('../native_notification_contract');
const {createNativeNotifications}=require('../native_notifications');
for(const eventType of Object.keys(events))for(const lang of ['pt','es'])test(`${eventType} ${lang}`,()=>{
 const m=payload({eventType,resourceId:'synthetic-1',notificationId:'stable-1'},{token:'secret',activeAppLocale:lang});
 assert.equal(m.notification.title,events[eventType][lang==='es'?3:2]);
 assert.equal(m.data.notificationId,'stable-1');
 assert.equal(m.android.notification.channelId,`medcases_${events[eventType][0]}`);
 assert.equal(m.android.notification.tag,'stable-1');
 assert.match(m.data.deepLink,/^medcases:\/\//);
 assert.deepEqual(Object.keys(m.data).sort(),['deepLink','eventType','notificationId','resourceId']);
});
const now=new Date('2026-09-28T15:00:00Z');
const device={enabled:true,token:'x',preferences:{marketingEngagement:true},utcOffsetMinutes:0,lastActiveAt:now.getTime()-48*3600000};
test('marketing defaults off, quiet hours, recent-use, rolling cap',()=>{
 const e={eventType:'GLOBAL_ENGAGEMENT_REMINDER'};
 assert.equal(eligible(e,device,now),true);
 assert.equal(eligible(e,{...device,preferences:{}},now),false);
 assert.equal(eligible(e,{...device,utcOffsetMinutes:600},now),false);
 assert.equal(eligible(e,{...device,lastActiveAt:now.getTime()},now),false);
 assert.equal(eligible(e,{...device,engagementSentAt:[1,2,3].map(i=>now.getTime()-i*3600000)},now),false);
 assert.equal(eligible({eventType:'TRANSCRIPTION_COMPLETED'},{...device,preferences:{}},now),true);
});
function fakeDb(){
 const store=new Map();
 const snap=(ref)=>({exists:store.has(ref.path),data:()=>store.get(ref.path),ref,id:ref.path.split('/').at(-1)});
 const doc=path=>({path,get:async()=>snap(doc(path)),
  create:async data=>{if(store.has(path))throw {code:6};store.set(path,data);},
  update:async data=>store.set(path,{...store.get(path),...data})});
 const db={store,collection:name=>({doc:id=>doc(`${name}/${id}`),where:(field,op,value)=>{
  const filters=[[field,value]];
  const q={where:(f,o,v)=>{filters.push([f,v]);return q;},get:async()=>({docs:[...store.keys()].filter(k=>k.startsWith(`${name}/`)&&filters.every(([f,v])=>store.get(k)[f]===v)).map(k=>snap(doc(k)))})};return q;}}),
  runTransaction:async fn=>fn({get:async ref=>snap(ref),set:(ref,data,opts)=>store.set(ref.path,opts?.merge?{...store.get(ref.path),...data}:data),
   create:(ref,data)=>{if(store.has(ref.path))throw Error('exists');store.set(ref.path,data);},
   update:(ref,data)=>store.set(ref.path,{...store.get(ref.path),...data}),delete:ref=>store.delete(ref.path)})};return db;
}
const input={installationId:'a'.repeat(64),token:'synthetic-token-1234567890',platform:'ios',activeAppLocale:'es',preferences:{}};
test('registration account switch, locale, refresh and logout',async()=>{
 const db=fakeDb(),r=createNativeNotifications({db,messaging:{send:async()=>{}},serverTimestamp:()=>1});
 await r.register('user1',input);await r.register('user2',{...input,activeAppLocale:'pt'});
 const devices=()=>[...db.store.entries()].filter(([k])=>k.startsWith('notificationDevices/')).map(([,v])=>v);
 assert.equal(devices()[0].userId,'user2');assert.equal(devices()[0].activeAppLocale,'pt');
 await r.unregister('user1',input.installationId);assert.equal(devices()[0].enabled,true);
 await r.register('user2',{...input,token:input.token+'-new'});assert.equal(devices().filter(d=>d.enabled).length,1);
 await r.unregister('user2',input.installationId);assert.equal(devices().filter(d=>d.enabled).length,0);
 await assert.rejects(r.register(null,input));
});
test('outbox requires durable result, duplicate retry sends once',async()=>{
 const db=fakeDb();let sent=0;
 const r=createNativeNotifications({db,messaging:{send:async()=>{sent++;}},serverTimestamp:()=>1});
 await r.register('user1',input);
 await assert.rejects(r.enqueue({userId:'user1',eventType:'ANALYSIS_COMPLETED',resourceId:'a'}));
 const e={userId:'user1',eventType:'ANALYSIS_COMPLETED',resourceId:'a',durable:true};
 const id=await r.enqueue(e);assert.equal(await r.enqueue(e),id);
 await r.dispatch({...e,notificationId:id});await r.dispatch({...e,notificationId:id});assert.equal(sent,1);
});
test('invalid token disabled, no infinite retry',async()=>{
 const db=fakeDb();let sent=0;const r=createNativeNotifications({db,messaging:{send:async()=>{sent++;throw {code:'messaging/registration-token-not-registered'};}},serverTimestamp:()=>1});
 await r.register('user1',input);const e={userId:'user1',eventType:'ANALYSIS_COMPLETED',resourceId:'a',notificationId:'id'};
 await r.dispatch(e);await r.dispatch(e);assert.equal(sent,1);
 assert.equal([...db.store.values()].some(d=>d.enabled===true),false);
});

test('Android devices retain per-device PT/ES locale and FCM routing',async()=>{
 const db=fakeDb(),sent=[];
 const r=createNativeNotifications({db,messaging:{send:async m=>sent.push(m)},serverTimestamp:()=>1});
 await r.register('user1',{...input,platform:'android',activeAppLocale:'pt'});
 await r.register('user1',{...input,installationId:'b'.repeat(64),token:input.token+'-es',platform:'android',activeAppLocale:'es'});
 await r.dispatch({userId:'user1',eventType:'TRANSCRIPTION_COMPLETED',resourceId:'synthetic',notificationId:'android-event'});
 assert.equal(sent.length,2);
 assert.deepEqual(new Set(sent.map(m=>m.notification.title)),new Set([events.TRANSCRIPTION_COMPLETED[2],events.TRANSCRIPTION_COMPLETED[3]]));
 for(const message of sent) assert.equal(message.android.notification.channelId,'medcases_results');
});

 test('late Android/iOS registration recovers pending result exactly once',async()=>{
 for(const platform of ['ios','android']) {
  const db=fakeDb(),sent=[];
  const r=createNativeNotifications({db,messaging:{send:async m=>sent.push(m)},serverTimestamp:()=>Date.now()});
  const e={userId:'user1',eventType:'TRANSCRIPTION_COMPLETED',resourceId:'late',durable:true};
  const id=await r.enqueue(e);
  await r.dispatch({...e,notificationId:id});assert.equal(sent.length,0);
  await r.register('user1',{...input,platform});assert.equal(sent.length,1);
  await r.register('user1',{...input,platform});assert.equal(sent.length,1);
  await r.register('other',{...input,installationId:'c'.repeat(64),token:input.token+'other',platform});assert.equal(sent.length,1);
 }
});

test('provider reason codes distinguish auth, token and rate errors without raw message',()=>{
 const {sendReason}=require('../native_notifications');
 assert.equal(sendReason('messaging/third-party-auth-error'),'APNS_AUTH_FAILED');
 assert.equal(sendReason('messaging/registration-token-not-registered'),'FCM_UNREGISTERED');
 assert.equal(sendReason('messaging/message-rate-exceeded'),'PUSH_RATE_LIMITED');
 assert.equal(sendReason('private unknown text'),'PUSH_SEND_UNCERTAIN');
});
test('accepted send persists provider message identity',async()=>{
 const db=fakeDb();const r=createNativeNotifications({db,messaging:{send:async()=> 'projects/test/messages/synthetic'},serverTimestamp:()=>1});
 await r.register('user1',input);await r.dispatch({userId:'user1',eventType:'ANALYSIS_COMPLETED',resourceId:'a',notificationId:'receipt'});
 const receipt=[...db.store.entries()].find(([k])=>k.startsWith('notificationDeliveries/'))[1];
 assert.equal(receipt.reasonCode,'SEND_ACCEPTED');assert.equal(receipt.providerMessageId,'projects/test/messages/synthetic');
});
