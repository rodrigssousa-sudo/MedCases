"use strict";

const {
  evaluateRuntimeSeamGate,
} = require("./clinical_context_runtime_seam_gate");

class ClinicalContextProviderShadowSeamAdapter {
  constructor({
    providerExecutor,
    shadowExecutionEnabled = false,
  } = {}) {
    this.providerExecutor =
      typeof providerExecutor === "function"
        ? providerExecutor
        : null;

    this.shadowExecutionEnabled =
      shadowExecutionEnabled === true;

    this.visibleCutoverEnabled = false;
    this.realProviderExecutionEnabled = false;
  }

  async execute(request) {
    const gate = evaluateRuntimeSeamGate({
      shadowExecutionEnabled: this.shadowExecutionEnabled,
      providerExecutor: this.providerExecutor,
    });

    if (!gate.allowed) {
      return deepFreeze({
        handled: false,
        committed: false,
        status: "blocked",
        disposition: "blocked",
        reason: gate.reason,
        providerExecuted: false,
        visibleCutoverEnabled: false,
        realProviderExecutionEnabled: false,
      });
    }

    let result;

    try {
      result = await this.providerExecutor(
        deepFreeze({
          ...(request || {}),
          __clinicalContextSyntheticOnly: true,
        }),
      );
    } catch (error) {
      throw error;
    }

    return deepFreeze({
      ...(result && typeof result === "object" ? result : {}),
      providerExecuted: true,
      syntheticProviderOnly: true,
      visibleCutoverEnabled: false,
      realProviderExecutionEnabled: false,
    });
  }
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
  ClinicalContextProviderShadowSeamAdapter,
};
