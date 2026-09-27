'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {requestIdentity,semanticQuery,freshnessRequested}=require('../plantao_snapshot_identity');
const {snapshotKey}=require('../plantao_clinical_snapshot');
const base={uid:'qa_one',internalContext:'shared_clinical_policy',history:[],clinicalContext:{},knowledgeVersion:'knowledge_1'};
const pairs=[['Encefalopatia hepática: tratamento e doses','Encefalopatía hepática: tratamiento y dosis'],['Metformina: doses e indicações','Metformina: dosis e indicaciones'],['Infarto agudo do miocárdio: tratamento e doses','Infarto agudo de miocardio: tratamiento y dosis'],['Hipercalemia: tratamento e doses','Hiperkalemia: tratamiento y dosis'],['Sepse: tratamento e doses','Sepsis: tratamiento y dosis']];
for(const [pt,es] of pairs)test('shared semantic identity '+semanticQuery(pt).topic,()=>{
 assert.deepEqual(semanticQuery(pt),semanticQuery(es));
 assert.equal(snapshotKey(requestIdentity({...base,query:pt})),snapshotKey(requestIdentity({...base,query:es})));
});
test('context, active history, knowledge, policy, model contract and UID all invalidate',()=>{
 const input={...base,query:pairs[0][0]},key=snapshotKey(requestIdentity(input));
 for(const change of [{uid:'other_user'},{clinicalContext:{egfr:25}},{history:[{role:'user',content:'metformin'}]},{knowledgeVersion:'knowledge_2'},{policyVersion:'policy_2'},{modelContractVersion:'model_contract_2'},{internalContext:'changed guideline'}])assert.notEqual(key,snapshotKey(requestIdentity({...input,...change})));
});
test('follow-up cannot reuse the generic metformin snapshot',()=>{
 const key=snapshotKey(requestIdentity({...base,query:'Metformina'}));
 for(const query of ['¿Y si el paciente tiene eGFR 25?','Metformina: calcule la dosis','Metformina sem insuficiência renal','Metformina com insuficiência renal'])assert.notEqual(key,snapshotKey(requestIdentity({...base,query,history:[{role:'user',content:'Metformina'}]})));
});
test('unrecognized prose, negation, dose numbers and case-sensitive units are never erased',()=>{
 for(const [a,b] of [['sí','si'],['no tiene alergia','tiene alergia'],['1 mg','1 Mg'],['eGFR 25','eGFR 45']])assert.notDeepEqual(semanticQuery(a),semanticQuery(b));
});
test('explicit current requests need a fresh nonce; a stale deterministic entry is not reused',()=>{
 for(const query of ['latest metformin guideline','Metformina actualizada','Sepse: diretriz atual','IAM 2026']) {
  assert.ok(freshnessRequested(query));assert.throws(()=>requestIdentity({...base,query}));
  assert.notEqual(snapshotKey(requestIdentity({...base,query,freshnessNonce:'first'})),snapshotKey(requestIdentity({...base,query,freshnessNonce:'second'})));
 }
});
