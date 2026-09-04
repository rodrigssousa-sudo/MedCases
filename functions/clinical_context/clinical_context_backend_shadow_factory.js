"use strict";

const backendIntegrationModule =
  require("./clinical_context_backend_integration");

const {
  createClinicalContextCompatibilityIntegration,
} = require("./clinical_context_compatibility_integration");

const REAL_BACKEND_FACTORY_CANDIDATE_NAMES = Object.freeze([
  "createClinicalContextBackendIntegration",
  "createClinicalContextIntegration",
  "createBackendIntegration",
  "createClinicalBackendIntegration",
]);

function resolveRealBackendFactory(moduleExports = backendIntegrationModule) {
  for (const name of REAL_BACKEND_FACTORY_CANDIDATE_NAMES) {
    if (typeof moduleExports[name] === "function") {
      return Object.freeze({
        name,
        factory: moduleExports[name],
        resolution: "canonical_candidate_name",
      });
    }
  }

  const genericCandidates = Object.entries(moduleExports)
    .filter(([name, value]) => (
      typeof value === "function" &&
      /create|factory|integration/i.test(name)
    ))
    .sort(([a], [b]) => a.localeCompare(b));

  if (genericCandidates.length === 1) {
    const [name, factory] = genericCandidates[0];
    return Object.freeze({
      name,
      factory,
      resolution: "single_generic_factory_candidate",
    });
  }

  return Object.freeze({
    name: null,
    factory: null,
    resolution: genericCandidates.length === 0
      ? "no_factory_candidate"
      : "ambiguous_generic_factory_candidates",
    candidateNames: Object.freeze(
      genericCandidates.map(([name]) => name),
    ),
  });
}

function createClinicalContextBackendShadowFactory({
  protocolLoader,
  backendFactory,
  backendFactoryOptions,
  remoteExecutor,
  remoteEndpointAdapter,
  shadowExecutionEnabled = false,
} = {}) {
  if (typeof protocolLoader !== "function") {
    throw new Error("protocol_loader_required");
  }

  const discovered = resolveRealBackendFactory();
  const selectedBackendFactory = typeof backendFactory === "function"
    ? backendFactory
    : discovered.factory;

  if (typeof selectedBackendFactory !== "function") {
    throw new Error(
      `backend_factory_unavailable:${discovered.resolution}`,
    );
  }

  // Inert by design:
  // The real backend integration is only instantiated if the caller
  // explicitly invokes createBackendIntegration(). Build 17 never calls it
  // automatically and never changes an existing exported runtime path.
  function createBackendIntegration() {
    return selectedBackendFactory({
      ...(backendFactoryOptions || {}),
    });
  }

  const compatibilityIntegration =
    createClinicalContextCompatibilityIntegration({
      protocolLoader,
      remoteExecutor,
      remoteEndpointAdapter,
      shadowExecutionEnabled,
    });

  return Object.freeze({
    schemaVersion: "clinical_context_backend_shadow_factory_v1",
    backendFactoryReference: Object.freeze({
      name: typeof backendFactory === "function"
        ? "injected_backend_factory"
        : discovered.name,
      resolution: typeof backendFactory === "function"
        ? "explicit_injection"
        : discovered.resolution,
    }),
    createBackendIntegration,
    compatibilityIntegration,
    shadowExecutionEnabled: shadowExecutionEnabled === true,
    visibleCutoverEnabled: false,
    cutoverState: "OFF",
    visibleDisposition: "legacy_unchanged",
  });
}

module.exports = {
  REAL_BACKEND_FACTORY_CANDIDATE_NAMES,
  resolveRealBackendFactory,
  createClinicalContextBackendShadowFactory,
};
