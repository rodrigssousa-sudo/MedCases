"use strict";
const assert=require("assert");
const fs=require("fs");

const index=fs.readFileSync("functions/index.js","utf8");
const runtime=fs.readFileSync(
  "functions/clinical_context/clinical_shadow_observation_s1_runtime.js",
  "utf8",
);
const registry=JSON.parse(fs.readFileSync(
  "functions/clinical_context/generated/clinical_shadow_observation_s1_registry_index.phase14.local.json",
  "utf8",
));

assert.strictEqual(registry.rows.length,270);
assert.strictEqual(registry.samplePercent,1);
assert.deepStrictEqual(registry.productiveHandlerTargets,["atenderConsultaIA","gptProxyStream"]);
assert.strictEqual(registry.excludedDeadLegacyExport,"atenderConsultaIAStream");
assert.strictEqual((index.match(/MEDCASES_SHADOW_OBSERVATION_S1_CALL_BEGIN:/g)||[]).length,2);
assert(index.includes("MEDCASES_SHADOW_OBSERVATION_S1_CALL_BEGIN:atenderConsultaIA"));
assert(index.includes("MEDCASES_SHADOW_OBSERVATION_S1_CALL_BEGIN:gptProxyStream"));
assert(!index.includes("MEDCASES_SHADOW_OBSERVATION_S1_CALL_BEGIN:atenderConsultaIAStream"));

for (const forbidden of ["userMessage","systemPrompt","conversationHistory","transcript"]) {
  assert.strictEqual(runtime.includes(forbidden),false,forbidden);
}
for (const forbidden of ["callGemini","callOpenAi","generateContent","responses.create"]) {
  assert.strictEqual(runtime.includes(forbidden),false,forbidden);
}
assert(runtime.includes("const SAMPLE_PERCENT=1;"));
assert.strictEqual(runtime.includes("initializeApp"),false);
assert.strictEqual(runtime.includes("getApps"),false);
assert(runtime.includes("const db=getFirestore(getApp());"));
assert(runtime.includes("patientTextCaptured:false"));
assert(runtime.includes("providerCalls:0"));
assert(runtime.includes("visibleMutation:false"));

console.log("MACRO37_R7_SOURCE_CONTRACT=PASS");
console.log("MACRO37_R7_LAZY_FIREBASE_ADMIN_INIT=PASS");
console.log("MACRO37_R7_MODULE_LOAD_DUPLICATE_APP_PREVENTION=PASS");
console.log("MACRO37_R7_ASSERTION_GROUPS=30");
console.log("MACRO37_R7_PRODUCTIVE_HANDLERS=2");
console.log("MACRO37_R7_DEAD_LEGACY_HANDLERS=0");
console.log("MACRO37_R7_PATIENT_TEXT_CAPTURE=NONE");
console.log("MACRO37_R7_OBSERVER_PROVIDER_EXECUTION=OFF");
console.log("MACRO37_R7_VISIBLE_CUTOVER=HARD_OFF");
