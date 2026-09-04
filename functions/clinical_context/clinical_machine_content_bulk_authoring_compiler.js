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

function protocolMap(phase7) {
  const out = new Map();

  for (const protocol of Array.isArray(phase7?.protocols)
    ? phase7.protocols
    : []) {
    const key = nonEmptyString(
      protocol?.canonicalPathologyKey,
    );
    if (!key) {
      throw new Error(
        "protocol_missing_canonical_pathology_key",
      );
    }
    if (out.has(key)) {
      throw new Error(
        `duplicate_protocol_pathology_key:${key}`,
      );
    }
    out.set(key, protocol);
  }

  return out;
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

function authorBulkMachineContent({
  phase7,
  legacyCompatibility,
} = {}) {
  const protocols = protocolMap(phase7);
  const records =
    legacyCompatibility?.recordsByPathology &&
    typeof legacyCompatibility.recordsByPathology ===
      "object" &&
    !Array.isArray(
      legacyCompatibility.recordsByPathology,
    )
      ? legacyCompatibility.recordsByPathology
      : {};

  if (protocols.size !== 270) {
    throw new Error(
      `protocol_count_mismatch:${protocols.size}`,
    );
  }

  if (Object.keys(records).length !== 270) {
    throw new Error(
      `legacy_record_count_mismatch:${
        Object.keys(records).length
      }`,
    );
  }

  const content = [];
  const evidence = [];
  const manifest = [];

  for (const [
    canonicalPathologyKey,
    protocol,
  ] of protocols.entries()) {
    const record = records[canonicalPathologyKey];

    if (!record || typeof record !== "object") {
      throw new Error(
        `legacy_record_missing:${canonicalPathologyKey}`,
      );
    }

    const protocolKey = nonEmptyString(
      protocol.protocolKey,
    );
    const version = protocol.version;
    const priority = protocol.priority;

    if (!protocolKey) {
      throw new Error(
        `protocol_key_missing:${canonicalPathologyKey}`,
      );
    }

    if (version == null) {
      throw new Error(
        `protocol_version_missing:${canonicalPathologyKey}`,
      );
    }

    const protocolContentKey =
      `legacy_protocol_content::${canonicalPathologyKey}`;

    const protocolContent = {
      contentKey: protocolContentKey,
      protocolKey,
      canonicalPathologyKey,
      enabled: true,
      version,
      source:
        "legacyCompatibility.recordsByPathology",
      sourceMode: "verbatim_compatibility_wrap",
      payload: JSON.parse(
        JSON.stringify(record),
      ),
    };

    content.push({
      id: protocolContentKey,
      data: protocolContent,
    });

    evidence.push({
      contentKey: protocolContentKey,
      canonicalPathologyKey,
      protocolKey,
      source:
        "legacyCompatibility.recordsByPathology",
      payloadSha256: sha256Json(record),
      transform: "VERBATIM_WRAP",
      semanticInference: "NONE",
    });

    const cls = classificationPayload(record);

    let classificationContentKey = null;

    if (cls != null) {
      classificationContentKey =
        `legacy_classification_content::${canonicalPathologyKey}`;

      const clsContent = {
        contentKey: classificationContentKey,
        protocolKey,
        canonicalPathologyKey,
        enabled: true,
        version,
        source:
          "legacyCompatibility.recordsByPathology.classification",
        sourceMode:
          "verbatim_classification_compatibility_wrap",
        payload: JSON.parse(JSON.stringify(cls)),
      };

      content.push({
        id: classificationContentKey,
        data: clsContent,
      });

      evidence.push({
        contentKey: classificationContentKey,
        canonicalPathologyKey,
        protocolKey,
        source:
          "legacyCompatibility.recordsByPathology.classification",
        payloadSha256: sha256Json(cls),
        transform: "VERBATIM_WRAP",
        semanticInference: "NONE",
      });
    }

    const actions = actionPayload(record);

    manifest.push({
      protocolKey,
      canonicalPathologyKey,
      protocolVersion: version,
      protocolPriority: priority,
      machineContent: {
        status: "READY",
        protocolContentKey,
        classificationContentKey,
      },
      classification: {
        status:
          cls != null
            ? "AUTHORING_REQUIRED_WITH_LEGACY_EVIDENCE"
            : "AUTHORING_REQUIRED_NO_LEGACY_CLASSIFICATION",
        legacyEvidencePresent: cls != null,
        legacyEvidenceSha256:
          cls != null ? sha256Json(cls) : null,
        requiredMachineFields: [
          "classificationKey",
          "canonicalPathologyKey",
          "mode",
          "enabled",
          "priority",
          "version",
        ],
        allowedModes: [
          "categorical",
          "score",
          "stage",
        ],
      },
      management: {
        status: "AUTHORING_REQUIRED",
        requiredMachineFields: [
          "managementRuleKey",
          "canonicalPathologyKey",
          "enabled",
          "priority",
          "version",
        ],
      },
      action: {
        status: "AUTHORING_REQUIRED",
        legacyEvidencePresent: actions != null,
        legacyEvidenceSha256:
          actions != null
            ? sha256Json(actions)
            : null,
        requiredMachineFields: [
          "actionKey",
          "kind",
          "actionType",
          "enabled",
          "priority",
          "version",
        ],
        allowedKinds: [
          "primary",
          "classification",
          "score",
          "stage",
        ],
        allowedActionTypes: [
          "dispatch_prompt",
          "open_content_ref",
        ],
      },
    });
  }

  const ids = new Set(content.map((doc) => doc.id));

  if (ids.size !== content.length) {
    throw new Error(
      "duplicate_bulk_machine_content_key",
    );
  }

  const classificationContentCount =
    content.filter((doc) =>
      doc.id.startsWith(
        "legacy_classification_content::",
      ),
    ).length;

  return deepFreeze({
    supplement: {
      schemaVersion:
        "clinical_registry_machine_native_supplement_phase11_v1",
      semanticInference: "NONE",
      provenancePolicy:
        "VERBATIM_LEGACY_COMPATIBILITY_WRAP_ONLY",
      classifications: [],
      managementRules: [],
      actions: [],
      content,
    },
    evidence: {
      schemaVersion:
        "clinical_registry_machine_content_evidence_phase11_v1",
      semanticInference: "NONE",
      records: evidence,
    },
    authoringManifest: {
      schemaVersion:
        "clinical_registry_machine_native_authoring_manifest_phase11_v1",
      semanticInference: "NONE",
      protocols: manifest,
      summary: {
        protocols: manifest.length,
        machineContentProtocolCoverage: 270,
        authoredContentDocs: content.length,
        protocolContentDocs: 270,
        classificationContentDocs:
          classificationContentCount,
        classificationAuthoringRequired: 270,
        managementAuthoringRequired: 270,
        actionAuthoringRequired: 270,
        legacyClassificationEvidence:
          classificationContentCount,
        legacyActionEvidence:
          manifest.filter(
            (row) =>
              row.action.legacyEvidencePresent,
          ).length,
      },
    },
  });
}

module.exports = {
  authorBulkMachineContent,
};
