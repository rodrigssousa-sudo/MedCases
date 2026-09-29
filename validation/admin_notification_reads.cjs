'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('EMULATOR_REQUIRED');
const req=require('node:module').createRequire(require.resolve('../functions/package.json'));
const {initializeApp,deleteApp}=req('firebase-admin/app');
const {getFirestore,FieldPath,Timestamp}=req('firebase-admin/firestore');
const app=initializeApp({projectId:'demo-admin-manual-time'},'notification-tests'),db=getFirestore(app);
const {createAdminNotificationReads}=require('../functions/admin_notification_reads');
const api=()=>createAdminNotificationReads({db,documentId:FieldPath.documentId()});
const request=notificationId=>({notificationId,requestId:crypto.randomUUID()});
after(()=>deleteApp(app));
async function setup(){for(const role of ['admin','supervisor','user'])await db.doc('users/n-'+role).set({role,status:'approved'});for(const d of (await db.collection('admin_notifications').get()).docs)await d.ref.delete();}
async function seed(id){await db.doc('admin_notifications/'+id).set({title:id,readBy:[],createdAt:Timestamp.now()});}
test('single read removed from UNREAD; ALL and fresh instance persist canonical receipt without deleting history',async()=>{
 await setup();await seed('one');const r=await api().mark('n-admin',request('one'));assert.equal(r.unreadCount,0);
 assert.equal((await api().page('n-admin')).items.length,0);const all=await api().page('n-admin',{filter:'ALL'});assert.equal(all.items[0].read,true);assert(all.items[0].readAt>0);assert.equal(all.items[0].readBy,'n-admin');assert(all.items[0].createdAt>0);assert((await db.doc('admin_notifications/one').get()).exists);
});
test('concurrent double clicks same/different requests: one audit and stable timestamp, no negative count',async()=>{
 await setup();await seed('double');const r=request('double');await Promise.all(Array.from({length:2},()=>api().mark('n-admin',r)));
 const before=(await api().page('n-admin',{filter:'ALL'})).items[0].readAt;await Promise.all(Array.from({length:2},()=>api().mark('n-admin',request('double'))));
 const after=(await api().page('n-admin',{filter:'ALL'}));assert.equal(after.unreadCount,0);assert.equal(after.items[0].readAt,before);assert.equal((await db.collection('adminControlAudit').where('targetId','==','double').get()).size,1);
});
test('mark one leaves other unread, separate administrators remain independent',async()=>{
 await setup();await seed('a');await seed('b');await api().mark('n-admin',request('a'));assert.deepEqual((await api().page('n-admin')).items.map(x=>x.notificationId),['b']);assert.equal((await api().page('n-supervisor')).unreadCount,2);
});
test('mark all batches over 100 and replay after network loss are idempotent',async()=>{
 await setup();const batch=db.batch();for(let i=0;i<105;i++)batch.set(db.doc('admin_notifications/batch-'+String(i).padStart(3,'0')),{readBy:[],createdAt:Timestamp.now()});await batch.commit();
 let cursor;do{const input={all:true,requestId:crypto.randomUUID(),...(cursor?{cursor}:{})};const result=await api().mark('n-admin',input);const replay=await api().mark('n-admin',input);assert.deepEqual(replay,result);cursor=result.nextCursor;}while(cursor);
 assert.equal((await api().page('n-admin')).unreadCount,0);assert.equal((await db.collection('admin_notifications').count().get()).data().count,105);
});
test('unauthorized writes denied and request ID reuse mismatch denied',async()=>{
 for(const uid of ['n-user','n-supervisor','absent'])await assert.rejects(api().mark(uid,request('batch-000')));
 await assert.rejects(api().mark('n-admin',{all:'yes',requestId:'invalid'}),/INVALID_NOTIFICATION_REQUEST/);
 const r=request('batch-000');await api().mark('n-admin',r);await assert.rejects(api().mark('n-admin',{...r,notificationId:'batch-001'}),/IDEMPOTENCY_CONFLICT/);
});
