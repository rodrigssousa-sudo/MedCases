'use strict';
const {MonthlyUsageOwner}=require('./monthly_usage_owner');
const {selectedProvider,providerGateError}=require('./transcription_profiles');
function registerMonthlyUsageRoutes({app,authenticate,limiter,db}) {
 const owner=new MonthlyUsageOwner({db});
 for(const action of ['reserve','finish','balance','eligibility']) app.post(`/api/usage/${action}`,authenticate,limiter,async(req,res)=>{
  res.setHeader('Cache-Control','no-store');
  const uid=req.auth?.uid;
  if(!uid)return res.status(401).json({error:'AUTH_REQUIRED'});
  try {
   if(action==='eligibility' || (action==='reserve'&&req.body?.kinds?.includes('transcription'))) {
    selectedProvider(process.env,uid);
    if(action==='eligibility')return res.json({eligible:true});
   }
   const result=await owner[action](uid,req.body||{});
   return res.json(result);
  } catch(error) {
   const gate=providerGateError(error);
   if(gate){
    const id=req.headers?.['x-medcases-usage-reservation'],attempt=req.headers?.['x-medcases-usage-attempt'];
    if(gate.retryable===false&&/^[a-f0-9]{64}$/.test(id||'')&&typeof attempt==='string')
     await owner.failBeforeExecution(uid,{id,attempt}).catch(()=>{});
    return res.status(gate.retryable?503:403).json(gate);
   }
   const known=new Set(['AUTH_REQUIRED','INVALID_USAGE_REQUEST','INVALID_USAGE_RESULT','IDEMPOTENCY_CONFLICT','MONTHLY_USAGE_LIMIT','RESERVATION_NOT_OWNED','STALE_ATTEMPT','USAGE_OUT_OF_BOUNDS']);
   const code=known.has(error.message)?error.message:'USAGE_UNAVAILABLE';
   return res.status(code==='MONTHLY_USAGE_LIMIT'?429:code==='AUTH_REQUIRED'?401:code==='USAGE_UNAVAILABLE'?503:400).json({error:code});
  }
 });
}
module.exports={registerMonthlyUsageRoutes};
