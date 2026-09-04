"use strict";

const {
  ClinicalCaseIdentityResolver,
} = require("./clinical_case_identity_resolver");
const {
  ClinicalProtocolMatcher,
} = require("./clinical_protocol_matcher");
const {
  ClinicalClassificationResolver,
} = require("./clinical_classification_resolver");
const {
  ClinicalManagementDependencyResolver,
} = require("./clinical_management_dependency_resolver");
const {
  ClinicalNextActionEngine,
} = require("./clinical_next_action_engine");
const {
  createStructuredClinicalResponse,
  createWaitingForFactsResponse,
} = require("./structured_clinical_response_contract");
const {
  ClinicalResponseFinalizer,
} = require("./clinical_response_finalizer");

/**
 * End-to-end clinical context orchestrator.
 *
 * All clinical variation is supplied as remote registry data. This executable
 * code remains pathology-agnostic.
 *
 * Provider generation is injected and buffered internally. No partial provider
 * output is exposed by this class.
 */
class ClinicalContextOrchestrator {
  constructor({
    identityResolver = new ClinicalCaseIdentityResolver(),
    protocolMatcher = new ClinicalProtocolMatcher(),
    classificationResolver = new ClinicalClassificationResolver(),
    managementResolver = new ClinicalManagementDependencyResolver(),
    nextActionEngine = new ClinicalNextActionEngine(),
  } = {}) {
    this.identityResolver = identityResolver;
    this.protocolMatcher = protocolMatcher;
    this.classificationResolver = classificationResolver;
    this.managementResolver = managementResolver;
    this.nextActionEngine = nextActionEngine;
  }

  async execute({
    input,
    activeCaseAnchor = "",
    patientFacts = {},
    language = "es",
    clinicalPhase = "",
    userIntent = "",
    registrySnapshot,
    actionDefinitions = [],
    generateResponse,
    validateResponse,
    repairResponse = null,
    provenance = {},
  }) {
    requireFunction(generateResponse, "generate_response_adapter_required");
    requireFunction(validateResponse, "validate_response_adapter_required");

    const identities = registrySnapshot?.identities || [];
    const protocols = registrySnapshot?.protocols || [];
    const classifications = registrySnapshot?.classifications || [];
    const managementRules = registrySnapshot?.managementRules || [];

    const identity = this.identityResolver.resolve({
      input,
      descriptors: identities,
      activeCaseAnchor,
    });

    if (identity.ambiguous) {
      return freezeState({
        status: "identity_ambiguous",
        identity,
        protocol: null,
        classification: null,
        management: null,
        actions: emptyActions("identity_ambiguous"),
        response: null,
      });
    }

    if (!identity.canonicalKey) {
      return freezeState({
        status: "identity_unresolved",
        identity,
        protocol: null,
        classification: null,
        management: null,
        actions: emptyActions("identity_unresolved"),
        response: null,
      });
    }

    const protocol = this.protocolMatcher.match({
      input,
      identities,
      protocols,
      activeCaseAnchor,
    });

    if (!protocol.found) {
      return freezeState({
        status: protocol.ambiguous
          ? "protocol_ambiguous"
          : "protocol_unresolved",
        identity,
        protocol,
        classification: null,
        management: null,
        actions: emptyActions(protocol.reason),
        response: null,
      });
    }

    const classification = this.classificationResolver.resolve({
      pathologyKey: identity.canonicalKey,
      descriptors: classifications,
      patientFacts,
    });

    const management = this.managementResolver.resolve({
      pathologyKey: identity.canonicalKey,
      classificationResult: classification,
      managementRules,
    });

    const actions = this.nextActionEngine.resolve({
      pathologyKey: identity.canonicalKey,
      protocolKey: String(protocol.protocol?.protocolKey || ""),
      managementResult: management,
      classificationResult: classification,
      actions: actionDefinitions,
      language,
      clinicalPhase,
      userIntent,
    });

    if (
      management.requiresClassification === true &&
      management.resolved !== true
    ) {
      const response = createWaitingForFactsResponse({
        identityResult: identity,
        protocolResult: protocol,
        classificationResult: classification,
        managementResult: management,
        actionResult: actions,
        language,
        provenance,
      });

      return freezeState({
        status: "waiting_for_facts",
        identity,
        protocol,
        classification,
        management,
        actions,
        response,
      });
    }

    const generationContext = deepFreeze({
      input: String(input || ""),
      language: String(language || "es"),
      activeCaseAnchor: String(activeCaseAnchor || ""),
      patientFacts: clonePlain(patientFacts),
      identity: clonePlain(identity),
      protocol: clonePlain(protocol),
      classification: clonePlain(classification),
      management: clonePlain(management),
      actions: clonePlain(actions),
    });

    const generatedText = await collectGeneration({
      generateResponse,
      context: generationContext,
    });

    const finalizer = new ClinicalResponseFinalizer({
      validator: validateResponse,
      repairer: repairResponse,
    });

    const finalized = await finalizer.finalize({
      generatedText,
      context: generationContext,
    });

    if (!finalized.ok) {
      return freezeState({
        status: "response_not_committed",
        identity,
        protocol,
        classification,
        management,
        actions,
        response: null,
        finalization: finalized,
      });
    }

    const response = createStructuredClinicalResponse({
      text: finalized.text,
      identityResult: identity,
      protocolResult: protocol,
      classificationResult: classification,
      managementResult: management,
      actionResult: actions,
      language,
      provenance,
    });

    return freezeState({
      status: "ready",
      identity,
      protocol,
      classification,
      management,
      actions,
      response,
      finalization: finalized,
    });
  }
}

async function collectGeneration({
  generateResponse,
  context,
}) {
  const value = await generateResponse({ context });

  if (typeof value === "string") {
    return value;
  }

  if (value && typeof value.text === "string") {
    return value.text;
  }

  if (value && value[Symbol.asyncIterator]) {
    let buffer = "";
    for await (const chunk of value) {
      if (typeof chunk === "string") {
        buffer += chunk;
      } else if (chunk && typeof chunk.text === "string") {
        buffer += chunk.text;
      }
    }
    return buffer;
  }

  throw new Error("unsupported_generation_adapter_result");
}

function freezeState(value) {
  return deepFreeze({
    schemaVersion: "clinical_context_orchestrator_v1",
    ...value,
  });
}

function emptyActions(reason) {
  return {
    primaryAction: null,
    classificationAction: null,
    ambiguous: false,
    reason,
  };
}

function requireFunction(value, code) {
  if (typeof value !== "function") throw new Error(code);
}

function clonePlain(value) {
  if (Array.isArray(value)) return value.map(clonePlain);
  if (!value || typeof value !== "object") return value;
  const out = {};
  for (const [key, child] of Object.entries(value)) {
    out[key] = clonePlain(child);
  }
  return out;
}

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

module.exports = {
  ClinicalContextOrchestrator,
  collectClinicalGenerationToBuffer: collectGeneration,
};
