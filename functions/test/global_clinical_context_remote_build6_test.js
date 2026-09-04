"use strict";

const assert = require("assert");

const {
  createReadOnlyClinicalDbFacade,
} = require("../clinical_context/clinical_context_firestore_readers");
const {
  createClinicalContextBackendIntegration,
} = require("../clinical_context/clinical_context_backend_integration");
const {
  exportClinicalRegistrySeed,
} = require("../clinical_context/clinical_registry_seed_exporter");

function fakeDb(data) {
  return {
    collection(name) {
      const rows = data[name] || [];

      return {
        async get() {
          return {
            docs: rows.map((row) => ({
              id: row.id,
              data: () => ({ ...row.data }),
            })),
          };
        },

        doc(id) {
          const row = rows.find((item) => item.id === id);

          return {
            async get() {
              return {
                id,
                exists: Boolean(row),
                data: () => (row ? { ...row.data } : undefined),
              };
            },
          };
        },

        async add() {
          throw new Error("write_should_never_be_exposed");
        },
      };
    },
  };
}

async function main() {
  const data = {
    clinical_identity_registry: [
      {
        id: "condition_alpha",
        data: {
          canonicalKey: "condition_alpha",
          enabled: true,
          priority: 100,
          version: "1",
          aliases: ["condition alpha"],
        },
      },
    ],
    clinical_protocols: [
      {
        id: "protocol_alpha",
        data: {
          protocolKey: "protocol_alpha",
          canonicalPathologyKey: "condition_alpha",
          enabled: true,
          priority: 100,
          version: "1",
        },
      },
    ],
    clinical_classification_registry: [
      {
        id: "severity_alpha",
        data: {
          classificationKey: "severity_alpha",
          canonicalPathologyKey: "condition_alpha",
          mode: "categorical",
          enabled: true,
          priority: 100,
          version: "1",
        },
      },
    ],
    clinical_management_rules: [
      {
        id: "management_alpha",
        data: {
          managementRuleKey: "management_alpha",
          canonicalPathologyKey: "condition_alpha",
          enabled: true,
          priority: 100,
          version: "1",
          dependsOn: {
            classificationKey: "severity_alpha",
          },
        },
      },
    ],
    clinical_action_registry: [
      {
        id: "primary_alpha",
        data: {
          actionKey: "primary_alpha",
          kind: "primary",
          actionType: "dispatch_prompt",
          enabled: true,
          priority: 100,
          version: "1",
          prompts: {
            es: "Continue",
          },
          match: {
            canonicalPathologyKey: "condition_alpha",
            managementRuleKey: "management_alpha",
          },
        },
      },
      {
        id: "classification_alpha",
        data: {
          actionKey: "classification_alpha",
          kind: "classification",
          actionType: "open_content_ref",
          enabled: true,
          priority: 100,
          version: "1",
          contentRef: "classification_alpha_content",
          match: {
            canonicalPathologyKey: "condition_alpha",
            classificationKey: "severity_alpha",
          },
        },
      },
    ],
    clinical_content_registry: [
      {
        id: "classification_alpha_content",
        data: {
          contentKey: "classification_alpha_content",
          enabled: true,
          version: "1",
          sections: [],
        },
      },
    ],
  };

  const rawDb = fakeDb(data);
  const readOnly = createReadOnlyClinicalDbFacade(rawDb);

  assert.strictEqual(
    typeof readOnly.collection("clinical_protocols").get,
    "function",
  );
  assert.strictEqual(
    readOnly.collection("clinical_protocols").add,
    undefined,
  );
  assert.strictEqual(
    readOnly.collection("clinical_protocols").doc("protocol_alpha").set,
    undefined,
  );

  const integration = createClinicalContextBackendIntegration({
    db: rawDb,
  });

  const gate = integration.cutoverGate.evaluate({
    mode: "plantao",
    userId: "user1",
    requestKey: "request1",
  });

  assert.strictEqual(gate.allowed, false);
  assert.strictEqual(gate.reason, "cutover_disabled");

  const content = await integration.endpoint.loadContentRef(
    "classification_alpha_content",
  );
  assert.strictEqual(content.contentKey, "classification_alpha_content");

  const exported = await exportClinicalRegistrySeed({
    db: rawDb,
    asOf: new Date("2026-08-30T12:00:00Z"),
  });

  assert.strictEqual(exported.validation.ok, true);
  assert.strictEqual(exported.validation.errors.length, 0);
  assert.strictEqual(exported.seed.identities.length, 1);
  assert.strictEqual(exported.seed.protocols.length, 1);
  assert.strictEqual(exported.seed.actions.length, 2);
  assert.strictEqual(exported.seed.content.length, 1);

  console.log("REMOTE_BUILD6_CONTRACT_TEST=PASS");
  console.log("REMOTE_BUILD6_ASSERTION_GROUPS=10");
}

main().catch((error) => {
  console.error("REMOTE_BUILD6_CONTRACT_TEST=FAIL");
  console.error(error && error.stack ? error.stack : String(error));
  process.exitCode = 1;
});
