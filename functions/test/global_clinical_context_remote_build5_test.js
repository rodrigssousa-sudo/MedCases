"use strict";

const assert = require("assert");

const {
  validateRegistrySeed,
} = require("../clinical_context/clinical_registry_seed_validator");
const {
  ClinicalContextCutoverGate,
} = require("../clinical_context/clinical_context_cutover_gate");
const {
  ClinicalContextEndpointAdapter,
} = require("../clinical_context/clinical_context_endpoint_adapter");

async function main() {
  const seed = {
    identities: [
      {
        canonicalKey: "condition_alpha",
        enabled: true,
        priority: 100,
        version: "1",
        aliases: ["condition alpha"],
      },
    ],
    protocols: [
      {
        protocolKey: "protocol_alpha",
        canonicalPathologyKey: "condition_alpha",
        enabled: true,
        priority: 100,
        version: "1",
      },
    ],
    classifications: [
      {
        classificationKey: "severity_alpha",
        canonicalPathologyKey: "condition_alpha",
        mode: "categorical",
        enabled: true,
        priority: 100,
        version: "1",
      },
    ],
    managementRules: [
      {
        managementRuleKey: "management_alpha",
        canonicalPathologyKey: "condition_alpha",
        enabled: true,
        priority: 100,
        version: "1",
        dependsOn: {
          classificationKey: "severity_alpha",
        },
      },
    ],
    actions: [
      {
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
      {
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
    ],
    content: [
      {
        contentKey: "classification_alpha_content",
        enabled: true,
        version: "1",
        sections: [],
      },
    ],
  };

  const validation = validateRegistrySeed(seed);
  assert.strictEqual(validation.ok, true);
  assert.strictEqual(validation.errors.length, 0);
  assert.strictEqual(validation.counts.identities, 1);
  assert.strictEqual(validation.counts.content, 1);

  const invalid = JSON.parse(JSON.stringify(seed));
  invalid.actions[1].contentRef = "missing_content";

  const invalidValidation = validateRegistrySeed(invalid);
  assert.strictEqual(invalidValidation.ok, false);
  assert(
    invalidValidation.errors.includes(
      "action_unknown_content_ref:missing_content",
    ),
  );

  const offGate = new ClinicalContextCutoverGate();
  assert.strictEqual(
    offGate.evaluate({
      mode: "plantao",
      userId: "u1",
      requestKey: "r1",
    }).allowed,
    false,
  );

  const allowlistGate = new ClinicalContextCutoverGate({
    enabled: true,
    allowedModes: ["plantao"],
    allowedUserIds: ["u1"],
    allowedPercent: 0,
  });

  assert.strictEqual(
    allowlistGate.evaluate({
      mode: "plantao",
      userId: "u1",
      requestKey: "r1",
    }).allowed,
    true,
  );

  assert.strictEqual(
    allowlistGate.evaluate({
      mode: "estudo",
      userId: "u1",
      requestKey: "r1",
    }).allowed,
    false,
  );

  let providerCalls = 0;

  const deniedEndpoint = new ClinicalContextEndpointAdapter({
    registryLoader: async () => ({
      identities: [],
      protocols: [],
      classifications: [],
      managementRules: [],
    }),
    actionLoader: async () => [],
    contentLoader: async () => null,
    cutoverGate: offGate,
  });

  const denied = await deniedEndpoint.handle({
    mode: "plantao",
    userId: "u1",
    requestKey: "r1",
    request: {},
    providerAdapter: async () => {
      providerCalls += 1;
      return "should not run";
    },
    validatorAdapter: async () => ({ ok: true }),
  });

  assert.strictEqual(denied.handled, false);
  assert.strictEqual(providerCalls, 0);

  const contentEndpoint = new ClinicalContextEndpointAdapter({
    registryLoader: async () => ({
      identities: [],
      protocols: [],
      classifications: [],
      managementRules: [],
    }),
    actionLoader: async () => [],
    contentLoader: async (ref) => (
      ref === "classification_alpha_content"
        ? { sections: [{ title: "Remote", rows: [] }] }
        : null
    ),
    cutoverGate: offGate,
  });

  const content = await contentEndpoint.loadContentRef(
    "classification_alpha_content",
  );
  assert.strictEqual(content.sections[0].title, "Remote");

  console.log("REMOTE_BUILD5_CONTRACT_TEST=PASS");
  console.log("REMOTE_BUILD5_ASSERTION_GROUPS=9");
}

main().catch((error) => {
  console.error("REMOTE_BUILD5_CONTRACT_TEST=FAIL");
  console.error(error && error.stack ? error.stack : String(error));
  process.exitCode = 1;
});
