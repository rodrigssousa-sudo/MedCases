"use strict";

const assert = require("assert");

const {
  ClinicalActionRegistryAdapter,
} = require("../clinical_context/clinical_action_registry_adapter");
const {
  ClinicalNextActionEngine,
} = require("../clinical_context/clinical_next_action_engine");
const {
  createStructuredClinicalResponse,
  createWaitingForFactsResponse,
} = require("../clinical_context/structured_clinical_response_contract");

function fakeDb(rows) {
  return {
    collection(name) {
      assert.strictEqual(name, "clinical_action_registry");
      return {
        async get() {
          return {
            docs: rows.map((row) => ({
              id: row.id,
              data: () => ({ ...row.data }),
            })),
          };
        },
      };
    },
  };
}

async function main() {
  const now = new Date("2026-08-30T12:00:00Z");

  const adapter = new ClinicalActionRegistryAdapter({
    db: fakeDb([
      {
        id: "primary_specific",
        data: {
          actionKey: "primary_specific",
          enabled: true,
          priority: 100,
          effectiveFrom: "2026-01-01T00:00:00Z",
          kind: "primary",
          actionType: "dispatch_prompt",
          labels: {
            es: "Continuar manejo",
            pt: "Continuar manejo",
          },
          prompts: {
            es: "Continuar el manejo del caso activo con los datos ya confirmados.",
            pt: "Continuar o manejo do caso ativo com os dados já confirmados.",
          },
          match: {
            canonicalPathologyKey: "condition_alpha",
            managementRuleKey: "management_low",
          },
        },
      },
      {
        id: "classification_specific",
        data: {
          actionKey: "classification_specific",
          enabled: true,
          priority: 100,
          kind: "classification",
          actionType: "open_content_ref",
          labels: {
            es: "Ver clasificación",
            pt: "Ver classificação",
          },
          contentRef: "classification_alpha_table",
          match: {
            canonicalPathologyKey: "condition_alpha",
            classificationKey: "severity_alpha",
          },
        },
      },
      {
        id: "future_disabled_by_date",
        data: {
          actionKey: "future_action",
          enabled: true,
          priority: 999,
          effectiveFrom: "2027-01-01T00:00:00Z",
          kind: "primary",
          labels: { es: "Future" },
          prompts: { es: "Future" },
          match: {
            canonicalPathologyKey: "condition_alpha",
          },
        },
      },
    ]),
    clock: () => now,
  });

  const actions = await adapter.loadActions();
  assert.strictEqual(actions.length, 2);

  const engine = new ClinicalNextActionEngine();

  const actionResult = engine.resolve({
    pathologyKey: "condition_alpha",
    protocolKey: "protocol_current",
    managementResult: {
      resolved: true,
      managementRuleKey: "management_low",
      requiresClassification: true,
      missingFacts: [],
    },
    classificationResult: {
      resolved: true,
      classificationKey: "severity_alpha",
      categoryKey: "low",
    },
    actions,
    language: "es",
  });

  assert.strictEqual(actionResult.ambiguous, false);
  assert.strictEqual(actionResult.primaryAction.actionKey, "primary_specific");
  assert.strictEqual(
    actionResult.primaryAction.label,
    "Continuar manejo",
  );
  assert.strictEqual(
    actionResult.classificationAction.actionKey,
    "classification_specific",
  );
  assert.strictEqual(
    actionResult.classificationAction.contentRef,
    "classification_alpha_table",
  );

  const noFallback = engine.resolve({
    pathologyKey: "condition_beta",
    managementResult: {},
    classificationResult: {},
    actions,
    language: "es",
  });

  assert.strictEqual(noFallback.primaryAction, null);
  assert.strictEqual(noFallback.classificationAction, null);
  assert.strictEqual(noFallback.reason, "no_confident_remote_action");

  const response = createStructuredClinicalResponse({
    text: "Final validated clinical answer.",
    identityResult: {
      canonicalKey: "condition_alpha",
      displayLabel: "Condition Alpha",
      confidence: 0.98,
    },
    protocolResult: {
      protocol: { protocolKey: "protocol_current" },
    },
    classificationResult: {
      classificationKey: "severity_alpha",
      classificationLabel: "Severity",
      mode: "categorical",
      resolved: true,
      categoryKey: "low",
      categoryLabel: "Low",
      missingFacts: [],
      sourceVersion: "2",
    },
    managementResult: {
      resolved: true,
      managementRuleKey: "management_low",
      managementLabel: "Low management",
      missingFacts: [],
      sourceVersion: "3",
    },
    actionResult,
    language: "es",
    provenance: {
      registryVersion: "10",
      secretShouldBeDropped: "do-not-emit",
    },
  });

  assert.strictEqual(response.status, "ready");
  assert.strictEqual(
    response.presentation.revealMode,
    "local_progressive_after_commit",
  );
  assert.strictEqual(response.presentation.immutableAfterCommit, true);
  assert.strictEqual(response.presentation.allowVisibleTextMutation, false);
  assert.strictEqual(response.actions.primary.actionKey, "primary_specific");
  assert.strictEqual(
    response.actions.classification.actionKey,
    "classification_specific",
  );
  assert.strictEqual(Object.isFrozen(response), true);
  assert.strictEqual(Object.isFrozen(response.clinicalContext), true);
  assert.strictEqual(
    Object.prototype.hasOwnProperty.call(
      response.provenance,
      "secretShouldBeDropped",
    ),
    false,
  );

  const waitingActionResult = engine.resolve({
    pathologyKey: "condition_alpha",
    managementResult: {
      resolved: false,
      managementRuleKey: "",
      requiresClassification: true,
      missingFacts: ["marker.value"],
    },
    classificationResult: {
      resolved: false,
      classificationKey: "severity_alpha",
      categoryKey: "",
      missingFacts: ["marker.value"],
    },
    actions,
    language: "es",
  });

  const waiting = createWaitingForFactsResponse({
    identityResult: {
      canonicalKey: "condition_alpha",
      displayLabel: "Condition Alpha",
      confidence: 0.94,
    },
    protocolResult: {
      protocol: { protocolKey: "protocol_current" },
    },
    classificationResult: {
      classificationKey: "severity_alpha",
      classificationLabel: "Severity",
      mode: "categorical",
      resolved: false,
      missingFacts: ["marker.value"],
      sourceVersion: "2",
    },
    managementResult: {
      resolved: false,
      requiresClassification: true,
      missingFacts: ["marker.value"],
    },
    actionResult: waitingActionResult,
    language: "es",
  });

  assert.strictEqual(waiting.status, "waiting_for_facts");
  assert.strictEqual(waiting.text, "");
  assert.deepStrictEqual(
    waiting.clinicalContext.classification.missingFacts,
    ["marker.value"],
  );
  assert.strictEqual(waiting.presentation.immutableAfterCommit, true);

  console.log("REMOTE_BUILD3_CONTRACT_TEST=PASS");
  console.log("REMOTE_BUILD3_ASSERTION_GROUPS=10");
}

main().catch((error) => {
  console.error("REMOTE_BUILD3_CONTRACT_TEST=FAIL");
  console.error(error && error.stack ? error.stack : String(error));
  process.exitCode = 1;
});
