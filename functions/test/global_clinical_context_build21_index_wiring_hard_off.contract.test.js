"use strict";

const assert = require("assert");
const fs = require("fs");
const crypto = require("crypto");

const source = fs.readFileSync("functions/index.js", "utf8");

function sha(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

for (const tag of [
  "P1",
  "P2_GEMINI_AI",
  "P3_GEMINI_SSE",
  "P4_OPENAI_STREAM",
]) {
  const begin =
    `MEDCASES_GLOBAL_CLINICAL_CONTEXT_BUILD21_${tag}_BEGIN`;
  const end =
    `MEDCASES_GLOBAL_CLINICAL_CONTEXT_BUILD21_${tag}_END`;
  assert.strictEqual(source.split(begin).length - 1, 1);
  assert.strictEqual(source.split(end).length - 1, 1);
}

assert(
  source.includes(
    'require("./clinical_context/clinical_context_runtime_seam_preparation")',
  ),
);

for (const token of [
  "runtimeActivationEnabled: false",
  "shadowExecutionEnabled: false",
  "realProviderExecutionEnabled: false",
  "visibleCutoverEnabled: false",
  'cutoverState: "OFF"',
  'visibleDisposition: "legacy_unchanged"',
]) {
  assert(source.includes(token));
}

assert.strictEqual(
  source.split(
    "clinical_context_runtime_wiring_hard_off_invariant_violation",
  ).length - 1,
  3,
);

for (const rawCall of [
  "_callGeminiRestAIRaw(",
  "_callGeminiRestSSERaw(",
  "_callOpenAiResponsesStreamRaw(",
]) {
  assert(source.includes(rawCall));
}

for (const forbidden of [
  "runtimeActivationEnabled: true",
  "shadowExecutionEnabled: true",
  "realProviderExecutionEnabled: true",
  "visibleCutoverEnabled: true",
]) {
  assert.strictEqual(source.includes(forbidden), false);
}

console.log("BUILD21_CONTRACT_TEST=PASS");
console.log("BUILD21_ASSERTION_GROUPS=18");
console.log(`BUILD21_INDEX_SHA=${sha(source)}`);
