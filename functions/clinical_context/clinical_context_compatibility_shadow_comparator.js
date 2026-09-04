"use strict";

function compareCompatibilityShadow({
  legacy,
  remote,
  language,
} = {}) {
  const legacyClassification = Boolean(
    legacy &&
    legacy.classification &&
    legacy.classification.ok === true,
  );

  const legacyActions = Boolean(
    legacy &&
    legacy.actions &&
    legacy.actions.ok === true,
  );

  const remoteHandled = Boolean(remote && remote.handled === true);
  const remoteCommitted = Boolean(
    remote &&
    (
      remote.committed === true ||
      remote.status === "committed" ||
      remote.disposition === "committed"
    ),
  );

  const remoteResponse = remote && remote.response && typeof remote.response === "object"
    ? remote.response
    : null;

  const remoteActions = Array.isArray(remoteResponse && remoteResponse.actions)
    ? remoteResponse.actions
    : [];

  const remoteClassificationSignal = remoteActions.some((action) => {
    const kind = String(action && action.kind || "").toLowerCase();
    return ["classification", "score", "stage"].includes(kind);
  });

  const remotePrimaryActionSignal = remoteActions.some((action) => {
    const kind = String(action && action.kind || "").toLowerCase();
    return kind === "primary";
  });

  const observations = Object.freeze({
    language: String(language || ""),
    legacyClassificationPresent: legacyClassification,
    legacyActionsPresent: legacyActions,
    remoteHandled,
    remoteCommitted,
    remoteClassificationSignal,
    remotePrimaryActionSignal,
  });

  const structuralMismatches = [];

  if (
    remoteCommitted &&
    legacyClassification !== remoteClassificationSignal
  ) {
    structuralMismatches.push(
      "classification_presence_signal_mismatch",
    );
  }

  if (
    remoteCommitted &&
    legacyActions &&
    !remotePrimaryActionSignal &&
    remoteActions.length === 0
  ) {
    structuralMismatches.push(
      "legacy_actions_present_remote_actions_absent",
    );
  }

  return Object.freeze({
    schemaVersion: "clinical_compatibility_shadow_comparison_v1",
    comparisonScope: "structural_presence_only",
    clinicalEquivalenceClaimed: false,
    textEquivalenceClaimed: false,
    managementEquivalenceClaimed: false,
    observations,
    structuralMismatches: Object.freeze([...structuralMismatches]),
  });
}

module.exports = {
  compareCompatibilityShadow,
};
