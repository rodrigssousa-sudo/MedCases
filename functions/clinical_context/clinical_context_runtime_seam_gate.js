"use strict";

const RUNTIME_SEAM_SCHEMA_VERSION =
  "clinical_context_runtime_seam_gate_v1";

const VISIBLE_CUTOVER_ENABLED = false;
const REAL_PROVIDER_EXECUTION_ENABLED = false;
const DEFAULT_SHADOW_EXECUTION_ENABLED = false;

function evaluateRuntimeSeamGate({
  shadowExecutionEnabled = DEFAULT_SHADOW_EXECUTION_ENABLED,
  providerExecutor,
} = {}) {
  const executorPresent = typeof providerExecutor === "function";
  const syntheticMarked = Boolean(
    executorPresent &&
    providerExecutor.__clinicalContextSyntheticProviderStub === true,
  );

  if (!shadowExecutionEnabled) {
    return Object.freeze({
      allowed: false,
      reason: "shadow_execution_disabled",
      visibleCutoverEnabled: VISIBLE_CUTOVER_ENABLED,
      realProviderExecutionEnabled: REAL_PROVIDER_EXECUTION_ENABLED,
      syntheticMarked,
    });
  }

  if (!executorPresent) {
    return Object.freeze({
      allowed: false,
      reason: "provider_executor_missing",
      visibleCutoverEnabled: VISIBLE_CUTOVER_ENABLED,
      realProviderExecutionEnabled: REAL_PROVIDER_EXECUTION_ENABLED,
      syntheticMarked,
    });
  }

  if (!syntheticMarked) {
    return Object.freeze({
      allowed: false,
      reason: "unmarked_provider_executor_forbidden",
      visibleCutoverEnabled: VISIBLE_CUTOVER_ENABLED,
      realProviderExecutionEnabled: REAL_PROVIDER_EXECUTION_ENABLED,
      syntheticMarked,
    });
  }

  return Object.freeze({
    allowed: true,
    reason: "synthetic_provider_stub_allowed",
    visibleCutoverEnabled: VISIBLE_CUTOVER_ENABLED,
    realProviderExecutionEnabled: REAL_PROVIDER_EXECUTION_ENABLED,
    syntheticMarked,
  });
}

module.exports = {
  RUNTIME_SEAM_SCHEMA_VERSION,
  VISIBLE_CUTOVER_ENABLED,
  REAL_PROVIDER_EXECUTION_ENABLED,
  DEFAULT_SHADOW_EXECUTION_ENABLED,
  evaluateRuntimeSeamGate,
};
