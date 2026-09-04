"use strict";

const COMPATIBILITY_SCHEMA_VERSION = "legacy_localized_payload_v1";

const COMPATIBILITY_KINDS = Object.freeze({
  classification: "localized_classification_payload",
  actions: "localized_action_payload",
});

function validateLocalizedPayloadEnvelope(envelope, {
  expectedKind,
} = {}) {
  const errors = [];

  if (!envelope || typeof envelope !== "object" || Array.isArray(envelope)) {
    return {
      ok: false,
      errors: ["envelope_not_object"],
    };
  }

  if (envelope.schemaVersion !== COMPATIBILITY_SCHEMA_VERSION) {
    errors.push("schema_version_invalid");
  }

  if (
    expectedKind &&
    envelope.compatibilityKind !== expectedKind
  ) {
    errors.push("compatibility_kind_invalid");
  }

  if (
    !Object.values(COMPATIBILITY_KINDS).includes(
      envelope.compatibilityKind,
    )
  ) {
    errors.push("compatibility_kind_unknown");
  }

  if (!envelope.locales || typeof envelope.locales !== "object") {
    errors.push("locales_missing");
  } else {
    if (!Object.prototype.hasOwnProperty.call(envelope.locales, "pt")) {
      errors.push("locale_pt_missing");
    }
    if (!Object.prototype.hasOwnProperty.call(envelope.locales, "es")) {
      errors.push("locale_es_missing");
    }
  }

  if (!envelope.sourceProof || typeof envelope.sourceProof !== "object") {
    errors.push("source_proof_missing");
  } else {
    for (const key of [
      "protocolKey",
      "blockSha256",
      "sourceExpressionSha256",
    ]) {
      if (!String(envelope.sourceProof[key] || "").trim()) {
        errors.push(`source_proof_${key}_missing`);
      }
    }
  }

  if (
    envelope.machineRuleInferencePerformed !== false ||
    envelope.finalMachineRegistryDocument !== false
  ) {
    errors.push("unsafe_machine_promotion_flag");
  }

  return {
    ok: errors.length === 0,
    errors,
  };
}

function resolveLocalizedPayload(envelope, language) {
  const validation = validateLocalizedPayloadEnvelope(envelope);
  if (!validation.ok) {
    return Object.freeze({
      ok: false,
      reason: "invalid_legacy_compatibility_envelope",
      errors: validation.errors,
      value: null,
      language: null,
    });
  }

  const requested = String(language || "").toLowerCase();
  const languageKey = requested.startsWith("pt")
    ? "pt"
    : requested.startsWith("es")
      ? "es"
      : null;

  if (!languageKey) {
    return Object.freeze({
      ok: false,
      reason: "unsupported_language",
      errors: [],
      value: null,
      language: null,
    });
  }

  return Object.freeze({
    ok: true,
    reason: "resolved",
    errors: [],
    value: envelope.locales[languageKey],
    language: languageKey,
  });
}

module.exports = {
  COMPATIBILITY_SCHEMA_VERSION,
  COMPATIBILITY_KINDS,
  validateLocalizedPayloadEnvelope,
  resolveLocalizedPayload,
};
