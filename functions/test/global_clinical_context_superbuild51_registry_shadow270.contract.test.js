"use strict";
const assert=require("assert");
const fs=require("fs");
const {ClinicalManagementDependencyResolver}=require("../clinical_context/clinical_management_dependency_resolver");
const snapshot=JSON.parse(fs.readFileSync("functions/clinical_context/generated/clinical_registry_remote_snapshot.phase24_authoritative270.local.json","utf8"));
const payload=JSON.parse(fs.readFileSync("functions/clinical_context/generated/clinical_firestore_write_payload.phase24_authoritative270.local.json","utf8"));
const batches=JSON.parse(fs.readFileSync("functions/clinical_context/generated/clinical_firestore_write_batches.phase24_authoritative270.local.json","utf8"));
const shadow=JSON.parse(fs.readFileSync("functions/clinical_context/generated/clinical_shadow_global_validation.phase24.local.json","utf8"));
const report=JSON.parse(fs.readFileSync("functions/clinical_context/generated/global_clinical_context_superbuild51_registry_shadow_report.local.json","utf8"));

assert.deepStrictEqual(snapshot.counts,{identities:270,protocols:270,classifications:94,managementRules:270,actions:364,content:364});
assert.strictEqual(snapshot.managementAuthoring.ready,270);
assert.strictEqual(snapshot.managementAuthoring.failClosed,0);
assert.strictEqual(snapshot.classificationApplicability.authored,94);
assert.strictEqual(snapshot.classificationApplicability.backlog,0);
assert.strictEqual(snapshot.firebaseWriteAuthorized,false);
assert.strictEqual(snapshot.providerExecutionAuthorized,false);
assert.strictEqual(snapshot.patientTextCaptureAuthorized,false);
assert.strictEqual(snapshot.shadowS1Percent,1);
assert.strictEqual(snapshot.visibleCutover,false);
assert.strictEqual(payload.executionMode,"PREPARED_NOT_AUTHORIZED");
assert.strictEqual(payload.firebaseWriteAuthorized,false);
assert.strictEqual(payload.counts.totalOperations,1632);
assert.strictEqual(payload.counts.identities,270);
assert.strictEqual(payload.counts.protocols,270);
assert.strictEqual(payload.counts.classifications,94);
assert.strictEqual(payload.counts.managementRules,270);
assert.strictEqual(payload.counts.actions,364);
assert.strictEqual(payload.counts.content,364);
assert.strictEqual(batches.batchCount,5);
assert.strictEqual(batches.totalOperations,1632);
assert.deepStrictEqual(batches.batches.map(x=>x.operationCount),[400,400,400,400,32]);
assert.strictEqual(shadow.managementReady,270);
assert.strictEqual(shadow.managementFailClosed,0);
assert.strictEqual(shadow.classificationAuthored,94);
assert.strictEqual(shadow.classificationBacklog,0);
assert.strictEqual(shadow.managementClassificationDependencyMissing,0);
assert.strictEqual(shadow.providerCalls,0);
assert.strictEqual(shadow.patientTextCaptured,0);
assert.strictEqual(shadow.firebaseWrites,0);
assert.strictEqual(shadow.shadowS1Percent,1);
assert.strictEqual(shadow.visibleCutover,false);
assert.strictEqual(report.shadowGlobalStaticValidation,true);
assert.strictEqual(report.cloudMutation,false);

const idKeys=new Set(snapshot.identities.map(x=>x.canonicalKey));
const protocolKeys=new Set(snapshot.protocols.map(x=>x.canonicalPathologyKey));
const managementKeys=new Set(snapshot.managementRules.map(x=>x.canonicalPathologyKey));
assert.strictEqual(idKeys.size,270); assert.strictEqual(protocolKeys.size,270); assert.strictEqual(managementKeys.size,270);
assert.deepStrictEqual([...idKeys].sort(),[...protocolKeys].sort());
assert.deepStrictEqual([...idKeys].sort(),[...managementKeys].sort());

const resolver=new ClinicalManagementDependencyResolver();
let resolved=0, waiting=0;
for(const rule of snapshot.managementRules){
  assert.strictEqual(rule.enabled,true,rule.canonicalPathologyKey);
  assert.strictEqual(rule.managementReady,true,rule.canonicalPathologyKey);
  assert.strictEqual(rule.visibleCutoverEligible,false,rule.canonicalPathologyKey);
  const hasDependency=Boolean(rule.dependsOn && rule.dependsOn.classificationKey);
  const result=resolver.resolve({pathologyKey:rule.canonicalPathologyKey,managementRules:[rule],classificationResult:{resolved:false,missingFacts:["classification"]}});
  if(hasDependency){
    assert.strictEqual(result.resolved,false,rule.canonicalPathologyKey);
    assert.strictEqual(result.reason,"management_waiting_for_classification",rule.canonicalPathologyKey);
    waiting++;
  }else{
    assert.strictEqual(result.resolved,true,rule.canonicalPathologyKey);
    assert.strictEqual(result.managementRuleKey,rule.managementRuleKey,rule.canonicalPathologyKey);
    resolved++;
  }
}
assert.strictEqual(resolved+waiting,270);

console.log("SUPERBUILD51_CONTRACT=PASS");
console.log("SUPERBUILD51_REGISTRY_SNAPSHOT_GLOBAL270=PASS");
console.log("SUPERBUILD51_FIRESTORE_PHASE24_DRYRUN=1632_OPERATIONS_PASS");
console.log("SUPERBUILD51_MANAGEMENT_RESOLVER_ALL270=270/270_PASS");
console.log("SUPERBUILD51_MANAGEMENT_RESOLVED_WITHOUT_CLASSIFICATION="+resolved);
console.log("SUPERBUILD51_MANAGEMENT_WAITING_FOR_CLASSIFICATION="+waiting);
console.log("SUPERBUILD51_ZERO_MISSING_CLASSIFICATION_DEPENDENCIES=PASS");
console.log("SUPERBUILD51_PROVIDER_EXECUTION=NONE");
console.log("SUPERBUILD51_PATIENT_TEXT_CAPTURE=NONE");
console.log("S1_SAMPLE_PERCENT=1_UNCHANGED");
console.log("VISIBLE_CUTOVER=HARD_OFF");
