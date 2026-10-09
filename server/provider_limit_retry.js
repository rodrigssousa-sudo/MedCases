'use strict';
const {DerivativeError}=require('./derivative_contract');
function retryAfterMs(value,now=Date.now()){
 if(typeof value!=='string'||!value.trim())return null;
 const s=value.trim();
 if(/^\d+(?:\.\d+)?$/.test(s)){const ms=Number(s)*1000;return Number.isFinite(ms)?ms:null;}
 const date=Date.parse(s);return Number.isFinite(date)?Math.max(0,date-now):null;
}
// Only an explicit rejection (429) is retried automatically. Network timeouts
// may represent accepted/billable work, so they require reconciliation.
async function withProviderLimitRetry(run,{maxAttempts=3,maxWaitMs=120000,baseDelayMs=1000,sleep=ms=>new Promise(r=>setTimeout(r,ms)),random=Math.random,onRetry=async()=>{}}={}){
 if(!Number.isInteger(maxAttempts)||maxAttempts<1||maxAttempts>4||!Number.isFinite(maxWaitMs)||maxWaitMs<0||!Number.isFinite(baseDelayMs)||baseDelayMs<0)throw new DerivativeError('invalid_retry_policy');
 let waited=0;
 for(let attempt=1;attempt<=maxAttempts;attempt++){
  try{return await run(attempt);}catch(e){
   if(e.code!=='RETRYABLE_PROVIDER_LIMIT'||e.metadata?.httpStatus!==429||attempt===maxAttempts)throw e;
   const floor=e.metadata.retryAfterMs??0;
   if(!Number.isFinite(floor)||floor<0)throw e;
   const delay=Math.max(floor,baseDelayMs*2**(attempt-1))+Math.floor(Math.max(0,Math.min(1,random()))*250);
   if(waited+delay>maxWaitMs)throw e;
   await onRetry({attempt,delayMs:delay,code:e.code});await sleep(delay);waited+=delay;
  }
 }
}
module.exports={retryAfterMs,withProviderLimitRetry};
