'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {database}=require('./transaction_fixture'),{registerMonthlyUsageRoutes}=require('../monthly_usage_routes');
test('authenticated status is read-only, authoritative, no-store, and ignores supplied UID',async()=>{
 const db=database(),before=JSON.stringify([...db.records]);const routes=new Map();const authenticate=()=>{},limiter=()=>{};
 const add=(path,a,l,h)=>{assert.equal(a,authenticate);assert.equal(l,limiter);routes.set(path,h);};
 registerMonthlyUsageRoutes({app:{get:add,post:add},authenticate,limiter,db});
 const response=()=>({code:200,headers:{},setHeader(k,v){this.headers[k]=v;},status(code){this.code=code;return this;},json(body){this.body=body;return this;}});
 let res=response();await routes.get('/api/usage/status')({query:{uid:'B'}},res);assert.equal(res.code,401);
 res=response();await routes.get('/api/usage/status')({auth:{uid:'A'},query:{uid:'B'}},res);
 assert.equal(res.body.tier,'free');assert.equal(res.body.remainingMs,900000);assert.equal(res.body.transcriptionRangeV1,true);assert.equal(res.body.serverAuthoritative,true);assert.equal(res.headers['Cache-Control'],'no-store');assert.equal(JSON.stringify([...db.records]),before);
});
