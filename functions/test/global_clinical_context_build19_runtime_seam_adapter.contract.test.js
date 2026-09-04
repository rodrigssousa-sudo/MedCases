"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  evaluateRuntimeSeamGate,
  VISIBLE_CUTOVER_ENABLED,
  REAL_PROVIDER_EXECUTION_ENABLED,
  DEFAULT_SHADOW_EXECUTION_ENABLED,
} = require("../clinical_context/clinical_context_runtime_seam_gate");

const {
  ClinicalContextProviderShadowSeamAdapter,
} = require("../clinical_context/clinical_context_provider_shadow_seam_adapter");

const {
  createClinicalContextRuntimeSeamPreparation,
} = require("../clinical_context/clinical_context_runtime_seam_preparation");

const {
  createSyntheticClinicalProviderStub,
} = require("./fixtures/clinical_context_synthetic_provider_stub");

const seed = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase7_legacy_compatibility.local.json",
    "utf8",
  ),
);

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

const example = seed.protocols.find(
  (protocol) => protocol.legacyCompatibility?.actions,
);
assert(example);

(async () => {
  assert.strictEqual(VISIBLE_CUTOVER_ENABLED, false);
  assert.strictEqual(REAL_PROVIDER_EXECUTION_ENABLED, false);
  assert.strictEqual(DEFAULT_SHADOW_EXECUTION_ENABLED, false);

  // A. Gate default blocks execution.
  let syntheticCalls = 0;
  const syntheticStub = createSyntheticClinicalProviderStub({
    onCall: () => {
      syntheticCalls += 1;
    },
  });

  const defaultGate = evaluateRuntimeSeamGate({
    providerExecutor: syntheticStub,
  });

  assert.strictEqual(defaultGate.allowed, false);
  assert.strictEqual(
    defaultGate.reason,
    "shadow_execution_disabled",
  );

  // B. Unmarked provider executor is blocked even if shadow requested.
  let unmarkedCalls = 0;
  const unmarkedExecutor = async () => {
    unmarkedCalls += 1;
    return {
      handled: true,
      committed: true,
    };
  };

  const unmarkedGate = evaluateRuntimeSeamGate({
    shadowExecutionEnabled: true,
    providerExecutor: unmarkedExecutor,
  });

  assert.strictEqual(unmarkedGate.allowed, false);
  assert.strictEqual(
    unmarkedGate.reason,
    "unmarked_provider_executor_forbidden",
  );

  const unmarkedAdapter =
    new ClinicalContextProviderShadowSeamAdapter({
      providerExecutor: unmarkedExecutor,
      shadowExecutionEnabled: true,
    });

  const unmarkedResult = await unmarkedAdapter.execute({
    synthetic: false,
  });

  assert.strictEqual(unmarkedCalls, 0);
  assert.strictEqual(unmarkedResult.providerExecuted, false);
  assert.strictEqual(
    unmarkedResult.reason,
    "unmarked_provider_executor_forbidden",
  );

  // C. Runtime preparation defaults to OFF and does not call stub.
  const disabledPrep =
    createClinicalContextRuntimeSeamPreparation({
      protocolLoader,
      backendFactory: () => ({
        syntheticBackend: true,
      }),
      providerExecutor: syntheticStub,
    });

  assert.strictEqual(disabledPrep.shadowExecutionEnabled, false);
  assert.strictEqual(disabledPrep.visibleCutoverEnabled, false);
  assert.strictEqual(disabledPrep.realProviderExecutionEnabled, false);
  assert.strictEqual(disabledPrep.runtimeActivationEnabled, false);
  assert.strictEqual(disabledPrep.cutoverState, "OFF");
  assert.strictEqual(
    disabledPrep.visibleDisposition,
    "legacy_unchanged",
  );

  const disabledResult =
    await disabledPrep.compatibilityIntegration.bridge.evaluate({
      protocolKey: example.protocolKey,
      canonicalPathologyKey:
        example.canonicalPathologyKey,
      language: "es-AR",
    });

  assert.strictEqual(syntheticCalls, 0);
  assert.strictEqual(disabledResult.remoteExecuted, false);
  assert.strictEqual(
    disabledResult.visibleDisposition,
    "legacy_unchanged",
  );
  assert.strictEqual(disabledResult.legacy.handled, true);

  // D. Marked synthetic stub can run only when shadow explicitly enabled.
  const enabledPrep =
    createClinicalContextRuntimeSeamPreparation({
      protocolLoader,
      backendFactory: () => ({
        syntheticBackend: true,
      }),
      providerExecutor: syntheticStub,
      shadowExecutionEnabled: true,
    });

  const enabledResult =
    await enabledPrep.compatibilityIntegration.bridge.evaluate({
      protocolKey: example.protocolKey,
      canonicalPathologyKey:
        example.canonicalPathologyKey,
      language: "pt-BR",
    });

  assert.strictEqual(syntheticCalls, 1);
  assert.strictEqual(enabledResult.remoteExecuted, true);
  assert.strictEqual(
    enabledResult.visibleDisposition,
    "legacy_unchanged",
  );
  assert.strictEqual(
    enabledResult.visibleRemoteCutoverEnabled,
    false,
  );
  assert.strictEqual(
    enabledResult.comparison.clinicalEquivalenceClaimed,
    false,
  );
  assert.strictEqual(
    enabledResult.comparison.textEquivalenceClaimed,
    false,
  );

  // E. Synthetic failure remains isolated by the Build16 bridge.
  let throwingCalls = 0;
  const throwingStub = createSyntheticClinicalProviderStub({
    mode: "throw",
    onCall: () => {
      throwingCalls += 1;
    },
  });

  const failurePrep =
    createClinicalContextRuntimeSeamPreparation({
      protocolLoader,
      backendFactory: () => ({
        syntheticBackend: true,
      }),
      providerExecutor: throwingStub,
      shadowExecutionEnabled: true,
    });

  const failureResult =
    await failurePrep.compatibilityIntegration.bridge.evaluate({
      protocolKey: example.protocolKey,
      canonicalPathologyKey:
        example.canonicalPathologyKey,
      language: "es",
    });

  assert.strictEqual(throwingCalls, 1);
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

  // F. Explicit gate with marked stub succeeds.
  const enabledGate = evaluateRuntimeSeamGate({
    shadowExecutionEnabled: true,
    providerExecutor: syntheticStub,
  });

  assert.strictEqual(enabledGate.allowed, true);
  assert.strictEqual(
    enabledGate.reason,
    "synthetic_provider_stub_allowed",
  );
  assert.strictEqual(
    enabledGate.realProviderExecutionEnabled,
    false,
  );
  assert.strictEqual(
    enabledGate.visibleCutoverEnabled,
    false,
  );

  console.log("BUILD19_CONTRACT_TEST=PASS");
  console.log("BUILD19_ASSERTION_GROUPS=34");
  console.log(
    `BUILD19_SYNTHETIC_PROVIDER_CALL_COUNT=${syntheticCalls}`,
  );
  console.log(
    `BUILD19_THROWING_SYNTHETIC_PROVIDER_CALL_COUNT=${throwingCalls}`,
  );
  console.log(
    `BUILD19_UNMARKED_PROVIDER_EXECUTOR_CALL_COUNT=${unmarkedCalls}`,
  );
})().catch((error) => {
  console.error(
    error && error.stack ? error.stack : String(error),
  );
  process.exitCode = 1;
});
