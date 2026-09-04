"use strict";

const {
  ClinicalLegacyCompatibilityAdapter,
} = require("./clinical_legacy_compatibility_adapter");
const {
  ClinicalContextEndpointCompatibilityShadowBridge,
} = require("./clinical_context_endpoint_compatibility_shadow_bridge");

function createClinicalContextCompatibilityIntegration({
  protocolLoader,
  remoteEndpointAdapter,
  remoteExecutor,
  shadowExecutionEnabled = false,
} = {}) {
  if (typeof protocolLoader !== "function") {
    throw new Error("protocol_loader_required");
  }

  const legacyCompatibilityAdapter =
    new ClinicalLegacyCompatibilityAdapter({
      protocolLoader,
    });

  const resolvedRemoteExecutor =
    typeof remoteExecutor === "function"
      ? remoteExecutor
      : createEndpointExecutor(remoteEndpointAdapter);

  const bridge =
    new ClinicalContextEndpointCompatibilityShadowBridge({
      legacyCompatibilityAdapter,
      remoteExecutor: resolvedRemoteExecutor,
      shadowExecutionEnabled,
    });

  return Object.freeze({
    legacyCompatibilityAdapter,
    bridge,
    shadowExecutionEnabled: shadowExecutionEnabled === true,
    visibleCutoverEnabled: false,
    cutoverState: "OFF",
  });
}

function createEndpointExecutor(remoteEndpointAdapter) {
  if (!remoteEndpointAdapter || typeof remoteEndpointAdapter !== "object") {
    return null;
  }

  for (const method of ["handle", "execute", "resolve", "run"]) {
    if (typeof remoteEndpointAdapter[method] === "function") {
      return (request) => remoteEndpointAdapter[method](request);
    }
  }

  return null;
}

module.exports = {
  createClinicalContextCompatibilityIntegration,
  createEndpointExecutor,
};
