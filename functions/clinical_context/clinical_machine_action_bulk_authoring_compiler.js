"use strict";

const crypto = require("crypto");

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

function nonEmptyString(value) {
  return typeof value === "string" && value.trim()
    ? value.trim()
    : null;
}

function sha256Json(value) {
  return crypto
    .createHash("sha256")
    .update(JSON.stringify(value))
    .digest("hex");
}

function classificationPayload(record) {
  if (!record || typeof record !== "object") {
    return null;
  }

  return (
    record.classification ??
    record.classifications ??
    record.classificationEnvelope ??
    record.classificationLegacyEnvelope ??
    null
  );
}

function actionPayload(record) {
  if (!record || typeof record !== "object") {
    return null;
  }

  return (
    record.actions ??
    record.action ??
    record.actionsEnvelope ??
    record.actionLegacyEnvelope ??
    null
  );
}

function authorDeterministicMachineActions({
  phase7,
  legacyCompatibility,
  phase11Manifest,
} = {}) {
  const protocols = Array.isArray(phase7?.protocols)
    ? phase7.protocols
    : [];

  const records =
    legacyCompatibility?.recordsByPathology &&
    typeof legacyCompatibility.recordsByPathology ===
      "object" &&
    !Array.isArray(
      legacyCompatibility.recordsByPathology,
    )
      ? legacyCompatibility.recordsByPathology
      : {};

  if (protocols.length !== 270) {
    throw new Error(
      `protocol_count_mismatch:${protocols.length}`,
    );
  }

  if (Object.keys(records).length !== 270) {
    throw new Error(
      `legacy_record_count_mismatch:${
        Object.keys(records).length
      }`,
    );
  }

  if (
    phase11Manifest?.summary?.protocols !== 270
  ) {
    throw new Error(
      "phase11_authoring_manifest_not_ready",
    );
  }

  const actions = [];
  const evidence = [];
  const backlog = [];

  for (const protocol of protocols) {
    const protocolKey =
      nonEmptyString(protocol?.protocolKey);
    const canonicalPathologyKey =
      nonEmptyString(
        protocol?.canonicalPathologyKey,
      );

    if (!protocolKey || !canonicalPathologyKey) {
      throw new Error(
        "protocol_machine_identity_missing",
      );
    }

    const record = records[canonicalPathologyKey];

    if (!record || typeof record !== "object") {
      throw new Error(
        `legacy_record_missing:${canonicalPathologyKey}`,
      );
    }

    const version = protocol.version;
    const priority = protocol.priority;

    if (version == null || priority == null) {
      throw new Error(
        `protocol_version_priority_missing:${canonicalPathologyKey}`,
      );
    }

    // Deterministic generic primary navigation action.
    // No clinical interpretation is performed:
    // every protocol has exactly one protocol-content doc from Phase11.
    const primaryActionKey =
      `primary_open_protocol_content::${canonicalPathologyKey}`;

    const protocolContentKey =
      `legacy_protocol_content::${canonicalPathologyKey}`;

    const primaryAction = {
      actionKey: primaryActionKey,
      protocolKey,
      canonicalPathologyKey,
      kind: "primary",
      actionType: "open_content_ref",
      contentRef: protocolContentKey,
      enabled: true,
      priority,
      version,
      provenance: {
        source:
          "phase11.protocol_machine_content",
        transform:
          "DETERMINISTIC_NAVIGATION_BINDING",
        semanticInference: "NONE",
      },
    };

    actions.push({
      id: primaryActionKey,
      data: primaryAction,
    });

    evidence.push({
      actionKey: primaryActionKey,
      canonicalPathologyKey,
      protocolKey,
      kind: "primary",
      actionType: "open_content_ref",
      contentRef: protocolContentKey,
      source:
        "phase11.protocol_machine_content",
      transform:
        "DETERMINISTIC_NAVIGATION_BINDING",
      semanticInference: "NONE",
    });

    const cls = classificationPayload(record);
    const legacyActions = actionPayload(record);

    let classificationActionKey = null;

    // A classification action is deterministic only where an explicit
    // legacy classification envelope already exists. It opens the
    // verbatim classification-content doc; it does NOT infer score/stage/
    // categorical mode and does NOT calculate a patient classification.
    if (cls != null) {
      classificationActionKey =
        `classification_open_content::${canonicalPathologyKey}`;

      const classificationContentKey =
        `legacy_classification_content::${canonicalPathologyKey}`;

      const classificationAction = {
        actionKey: classificationActionKey,
        protocolKey,
        canonicalPathologyKey,
        kind: "classification",
        actionType: "open_content_ref",
        contentRef: classificationContentKey,
        enabled: true,
        priority,
        version,
        provenance: {
          source:
            "legacyCompatibility.recordsByPathology.classification",
          legacyEvidenceSha256:
            sha256Json(cls),
          transform:
            "DETERMINISTIC_CLASSIFICATION_CONTENT_BINDING",
          semanticInference: "NONE",
        },
      };

      actions.push({
        id: classificationActionKey,
        data: classificationAction,
      });

      evidence.push({
        actionKey: classificationActionKey,
        canonicalPathologyKey,
        protocolKey,
        kind: "classification",
        actionType: "open_content_ref",
        contentRef: classificationContentKey,
        source:
          "legacyCompatibility.recordsByPathology.classification",
        legacyEvidenceSha256:
          sha256Json(cls),
        transform:
          "DETERMINISTIC_CLASSIFICATION_CONTENT_BINDING",
        semanticInference: "NONE",
      });
    }

    backlog.push({
      protocolKey,
      canonicalPathologyKey,
      protocolVersion: version,
      protocolPriority: priority,

      action: {
        status: "READY",
        primaryActionKey,
        classificationActionKey,
        legacyActionEvidencePresent:
          legacyActions != null,
        legacyActionEvidenceSha256:
          legacyActions != null
            ? sha256Json(legacyActions)
            : null,
      },

      classification: cls != null
        ? {
            status:
              "CLINICAL_AUTHORING_REQUIRED",
            applicabilityEvidence:
              "EXPLICIT_LEGACY_CLASSIFICATION_ENVELOPE",
            legacyEvidenceSha256:
              sha256Json(cls),
            contentRef:
              `legacy_classification_content::${canonicalPathologyKey}`,
            requiredMachineFields: [
              "classificationKey",
              "canonicalPathologyKey",
              "mode",
              "enabled",
              "priority",
              "version",
            ],
            modeDecisionRequired: true,
            allowedModes: [
              "categorical",
              "score",
              "stage",
            ],
          }
        : {
            status:
              "NO_EXPLICIT_CLASSIFICATION_REQUIREMENT_IN_CURRENT_SOURCE",
            applicabilityEvidence: null,
            modeDecisionRequired: false,
          },

      management: {
        status:
          "CLINICAL_AUTHORING_REQUIRED",
        requiredMachineFields: [
          "managementRuleKey",
          "canonicalPathologyKey",
          "enabled",
          "priority",
          "version",
        ],
        clinicalDependencyDecisionRequired: true,
      },
    });
  }

  const actionIds = actions.map((doc) => doc.id);

  if (new Set(actionIds).size !== actionIds.length) {
    throw new Error("duplicate_machine_action_key");
  }

  const primaryCount = actions.filter(
    (doc) => doc.data.kind === "primary",
  ).length;

  const classificationCount = actions.filter(
    (doc) => doc.data.kind === "classification",
  ).length;

  const classificationBacklog = backlog.filter(
    (row) =>
      row.classification.status ===
      "CLINICAL_AUTHORING_REQUIRED",
  );

  return deepFreeze({
    supplement: {
      schemaVersion:
        "clinical_registry_machine_native_supplement_phase12_v1",
      semanticInference: "NONE",
      provenancePolicy:
        "DETERMINISTIC_NAVIGATION_BINDING_ONLY",
      classifications: [],
      managementRules: [],
      actions,
      content: [],
    },

    evidence: {
      schemaVersion:
        "clinical_registry_machine_action_evidence_phase12_v1",
      semanticInference: "NONE",
      records: evidence,
    },

    clinicalAuthoringBacklog: {
      schemaVersion:
        "clinical_registry_clinical_authoring_backlog_phase12_v1",
      semanticInference: "NONE",
      protocols: backlog,
      summary: {
        protocols: backlog.length,
        machineActionProtocolCoverage: primaryCount,
        primaryActions: primaryCount,
        classificationNavigationActions:
          classificationCount,
        classificationClinicalAuthoringRequired:
          classificationBacklog.length,
        classificationNotExplicitlyRequired:
          backlog.length -
          classificationBacklog.length,
        managementClinicalAuthoringRequired:
          backlog.length,
        legacyActionEvidence:
          backlog.filter(
            (row) =>
              row.action.legacyActionEvidencePresent,
          ).length,
      },
    },
  });
}

module.exports = {
  authorDeterministicMachineActions,
};
