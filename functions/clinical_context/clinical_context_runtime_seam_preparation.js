"use strict";

const {
  createClinicalContextBackendShadowFactory,
} = require("./clinical_context_backend_shadow_factory");

const {
  ClinicalContextProviderShadowSeamAdapter,
} = require("./clinical_context_provider_shadow_seam_adapter");

function createClinicalContextRuntimeSeamPreparation({
  protocolLoader,
  backendFactory,
  backendFactoryOptions,
  providerExecutor,
  shadowExecutionEnabled = false,
} = {}) {
  if (typeof protocolLoader !== "function") {
    throw new Error("protocol_loader_required");
  }

  const providerShadowSeam =
    new ClinicalContextProviderShadowSeamAdapter({
      providerExecutor,
      shadowExecutionEnabled,
    });

  const backendShadowFactory =
    createClinicalContextBackendShadowFactory({
      protocolLoader,
      backendFactory,
      backendFactoryOptions,
      shadowExecutionEnabled,
      remoteExecutor: (request) =>
        providerShadowSeam.execute(request),
    });

  return Object.freeze({
    schemaVersion:
      "clinical_context_runtime_seam_preparation_v1",
    providerShadowSeam,
    backendShadowFactory,
    compatibilityIntegration:
      backendShadowFactory.compatibilityIntegration,
    shadowExecutionEnabled:
      shadowExecutionEnabled === true,
    visibleCutoverEnabled: false,
    realProviderExecutionEnabled: false,
    runtimeActivationEnabled: false,
    cutoverState: "OFF",
    visibleDisposition: "legacy_unchanged",
  });
}

module.exports = {
  createClinicalContextRuntimeSeamPreparation,
};
