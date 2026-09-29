'use strict';
const assert=require('node:assert/strict');
function database(seed=[['users/A',{plan:'free'}],['users/B',{plan:'premium'}]]){
 const records=new Map(seed);let queue=Promise.resolve();
 const snapshot=path=>({id:path.split('/').at(-1),exists:records.has(path),data:()=>structuredClone(records.get(path)),ref:doc(path)});
 const doc=path=>({path,id:path.split('/').at(-1),get:async()=>snapshot(path),set:async(value)=>records.set(path,structuredClone(value))});
 function collection(name,filters=[],count=Infinity){return {doc:id=>doc(`${name}/${id}`),where:(field,op,value)=>collection(name,[...filters,[field,op,value]],count),limit:n=>collection(name,filters,n),get:async()=>({docs:[...records].filter(([k,v])=>k.startsWith(name+'/')&&filters.every(([f,op,x])=>op==='in'?x.includes(v[f]):op==='<='?v[f]<=x:v[f]===x)).slice(0,count).map(([k])=>snapshot(k))})};}
 return {records,data:records,collection,runTransaction(fn){const result=queue.then(async()=>{const staged=[];const getKey=r=>typeof r==='string'?r:r.path;
  const value=await fn({get:async r=>{assert.equal(staged.length,0,'all transaction reads must precede writes');return typeof r==='string'?snapshot(r):r.get();},set:(r,v,opt)=>staged.push([getKey(r),opt?.merge?{...records.get(getKey(r)),...v}:structuredClone(v)]),update:(r,v)=>{assert(records.has(getKey(r)));staged.push([getKey(r),{...records.get(getKey(r)),...v}]);},create:(r,v)=>{assert(!records.has(getKey(r)));staged.push([getKey(r),structuredClone(v)]);}});
  for(const [k,v] of staged)records.set(k,v);return value;
 });queue=result.catch(()=>{});return result;}};
}
module.exports={database};
