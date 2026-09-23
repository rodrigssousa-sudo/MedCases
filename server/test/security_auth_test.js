'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),acorn=require('acorn');
const source=fs.readFileSync('server/server.js','utf8');
const node=acorn.parse(source,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='authenticateFirebaseToken');
for(const code of [null,'auth/argument-error','auth/id-token-expired','auth/id-token-revoked','auth/user-disabled'])test('actual auth middleware '+(code||'valid'),async()=>{
 let called=false,verified=false;
 const context={firebaseAuth:{verifyIdToken:async(token,checkRevoked)=>{assert.equal(checkRevoked,true);assert.equal(token,'synthetic-fixture');verified=true;if(code)throw Object.assign(Error('synthetic'),{code});return {uid:'synthetic-a'};}},log:{warn(){},info(){},error(){}},Date};
 vm.createContext(context);vm.runInContext(source.slice(node.start,node.end),context);
 const res={status(n){this.code=n;return this;},json(v){this.body=v;return this;}};
 await context.authenticateFirebaseToken({method:'POST',headers:{authorization:'Bearer synthetic-fixture'}},res,()=>{called=true;});
 assert.equal(verified,true);assert.equal(called,!code);if(code)assert.equal(res.code,401);
});
test('manual Cloud Function SDK token verification always checks revocation',()=>{
 for(const path of ['functions/index.js','functions/lib/ai_control_plane_v2/study_google_ai_oauth_physical_canary_http_server_v1.js']){
  const text=fs.readFileSync(path,'utf8');
  const ast=acorn.parse(text,{ecmaVersion:'latest'});let count=0;
  function walk(n){if(!n||typeof n!=='object')return;if(n.type==='CallExpression'&&n.callee.type==='MemberExpression'&&n.callee.property.name==='verifyIdToken'){count++;assert.equal(n.arguments[1]?.value,true,path);}for(const v of Object.values(n))if(Array.isArray(v))v.forEach(walk);else if(v&&typeof v==='object')walk(v);}
  walk(ast);assert.ok(count>0);
 }
});
test('backend private logger never forwards sensitive arguments',()=>{
 const captured=[];const module={exports:{}};
 vm.runInNewContext(fs.readFileSync('server/private_logger.js','utf8'),{module,globalThis:{console:Object.fromEntries(['log','warn','error','info','debug'].map(k=>[k,(...a)=>captured.push(a)]))}});
 for(const level of ['log','warn','error','info','debug'])module.exports[level]('synthetic patient',new Error('secret-provider-body'),{uid:'synthetic-uid',token:'synthetic-token'});
 assert.equal(captured.length,5);assert.ok(!JSON.stringify(captured).includes('synthetic'));assert.ok(!JSON.stringify(captured).includes('secret'));
});
