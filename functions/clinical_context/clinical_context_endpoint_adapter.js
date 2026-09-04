"use strict";

const {
  ClinicalContextOrchestrator,
} = require("./clinical_context_orchestrator");

class ClinicalContextEndpointAdapter {
  constructor({
    registryLoader,
    actionLoader,
    contentLoader,
    orchestrator = new ClinicalContextOrchestrator(),
    cutoverGate,
  } = {}) {
    requireFunction(registryLoader, "registry_loader_required");
    requireFunction(actionLoader, "action_loader_required");
    requireFunction(contentLoader, "content_loader_required");
    if (!cutoverGate || typeof cutoverGate.evaluate !== "function") {
      throw new Error("cutover_gate_required");
    }

    this.registryLoader = registryLoader;
    this.actionLoader = actionLoader;
    this.contentLoader = contentLoader;
    this.orchestrator = orchestrator;
    this.cutoverGate = cutoverGate;
  }

  async handle({
    mode,
    userId = "",
    requestKey = "",
    request,
    providerAdapter,
    validatorAdapter,
    repairAdapter = null,
  }) {
    const gate = this.cutoverGate.evaluate({
      mode,
      userId,
      requestKey,
    });

    if (!gate.allowed) {
      return Object.freeze({
        handled: false,
        reason: gate.reason,
        bucket: gate.bucket,
      });
    }

    requireFunction(providerAdapter, "provider_adapter_required");
    requireFunction(validatorAdapter, "validator_adapter_required");

    const [registrySnapshot, actionDefinitions] = await Promise.all([
      this.registryLoader(),
      this.actionLoader(),
    ]);

    const result = await this.orchestrator.execute({
      ...request,
      registrySnapshot,
      actionDefinitions,
      generateResponse: providerAdapter,
      validateResponse: validatorAdapter,
      repairResponse: repairAdapter,
    });

    return Object.freeze({
      handled: true,
      result,
    });
  }

  async loadContentRef(contentRef) {
    const ref = String(contentRef || "").trim();
    if (!ref) return null;
    return this.contentLoader(ref);
  }
}

function requireFunction(value, code) {
  if (typeof value !== "function") throw new Error(code);
}

module.exports = {
  ClinicalContextEndpointAdapter,
};
