'use strict';
const {MonthlyUsageOwner}=require('./monthly_usage_owner');
function registerMonthlyUsageRoutes({app,authenticate,limiter,db}) {
 const owner=new MonthlyUsageOwner({db});
 for(const action of ['reserve','finish','balance']) app.post(`/api/usage/${action}`,authenticate,limiter,async(req,res)=>{
  res.setHeader('Cache-Control','no-store');
  const uid=req.auth?.uid;
  if(!uid)return res.status(401).json({error:'AUTH_REQUIRED'});
  try {
   const result=await owner[action](uid,req.body||{});
   return res.json(result);
  } catch(error) {
   const known=new Set(['AUTH_REQUIRED','INVALID_USAGE_REQUEST','INVALID_USAGE_RESULT','IDEMPOTENCY_CONFLICT','MONTHLY_USAGE_LIMIT','RESERVATION_NOT_OWNED','STALE_ATTEMPT','USAGE_OUT_OF_BOUNDS']);
   const code=known.has(error.message)?error.message:'USAGE_UNAVAILABLE';
   return res.status(code==='MONTHLY_USAGE_LIMIT'?429:code==='AUTH_REQUIRED'?401:code==='USAGE_UNAVAILABLE'?503:400).json({error:code});
  }
 });
}
module.exports={registerMonthlyUsageRoutes};
