'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {createManualTimeLedger}=require('../admin/manual_time_ledger');
function database(){
 const data=new Map();let tail=Promise.resolve();
 const snap=(key)=>({id:key.split('/').at(-1),exists:data.has(key),data:()=>structuredClone(data.get(key))});
 const collection=(name,filters=[],limit=Infinity)=>({doc:id=>({id,key:`${name}/${id}`}),where:(key,op,value)=>{assert.equal(op,'==');return collection(name,[...filters,[key,value]],limit);},limit:n=>collection(name,filters,n),query:()=>({docs:[...data.keys()].filter(k=>k.startsWith(name+'/')&&filters.every(([f,v])=>data.get(k)[f]===v)).slice(0,limit).map(snap)})});
 return {data,collection,runTransaction:fn=>{const job=tail.then(async()=>{
   const writes=[];const tx={get:async r=>{assert.equal(writes.length,0,'read after write');return r.key?snap(r.key):r.query();},create:(r,v)=>{assert(!data.has(r.key));writes.push([r.key,v]);},update:(r,v)=>{assert(data.has(r.key));writes.push([r.key,{...data.get(r.key),...v}]);}};
   const result=await fn(tx);for(const [key,value] of writes)data.set(key,value);return result;
 });tail=job.catch(()=>{});return job;}};
}
function setup(){const db=database();db.data.set('adminManualCredits/a',{userId:'user',amountSeconds:600,remainingSeconds:600,reservedSeconds:0,status:'ACTIVE',expiresAt:null});return {db,ledger:createManualTimeLedger({db,now:()=>100})};}
test('concurrent duplicate reserve and complete produce one debit',async()=>{
 const {db,ledger}=setup();await Promise.all(Array.from({length:10},()=>ledger.reserve('user','op',300)));
 assert.equal(db.data.get('adminManualCredits/a').reservedSeconds,300);
 await Promise.all(Array.from({length:10},()=>ledger.complete('user','op',200)));
 assert.equal(db.data.get('adminManualCredits/a').remainingSeconds,400);assert.equal(db.data.get('adminManualCredits/a').reservedSeconds,0);
 assert.equal([...db.data.keys()].filter(k=>k.startsWith('adminCreditLedger/')).length,1);
});
test('concurrent distinct reservations cannot overspend',async()=>{
 const {db,ledger}=setup();const results=await Promise.allSettled([ledger.reserve('user','a',400),ledger.reserve('user','b',400)]);
 assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal(db.data.get('adminManualCredits/a').reservedSeconds,400);
});
test('settlement cannot exceed reservation or change on retry',async()=>{
 const {ledger}=setup();await ledger.reserve('user','a',100);
 await assert.rejects(ledger.complete('user','a',101),/INVALID_SETTLEMENT/);
 await ledger.complete('user','a',90);await assert.rejects(ledger.complete('user','a',80),/IDEMPOTENCY_CONFLICT/);
});
test('different owner cannot consume reservation',async()=>{
 const {ledger}=setup();await ledger.reserve('user','a',100);await assert.rejects(ledger.complete('other','a',100),/RESERVATION_NOT_FOUND/);
});
test('revoked reserve releases without restoring spendable time',async()=>{
 const {db,ledger}=setup();await ledger.reserve('user','a',100);
 Object.assign(db.data.get('adminManualCredits/a'),{remainingSeconds:100,status:'REVOKED_RESERVED'});
 await ledger.complete('user','a',40);assert.equal(db.data.get('adminManualCredits/a').remainingSeconds,0);
 assert.equal([...db.data.values()].filter(v=>v.type==='REVOKE_UNUSED')[0].amountSeconds,60);
});
test('failed reserve writes no records',async()=>{
 const {db,ledger}=setup();await assert.rejects(ledger.reserve('user','a',601),/INSUFFICIENT/);assert.equal(db.data.size,1);
});
