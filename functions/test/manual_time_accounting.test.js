'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {available,allocate,settle,expire}=require('../admin/manual_time_accounting');
const credit=(extra={})=>({id:'a',amountSeconds:3600,remainingSeconds:3000,reservedSeconds:100,status:'ACTIVE',expiresAt:null,...extra});
test('manual minutes are additive and allocation does not mutate base or input',()=>{
 const c=credit(),before=structuredClone(c);assert.equal(available(c,100),2900);
 assert.deepEqual(allocate([c],60,100),[{creditId:'a',seconds:60,reservedSeconds:160}]);assert.deepEqual(c,before);
});
test('earliest expiry consumed first, expired and revoked excluded',()=>{
 const rows=[credit(),credit({id:'b',expiresAt:200}),credit({id:'c',expiresAt:99}),credit({id:'d',status:'REVOKED'})];
 assert.deepEqual(allocate(rows,3000,100).map(x=>[x.creditId,x.seconds]),[['b',2900],['a',100]]);
});
test('insufficient credit yields no partial allocation',()=>assert.throws(()=>allocate([credit()],2901,100),/INSUFFICIENT/));
test('partial consumption releases unused reserved time',()=>assert.deepEqual(settle(credit(),100,30,100),{remainingSeconds:2970,reservedSeconds:0,consumedSeconds:30,releasedSeconds:70,forfeitedSeconds:0}));
test('revocation while reserved cannot restore revoked time on release',()=>assert.deepEqual(settle(credit({remainingSeconds:100,status:'REVOKED_RESERVED'}),100,30,100),{remainingSeconds:0,reservedSeconds:0,consumedSeconds:30,releasedSeconds:0,forfeitedSeconds:70}));
test('expiry preserves in-flight reservation and excludes new allocation',()=>{
 const c=credit({expiresAt:100});assert.equal(available(c,100),0);assert.deepEqual(expire(c,100),{remainingSeconds:100,reservedSeconds:100,expiredSeconds:2900,status:'EXPIRED_RESERVED'});
 assert.equal(expire({...c,status:'EXPIRED_RESERVED'},101),null);
});
test('expired in-flight release cannot reintroduce available time',()=>assert.equal(settle(credit({expiresAt:100}),100,0,101).releasedSeconds,0));
test('invalid or duplicate balances rejected',()=>{
 for(const patch of [{remainingSeconds:-1},{reservedSeconds:3001},{amountSeconds:NaN},{remainingSeconds:3601}])assert.throws(()=>available(credit(patch),100),/CORRUPT/);
 assert.throws(()=>allocate([credit(),credit()],1,100),/INVALID_CREDIT_ID/);
 assert.throws(()=>settle(credit(),101,0,100),/INVALID_SETTLEMENT/);
 assert.throws(()=>settle(credit(),100,101,100),/INVALID_SETTLEMENT/);
});
