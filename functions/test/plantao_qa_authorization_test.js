
'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {isScopedPlantaoQaAuthorized: allowed}=require('../plantao_qa_authorization');
const now=1700000000000;
const qa={uid:'synthetic-qa',medcasesQaPlantao:{uid:'synthetic-qa',endpoint:'plantaoProxyStream',syntheticOnly:true,expiresAtMs:now+3600000}};
test('QA grant is allowed only for canonical Plantao',()=>assert.equal(allowed(qa,'plantaoProxyStream',now),true));
for(const endpoint of ['gptProxyStream','gptProxy','atenderConsultaIA','admin','']) test('QA denied on '+endpoint,()=>assert.equal(allowed(qa,endpoint,now),false));
test('ordinary user receives no exception',()=>assert.equal(allowed({uid:'ordinary'},'plantaoProxyStream',now),false));
test('owner record and roles are never mutated',()=>{const before=JSON.stringify(qa);allowed(qa,'plantaoProxyStream',now);assert.equal(JSON.stringify(qa),before);assert.equal(allowed({uid:'owner',admin:true},'plantaoProxyStream',now),false);});
test('absent or mismatched verified UID denied',()=>{for(const t of [null,{}, {...qa,uid:''},{...qa,uid:'different'}])assert.equal(allowed(t,'plantaoProxyStream',now),false);});
test('expired, wrong scope, missing synthetic flag and malformed expiry denied',()=>{for(const change of [{expiresAtMs:now},{expiresAtMs:'forever'},{endpoint:'gptProxyStream'},{syntheticOnly:false}])assert.equal(allowed({...qa,medcasesQaPlantao:{...qa.medcasesQaPlantao,...change}},'plantaoProxyStream',now),false);});
