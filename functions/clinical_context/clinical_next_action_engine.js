"use strict";

/**
 * Remote-data-driven NextAction resolver.
 *
 * It selects at most:
 * - one primary clinical continuation action;
 * - one secondary classification/score/stage action.
 *
 * User-facing labels and prompts come only from the remote action registry.
 * If no confident specific action matches, the engine returns no action.
 */
class ClinicalNextActionEngine {
  resolve({
    pathologyKey,
    protocolKey = "",
    managementResult = {},
    classificationResult = {},
    actions = [],
    language = "es",
    clinicalPhase = "",
    userIntent = "",
  }) {
    if (!pathologyKey) {
      return emptyActions("pathology_key_missing");
    }

    const context = {
      pathologyKey: String(pathologyKey),
      protocolKey: String(protocolKey || ""),
      managementRuleKey: String(managementResult.managementRuleKey || ""),
      classificationKey: String(classificationResult.classificationKey || ""),
      categoryKey: String(classificationResult.categoryKey || ""),
      classificationResolved: Boolean(classificationResult.resolved),
      managementResolved: Boolean(managementResult.resolved),
      requiresClassification: Boolean(managementResult.requiresClassification),
      hasMissingFacts:
        Array.isArray(managementResult.missingFacts) &&
        managementResult.missingFacts.length > 0,
      clinicalPhase: String(clinicalPhase || ""),
      userIntent: String(userIntent || ""),
    };

    const candidates = (actions || [])
      .filter((action) => action && action.enabled !== false)
      .filter((action) => actionMatches(action, context))
      .map((action) => ({
        action,
        score: specificityScore(action, context),
      }))
      .sort((a, b) => {
        const scoreDelta = b.score - a.score;
        if (scoreDelta !== 0) return scoreDelta;

        const priorityDelta =
          Number(b.action.priority || 0) - Number(a.action.priority || 0);
        if (priorityDelta !== 0) return priorityDelta;

        return String(a.action.id || a.action.actionKey || "").localeCompare(
          String(b.action.id || b.action.actionKey || ""),
        );
      });

    const primary = selectOne(
      candidates.filter(({ action }) => normalizeKind(action.kind) === "primary"),
      language,
      "primary",
    );

    const classification = selectOne(
      candidates.filter(({ action }) =>
        ["classification", "score", "stage"].includes(normalizeKind(action.kind))
      ),
      language,
      "classification",
    );

    const ambiguous = Boolean(primary.ambiguous || classification.ambiguous);

    return {
      primaryAction: primary.action,
      classificationAction: classification.action,
      ambiguous,
      reason: ambiguous
        ? "action_priority_or_specificity_tie"
        : (primary.action || classification.action)
          ? "contextual_actions_resolved"
          : "no_confident_remote_action",
    };
  }
}

function selectOne(candidates, language, slot) {
  if (!candidates.length) {
    return { action: null, ambiguous: false };
  }

  const top = candidates[0];
  const ties = candidates.filter((candidate) =>
    candidate.score === top.score &&
    Number(candidate.action.priority || 0) ===
      Number(top.action.priority || 0)
  );

  if (ties.length > 1) {
    return { action: null, ambiguous: true };
  }

  const normalized = normalizeAction(top.action, language, slot);
  if (!normalized) {
    return { action: null, ambiguous: false };
  }

  return { action: normalized, ambiguous: false };
}

function actionMatches(action, context) {
  const match = action.match || {};

  if (
    match.canonicalPathologyKey &&
    String(match.canonicalPathologyKey) !== context.pathologyKey
  ) {
    return false;
  }

  if (match.protocolKey && String(match.protocolKey) !== context.protocolKey) {
    return false;
  }

  if (
    match.managementRuleKey &&
    String(match.managementRuleKey) !== context.managementRuleKey
  ) {
    return false;
  }

  if (
    match.classificationKey &&
    String(match.classificationKey) !== context.classificationKey
  ) {
    return false;
  }

  if (match.categoryKey && String(match.categoryKey) !== context.categoryKey) {
    return false;
  }

  if (
    match.classificationResolved != null &&
    Boolean(match.classificationResolved) !== context.classificationResolved
  ) {
    return false;
  }

  if (
    match.managementResolved != null &&
    Boolean(match.managementResolved) !== context.managementResolved
  ) {
    return false;
  }

  if (
    match.requiresClassification != null &&
    Boolean(match.requiresClassification) !== context.requiresClassification
  ) {
    return false;
  }

  if (
    match.hasMissingFacts != null &&
    Boolean(match.hasMissingFacts) !== context.hasMissingFacts
  ) {
    return false;
  }

  if (
    match.clinicalPhase &&
    String(match.clinicalPhase) !== context.clinicalPhase
  ) {
    return false;
  }

  if (match.userIntent && String(match.userIntent) !== context.userIntent) {
    return false;
  }

  return true;
}

function specificityScore(action, context) {
  const match = action.match || {};
  const weighted = [
    ["canonicalPathologyKey", 8],
    ["protocolKey", 7],
    ["managementRuleKey", 8],
    ["classificationKey", 6],
    ["categoryKey", 8],
    ["classificationResolved", 3],
    ["managementResolved", 3],
    ["requiresClassification", 3],
    ["hasMissingFacts", 3],
    ["clinicalPhase", 4],
    ["userIntent", 4],
  ];

  let score = 0;
  for (const [key, weight] of weighted) {
    if (match[key] != null && match[key] !== "") score += weight;
  }

  if (
    match.canonicalPathologyKey &&
    String(match.canonicalPathologyKey) === context.pathologyKey
  ) {
    score += 2;
  }

  return score;
}

function normalizeAction(action, language, slot) {
  const labels = action.labels || {};
  const prompts = action.prompts || {};
  const label =
    String(labels[language] || labels.es || labels.pt || labels.en || "").trim();
  const prompt =
    String(prompts[language] || prompts.es || prompts.pt || prompts.en || "").trim();

  if (!label) return null;

  const actionType = String(action.actionType || "dispatch_prompt");
  if (slot === "primary" && actionType === "dispatch_prompt" && !prompt) {
    return null;
  }

  return Object.freeze({
    actionKey: String(action.actionKey || action.id || ""),
    kind: normalizeKind(action.kind),
    actionType,
    label,
    prompt,
    contentRef: String(action.contentRef || ""),
    payload: plainObject(action.payload),
    sourceVersion: String(action.version || ""),
  });
}

function normalizeKind(value) {
  const kind = String(value || "").toLowerCase();
  if (["primary", "classification", "score", "stage"].includes(kind)) {
    return kind;
  }
  return "";
}

function plainObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return { ...value };
}

function emptyActions(reason) {
  return {
    primaryAction: null,
    classificationAction: null,
    ambiguous: false,
    reason,
  };
}

module.exports = {
  ClinicalNextActionEngine,
};
