"use strict";

const {
  COMPATIBILITY_KINDS,
  validateLocalizedPayloadEnvelope,
  resolveLocalizedPayload,
} = require("./clinical_legacy_compatibility_schema");

class ClinicalLegacyCompatibilityAdapter {
  constructor({
    protocolLoader,
  } = {}) {
    if (typeof protocolLoader !== "function") {
      throw new Error("protocol_loader_required");
    }
    this.protocolLoader = protocolLoader;
  }

  async load({
    protocolKey,
    canonicalPathologyKey,
    language,
  } = {}) {
    const protocol = await this.protocolLoader({
      protocolKey,
      canonicalPathologyKey,
    });

    if (!protocol || typeof protocol !== "object") {
      return Object.freeze({
        handled: false,
        reason: "protocol_not_found",
        classification: null,
        actions: null,
      });
    }

    const compatibility = protocol.legacyCompatibility;
    if (!compatibility || typeof compatibility !== "object") {
      return Object.freeze({
        handled: false,
        reason: "legacy_compatibility_missing",
        classification: null,
        actions: null,
      });
    }

    const classification = resolveOptionalEnvelope(
      compatibility.classification,
      COMPATIBILITY_KINDS.classification,
      language,
    );

    const actions = resolveOptionalEnvelope(
      compatibility.actions,
      COMPATIBILITY_KINDS.actions,
      language,
    );

    return Object.freeze({
      handled: Boolean(classification || actions),
      reason: classification || actions
        ? "legacy_compatibility_resolved"
        : "no_valid_legacy_compatibility_payload",
      classification,
      actions,
    });
  }
}

function resolveOptionalEnvelope(envelope, expectedKind, language) {
  if (!envelope) return null;

  const validation = validateLocalizedPayloadEnvelope(envelope, {
    expectedKind,
  });

  if (!validation.ok) {
    return Object.freeze({
      ok: false,
      reason: "invalid_envelope",
      errors: validation.errors,
      value: null,
      language: null,
    });
  }

  return resolveLocalizedPayload(envelope, language);
}

module.exports = {
  ClinicalLegacyCompatibilityAdapter,
};
