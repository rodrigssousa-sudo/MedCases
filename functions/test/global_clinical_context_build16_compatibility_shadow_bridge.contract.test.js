"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  createClinicalContextCompatibilityIntegration,
} = require("../clinical_context/clinical_context_compatibility_integration");

const seed = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase7_legacy_compatibility.local.json",
    "utf8",
  ),
);

function protocolLoader({ protocolKey, canonicalPathologyKey }) {
  return Promise.resolve(
    seed.protocols.find((protocol) => {
      if (protocolKey && protocol.protocolKey === protocolKey) {
        return true;
      }
      if (
        canonicalPathologyKey &&
        protocol.canonicalPathologyKey === canonicalPathologyKey
      ) {
        return true;
      }
      return false;
    }) || null,
  );
}

const example = seed.protocols.find(
  (protocol) => protocol.legacyCompatibility?.actions,
);
assert(example);

(async () => {
  let remoteCalls = 0;

  const defaultIntegration =
    createClinicalContextCompatibilityIntegration({
      protocolLoader,
      remoteExecutor: async () => {
        remoteCalls += 1;
        return { handled: true, committed: true };
      },
    });

  assert.strictEqual(
    defaultIntegration.shadowExecutionEnabled,
    false,
  );
  assert.strictEqual(
    defaultIntegration.visibleCutoverEnabled,
    false,
  );
  assert.strictEqual(defaultIntegration.cutoverState, "OFF");

  const defaultResult = await defaultIntegration.bridge.evaluate({
    protocolKey: example.protocolKey,
    canonicalPathologyKey: example.canonicalPathologyKey,
    language: "es-AR",
  });

  assert.strictEqual(remoteCalls, 0);
  assert.strictEqual(
    defaultResult.visibleDisposition,
    "legacy_unchanged",
  );
  assert.strictEqual(
    defaultResult.visibleRemoteCutoverEnabled,
    false,
  );
  assert.strictEqual(defaultResult.remoteExecuted, false);
  assert.strictEqual(
    defaultResult.comparison.clinicalEquivalenceClaimed,
    false,
  );

  const successIntegration =
    createClinicalContextCompatibilityIntegration({
      protocolLoader,
      shadowExecutionEnabled: true,
      remoteExecutor: async () => {
        remoteCalls += 1;
        return {
          handled: true,
          committed: true,
          response: {
            actions: [
              {
                kind: "primary",
                actionType: "dispatch_prompt",
              },
            ],
          },
        };
      },
    });

  const successResult = await successIntegration.bridge.evaluate({
    protocolKey: example.protocolKey,
    canonicalPathologyKey: example.canonicalPathologyKey,
    language: "pt-BR",
  });

  assert.strictEqual(successResult.remoteExecuted, true);
  assert.strictEqual(
    successResult.visibleDisposition,
    "legacy_unchanged",
  );
  assert.strictEqual(
    successResult.visibleRemoteCutoverEnabled,
    false,
  );
  assert.strictEqual(
    successResult.comparison.comparisonScope,
    "structural_presence_only",
  );
  assert.strictEqual(
    successResult.comparison.textEquivalenceClaimed,
    false,
  );
  assert.strictEqual(
    successResult.comparison.managementEquivalenceClaimed,
    false,
  );

  const failureIntegration =
    createClinicalContextCompatibilityIntegration({
      protocolLoader,
      shadowExecutionEnabled: true,
      remoteExecutor: async () => {
        throw new Error("synthetic_shadow_failure");
      },
    });

  const failureResult = await failureIntegration.bridge.evaluate({
    protocolKey: example.protocolKey,
    canonicalPathologyKey: example.canonicalPathologyKey,
    language: "es",
  });

  assert.strictEqual(failureResult.remoteExecuted, true);
  assert.strictEqual(
    failureResult.visibleDisposition,
    "legacy_unchanged",
  );
  assert.strictEqual(
    failureResult.remoteShadow.reason,
    "remote_shadow_exception",
  );
  assert(failureResult.remoteError);
  assert.strictEqual(
    failureResult.visibleRemoteCutoverEnabled,
    false,
  );

  assert(failureResult.legacy);
  assert.strictEqual(failureResult.legacy.handled, true);
  assert(failureResult.legacy.actions);
  assert.strictEqual(failureResult.legacy.actions.ok, true);
  assert.strictEqual(failureResult.legacy.actions.language, "es");

  assert(Object.isFrozen(failureResult));
  assert(Object.isFrozen(failureResult.comparison));

  console.log("BUILD16_CONTRACT_TEST=PASS");
  console.log("BUILD16_ASSERTION_GROUPS=24");
  console.log(`BUILD16_SYNTHETIC_REMOTE_CALL_COUNT=${remoteCalls}`);
})().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exitCode = 1;
});
