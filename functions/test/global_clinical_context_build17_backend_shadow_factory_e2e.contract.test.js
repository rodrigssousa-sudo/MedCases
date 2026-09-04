"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  resolveRealBackendFactory,
  createClinicalContextBackendShadowFactory,
} = require("../clinical_context/clinical_context_backend_shadow_factory");

const seed = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase7_legacy_compatibility.local.json",
    "utf8",
  ),
);

const discovered = resolveRealBackendFactory();

assert(discovered);
assert.strictEqual(typeof discovered.factory, "function");
assert(discovered.name);

function protocolLoader({
  protocolKey,
  canonicalPathologyKey,
}) {
  return Promise.resolve(
    seed.protocols.find((protocol) => (
      (protocolKey && protocol.protocolKey === protocolKey) ||
      (
        canonicalPathologyKey &&
        protocol.canonicalPathologyKey === canonicalPathologyKey
      )
    )) || null,
  );
}

const withClassification = seed.protocols.find(
  (protocol) => (
    protocol.legacyCompatibility?.classification &&
    protocol.legacyCompatibility?.actions
  ),
);

const actionsOnly = seed.protocols.find(
  (protocol) => (
    !protocol.legacyCompatibility?.classification &&
    protocol.legacyCompatibility?.actions
  ),
);

assert(withClassification);
assert(actionsOnly);

(async () => {
  let syntheticBackendFactoryCalls = 0;
  let syntheticRemoteCalls = 0;

  const syntheticBackendFactory = () => {
    syntheticBackendFactoryCalls += 1;
    return Object.freeze({
      synthetic: true,
      source: "build17",
    });
  };

  // A. Factory creation is inert. It must not instantiate backend runtime.
  const disabled = createClinicalContextBackendShadowFactory({
    protocolLoader,
    backendFactory: syntheticBackendFactory,
    remoteExecutor: async () => {
      syntheticRemoteCalls += 1;
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

  assert.strictEqual(syntheticBackendFactoryCalls, 0);
  assert.strictEqual(syntheticRemoteCalls, 0);
  assert.strictEqual(disabled.shadowExecutionEnabled, false);
  assert.strictEqual(disabled.visibleCutoverEnabled, false);
  assert.strictEqual(disabled.cutoverState, "OFF");
  assert.strictEqual(
    disabled.visibleDisposition,
    "legacy_unchanged",
  );

  // Explicit factory invocation remains local/synthetic and separate.
  const syntheticBackend = disabled.createBackendIntegration();
  assert.strictEqual(syntheticBackend.synthetic, true);
  assert.strictEqual(syntheticBackendFactoryCalls, 1);

  // B. Shadow disabled: no remote execution, exact legacy payload retained.
  const disabledResult =
    await disabled.compatibilityIntegration.bridge.evaluate({
      protocolKey: withClassification.protocolKey,
      canonicalPathologyKey:
        withClassification.canonicalPathologyKey,
      language: "es-AR",
      remoteRequest: {
        mode: "plantao",
        prompt: "synthetic only",
      },
    });

  assert.strictEqual(syntheticRemoteCalls, 0);
  assert.strictEqual(disabledResult.remoteExecuted, false);
  assert.strictEqual(
    disabledResult.visibleDisposition,
    "legacy_unchanged",
  );
  assert.strictEqual(
    disabledResult.visibleRemoteCutoverEnabled,
    false,
  );
  assert.strictEqual(disabledResult.legacy.handled, true);
  assert.strictEqual(
    disabledResult.legacy.classification.language,
    "es",
  );
  assert.strictEqual(
    disabledResult.legacy.actions.language,
    "es",
  );

  // C. Shadow enabled success: remote may execute, never becomes visible.
  const success = createClinicalContextBackendShadowFactory({
    protocolLoader,
    backendFactory: syntheticBackendFactory,
    shadowExecutionEnabled: true,
    remoteExecutor: async ({ canonicalPathologyKey }) => {
      syntheticRemoteCalls += 1;

      return {
        handled: true,
        committed: true,
        response: {
          schemaVersion: "clinical_response_v1",
          finalText: "SYNTHETIC_REMOTE_HIDDEN",
          actions: [
            {
              kind: "primary",
              actionType: "dispatch_prompt",
            },
            ...(canonicalPathologyKey ===
              withClassification.canonicalPathologyKey
              ? [
                  {
                    kind: "classification",
                    actionType: "open_content_ref",
                    contentRef: "synthetic://classification",
                  },
                ]
              : []),
          ],
        },
      };
    },
  });

  const successWithClassification =
    await success.compatibilityIntegration.bridge.evaluate({
      protocolKey: withClassification.protocolKey,
      canonicalPathologyKey:
        withClassification.canonicalPathologyKey,
      language: "pt-BR",
    });

  assert.strictEqual(successWithClassification.remoteExecuted, true);
  assert.strictEqual(
    successWithClassification.visibleDisposition,
    "legacy_unchanged",
  );
  assert.strictEqual(
    successWithClassification.visibleRemoteCutoverEnabled,
    false,
  );
  assert.strictEqual(
    successWithClassification.comparison
      .structuralMismatches.length,
    0,
  );
  assert.strictEqual(
    successWithClassification.comparison
      .clinicalEquivalenceClaimed,
    false,
  );
  assert.strictEqual(
    successWithClassification.comparison
      .textEquivalenceClaimed,
    false,
  );

  const successActionsOnly =
    await success.compatibilityIntegration.bridge.evaluate({
      protocolKey: actionsOnly.protocolKey,
      canonicalPathologyKey: actionsOnly.canonicalPathologyKey,
      language: "es",
    });

  assert.strictEqual(successActionsOnly.remoteExecuted, true);
  assert.strictEqual(
    successActionsOnly.visibleDisposition,
    "legacy_unchanged",
  );
  assert.strictEqual(
    successActionsOnly.legacy.classification,
    null,
  );
  assert(successActionsOnly.legacy.actions);

  // D. Shadow failure: legacy remains intact.
  const failure = createClinicalContextBackendShadowFactory({
    protocolLoader,
    backendFactory: syntheticBackendFactory,
    shadowExecutionEnabled: true,
    remoteExecutor: async () => {
      syntheticRemoteCalls += 1;
      throw new Error("synthetic_e2e_shadow_failure");
    },
  });

  const failureResult =
    await failure.compatibilityIntegration.bridge.evaluate({
      protocolKey: withClassification.protocolKey,
      canonicalPathologyKey:
        withClassification.canonicalPathologyKey,
      language: "pt",
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
  assert.strictEqual(failureResult.legacy.handled, true);
  assert(failureResult.legacy.classification);
  assert(failureResult.legacy.actions);

  // E. Frozen result: no post-evaluation replacement.
  assert(Object.isFrozen(failureResult));
  assert(Object.isFrozen(failureResult.comparison));

  console.log("BUILD17_CONTRACT_TEST=PASS");
  console.log("BUILD17_ASSERTION_GROUPS=30");
  console.log(
    `BUILD17_SYNTHETIC_BACKEND_FACTORY_CALL_COUNT=${syntheticBackendFactoryCalls}`,
  );
  console.log(
    `BUILD17_SYNTHETIC_REMOTE_CALL_COUNT=${syntheticRemoteCalls}`,
  );
  console.log(
    `BUILD17_REAL_BACKEND_FACTORY_DISCOVERED=${discovered.name}`,
  );
})().catch((error) => {
  console.error(
    error && error.stack ? error.stack : String(error),
  );
  process.exitCode = 1;
});
