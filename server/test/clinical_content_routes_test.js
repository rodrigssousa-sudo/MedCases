'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const os=require('node:os');
const path=require('node:path');
const {registerClinicalContentRoutes}=require('../clinical_content_routes');
async function run({uid='TEST_UID',premium=true,relative='manifest.json',root}={}) {
  let handler;let reads=0;
  registerClinicalContentRoutes({root,app:{get:(route,auth,limiter,h)=>{assert.equal(route,'/api/clinical-content/*');handler=h;}},authenticate:()=>{},limiter:()=>{},
    db:{collection:(name)=>{assert.equal(name,'users');return {doc:(id)=>{assert.equal(id,uid);return {get:async()=>{reads++;return {exists:true,data:()=>premium?{plan:'premium'}:{plan:'free'}};}};}};}}});
  const res={code:200,headers:{},setHeader(k,v){this.headers[k]=v;},status(c){this.code=c;return this;},json(v){this.value=v;return this;},type(){return this;},send(v){this.value=v;return this;}};
  await handler({auth:uid?{uid}:null,params:{0:relative}},res);return {res,reads};
}
test('unauthenticated requests do not read entitlement or content',async()=>{const x=await run({uid:''});assert.equal(x.res.code,401);assert.equal(x.reads,0);});
test('free denied before content read',async()=>{assert.equal((await run({premium:false,root:'/nonexistent'})).res.code,403);});
test('endpoint fails closed until publication root configured',async()=>{assert.equal((await run()).res.code,503);});
test('traversal and unknown path denied',async()=>{for(const relative of ['../secret','snapshots/1/../secret.json','manifest.json?key=x'])assert.equal((await run({relative})).res.code,400);});
test('published JSON served exactly without mutation; no-store',async()=>{const root=await fs.mkdtemp(path.join(os.tmpdir(),'rk19-content-'));try{const data=JSON.stringify({testOnly:true});await fs.writeFile(path.join(root,'manifest.json'),data);const x=await run({root});assert.equal(x.res.code,200);assert.equal(x.res.value.toString(),data);assert.equal(x.res.headers['Cache-Control'],'private, no-store');}finally{await fs.rm(root,{recursive:true,force:true});}});
test('symlink outside publication root rejected',async()=>{const root=await fs.mkdtemp(path.join(os.tmpdir(),'rk19-symlink-'));try{await fs.symlink(__filename,path.join(root,'manifest.json'));assert.equal((await run({root})).res.code,400);}finally{await fs.rm(root,{recursive:true,force:true});}});
