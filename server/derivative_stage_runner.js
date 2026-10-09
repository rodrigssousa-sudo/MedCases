'use strict';
const {randomUUID}=require('node:crypto');
const {hash,DerivativeError}=require('./derivative_contract');
// Stores responses server-side, never logs source/response. A stage key binds
// owner, operation, revision, provider and complete request (including schema).
// Restart after an unknown request outcome requires reconciliation, not resend.
class DerivativeStageRunner {
 constructor({store,ownerUid,operationId,revision,now=Date.now,maxAttempts=3}){
  if(!store||![ownerUid,operationId,revision].every(v=>typeof v==='string'&&v.length)||!Number.isInteger(maxAttempts)||maxAttempts<1||maxAttempts>4)throw new DerivativeError('invalid_stage_context');
  Object.assign(this,{store,ownerUid,operationId,revision,now,maxAttempts});
 }
 wrap(client){return {identity:client.identity,complete:args=>this.complete(client,args)};}
 async complete(client,args){
  if(typeof client.identity!=='string'||!client.identity)throw new DerivativeError('missing_provider_identity');
  const key=hash(JSON.stringify(['r23-stage',this.ownerUid,this.operationId,this.revision,client.identity,args]));
  const lease=randomUUID();let cached;
  await this.store.transaction(key,async tx=>{
   const row=await tx.read();
   if(row?.status==='COMPLETED'){
    if(hash(JSON.stringify(row.response))!==row.responseHash)throw new DerivativeError('stage_integrity_error');
    cached=row.response;return;
   }
   if(row?.status==='IN_FLIGHT'||row?.status==='RECONCILIATION_REQUIRED')throw new DerivativeError('provider_outcome_unknown');
   if(row&&row.status!=='RETRYABLE_PROVIDER_LIMIT')throw new DerivativeError('stage_not_retryable');
   if(row?.attempt>=this.maxAttempts)throw new DerivativeError('provider_retry_exhausted');
   if(row?.nextAttemptAt>this.now())throw new DerivativeError('RETRYABLE_PROVIDER_LIMIT',true,{httpStatus:429,retryAfterMs:row.nextAttemptAt-this.now()});
   await tx.write({status:'IN_FLIGHT',lease,ownerUid:this.ownerUid,operationId:this.operationId,revision:this.revision,stage:args.name,provider:client.identity,attempt:(row?.attempt??0)+1,startedAt:this.now()});
  });
  if(cached)return cached;
  let response;
  try{response=await client.complete(args);}catch(e){
   const limited=e.code==='RETRYABLE_PROVIDER_LIMIT'&&e.metadata?.httpStatus===429;
   // Other failed responses may carry billable partial output. Never retry
   // them automatically merely because the HTTP client labels them retryable.
   await this.store.transaction(key,async tx=>{
    const row=await tx.read();if(row?.lease!==lease)throw new DerivativeError('stage_lease_lost');
    const delay=Math.max(e.metadata?.retryAfterMs??0,1000*2**(row.attempt-1));
    await tx.write({...row,status:limited?'RETRYABLE_PROVIDER_LIMIT':'RECONCILIATION_REQUIRED',errorCode:e.code??'provider_outcome_unknown',...(limited?{nextAttemptAt:this.now()+delay}:{}),updatedAt:this.now()});
   });throw e;
  }
  // If this write fails, IN_FLIGHT remains and the provider is not called twice.
  await this.store.transaction(key,async tx=>{
   const row=await tx.read();if(row?.lease!==lease)throw new DerivativeError('stage_lease_lost');
   await tx.write({...row,status:'COMPLETED',response,responseHash:hash(JSON.stringify(response)),completedAt:this.now()});
  });
  return response;
 }
}
module.exports={DerivativeStageRunner};
