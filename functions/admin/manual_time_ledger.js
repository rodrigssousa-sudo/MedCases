'use strict';
const {createHash}=require('node:crypto');
const {allocate,settle}=require('./manual_time_accounting');
const hash=x=>createHash('sha256').update(x).digest('hex');
// Internal service only: never exported as a callable. The authenticated usage
// owner supplies uid and decides the base-plan shortfall. All reads precede writes.
function createManualTimeLedger({db,now=()=>Date.now()}) {
  function reservationRef(uid,operationId) {
    if(typeof uid!=='string'||!uid||typeof operationId!=='string'||!operationId)throw Error('INVALID_RESERVATION');
    return db.collection('adminManualTimeReservations').doc(hash(JSON.stringify([uid,operationId])));
  }
  async function reserve(uid,operationId,seconds) {
    if(!Number.isSafeInteger(seconds)||seconds<=0)throw Error('INVALID_TIME');
    const ref=reservationRef(uid,operationId);
    return db.runTransaction(async tx=>{
      const prior=await tx.get(ref);
      if(prior.exists){if(prior.data().seconds!==seconds)throw Error('IDEMPOTENCY_CONFLICT');return prior.data();}
      const page=await tx.get(db.collection('adminManualCredits').where('userId','==',uid).where('status','==','ACTIVE').limit(101));
      if(page.docs.length>100)throw Error('MANUAL_CREDIT_RECONCILIATION_REQUIRED');
      const records=page.docs.map(d=>({id:d.id,...d.data()}));
      const allocations=allocate(records,seconds,now());
      const data={uid,operationId,seconds,allocations:allocations.map(({creditId,seconds})=>({creditId,seconds})),state:'reserved',createdAt:now()};
      for(const item of allocations)tx.update(db.collection('adminManualCredits').doc(item.creditId),{reservedSeconds:item.reservedSeconds});
      tx.create(ref,data);return data;
    });
  }
  // consumedSeconds must be server-verified. A client cannot request a refund.
  async function complete(uid,operationId,consumedSeconds) {
    const ref=reservationRef(uid,operationId);
    return db.runTransaction(async tx=>{
      const snap=await tx.get(ref);if(!snap.exists)throw Error('RESERVATION_NOT_FOUND');
      const r=snap.data();
      if(!Number.isSafeInteger(consumedSeconds)||consumedSeconds<0||consumedSeconds>r.seconds)throw Error('INVALID_SETTLEMENT');
      if(r.state==='completed'){if(r.consumedSeconds!==consumedSeconds)throw Error('IDEMPOTENCY_CONFLICT');return r;}
      const credits=await Promise.all(r.allocations.map(a=>tx.get(db.collection('adminManualCredits').doc(a.creditId))));
      let left=consumedSeconds;const timestamp=now();
      const patches=r.allocations.map((a,i)=>{
        if(!credits[i].exists||credits[i].data().userId!==uid)throw Error('CORRUPT_CREDIT');
        const used=Math.min(left,a.seconds);left-=used;
        return {a,patch:settle(credits[i].data(),a.seconds,used,timestamp)};
      });
      if(left)throw Error('CORRUPT_RESERVATION');
      for(const {a,patch} of patches){
        tx.update(db.collection('adminManualCredits').doc(a.creditId),{remainingSeconds:patch.remainingSeconds,reservedSeconds:patch.reservedSeconds});
        if(patch.consumedSeconds)tx.create(db.collection('adminCreditLedger').doc(hash(`${ref.id}:${a.creditId}:CONSUME`)),{userId:uid,creditId:a.creditId,type:'CONSUME',amountSeconds:patch.consumedSeconds,operationId,timestamp,actorUid:'server'});
        if(patch.forfeitedSeconds)tx.create(db.collection('adminCreditLedger').doc(hash(`${ref.id}:${a.creditId}:FORFEIT`)),{userId:uid,creditId:a.creditId,type:credits[r.allocations.indexOf(a)].data().status.startsWith('REVOKED')?'REVOKE_UNUSED':'EXPIRE',amountSeconds:patch.forfeitedSeconds,operationId,timestamp,actorUid:'server'});
      }
      const result={...r,state:'completed',consumedSeconds,completedAt:timestamp};
      tx.update(ref,result);return result;
    });
  }
  return {reserve,complete};
}
module.exports={createManualTimeLedger};
