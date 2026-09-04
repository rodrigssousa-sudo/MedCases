"use strict";

function firstNonEmptyString(values) {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }

  return null;
}

function normalizeExplicitLanguage(value) {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim().toLowerCase();

  if (!normalized) {
    return null;
  }

  if (
    normalized === "es" ||
    normalized.startsWith("es-") ||
    normalized.startsWith("es_")
  ) {
    return "es";
  }

  if (
    normalized === "pt" ||
    normalized.startsWith("pt-") ||
    normalized.startsWith("pt_")
  ) {
    return "pt";
  }

  return null;
}

function headerValue(headers, name) {
  if (!headers || typeof headers !== "object") {
    return null;
  }

  const target = name.toLowerCase();

  for (const [key, value] of Object.entries(headers)) {
    if (String(key).toLowerCase() === target) {
      if (Array.isArray(value)) {
        return firstNonEmptyString(value);
      }

      if (typeof value === "string") {
        return value;
      }
    }
  }

  return null;
}

function languageFromAcceptLanguage(value) {
  if (typeof value !== "string") {
    return null;
  }

  const candidates = value
    .split(",")
    .map((part) => part.split(";")[0].trim())
    .filter(Boolean);

  for (const candidate of candidates) {
    const normalized = normalizeExplicitLanguage(candidate);
    if (normalized) {
      return normalized;
    }
  }

  return null;
}

function extractExplicitLanguage(requestLike = {}) {
  const data =
    requestLike.data && typeof requestLike.data === "object"
      ? requestLike.data
      : {};

  const body =
    requestLike.body && typeof requestLike.body === "object"
      ? requestLike.body
      : {};

  for (const value of [
    requestLike.language,
    requestLike.lang,
    requestLike.locale,
    requestLike.idioma,
    data.language,
    data.lang,
    data.locale,
    data.idioma,
    body.language,
    body.lang,
    body.locale,
    body.idioma,
  ]) {
    const normalized = normalizeExplicitLanguage(value);
    if (normalized) {
      return Object.freeze({
        language: normalized,
        source: "explicit_language_field",
      });
    }
  }

  for (const value of [
    requestLike.isEs,
    data.isEs,
    body.isEs,
  ]) {
    if (typeof value === "boolean") {
      return Object.freeze({
        language: value ? "es" : "pt",
        source: "explicit_isEs_boolean",
      });
    }
  }

  const acceptLanguage = firstNonEmptyString([
    headerValue(requestLike.headers, "accept-language"),
    headerValue(data.headers, "accept-language"),
    headerValue(body.headers, "accept-language"),
  ]);

  const fromHeader = languageFromAcceptLanguage(acceptLanguage);

  if (fromHeader) {
    return Object.freeze({
      language: fromHeader,
      source: "accept_language_header",
    });
  }

  return Object.freeze({
    language: null,
    source: "language_unavailable",
  });
}

function extractExplicitMachineIdentity(requestLike = {}) {
  const data =
    requestLike.data && typeof requestLike.data === "object"
      ? requestLike.data
      : {};

  const body =
    requestLike.body && typeof requestLike.body === "object"
      ? requestLike.body
      : {};

  const protocolKey = firstNonEmptyString([
    requestLike.protocolKey,
    data.protocolKey,
    body.protocolKey,
  ]);

  const canonicalPathologyKey = firstNonEmptyString([
    requestLike.canonicalPathologyKey,
    data.canonicalPathologyKey,
    body.canonicalPathologyKey,
  ]);

  if (!protocolKey && !canonicalPathologyKey) {
    return Object.freeze({
      resolved: false,
      reason: "machine_identity_unavailable",
    });
  }

  return Object.freeze({
    resolved: true,
    reason: "explicit_machine_identity",
    protocolKey: protocolKey || null,
    canonicalPathologyKey: canonicalPathologyKey || null,
  });
}

function extractExplicitIdentityAlias(requestLike = {}) {
  const data =
    requestLike.data && typeof requestLike.data === "object"
      ? requestLike.data
      : {};

  const body =
    requestLike.body && typeof requestLike.body === "object"
      ? requestLike.body
      : {};

  // These are intentionally explicit identity fields only.
  // General free text such as userMessage/prompt/query is excluded.
  return firstNonEmptyString([
    requestLike.pathologyAlias,
    requestLike.clinicalIdentityAlias,
    requestLike.pathology,
    requestLike.diagnosis,
    data.pathologyAlias,
    data.clinicalIdentityAlias,
    data.pathology,
    data.diagnosis,
    body.pathologyAlias,
    body.clinicalIdentityAlias,
    body.pathology,
    body.diagnosis,
  ]);
}

function createClinicalRequestContextBridge({
  identityIndex,
} = {}) {
  if (
    !identityIndex ||
    typeof identityIndex.resolveExactAlias !== "function"
  ) {
    throw new Error("exact_identity_index_required");
  }

  function resolve(requestLike = {}) {
    const language = extractExplicitLanguage(requestLike);
    const machineIdentity =
      extractExplicitMachineIdentity(requestLike);

    let identity = machineIdentity;

    if (!identity.resolved) {
      const alias = extractExplicitIdentityAlias(requestLike);

      if (alias) {
        identity = identityIndex.resolveExactAlias(alias);
      }
    }

    return deepFreeze({
      schemaVersion: "clinical_request_context_bridge_v1",
      language: language.language,
      languageSource: language.source,
      identity,
      readyForProtocolLookup:
        Boolean(
          language.language &&
          identity &&
          identity.resolved &&
          (
            identity.protocolKey ||
            identity.canonicalPathologyKey
          ),
        ),
      runtimeActivationEnabled: false,
      shadowExecutionEnabled: false,
      realProviderExecutionEnabled: false,
      visibleCutoverEnabled: false,
      cutoverState: "OFF",
    });
  }

  return Object.freeze({
    resolve,
    runtimeActivationEnabled: false,
    shadowExecutionEnabled: false,
    realProviderExecutionEnabled: false,
    visibleCutoverEnabled: false,
    cutoverState: "OFF",
  });
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
  normalizeExplicitLanguage,
  languageFromAcceptLanguage,
  extractExplicitLanguage,
  extractExplicitMachineIdentity,
  extractExplicitIdentityAlias,
  createClinicalRequestContextBridge,
};
