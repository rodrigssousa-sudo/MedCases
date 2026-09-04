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

function createClinicalRuntimeIdentityProtocolComposition({
  requestContextBridge,
  protocolLoader,
} = {}) {
  if (
    !requestContextBridge ||
    typeof requestContextBridge.resolve !== "function"
  ) {
    throw new Error("request_context_bridge_required");
  }

  if (
    !protocolLoader ||
    typeof protocolLoader.load !== "function"
  ) {
    throw new Error("protocol_loader_required");
  }

  function resolve(requestLike = {}) {
    const context =
      requestContextBridge.resolve(requestLike);

    if (!context.readyForProtocolLookup) {
      return deepFreeze({
        resolved: false,
        reason: "request_context_not_ready",
        context,
        protocolLookup: null,
        runtimeActivationEnabled: false,
        shadowExecutionEnabled: false,
        realProviderExecutionEnabled: false,
        visibleCutoverEnabled: false,
        cutoverState: "OFF",
      });
    }

    const protocolLookup = protocolLoader.load({
      protocolKey: context.identity?.protocolKey,
      canonicalPathologyKey:
        context.identity?.canonicalPathologyKey,
    });

    return deepFreeze({
      resolved: protocolLookup.resolved === true,
      reason:
        protocolLookup.resolved === true
          ? "identity_protocol_composition_resolved"
          : protocolLookup.reason,
      context,
      protocolLookup,
      runtimeActivationEnabled: false,
      shadowExecutionEnabled: false,
      realProviderExecutionEnabled: false,
      visibleCutoverEnabled: false,
      cutoverState: "OFF",
    });
  }

  return Object.freeze({
    schemaVersion:
      "clinical_runtime_identity_protocol_composition_v1",
    resolve,
    runtimeActivationEnabled: false,
    shadowExecutionEnabled: false,
    realProviderExecutionEnabled: false,
    visibleCutoverEnabled: false,
    cutoverState: "OFF",
  });
}

module.exports = {
  createClinicalRuntimeIdentityProtocolComposition,
};
