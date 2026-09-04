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

function enumValues(value) {
  if (Array.isArray(value)) return value.map(String);
  if (value && typeof value === "object") {
    return Object.values(value).map(String);
  }
  return [];
}

function sha256(value) {
  return crypto
    .createHash("sha256")
    .update(
      typeof value === "string"
        ? value
        : JSON.stringify(value),
    )
    .digest("hex");
}

function walk(value, path = "$", out = []) {
  if (Array.isArray(value)) {
    value.forEach((child, index) => {
      walk(child, `${path}[${index}]`, out);
    });
    return out;
  }

  if (!value || typeof value !== "object") {
    return out;
  }

  out.push({ path, value });

  for (const [key, child] of Object.entries(value)) {
    walk(child, `${path}.${key}`, out);
  }

  return out;
}

function exactJoinKeys(value) {
  if (!value || typeof value !== "object") {
    return [];
  }

  return [
    value.protocolKey,
    value.canonicalPathologyKey,
    value.canonicalKey,
    value.pathologyKey,
    value.protocolId,
    value.sourceKey,
  ]
    .map(nonEmptyString)
    .filter(Boolean);
}

function machineMarkerValues(value) {
  if (!value || typeof value !== "object") {
    return {};
  }

  return {
    classificationMode:
      nonEmptyString(value.classificationMode) ||
      nonEmptyString(value.mode),
    actionKind:
      nonEmptyString(value.actionKind) ||
      nonEmptyString(value.kind),
    actionType:
      nonEmptyString(value.actionType) ||
      nonEmptyString(value.type),
    classificationKey:
      nonEmptyString(value.classificationKey),
    managementRuleKey:
      nonEmptyString(value.managementRuleKey),
    actionKey:
      nonEmptyString(value.actionKey),
    contentKey:
      nonEmptyString(value.contentKey),
    contentRef:
      nonEmptyString(value.contentRef),
    contentId:
      nonEmptyString(value.contentId),
  };
}

function hasExplicitUnambiguousProof(value, path) {
  if (!value || typeof value !== "object") {
    return false;
  }

  if (
    value.unambiguous === true ||
    value.unambiguousCompilation === true ||
    value.machineRuleInferencePerformed === false
  ) {
    return true;
  }

  return /(?:unambiguous|structuredProof|schemaProof)/i.test(
    path,
  );
}

function protocolMaps(phase7) {
  const byProtocol = new Map();
  const byPathology = new Map();

  for (const protocol of Array.isArray(phase7.protocols)
    ? phase7.protocols
    : []) {
    const p = nonEmptyString(protocol?.protocolKey);
    const c = nonEmptyString(
      protocol?.canonicalPathologyKey,
    );

    if (p) byProtocol.set(p, protocol);
    if (c) byPathology.set(c, protocol);
  }

  return { byProtocol, byPathology };
}

function resolveProtocolForCandidate(candidate, maps) {
  const keys = exactJoinKeys(candidate);
  const matches = new Set();

  for (const key of keys) {
    const p =
      maps.byProtocol.get(key) ||
      maps.byPathology.get(key) ||
      null;
    if (p) matches.add(p);
  }

  if (matches.size !== 1) {
    return null;
  }

  return [...matches][0];
}

function legacyRecordForProtocol(
  legacyCompatibility,
  protocol,
) {
  const records =
    legacyCompatibility?.recordsByPathology || {};

  const c = nonEmptyString(
    protocol?.canonicalPathologyKey,
  );

  return c ? records[c] || null : null;
}

function cloneWithIdentity(candidate, protocol) {
  const data = JSON.parse(JSON.stringify(candidate));

  if (
    !nonEmptyString(data.protocolKey) &&
    nonEmptyString(protocol?.protocolKey)
  ) {
    data.protocolKey = protocol.protocolKey;
  }

  if (
    !nonEmptyString(data.canonicalPathologyKey) &&
    nonEmptyString(protocol?.canonicalPathologyKey)
  ) {
    data.canonicalPathologyKey =
      protocol.canonicalPathologyKey;
  }

  return data;
}

