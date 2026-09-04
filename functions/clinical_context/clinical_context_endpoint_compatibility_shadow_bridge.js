"use strict";

const {
  compareCompatibilityShadow,
} = require("./clinical_context_compatibility_shadow_comparator");

const VISIBLE_DISPOSITION = "legacy_unchanged";

class ClinicalContextEndpointCompatibilityShadowBridge {
  constructor({
    legacyCompatibilityAdapter,
    remoteExecutor,
    shadowExecutionEnabled = false,
  } = {}) {
    if (
      !legacyCompatibilityAdapter ||
      typeof legacyCompatibilityAdapter.load !== "function"
    ) {
      throw new Error("legacy_compatibility_adapter_required");
    }

    if (
      remoteExecutor != null &&
      typeof remoteExecutor !== "function"
    ) {
      throw new Error("remote_executor_must_be_function");
    }

    this.legacyCompatibilityAdapter = legacyCompatibilityAdapter;
    this.remoteExecutor = remoteExecutor || null;
    this.shadowExecutionEnabled = shadowExecutionEnabled === true;

    this.visibleCutoverEnabled = false;
  }

  async evaluate({
    protocolKey,
    canonicalPathologyKey,
    language,
    remoteRequest,
  } = {}) {
    const legacy = await this.legacyCompatibilityAdapter.load({
      protocolKey,
      canonicalPathologyKey,
      language,
    });

    let remote = Object.freeze({
      handled: false,
      reason: this.shadowExecutionEnabled
        ? "remote_executor_missing"
        : "shadow_execution_disabled",
    });

    let remoteError = null;
    let remoteExecuted = false;

    if (
      this.shadowExecutionEnabled &&
      typeof this.remoteExecutor === "function"
    ) {
      remoteExecuted = true;

      try {
        const result = await this.remoteExecutor(
          Object.freeze({
            ...(remoteRequest || {}),
            protocolKey,
            canonicalPathologyKey,
            language,
          }),
        );

        remote = result && typeof result === "object"
          ? result
          : Object.freeze({
              handled: false,
              reason: "remote_executor_invalid_result",
            });
      } catch (error) {
        remoteError = Object.freeze({
          name: String(error && error.name || "Error"),
          message: String(error && error.message || error || "unknown_error"),
        });

        remote = Object.freeze({
          handled: false,
          reason: "remote_shadow_exception",
        });
      }
    }

    const comparison = compareCompatibilityShadow({
      legacy,
      remote,
      language,
    });

    return deepFreeze({
      schemaVersion: "clinical_context_endpoint_compatibility_shadow_v1",
      mode: "shadow_only",
      visibleDisposition: VISIBLE_DISPOSITION,
      visibleRemoteCutoverEnabled: false,
      remoteExecuted,
      legacy,
      remoteShadow: remote,
      remoteError,
      comparison,
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
  VISIBLE_DISPOSITION,
  ClinicalContextEndpointCompatibilityShadowBridge,
};
