'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{EventEmitter}=require('node:events');
const {uploadAdmission}=require('./transcription_upload_admission');
function pair(id){const req=new EventEmitter(),res=new EventEmitter();req.id=id;res.status=n=>(res.code=n,res);res.json=v=>(res.body=v,res);res.setHeader=()=>{};return {req,res,parsed:false};}
async function enter(m,p){await m(p.req,p.res,()=>{p.parsed=true;});return p;}
test('unauthorized upload never reaches body parser',async()=>{const p=await enter(uploadAdmission({authorize:async()=>{throw Error('invalid');}}),pair('a'));assert.equal(p.parsed,false);assert.equal(p.res.code,403);});
test('bounds concurrent authenticated bodies and releases exactly once',async()=>{const m=uploadAdmission({authorize:async r=>r.id});const a=await enter(m,pair('a')),b=await enter(m,pair('b')),c=await enter(m,pair('c'));assert.ok(a.parsed&&b.parsed);assert.equal(c.res.code,429);a.res.emit('finish');a.res.emit('close');a.req.emit('aborted');const d=await enter(m,pair('d'));assert.ok(d.parsed);assert.equal((await enter(m,pair('e'))).res.code,429);});
test('duplicate same-job uploads wait; disconnect permits same-job retry',async()=>{const m=uploadAdmission({authorize:async r=>r.id});const a=await enter(m,pair('a'));assert.equal((await enter(m,pair('a'))).res.code,429);a.req.emit('aborted');assert.ok((await enter(m,pair('a'))).parsed);});