function docId(type, data) {
  return (
    nonEmptyString(data?.classificationKey) ||
    nonEmptyString(data?.managementRuleKey) ||
    nonEmptyString(data?.actionKey) ||
    nonEmptyString(data?.contentKey) ||
    nonEmptyString(data?.id) ||
    [
      type,
      nonEmptyString(data?.canonicalPathologyKey) ||
        nonEmptyString(data?.protocolKey) ||
        sha256(data).slice(0, 16),
    ].join("::")
  );
}

function dedupeDocs(docs) {
  const byId = new Map();

  for (const doc of docs) {
    const hash = sha256(doc.data);
    const existing = byId.get(doc.id);

    if (!existing) {
      byId.set(doc.id, {
        ...doc,
        dataSha256: hash,
      });
      continue;
    }

    if (existing.dataSha256 !== hash) {
      byId.set(doc.id, {
        id: doc.id,
        ambiguous: true,
        reason: "same_document_id_different_payload",
        candidates: [
          existing,
          {
            ...doc,
            dataSha256: hash,
          },
        ],
      });
    }
  }

  const accepted = [];
  const ambiguous = [];

  for (const item of byId.values()) {
    if (item.ambiguous) {
      ambiguous.push(item);
    } else {
      accepted.push(item);
    }
  }

  return { accepted, ambiguous };
}

