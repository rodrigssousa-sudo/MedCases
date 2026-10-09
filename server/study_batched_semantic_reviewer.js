'use strict';
const {DerivativeError}=require('./derivative_contract');
const {StudySemanticReviewer}=require('./study_semantic_reviewer');
// Bound output size, never source context. Every batch retains the same complete
// transcript, ledger and candidate; all claim verdicts are required for approval.
class StudyBatchedSemanticReviewer {
 constructor(client,{batchSize=5}={}){if(!Number.isInteger(batchSize)||batchSize<1||batchSize>5)throw new DerivativeError('invalid_review_batch');this.client=client;this.identity=client.identity;this.batchSize=batchSize;}
 async review(context){
  if(!Array.isArray(context.claims)||!context.claims.length)throw new DerivativeError('invalid_semantic_reviewer');
  const verdicts=[],batches=[];
  for(let offset=0;offset<context.claims.length;offset+=this.batchSize){
   const client={identity:this.identity,complete:async args=>{
    const schema=structuredClone(args.schema);const paths=args.data.claimsToReview.map(c=>c.path);const item=schema.properties.verdicts.items;const slots=paths.map((_,i)=>'v'+i);
    schema.properties.verdicts={type:'object',properties:Object.fromEntries(slots.map((slot,i)=>[slot,{...structuredClone(item),properties:{...structuredClone(item.properties),path:{type:'string',enum:[paths[i]]}}}])),required:slots,additionalProperties:false};
    const r=await this.client.complete({...args,name:args.name+'_batch_'+offset,schema});const values=r.value?.verdicts;
    if(!values||Array.isArray(values)||Object.keys(values).length!==slots.length||slots.some((slot,i)=>values[slot]?.path!==paths[i]))throw new DerivativeError('incomplete_semantic_review',true,{usage:r.usage??null});
    return {...r,value:{verdicts:slots.map(slot=>values[slot])}};
   }};
   const r=await new StudySemanticReviewer(client).review({...context,claims:context.claims.slice(offset,offset+this.batchSize)});verdicts.push(...r.verdicts);batches.push(r.usage);
  }
  const usage={batches,inputTokens:0,outputTokens:0,estimatedCost:0};
  for(const key of ['inputTokens','outputTokens','estimatedCost'])usage[key]=batches.every(u=>Number.isFinite(u?.[key]))?batches.reduce((n,u)=>n+u[key],0):null;
  return {verifierIdentity:this.identity,verdicts,usage,revision:'study_batched_semantic_r24_v1'};
 }
}
module.exports={StudyBatchedSemanticReviewer};
