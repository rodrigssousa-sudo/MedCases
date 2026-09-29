'use strict';
const {createHash}=require('node:crypto');
const {FieldValue}=require('firebase-admin/firestore');
const {createAdminControlCenter}=require('./admin_control_center');
const hash=x=>createHash('sha256').update(x).digest('hex');
const validId=x=>typeof x==='string'&&x.length>0&&x.length<=180&&!/[\/\x00-\x1f]/.test(x);
const milliseconds=x=>x?.toMillis?.()??(Number.isFinite(x)?x:null);
function createAdminNotificationReads({db,documentId='__name__'}){
 const auth=createAdminControlCenter({db,documentId}),collection=db.collection('admin_notifications');
 const receipt=(uid,id)=>db.collection('adminNotificationReads').doc(hash(`${uid}:${id}`));
 const readBy=(data,uid)=>Array.isArray(data.readBy)&&data.readBy.includes(uid);
 async function count(uid){const [all,read]=await Promise.all([collection.count().get(),collection.where('readBy','array-contains',uid).count().get()]);return Math.max(0,all.data().count-read.data().count);}
 async function page(uid,{cursor,filter='UNREAD',limit=30}={}){
  await auth.authorize(uid);if(!['ALL','UNREAD'].includes(filter)||!Number.isInteger(limit)||limit<1||limit>100||(cursor&&!validId(cursor)))throw Error('INVALID_NOTIFICATION_QUERY');
  let q=collection.orderBy(documentId).limit(limit+1);if(cursor)q=q.startAfter(cursor);const snapshot=await q.get(),docs=snapshot.docs.slice(0,limit);
  const receipts=docs.length?await db.getAll(...docs.map(d=>receipt(uid,d.id))):[];
  const items=docs.map((doc,i)=>{const d=doc.data(),r=receipts[i].data();return {notificationId:doc.id,read:r?.read===true||readBy(d,uid),readAt:milliseconds(r?.readAt),readBy:r?.readBy??(readBy(d,uid)?uid:null),createdAt:milliseconds(d.createdAt),type:typeof d.type==='string'?d.type.slice(0,100):'ADMIN_NOTIFICATION',title:d.type==='new_user'?'Novo usuário cadastrado':typeof d.title==='string'?d.title.slice(0,200):typeof d.type==='string'?d.type.slice(0,100):'Notificação administrativa',userName:typeof d.userName==='string'?d.userName.slice(0,120):null};}).filter(d=>filter==='ALL'||!d.read);
  return {items,nextCursor:snapshot.docs.length>limit?docs.at(-1).id:null,unreadCount:await count(uid),filter};
 }
 async function mark(uid,{notificationId,cursor,all=false,requestId}={}){
  await auth.authorize(uid,true);if(typeof all!=='boolean'||!validId(requestId)||(!all&&!validId(notificationId))||(cursor&&!validId(cursor)))throw Error('INVALID_NOTIFICATION_REQUEST');
  const key=hash(`${uid}:notification:${requestId}`),request=db.collection('adminOperationRequests').doc(key),fingerprint=hash(JSON.stringify({notificationId:notificationId??null,cursor:cursor??null,all}));
  const result=await db.runTransaction(async tx=>{
   await auth.authorize(uid,true,tx);const prior=await tx.get(request);if(prior.exists){if(prior.data().fingerprint!==fingerprint)throw Error('IDEMPOTENCY_CONFLICT');return prior.data().result;}
   let docs,nextCursor=null;
   if(all){let q=collection.orderBy(documentId).limit(101);if(cursor)q=q.startAfter(cursor);const s=await tx.get(q);docs=s.docs.slice(0,100);nextCursor=s.docs.length>100?docs.at(-1).id:null;}
   else {const d=await tx.get(collection.doc(notificationId));if(!d.exists)throw Error('NOT_FOUND');docs=[d];}
   const refs=docs.map(d=>receipt(uid,d.id)),states=[];for(const ref of refs)states.push(await tx.get(ref));
   let changed=0;
   docs.forEach((doc,i)=>{const d=doc.data();if(states[i].data()?.read===true){if(!readBy(d,uid))tx.update(doc.ref,{readBy:FieldValue.arrayUnion(uid)});return;}
    if(!readBy(d,uid))changed++;
    tx.set(refs[i],{notificationId:doc.id,read:true,readAt:FieldValue.serverTimestamp(),readBy:uid,createdAt:d.createdAt??null});
    // Keep the existing array contract for older Admin consumers; no history loss.
    tx.update(doc.ref,{readBy:FieldValue.arrayUnion(uid)});
   });
   const output={readIds:docs.map(d=>d.id),changed,nextCursor};
   if(changed>0)tx.create(db.collection('adminControlAudit').doc(key),{actorUid:uid,action:all?'markAllNotificationsRead':'markNotificationRead',targetType:'adminNotification',targetId:all?'batch':notificationId,reason:'ADMIN_ACKNOWLEDGED_NOTIFICATION',beforeMetadata:{unreadChanged:changed},afterMetadata:{read:true},timestamp:FieldValue.serverTimestamp(),requestId});
   tx.create(request,{fingerprint,result:output,createdAt:FieldValue.serverTimestamp()});return output;
  });
  return {...result,unreadCount:await count(uid)};
 }
 return {page,mark};
}
module.exports={createAdminNotificationReads};