function compileMassGapfill({
  phase7,
  legacyCompatibility,
  schema,
} = {}) {
  const classificationModes = new Set(
    enumValues(schema?.CLASSIFICATION_MODES),
  );
  const actionKinds = new Set(
    enumValues(schema?.ACTION_KINDS),
  );
  const actionTypes = new Set(
    enumValues(schema?.ACTION_TYPES),
  );

  const maps = protocolMaps(phase7);

  const sources = {
    normalizedCandidateBundle:
      phase7?.normalizedCandidateBundle,
    structuredProofBundle:
      phase7?.structuredProofBundle,
    additionalOwnerProofBundle:
      phase7?.additionalOwnerProofBundle,
    schemaProofBundle:
      phase7?.schemaProofBundle,
    unambiguousCompilation:
      phase7?.unambiguousCompilation,
    legacyRecordsByPathology:
      legacyCompatibility?.recordsByPathology,
  };

  const classificationCandidates = [];
  const managementCandidates = [];
  const actionCandidates = [];
  const contentCandidates = [];
  const rejected = [];

  function consider(node, sourceName) {
    const { path, value } = node;
    const protocol =
      resolveProtocolForCandidate(value, maps);

    if (!protocol) {
      return;
    }

    const markers = machineMarkerValues(value);
    const proof =
      hasExplicitUnambiguousProof(value, path);

    const hasClassificationSignal = !!(
      markers.classificationKey ||
      markers.classificationMode
    );

    const classificationModeValid =
      markers.classificationMode &&
      classificationModes.has(
        markers.classificationMode,
      );

    if (hasClassificationSignal) {
      if (
        proof &&
        (
          markers.classificationKey ||
          classificationModeValid
        )
      ) {
        const data =
          cloneWithIdentity(value, protocol);

        classificationCandidates.push({
          id: docId("classification", data),
          data,
          evidence: {
            sourceName,
            sourcePath: path,
            proof: "STRUCTURAL_UNAMBIGUOUS",
          },
        });
      } else {
        rejected.push({
          type: "classification",
          sourceName,
          sourcePath: path,
          reason:
            "missing_unambiguous_proof_or_valid_classification_mode",
        });
      }
    }

    const hasManagementSignal = !!(
      markers.managementRuleKey ||
      nonEmptyString(value.managementDependency) ||
      nonEmptyString(value.dependencyKey) ||
      (
        value.dependencies &&
        typeof value.dependencies === "object"
      )
    );

    if (hasManagementSignal) {
      if (proof && markers.managementRuleKey) {
        const data =
          cloneWithIdentity(value, protocol);

        managementCandidates.push({
          id: docId("management", data),
          data,
          evidence: {
            sourceName,
            sourcePath: path,
            proof: "STRUCTURAL_UNAMBIGUOUS",
          },
        });
      } else {
        rejected.push({
          type: "management",
          sourceName,
          sourcePath: path,
          reason:
            "management_rule_key_or_unambiguous_proof_missing",
        });
      }
    }

    const hasActionSignal = !!(
      markers.actionKey ||
      markers.actionKind ||
      markers.actionType
    );

    const actionKindValid =
      markers.actionKind &&
      actionKinds.has(markers.actionKind);

    const actionTypeValid =
      markers.actionType &&
      actionTypes.has(markers.actionType);

    if (hasActionSignal) {
      if (
        proof &&
        (
          markers.actionKey ||
          actionKindValid ||
          actionTypeValid
        )
      ) {
        const data =
          cloneWithIdentity(value, protocol);

        actionCandidates.push({
          id: docId("action", data),
          data,
          evidence: {
            sourceName,
            sourcePath: path,
            proof: "STRUCTURAL_UNAMBIGUOUS",
          },
        });
      } else {
        rejected.push({
          type: "action",
          sourceName,
          sourcePath: path,
          reason:
            "missing_unambiguous_proof_or_valid_action_enum",
        });
      }
    }

    const hasContentSignal = !!(
      markers.contentKey ||
      markers.contentRef ||
      markers.contentId
    );

    if (hasContentSignal) {
      if (proof) {
        const data =
          cloneWithIdentity(value, protocol);

        contentCandidates.push({
          id: docId("content", data),
          data,
          evidence: {
            sourceName,
            sourcePath: path,
            proof: "STRUCTURAL_UNAMBIGUOUS",
          },
        });
      } else {
        rejected.push({
          type: "content",
          sourceName,
          sourcePath: path,
          reason: "unambiguous_proof_missing",
        });
      }
    }
  }

  for (const [sourceName, root] of Object.entries(sources)) {
    for (const node of walk(root, `$${sourceName}`)) {
      consider(node, sourceName);
    }
  }

  // Legacy payloads are inspected for exact machine markers only.
  // Localized classification/action payloads alone are not promoted.
  for (const protocol of Array.isArray(phase7.protocols)
    ? phase7.protocols
    : []) {
    const legacy =
      legacyRecordForProtocol(
        legacyCompatibility,
        protocol,
      );

    if (!legacy) continue;

    for (const node of walk(
      legacy,
      `$legacy.${protocol.canonicalPathologyKey}`,
    )) {
      consider(node, "legacyRecordsByPathology");
    }
  }

  const classification =
    dedupeDocs(classificationCandidates);
  const management =
    dedupeDocs(managementCandidates);
  const actions =
    dedupeDocs(actionCandidates);
  const content =
    dedupeDocs(contentCandidates);

  const supplement = {
    schemaVersion:
      "clinical_registry_machine_native_supplement_phase10_v1",
    semanticInference: "NONE",
    provenancePolicy:
      "STRUCTURAL_MACHINE_MARKERS_AND_UNAMBIGUOUS_PROOF_ONLY",
    classifications: classification.accepted,
    managementRules: management.accepted,
    actions: actions.accepted,
    content: content.accepted,
  };

  const ambiguity = [
    ...classification.ambiguous.map((x) => ({
      type: "classification",
      ...x,
    })),
    ...management.ambiguous.map((x) => ({
      type: "management",
      ...x,
    })),
    ...actions.ambiguous.map((x) => ({
      type: "action",
      ...x,
    })),
    ...content.ambiguous.map((x) => ({
      type: "content",
      ...x,
    })),
  ];

  const acceptedEvidence = [
    ...classification.accepted.map((x) => ({
      type: "classification",
      id: x.id,
      evidence: x.evidence,
    })),
    ...management.accepted.map((x) => ({
      type: "management",
      id: x.id,
      evidence: x.evidence,
    })),
    ...actions.accepted.map((x) => ({
      type: "action",
      id: x.id,
      evidence: x.evidence,
    })),
    ...content.accepted.map((x) => ({
      type: "content",
      id: x.id,
      evidence: x.evidence,
    })),
  ];

  const byPathology = {};

  for (const protocol of Array.isArray(phase7.protocols)
    ? phase7.protocols
    : []) {
    const c = nonEmptyString(
      protocol?.canonicalPathologyKey,
    );
    const p = nonEmptyString(protocol?.protocolKey);

    if (!c) continue;

    const matches = (docs) =>
      docs.filter((doc) => {
        const keys = exactJoinKeys(doc.data);
        return keys.includes(c) || (p && keys.includes(p));
      }).length;

    const legacy =
      legacyRecordForProtocol(
        legacyCompatibility,
        protocol,
      );

    const hasLegacyClassification = !!(
      legacy &&
      (
        legacy.classification != null ||
        legacy.classifications != null ||
        legacy.classificationEnvelope != null ||
        legacy.classificationLegacyEnvelope != null
      )
    );

    const hasLegacyActions = !!(
      legacy &&
      (
        legacy.actions != null ||
        legacy.action != null ||
        legacy.actionsEnvelope != null ||
        legacy.actionLegacyEnvelope != null
      )
    );

    byPathology[c] = {
      protocolKey: p,
      canonicalPathologyKey: c,
      legacyClassificationEnvelope:
        hasLegacyClassification,
      legacyActionEnvelope:
        hasLegacyActions,
      machineClassificationCount:
        matches(supplement.classifications),
      machineManagementCount:
        matches(supplement.managementRules),
      machineActionCount:
        matches(supplement.actions),
      machineContentCount:
        matches(supplement.content),
    };
  }

  const gaps = Object.values(byPathology).map((row) => ({
    ...row,
    missing: [
      ...(row.machineClassificationCount > 0
        ? []
        : ["classification"]),
      ...(row.machineManagementCount > 0
        ? []
        : ["management"]),
      ...(row.machineActionCount > 0
        ? []
        : ["action"]),
      ...(row.machineContentCount > 0
        ? []
        : ["content"]),
    ],
  }));

  return deepFreeze({
    supplement,
    evidence: {
      schemaVersion:
        "clinical_registry_machine_native_evidence_phase10_v1",
      semanticInference: "NONE",
      accepted: acceptedEvidence,
      ambiguous: ambiguity,
      rejected,
    },
    gapManifest: {
      schemaVersion:
        "clinical_registry_machine_native_gap_manifest_phase10_v1",
      semanticInference: "NONE",
      protocols: gaps,
      summary: {
        protocols: gaps.length,
        withMachineClassification:
          gaps.filter(
            (x) => x.machineClassificationCount > 0,
          ).length,
        withMachineManagement:
          gaps.filter(
            (x) => x.machineManagementCount > 0,
          ).length,
        withMachineAction:
          gaps.filter(
            (x) => x.machineActionCount > 0,
          ).length,
        withMachineContent:
          gaps.filter(
            (x) => x.machineContentCount > 0,
          ).length,
        legacyClassificationEnvelopes:
          gaps.filter(
            (x) => x.legacyClassificationEnvelope,
          ).length,
        legacyActionEnvelopes:
          gaps.filter(
            (x) => x.legacyActionEnvelope,
          ).length,
        ambiguousCandidateCount:
          ambiguity.length,
        rejectedCandidateCount:
          rejected.length,
      },
    },
  });
}

module.exports = {
  compileMassGapfill,
};
