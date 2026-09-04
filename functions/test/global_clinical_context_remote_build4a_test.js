"use strict";

const assert = require("assert");

const {
  ClinicalContextOrchestrator,
  collectClinicalGenerationToBuffer,
} = require("../clinical_context/clinical_context_orchestrator");

async function* streamChunks() {
  yield "Validated ";
  yield { text: "clinical " };
  yield "answer.";
}

async function main() {
  const buffered = await collectClinicalGenerationToBuffer({
    generateResponse: async () => streamChunks(),
    context: {},
  });
  assert.strictEqual(buffered, "Validated clinical answer.");

  const snapshot = {
    identities: [
      {
        canonicalKey: "condition_alpha",
        displayLabel: "Condition Alpha",
        aliases: ["condition alpha", "alpha syndrome"],
        strongAliases: ["condition alpha"],
      },
    ],
    protocols: [
      {
        protocolKey: "protocol_alpha_current",
        canonicalPathologyKey: "condition_alpha",
        priority: 100,
        enabled: true,
      },
    ],
    classifications: [
      {
        classificationKey: "severity_alpha",
        canonicalPathologyKey: "condition_alpha",
        mode: "categorical",
        priority: 100,
        enabled: true,
        requiredFacts: ["state.stable", "marker.value"],
        categories: [
          {
            key: "low",
            label: "Low",
            priority: 100,
            criteria: {
              all: [
                { fact: "state.stable", op: "eq", value: true },
                { fact: "marker.value", op: "lt", value: 5 },
              ],
            },
            managementRuleKey: "management_low",
          },
        ],
      },
    ],
    managementRules: [
      {
        managementRuleKey: "management_low",
        canonicalPathologyKey: "condition_alpha",
        priority: 100,
        enabled: true,
        requiresClassification: true,
        dependsOn: {
          classificationKey: "severity_alpha",
          categoryKey: "low",
        },
        primaryActionRef: "primary_low",
        classificationActionRef: "classification_alpha",
      },
    ],
  };

  const actions = [
    {
      actionKey: "primary_low",
      kind: "primary",
      actionType: "dispatch_prompt",
      priority: 100,
      enabled: true,
      labels: {
        es: "Continuar manejo",
      },
      prompts: {
        es: "Continuar el manejo específico.",
      },
      match: {
        canonicalPathologyKey: "condition_alpha",
        managementRuleKey: "management_low",
      },
    },
    {
      actionKey: "classification_alpha",
      kind: "classification",
      actionType: "open_content_ref",
      priority: 100,
      enabled: true,
      labels: {
        es: "Ver clasificación",
      },
      contentRef: "classification_alpha_table",
      match: {
        canonicalPathologyKey: "condition_alpha",
        classificationKey: "severity_alpha",
      },
    },
  ];

  const orchestrator = new ClinicalContextOrchestrator();

  let generationCalls = 0;
  let validationCalls = 0;

  const waiting = await orchestrator.execute({
    input: "condition alpha",
    patientFacts: {
      state: { stable: true },
    },
    registrySnapshot: snapshot,
    actionDefinitions: actions,
    language: "es",
    generateResponse: async () => {
      generationCalls += 1;
      return "SHOULD_NOT_GENERATE";
    },
    validateResponse: async () => {
      validationCalls += 1;
      return { ok: true };
    },
  });

  assert.strictEqual(waiting.status, "waiting_for_facts");
  assert.strictEqual(waiting.response.status, "waiting_for_facts");
  assert.deepStrictEqual(
    waiting.response.clinicalContext.classification.missingFacts,
    ["marker.value"],
  );
  assert.strictEqual(generationCalls, 0);
  assert.strictEqual(validationCalls, 0);

  let visiblePartial = false;

  const ready = await orchestrator.execute({
    input: "condition alpha",
    patientFacts: {
      state: { stable: true },
      marker: { value: 2 },
    },
    registrySnapshot: snapshot,
    actionDefinitions: actions,
    language: "es",
    generateResponse: async function* () {
      yield "Initial ";
      visiblePartial = false;
      yield "final answer";
    },
    validateResponse: async ({ text }) => {
      validationCalls += 1;
      assert.strictEqual(text, "Initial final answer");
      return { ok: true, reason: "validated" };
    },
    provenance: {
      registryVersion: "100",
    },
  });

  assert.strictEqual(ready.status, "ready");
  assert.strictEqual(ready.response.text, "Initial final answer");
  assert.strictEqual(ready.response.actions.primary.label, "Continuar manejo");
  assert.strictEqual(
    ready.response.actions.classification.label,
    "Ver clasificación",
  );
  assert.strictEqual(
    ready.response.presentation.revealMode,
    "local_progressive_after_commit",
  );
  assert.strictEqual(
    ready.finalization.presentationBarrier.providerOutputVisibleBeforeCommit,
    false,
  );
  assert.strictEqual(
    ready.finalization.presentationBarrier.visibleTextMutableAfterCommit,
    false,
  );
  assert.strictEqual(visiblePartial, false);
  assert.strictEqual(Object.isFrozen(ready), true);
  assert.strictEqual(Object.isFrozen(ready.response), true);

  let repairCalls = 0;

  const repaired = await orchestrator.execute({
    input: "condition alpha",
    patientFacts: {
      state: { stable: true },
      marker: { value: 2 },
    },
    registrySnapshot: snapshot,
    actionDefinitions: actions,
    language: "es",
    generateResponse: async () => "bad answer",
    validateResponse: async ({ text }) => {
      if (text === "bad answer") {
        return { ok: false, reason: "needs_repair" };
      }
      return { ok: text === "repaired answer", reason: "validated" };
    },
    repairResponse: async () => {
      repairCalls += 1;
      return "repaired answer";
    },
  });

  assert.strictEqual(repaired.status, "ready");
  assert.strictEqual(repaired.response.text, "repaired answer");
  assert.strictEqual(repaired.finalization.repaired, true);
  assert.strictEqual(repairCalls, 1);

  const rejected = await orchestrator.execute({
    input: "condition alpha",
    patientFacts: {
      state: { stable: true },
      marker: { value: 2 },
    },
    registrySnapshot: snapshot,
    actionDefinitions: actions,
    language: "es",
    generateResponse: async () => "invalid answer",
    validateResponse: async () => ({
      ok: false,
      reason: "invalid",
    }),
  });

  assert.strictEqual(rejected.status, "response_not_committed");
  assert.strictEqual(rejected.response, null);
  assert.strictEqual(rejected.finalization.committed, false);
  assert.strictEqual(rejected.finalization.text, "");

  console.log("REMOTE_BUILD4A_CONTRACT_TEST=PASS");
  console.log("REMOTE_BUILD4A_ASSERTION_GROUPS=12");
}

main().catch((error) => {
  console.error("REMOTE_BUILD4A_CONTRACT_TEST=FAIL");
  console.error(error && error.stack ? error.stack : String(error));
  process.exitCode = 1;
});
