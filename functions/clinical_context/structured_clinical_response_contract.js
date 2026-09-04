"use strict";

const SCHEMA_VERSION = "clinical_response_v1";

/**
 * Canonical server-to-app response envelope.
 *
 * The server commits only a final, validated text. The app receives a stable
 * object and may reveal the already-final text progressively on-device.
 *
 * This contract does not perform provider generation yet; that wiring belongs
 * to the later stable-response pipeline build.
 */
function createStructuredClinicalResponse({
  text,
  identityResult = {},
  protocolResult = {},
  classificationResult = {},
  managementResult = {},
  actionResult = {},
  language = "es",
  provenance = {},
}) {
  const finalText = String(text || "").trim();
  if (!finalText) {
    throw new Error("structured_clinical_response_text_required");
  }

  const primaryAction = normalizeAction(actionResult.primaryAction);
  const classificationAction = normalizeAction(
    actionResult.classificationAction,
  );

  const response = {
    schemaVersion: SCHEMA_VERSION,
    status: "ready",
    language: String(language || "es"),
    text: finalText,
    clinicalContext: {
      pathologyKey: String(identityResult.canonicalKey || ""),
      pathologyLabel: String(identityResult.displayLabel || ""),
      identityConfidence: finiteOrNull(identityResult.confidence),
      protocolKey: String(protocolResult.protocol?.protocolKey || ""),
      classification: {
        key: String(classificationResult.classificationKey || ""),
        label: String(classificationResult.classificationLabel || ""),
        mode: String(classificationResult.mode || ""),
        resolved: Boolean(classificationResult.resolved),
        categoryKey: String(classificationResult.categoryKey || ""),
        categoryLabel: String(classificationResult.categoryLabel || ""),
        score: finiteOrNull(classificationResult.score),
        missingFacts: stringArray(classificationResult.missingFacts),
        sourceVersion: String(classificationResult.sourceVersion || ""),
      },
      management: {
        resolved: Boolean(managementResult.resolved),
        ruleKey: String(managementResult.managementRuleKey || ""),
        label: String(managementResult.managementLabel || ""),
        missingFacts: stringArray(managementResult.missingFacts),
        sourceVersion: String(managementResult.sourceVersion || ""),
      },
    },
    actions: {
      primary: primaryAction,
      classification: classificationAction,
    },
    presentation: {
      revealMode: "local_progressive_after_commit",
      immutableAfterCommit: true,
      allowVisibleTextMutation: false,
      actionsStableWithResponse: true,
    },
    provenance: sanitizeProvenance(provenance),
  };

  return deepFreeze(response);
}

function createWaitingForFactsResponse({
  identityResult = {},
  protocolResult = {},
  classificationResult = {},
  managementResult = {},
  actionResult = {},
  language = "es",
  provenance = {},
}) {
  const missingFacts = uniqueStrings([
    ...stringArray(classificationResult.missingFacts),
    ...stringArray(managementResult.missingFacts),
  ]);

  const response = {
    schemaVersion: SCHEMA_VERSION,
    status: "waiting_for_facts",
    language: String(language || "es"),
    text: "",
    clinicalContext: {
      pathologyKey: String(identityResult.canonicalKey || ""),
      pathologyLabel: String(identityResult.displayLabel || ""),
      identityConfidence: finiteOrNull(identityResult.confidence),
      protocolKey: String(protocolResult.protocol?.protocolKey || ""),
      classification: {
        key: String(classificationResult.classificationKey || ""),
        label: String(classificationResult.classificationLabel || ""),
        mode: String(classificationResult.mode || ""),
        resolved: false,
        categoryKey: "",
        categoryLabel: "",
        score: null,
        missingFacts,
        sourceVersion: String(classificationResult.sourceVersion || ""),
      },
      management: {
        resolved: false,
        ruleKey: "",
        label: "",
        missingFacts,
        sourceVersion: String(managementResult.sourceVersion || ""),
      },
    },
    actions: {
      primary: normalizeAction(actionResult.primaryAction),
      classification: normalizeAction(actionResult.classificationAction),
    },
    presentation: {
      revealMode: "structured_waiting_state",
      immutableAfterCommit: true,
      allowVisibleTextMutation: false,
      actionsStableWithResponse: true,
    },
    provenance: sanitizeProvenance(provenance),
  };

  return deepFreeze(response);
}

function normalizeAction(value) {
  if (!value || typeof value !== "object") return null;

  return {
    actionKey: String(value.actionKey || ""),
    kind: String(value.kind || ""),
    actionType: String(value.actionType || ""),
    label: String(value.label || ""),
    prompt: String(value.prompt || ""),
    contentRef: String(value.contentRef || ""),
    payload: plainObject(value.payload),
    sourceVersion: String(value.sourceVersion || ""),
  };
}

function sanitizeProvenance(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const allowed = [
    "registryVersion",
    "protocolVersion",
    "classificationVersion",
    "managementVersion",
    "actionVersion",
  ];
  const out = {};
  for (const key of allowed) {
    if (value[key] != null) out[key] = String(value[key]);
  }
  return out;
}

function finiteOrNull(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function stringArray(value) {
  if (!Array.isArray(value)) return [];
  return value.map((x) => String(x || "")).filter(Boolean);
}

function uniqueStrings(values) {
  return [...new Set(values.map((x) => String(x || "")).filter(Boolean))];
}

function plainObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return { ...value };
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
  SCHEMA_VERSION,
  createStructuredClinicalResponse,
  createWaitingForFactsResponse,
};
