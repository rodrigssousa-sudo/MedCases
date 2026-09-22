'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {registerMonthlyUsageRoutes}=require('../monthly_usage_routes');
test('usage routes take UID only from verified middleware and hide database failures',async()=>{
 const routes=new Map();const authenticate=()=>{},limiter=()=>{};
 registerMonthlyUsageRoutes({app:{post(path,a,l,handler){assert.equal(a,authenticate);assert.equal(l,limiter);routes.set(path,handler);}},authenticate,limiter,db:{collection:()=>({doc:()=>null}),runTransaction:async()=>{throw Error('private database detail');}}});
 function response(){return {code:200,setHeader(){},status(code){this.code=code;return this;},json(body){this.body=body;return this;}};}
 let res=response();await routes.get('/api/usage/reserve')({body:{uid:'forged'}},res);assert.equal(res.code,401);
 res=response();await routes.get('/api/usage/reserve')({auth:{uid:'A'},body:{uid:'B',operationId:'x',maximumMs:1,kinds:['recording']}},res);assert.equal(res.code,503);assert.equal(res.body.error,'USAGE_UNAVAILABLE');assert.ok(!JSON.stringify(res).includes('private database'));
 assert.ok(routes.has('/api/usage/finish'));
});
