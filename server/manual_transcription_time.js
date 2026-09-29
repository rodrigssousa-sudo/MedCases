'use strict';
const {createHash}=require('node:crypto');
const hash=s=>createHash('sha256').update(s).digest('hex');
function milliseconds(seconds){
 const value=Math.round(seconds*1000);
 if(typeof seconds!=='number'||!Number.isFinite(seconds)||seconds<0||!Number.isSafeInteger(value)||Math.abs(value/1000-seconds)>1e-9)throw Error('CORRUPT_MANUAL_TIME');
 return value;
}
function credit(d){
 const remaining=milliseconds(d.remainingSeconds),reserved=milliseconds(d.reservedSeconds),amount=milliseconds(d.amountSeconds);
 if(reserved>remaining||remaining>amount||d.expiresAt!=null&&!Number.isSafeInteger(d.expiresAt))throw Error('CORRUPT_MANUAL_TIME');
 return {remaining,reserved};
}
async function readAvailable(db,tx,uid,now){
 const page=await tx.get(db.collection('adminManualCredits').where('userId','==',uid).where('status','in',['ACTIVE','REVOKED_RESERVED','EXPIRED_RESERVED']).limit(101));
 if(page.docs.length>100)throw Error('MANUAL_CREDIT_RECONCILIATION_REQUIRED');
 const records=page.docs.map(s=>{const d=s.data(),v=credit(d);return {...d,...v,id:s.id,ref:s.ref||db.collection('adminManualCredits').doc(s.id)};});
 let availableMs=0,reservedMs=0;
 for(const d of records){reservedMs+=d.reserved;if(d.status==='ACTIVE'&&(d.expiresAt==null||d.expiresAt>now))availableMs+=d.remaining-d.reserved;}
 if(!Number.isSafeInteger(availableMs)||!Number.isSafeInteger(reservedMs))throw Error('CORRUPT_MANUAL_TIME');
 return {records,availableMs,reservedMs};
}
function allocation(state,amount,now){
 let left=amount;const result=[];
 const sorted=[...state.records].sort((a,b)=>(a.expiresAt??Number.MAX_SAFE_INTEGER)-(b.expiresAt??Number.MAX_SAFE_INTEGER)||a.id.localeCompare(b.id));
 for(const d of sorted){if(d.status!=='ACTIVE'||d.expiresAt!=null&&d.expiresAt<=now)continue;const ms=Math.min(left,d.remaining-d.reserved);if(ms){result.push({creditId:d.id,amountMs:ms});left-=ms;}}
 if(left)throw Error('INSUFFICIENT_MANUAL_TIME');return result;
}
function reserve(tx,db,state,allocations){for(const a of allocations){const d=state.records.find(c=>c.id===a.creditId);tx.update(db.collection('adminManualCredits').doc(a.creditId),{reservedSeconds:(d.reserved+a.amountMs)/1000});}}
// Reads first, returns deferred writes so base and manual accounting commit together.
async function prepareSettlement(db,tx,op,id,now,consume){
 if(!op.manualAllocations?.length)return ()=>{};
 if(op.manualTimeState==='consumed'||op.manualTimeState==='released')return ()=>{};
 if(op.manualTimeState!=='reserved')throw Error('CORRUPT_MANUAL_RESERVATION');
 const ids=new Set();let total=0;
 const rows=await Promise.all(op.manualAllocations.map(async a=>{
  if(ids.has(a.creditId)||!Number.isSafeInteger(a.amountMs)||a.amountMs<=0)throw Error('CORRUPT_MANUAL_RESERVATION');ids.add(a.creditId);total+=a.amountMs;
  const ref=db.collection('adminManualCredits').doc(a.creditId),s=await tx.get(ref);if(!s.exists||s.data().userId!==op.uid)throw Error('RESERVATION_NOT_OWNED');
  const d=s.data(),v=credit(d);if(v.reserved<a.amountMs)throw Error('CORRUPT_MANUAL_RESERVATION');
  const forfeited=!consume&&(d.status!=='ACTIVE'||d.expiresAt!=null&&d.expiresAt<=now);
  const remaining=v.remaining-(consume||forfeited?a.amountMs:0),reserved=v.reserved-a.amountMs;
  let status=d.status;if(remaining===0)status=consume?'CONSUMED':d.status.startsWith('REVOKED')?'REVOKED':'EXPIRED';
  return {a,ref,remaining,reserved,status,event:consume?'CONSUME':forfeited?(d.status.startsWith('REVOKED')?'REVOKE_UNUSED':'EXPIRE'):null};
 }));
 if(total!==milliseconds(op.manualReservedSeconds))throw Error('CORRUPT_MANUAL_RESERVATION');
 return ()=>{for(const r of rows){tx.update(r.ref,{remainingSeconds:r.remaining/1000,reservedSeconds:r.reserved/1000,status:r.status});if(r.event)tx.create(db.collection('adminCreditLedger').doc(hash(`${id}:${r.a.creditId}:${r.event}`)),{userId:op.uid,creditId:r.a.creditId,type:r.event,amountSeconds:r.a.amountMs/1000,operationId:id,actorUid:'server',timestamp:now});}};
}
module.exports={milliseconds,readAvailable,allocation,reserve,prepareSettlement};
