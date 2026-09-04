"use strict";

function deepFreeze(value) {
  if (!value || typeof value !== "object" || Object.isFrozen(value)) {
    return value;
  }
  Object.freeze(value);
  for (const child of Object.values(value)) {
    deepFreeze(child);
  }
  return value;
}

function normalizeString(value) {
  return typeof value === "string" && value.trim()
    ? value.trim()
    : null;
}

function createShadowObservationCanaryRuntime({
  shadowObservationEnabled = false,
  providerExecutionEnabled = false,
  firebaseReadEnabled = false,
  sampler = null,
  observer = null,
} = {}) {
  if (shadowObservationEnabled !== false) {
    throw new Error(
      "shadow_observation_activation_not_authorized",
    );
  }

  if (providerExecutionEnabled !== false) {
    throw new Error(
      "shadow_provider_execution_not_authorized",
    );
  }

  if (firebaseReadEnabled !== false) {
    throw new Error(
      "shadow_firebase_read_not_authorized",
    );
  }

  function shouldSample(context = {}) {
    if (!shadowObservationEnabled) {
      return false;
    }

    if (typeof sampler !== "function") {
      return false;
    }

    return sampler({
      requestId:
        normalizeString(context.requestId),
      protocolKey:
        normalizeString(context.protocolKey),
      canonicalPathologyKey:
        normalizeString(
          context.canonicalPathologyKey,
        ),
    }) === true;
  }

  function sanitizeObservation(input = {}) {
    return deepFreeze({
      requestIdHash:
        normalizeString(input.requestIdHash),
      protocolKey:
        normalizeString(input.protocolKey),
      canonicalPathologyKey:
        normalizeString(
          input.canonicalPathologyKey,
        ),
      identityResolved:
        input.identityResolved === true,
      protocolResolved:
        input.protocolResolved === true,
      machineActionReady:
        input.machineActionReady === true,
      machineContentReady:
        input.machineContentReady === true,
      identityMismatch:
        input.identityMismatch === true,
      protocolMismatch:
        input.protocolMismatch === true,
      missingMachineAction:
        input.missingMachineAction === true,
      missingMachineContent:
        input.missingMachineContent === true,
      errorCode:
        normalizeString(input.errorCode),
    });
  }

  function observe(context = {}) {
    if (!shadowObservationEnabled) {
      return deepFreeze({
        observed: false,
        reason: "shadow_observation_disabled",
        providerCalls: 0,
        firebaseReads: 0,
        visibleMutation: false,
      });
    }

    if (!shouldSample(context)) {
      return deepFreeze({
        observed: false,
        reason: "not_sampled",
        providerCalls: 0,
        firebaseReads: 0,
        visibleMutation: false,
      });
    }

    if (typeof observer !== "function") {
      return deepFreeze({
        observed: false,
        reason: "observer_missing",
        providerCalls: 0,
        firebaseReads: 0,
        visibleMutation: false,
      });
    }

    const sanitized =
      sanitizeObservation(observer(context));

    return deepFreeze({
      observed: true,
      reason: "observation_recorded",
      observation: sanitized,
      providerCalls: 0,
      firebaseReads: 0,
      visibleMutation: false,
    });
  }

  return Object.freeze({
    schemaVersion:
      "clinical_shadow_observation_canary_runtime_v1",
    shadowObservationEnabled: false,
    providerExecutionEnabled: false,
    firebaseReadEnabled: false,
    visibleCutoverEnabled: false,
    observe,
    sanitizeObservation,
  });
}

module.exports = {
  createShadowObservationCanaryRuntime,
};
