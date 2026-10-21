'use strict';
// Technical regression inputs from frozen source files, never a drug database.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const [recovery,sourceRoot]=process.argv.slice(2);if(!recovery||!sourceRoot)throw Error('Provide frozen R15 and source directories');
const {resolveDrugReference}=require(path.join(recovery,'functions/plantao_drug_reference.js'));
const docs=require(path.join(recovery,'catalog-readonly-fixture.json'));
const catalogVersion=docs['app_config/clinical_content'].activeVersion;
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
(async()=>{
const result={},inputs={};
for(const name of ['noradrenalina','ceftriaxona','metformina']){
 const file=path.join(sourceRoot,name+'.json'),raw=fs.readFileSync(file),drug=JSON.parse(raw);inputs[file]=hash(raw);
 for(const lang of ['pt','es']){
  const data={...require(path.join(recovery,'real-request-'+lang+'.json')),catalogQuery:name,userMessage:name,lang};
  const fetchImpl=async url=>{
   if(url==='https://medcasespro.com/api/calculator/session')return {ok:true,json:async()=>({accessToken:'mcc1.SYNTHETIC_LOCAL_ONLY',tier:'premium',capabilities:['drug_catalog_full'],expiresAtUtc:new Date(Date.now()+60000).toISOString()})};
   if(url==='https://plankton-app-9dgnu.ondigitalocean.app/api/drugs/'+name)return {ok:true,json:async()=>({ok:true,drug})};
   throw Error('NETWORK_FORBIDDEN');
  };
  result[name+'/'+lang]=await resolveDrugReference({query:name,language:lang,data,catalogVersion,authorization:'Bearer SYNTHETIC_LOCAL_ONLY',fetchImpl});
 }
}
fs.writeFileSync('test/fixtures/r15_named_drug_documents.json',JSON.stringify(result,null,2)+'\n');
fs.writeFileSync('maintenance/r15-ux/evidence/named-drug-fixture-provenance.json',JSON.stringify({scope:'FROZEN_REAL_SOURCE_SYNTHETIC_TRANSPORT_NOT_REAL_MCC1',inputs,outputSha256:hash(fs.readFileSync('test/fixtures/r15_named_drug_documents.json')),documents:Object.keys(result)},null,2)+'\n');
})();
