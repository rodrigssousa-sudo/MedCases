"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  ClinicalLegacyCompatibilityAdapter,
} = require("../clinical_context/clinical_legacy_compatibility_adapter");
const {
  COMPATIBILITY_KINDS,
  validateLocalizedPayloadEnvelope,
  resolveLocalizedPayload,
} = require("../clinical_context/clinical_legacy_compatibility_schema");

const seed = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase7_legacy_compatibility.local.json",
    "utf8",
  ),
);

const compatBundle = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_legacy_remote_compatibility.local.json",
    "utf8",
  ),
);

assert.strictEqual(seed.identities.length, 270);
assert.strictEqual(seed.protocols.length, 270);
assert.strictEqual(seed.cutoverReady, false);

assert.strictEqual(compatBundle.classificationEnvelopeCount, 94);
assert.strictEqual(compatBundle.actionsEnvelopeCount, 270);
assert.strictEqual(compatBundle.actionsPtEsNonParityCount, 20);
assert.strictEqual(compatBundle.machineRuleInferencePerformed, false);
assert.strictEqual(
  compatBundle.finalMachineRegistryDocumentsCreated,
  false,
);

let classificationCount = 0;
let actionsCount = 0;

for (const protocol of seed.protocols) {
  const compat = protocol.legacyCompatibility;
  if (!compat) continue;

  if (compat.classification) {
    classificationCount += 1;
    const validation = validateLocalizedPayloadEnvelope(
      compat.classification,
      { expectedKind: COMPATIBILITY_KINDS.classification },
    );
    assert.strictEqual(validation.ok, true);
    assert.strictEqual(
      compat.classification.machineRuleInferencePerformed,
      false,
    );
    assert.strictEqual(
      compat.classification.finalMachineRegistryDocument,
      false,
    );

    assert.strictEqual(
      resolveLocalizedPayload(compat.classification, "pt-BR").ok,
      true,
    );
    assert.strictEqual(
      resolveLocalizedPayload(compat.classification, "es-AR").ok,
      true,
    );
  }

  if (compat.actions) {
    actionsCount += 1;
    const validation = validateLocalizedPayloadEnvelope(
      compat.actions,
      { expectedKind: COMPATIBILITY_KINDS.actions },
    );
    assert.strictEqual(validation.ok, true);
  }
}

assert.strictEqual(classificationCount, 94);
assert.strictEqual(actionsCount, 270);

assert.deepStrictEqual(seed.classifications, []);
assert.deepStrictEqual(seed.managementRules, []);
assert.deepStrictEqual(seed.actions, []);
assert.deepStrictEqual(seed.content, []);

const example = seed.protocols.find(
  (protocol) => protocol.legacyCompatibility?.actions,
);
assert(example);

const adapter = new ClinicalLegacyCompatibilityAdapter({
  protocolLoader: async ({ protocolKey }) =>
    seed.protocols.find((protocol) => protocol.protocolKey === protocolKey),
});

(async () => {
  const resolved = await adapter.load({
    protocolKey: example.protocolKey,
    canonicalPathologyKey: example.canonicalPathologyKey,
    language: "es-AR",
  });

  assert.strictEqual(resolved.handled, true);
  assert(resolved.actions);
  assert.strictEqual(resolved.actions.ok, true);
  assert.strictEqual(resolved.actions.language, "es");

  console.log("BUILD15_CONTRACT_TEST=PASS");
  console.log("BUILD15_ASSERTION_GROUPS=20");
})().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exitCode = 1;
});
