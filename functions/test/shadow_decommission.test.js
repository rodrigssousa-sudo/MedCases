'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {createClinicalShadowObservationS1Runtime} = require('../clinical_context/clinical_shadow_observation_s1_runtime');
const {createShadowObservationCanaryRuntime} = require('../clinical_context/clinical_shadow_observation_canary_runtime');
const root = path.resolve(__dirname, '../..');
test('S1 is immutable and disabled even when caller supplies activation flags', async () => {
  const runtime = createClinicalShadowObservationS1Runtime({shadowObservationEnabled:true,providerExecutionEnabled:true,firebaseReadEnabled:true});
  for(const flag of ['shadowObservationEnabled','providerExecutionEnabled','firebaseReadEnabled','patientTextCaptureEnabled','visibleCutoverEnabled','visibleMutation']) assert.equal(runtime[flag],false,flag);
  assert.equal(runtime.samplePercent,0);assert.ok(Object.isFrozen(runtime));
  let reads=0;
  const request=new Proxy({}, {get(){reads++;throw Error('request must not be inspected');}});
  const result=await runtime.observeFromRequest(request);
  assert.equal(reads,0);assert.ok(Object.isFrozen(result));
  assert.deepEqual(result,{observed:false,reason:'shadow_observation_disabled',providerCalls:0,firebaseReads:0,visibleMutation:false});
});
test('versioned canary rejects activation and never invokes sampler or observer',()=>{
  for(const flag of ['shadowObservationEnabled','providerExecutionEnabled','firebaseReadEnabled'])assert.throws(()=>createShadowObservationCanaryRuntime({[flag]:true}),/not_authorized/);
  const runtime=createShadowObservationCanaryRuntime({sampler:()=>{throw Error('sampler executed');},observer:()=>{throw Error('observer executed');}});
  assert.equal(runtime.observe({}).observed,false);
});
test('complete Functions import succeeds without any generated registry or network',()=>{
  const code=`for(const id of ['node:http','node:https']){require(id).request=()=>{throw Error('NETWORK_FORBIDDEN')};} global.fetch=()=>{throw Error('NETWORK_FORBIDDEN')}; const f=require('./functions/index.js'); if(typeof f.atenderConsultaIA!=='function'||typeof f.gptProxyStream!=='function')throw Error('MISSING_HANDLERS'); if(Object.keys(require.cache).some(x=>x.includes('/clinical_context/generated/')))throw Error('GENERATED_REGISTRY_LOADED'); console.log('FUNCTIONS_INDEX_IMPORT=PASS');`;
  const result=spawnSync(process.execPath,['-e',code],{cwd:root,timeout:10000,encoding:'utf8',env:{...process.env,FIREBASE_CONFIG:'{"projectId":"demo-medcases-security"}',GCLOUD_PROJECT:'demo-medcases-security'}});
  assert.equal(result.status,0,result.stderr);assert.match(result.stdout,/FUNCTIONS_INDEX_IMPORT=PASS/);
});
test('current canonical embedded registry retains identities, references and disabled promotion flags',()=>{
  const registry=JSON.parse(fs.readFileSync(path.join(root,'assets/clinical/clinical_registry_phase24_authoritative270.json')));
  const ids=new Set(registry.identities.map(x=>x.canonicalKey));assert.equal(ids.size,registry.identities.length);
  assert.equal(registry.counts.identities,ids.size);assert.equal(registry.counts.protocols,registry.protocols.length);
  for(const p of registry.protocols)assert.ok(ids.has(p.canonicalPathologyKey));
  for(const flag of ['firebaseWriteAuthorized','providerExecutionAuthorized','patientTextCaptureAuthorized','visibleCutover','backendDeployAuthorized','remoteConfigWriteAuthorized'])assert.equal(registry[flag],false,flag);
  for(const key of ['actions','content','classifications','managementRules'])assert.equal(registry.counts[key],registry[key].length,key);
});
test('privacy disclosures and explicit first-use image consent remain in current source',()=>{
  const plist=fs.readFileSync(path.join(root,'ios/Runner/Info.plist'),'utf8');
  assert.match(plist,/NSCameraUsageDescription/);assert.match(plist,/NSPhotoLibraryUsageDescription/);
  const dart=fs.readFileSync(path.join(root,'lib/screens/clinical_recorder_sheet.dart'),'utf8');
  assert.match(dart,/showDialog<bool>/);assert.match(dart,/consent/i);
  const boundary=fs.readFileSync(path.join(root,'lib/services/private_log_boundary.dart'),'utf8');assert.match(boundary,/kReleaseMode/);assert.match(boundary,/MEDCASES_DIAGNOSTIC_REDACTED/);
});
