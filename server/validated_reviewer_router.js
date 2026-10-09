'use strict';
const {DerivativeError}=require('./derivative_contract');
const {withProviderLimitRetry}=require('./provider_limit_retry');
// Certificates come from server-owned release configuration, never request
// bodies. The release pipeline must bind them to an audited corpus/revision.
class ValidatedReviewerRouter {
 constructor({primary,fallback=null,certificates=[],revision,retryPolicy={},onRoute=async()=>{}}){
  if(!primary?.identity||!revision)throw new DerivativeError('invalid_reviewer_route');
  if(fallback&&(!fallback.identity||fallback.identity===primary.identity||!certificates.some(c=>c.identity===fallback.identity&&c.revision===revision&&c.passed===true&&/^[a-f0-9]{64}$/.test(c.corpusSha256??''))))throw new DerivativeError('unvalidated_reviewer_fallback');
  Object.assign(this,{primary,fallback,revision,retryPolicy,onRoute,identity:primary.identity});
 }
 async complete(args){
  if(!/(?:semantic|pedagogical|pedagogy|review)/.test(args?.name??''))throw new DerivativeError('reviewer_route_cannot_generate');
  try{return await withProviderLimitRetry(()=>this.primary.complete(args),this.retryPolicy);}
  catch(e){
   const explicitRejection=(e.code==='RETRYABLE_PROVIDER_LIMIT'&&e.metadata?.httpStatus===429)||(e.code==='provider_unavailable'&&e.metadata?.httpStatus===503);
   if(!this.fallback||!explicitRejection)throw e;
   await this.onRoute({stage:args.name,from:this.primary.identity,to:this.fallback.identity,reason:e.code,revision:this.revision});
   // One fallback reviewer, one request. No recursive chain or generator switch.
   return this.fallback.complete(args);
  }
 }
}
module.exports={ValidatedReviewerRouter};
