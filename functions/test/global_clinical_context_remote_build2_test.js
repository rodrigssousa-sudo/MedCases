"use strict";

const assert = require("assert");

const {
  ClinicalRegistryAdapter,
} = require("../clinical_context/clinical_registry_adapter");
const {
  ClinicalClassificationResolver,
} = require("../clinical_context/clinical_classification_resolver");
const {
  ClinicalManagementDependencyResolver,
} = require("../clinical_context/clinical_management_dependency_resolver");

function fakeDb(collections) {
  return {
    collection(name) {
      return {
        async get() {
          return {
            docs: (collections[name] || []).map((row) => ({
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

  const db = fakeDb({
    clinical_identity_registry: [
      {
        id: "identity_current",
        data: {
          canonicalKey: "condition_alpha",
          aliases: ["alpha syndrome", "sindrome alfa"],
          enabled: true,
          priority: 100,
          effectiveFrom: "2026-01-01T00:00:00Z",
        },
      },
      {
        id: "identity_future",
        data: {
          canonicalKey: "condition_future",
          enabled: true,
          priority: 200,
          effectiveFrom: "2027-01-01T00:00:00Z",
        },
      },
    ],
    clinical_protocols: [
      {
        id: "protocol_current",
        data: {
          protocolKey: "protocol_current",
          canonicalPathologyKey: "condition_alpha",
          enabled: true,
          priority: 100,
          version: "2.0",
        },
      },
      {
        id: "protocol_disabled",
        data: {
          protocolKey: "protocol_disabled",
          canonicalPathologyKey: "condition_alpha",
          enabled: false,
          priority: 999,
        },
      },
    ],
    clinical_classification_registry: [
      {
        id: "classification_current",
        data: {
          classificationKey: "severity_alpha",
          canonicalPathologyKey: "condition_alpha",
          enabled: true,
          priority: 100,
          mode: "categorical",
        },
      },
    ],
    clinical_management_rules: [
      {
        id: "management_current",
        data: {
          managementRuleKey: "management_current",
          canonicalPathologyKey: "condition_alpha",
          enabled: true,
          priority: 100,
        },
      },
    ],
  });

  const adapter = new ClinicalRegistryAdapter({
    db,
    clock: () => now,
  });
  const snapshot = await adapter.loadSnapshot();

  assert.strictEqual(snapshot.identities.length, 1);
  assert.strictEqual(snapshot.identities[0].id, "identity_current");
  assert.strictEqual(snapshot.protocols.length, 1);
  assert.strictEqual(snapshot.classifications.length, 1);
  assert.strictEqual(snapshot.managementRules.length, 1);

  const classifier = new ClinicalClassificationResolver();

  const categoricalDescriptors = [
    {
      id: "severity_alpha",
      classificationKey: "severity_alpha",
      canonicalPathologyKey: "condition_alpha",
      mode: "categorical",
      priority: 100,
      requiredFacts: ["hemodynamics.stable", "marker.value"],
      categories: [
        {
          key: "high",
          label: "High",
          priority: 100,
          managementRuleKey: "management_high",
          criteria: {
            all: [
              { fact: "hemodynamics.stable", op: "eq", value: false },
            ],
          },
        },
        {
          key: "low",
          label: "Low",
          priority: 10,
          managementRuleKey: "management_low",
          criteria: {
            all: [
              { fact: "hemodynamics.stable", op: "eq", value: true },
              { fact: "marker.value", op: "lt", value: 5 },
            ],
          },
        },
      ],
    },
  ];

  const missing = classifier.resolve({
    pathologyKey: "condition_alpha",
    descriptors: categoricalDescriptors,
    patientFacts: {
      hemodynamics: { stable: true },
    },
  });

  assert.strictEqual(missing.resolved, false);
  assert.strictEqual(missing.reason, "classification_missing_facts");
  assert.deepStrictEqual(missing.missingFacts, ["marker.value"]);

  const classified = classifier.resolve({
    pathologyKey: "condition_alpha",
    descriptors: categoricalDescriptors,
    patientFacts: {
      hemodynamics: { stable: true },
      marker: { value: 2 },
    },
  });

  assert.strictEqual(classified.resolved, true);
  assert.strictEqual(classified.categoryKey, "low");
  assert.strictEqual(classified.managementRuleKey, "management_low");

  const scoreDescriptors = [
    {
      id: "score_alpha",
      classificationKey: "score_alpha",
      canonicalPathologyKey: "condition_alpha",
      mode: "score",
      priority: 100,
      requiredFacts: ["age", "finding.present"],
      components: [
        {
          key: "age_component",
          points: 2,
          criteria: {
            all: [{ fact: "age", op: "gte", value: 65 }],
          },
        },
        {
          key: "finding_component",
          points: 1,
          criteria: {
            all: [{ fact: "finding.present", op: "eq", value: true }],
          },
        },
      ],
      bands: [
        { key: "band_0", label: "Band 0", min: 0, max: 0 },
        { key: "band_1", label: "Band 1", min: 1, max: 2 },
        { key: "band_2", label: "Band 2", min: 3, max: 3 },
      ],
    },
  ];

  const scored = classifier.resolve({
    pathologyKey: "condition_alpha",
    descriptors: scoreDescriptors,
    patientFacts: {
      age: 70,
      finding: { present: true },
    },
  });

  assert.strictEqual(scored.resolved, true);
  assert.strictEqual(scored.score, 3);
  assert.strictEqual(scored.categoryKey, "band_2");

  const management = new ClinicalManagementDependencyResolver();

  const managementRules = [
    {
      id: "management_low",
      managementRuleKey: "management_low",
      canonicalPathologyKey: "condition_alpha",
      priority: 100,
      enabled: true,
      requiresClassification: true,
      dependsOn: {
        classificationKey: "severity_alpha",
        categoryKey: "low",
      },
      payload: {
        responsePolicy: "category_specific",
      },
      primaryActionRef: "action_primary_low",
      classificationActionRef: "action_classification_alpha",
    },
  ];

  const waiting = management.resolve({
    pathologyKey: "condition_alpha",
    classificationResult: missing,
    managementRules,
  });

  assert.strictEqual(waiting.resolved, false);
  assert.strictEqual(waiting.requiresClassification, true);
  assert.deepStrictEqual(waiting.missingFacts, ["marker.value"]);

  const resolvedManagement = management.resolve({
    pathologyKey: "condition_alpha",
    classificationResult: classified,
    managementRules,
  });

  assert.strictEqual(resolvedManagement.resolved, true);
  assert.strictEqual(resolvedManagement.managementRuleKey, "management_low");
  assert.strictEqual(
    resolvedManagement.payload.responsePolicy,
    "category_specific",
  );
  assert.strictEqual(
    resolvedManagement.classificationActionRef,
    "action_classification_alpha",
  );

  console.log("REMOTE_BUILD2_CONTRACT_TEST=PASS");
  console.log("REMOTE_BUILD2_TEST_ASSERTION_GROUPS=8");
}

main().catch((error) => {
  console.error("REMOTE_BUILD2_CONTRACT_TEST=FAIL");
  console.error(error && error.stack ? error.stack : String(error));
  process.exitCode = 1;
});
