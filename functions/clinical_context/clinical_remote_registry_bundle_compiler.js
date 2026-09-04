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

function sha256Json(value) {
  return crypto
    .createHash("sha256")
    .update(JSON.stringify(value))
    .digest("hex");
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function nonEmptyString(value) {
  return typeof value === "string" && value.trim()
    ? value.trim()
    : null;
}

function idFromDoc(doc, index, prefix) {
  for (const key of [
    "id",
    "classificationKey",
    "managementRuleKey",
    "actionKey",
    "contentKey",
    "protocolKey",
    "canonicalPathologyKey",
    "canonicalKey",
    "key",
  ]) {
    const value = nonEmptyString(doc?.[key]);
    if (value) return value;
  }
  return `${prefix}_${index + 1}`;
}

function normalizeDocs(value, prefix) {
  return asArray(value).map((data, index) => ({
    id: idFromDoc(data, index, prefix),
    data,
  }));
}

function uniqueDocIds(docs, label) {
  const ids = new Set(docs.map((doc) => doc.id));
  if (ids.size !== docs.length) {
    throw new Error(`duplicate_${label}_document_id`);
  }
}

function normalizeLegacyCompatibility(compat) {
  const recordsByPathology =
    compat?.recordsByPathology &&
    typeof compat.recordsByPathology === "object" &&
    !Array.isArray(compat.recordsByPathology)
      ? compat.recordsByPathology
      : {};

  const classifications = [];
  const actions = [];
  const protocols = [];

  for (const [pathologyKey, record] of Object.entries(
    recordsByPathology,
  )) {
    if (!record || typeof record !== "object") {
      continue;
    }

    const classification =
      record.classification ??
      record.classifications ??
      record.classificationEnvelope ??
      record.classificationLegacyEnvelope ??
      null;

    if (classification != null) {
      classifications.push({
        pathologyKey,
        payload: classification,
      });
    }

    const action =
      record.actions ??
      record.action ??
      record.actionsEnvelope ??
      record.actionLegacyEnvelope ??
      null;

    if (action != null) {
      actions.push({
        pathologyKey,
        payload: action,
      });
    }

    protocols.push({
      pathologyKey,
      record,
    });
  }

  return {
    recordsByPathology,
    classifications,
    actions,
    protocols,
  };
}

function compileRemoteRegistryBundle({
  phase7,
  legacyCompatibility,
  machineNativeSupplement = null,
} = {}) {
  if (!phase7 || typeof phase7 !== "object") {
    throw new Error("phase7_seed_required");
  }

  if (
    !legacyCompatibility ||
    typeof legacyCompatibility !== "object"
  ) {
    throw new Error("legacy_compatibility_required");
  }

  const identities = normalizeDocs(
    phase7.identities,
    "identity",
  );
  const protocols = normalizeDocs(
    phase7.protocols,
    "protocol",
  );

  if (identities.length !== 270) {
    throw new Error(
      `identity_count_mismatch:${identities.length}`,
    );
  }

  if (protocols.length !== 270) {
    throw new Error(
      `protocol_count_mismatch:${protocols.length}`,
    );
  }

  uniqueDocIds(identities, "identity");
  uniqueDocIds(protocols, "protocol");

  const supplement =
    machineNativeSupplement &&
    typeof machineNativeSupplement === "object"
      ? machineNativeSupplement
      : {};

  const machineClassifications = [
    ...normalizeDocs(
      phase7.classifications,
      "classification",
    ),
    ...normalizeDocs(
      Array.isArray(supplement.classifications)
        ? supplement.classifications.map(
            (item) => item?.data ?? item,
          )
        : [],
      "classification",
    ),
  ];

  const machineManagement = [
    ...normalizeDocs(
      phase7.managementRules,
      "management",
    ),
    ...normalizeDocs(
      Array.isArray(supplement.managementRules)
        ? supplement.managementRules.map(
            (item) => item?.data ?? item,
          )
        : [],
      "management",
    ),
  ];

  const machineActions = [
    ...normalizeDocs(
      phase7.actions,
      "action",
    ),
    ...normalizeDocs(
      Array.isArray(supplement.actions)
        ? supplement.actions.map(
            (item) => item?.data ?? item,
          )
        : [],
      "action",
    ),
  ];

  const machineContent = [
    ...normalizeDocs(
      phase7.content,
      "content",
    ),
    ...normalizeDocs(
      Array.isArray(supplement.content)
        ? supplement.content.map(
            (item) => item?.data ?? item,
          )
        : [],
      "content",
    ),
  ];

  uniqueDocIds(
    machineClassifications,
    "classification",
  );
  uniqueDocIds(
    machineManagement,
    "management",
  );
  uniqueDocIds(
    machineActions,
    "action",
  );
  uniqueDocIds(
    machineContent,
    "content",
  );

  const compatibility =
    normalizeLegacyCompatibility(legacyCompatibility);

  return deepFreeze({
    schemaVersion:
      "clinical_registry_remote_bundle_phase9_v1",
    semanticInference: "NONE",
    collections: {
      identities,
      protocols,
      machineClassifications,
      machineManagement,
      machineActions,
      machineContent,
      legacyCompatibility: compatibility,
    },
    counts: {
      identities: identities.length,
      protocols: protocols.length,
      machineClassifications:
        machineClassifications.length,
      machineManagement:
        machineManagement.length,
      machineActions:
        machineActions.length,
      machineContent:
        machineContent.length,
      legacyCompatibilityRecords:
        Object.keys(
          compatibility.recordsByPathology,
        ).length,
      legacyClassificationEnvelopes:
        compatibility.classifications.length,
      legacyActionEnvelopes:
        compatibility.actions.length,
      legacyProtocolCompatibility:
        compatibility.protocols.length,
    },
  });
}

function protocolJoinKeys(protocol) {
  return new Set(
    [
      protocol?.data?.protocolKey,
      protocol?.data?.canonicalPathologyKey,
      protocol?.data?.canonicalKey,
    ]
      .map(nonEmptyString)
      .filter(Boolean),
  );
}

function documentJoinKeys(doc) {
  const data = doc?.data || {};
  return new Set(
    [
      data.protocolKey,
      data.canonicalPathologyKey,
      data.canonicalKey,
      data.pathologyKey,
      data.sourceKey,
      data.protocolId,
    ]
      .map(nonEmptyString)
      .filter(Boolean),
  );
}

function docsMatchingProtocol(docs, protocol) {
  const pkeys = protocolJoinKeys(protocol);
  if (pkeys.size === 0) return [];
  return docs.filter((doc) => {
    const dkeys = documentJoinKeys(doc);
    return [...dkeys].some((key) => pkeys.has(key));
  });
}

function buildMachineNativeCoverage({
  phase7,
  legacyCompatibility,
  machineNativeSupplement = null,
} = {}) {
  const bundle = compileRemoteRegistryBundle({
    phase7,
    legacyCompatibility,
    machineNativeSupplement,
  });

  const compat = bundle.collections.legacyCompatibility;

  const rows = bundle.collections.protocols.map(
    (protocol) => {
      const data = protocol.data;
      const protocolKey =
        nonEmptyString(data?.protocolKey);
      const canonicalPathologyKey =
        nonEmptyString(
          data?.canonicalPathologyKey,
        );

      const legacyRecord =
        canonicalPathologyKey
          ? compat.recordsByPathology[
              canonicalPathologyKey
            ] || null
          : null;

      const cls = docsMatchingProtocol(
        bundle.collections.machineClassifications,
        protocol,
      );
      const mgmt = docsMatchingProtocol(
        bundle.collections.machineManagement,
        protocol,
      );
      const actions = docsMatchingProtocol(
        bundle.collections.machineActions,
        protocol,
      );
      const content = docsMatchingProtocol(
        bundle.collections.machineContent,
        protocol,
      );

      return {
        protocolKey,
        canonicalPathologyKey,
        hasLegacyCompatibilityRecord:
          legacyRecord != null,
        machineClassificationReady:
          cls.length > 0,
        machineManagementReady:
          mgmt.length > 0,
        machineActionReady:
          actions.length > 0,
        machineContentReady:
          content.length > 0,
        machineClassificationCount: cls.length,
        machineManagementCount: mgmt.length,
        machineActionCount: actions.length,
        machineContentCount: content.length,
      };
    },
  );

  const countRows = (field) =>
    rows.filter((row) => row[field] === true).length;

  return deepFreeze({
    schemaVersion:
      "clinical_registry_machine_native_coverage_phase9_v1",
    semanticInference: "NONE",
    rows,
    summary: {
      protocols: rows.length,
      protocolsWithLegacyCompatibility:
        countRows("hasLegacyCompatibilityRecord"),
      protocolsWithMachineClassification:
        countRows("machineClassificationReady"),
      protocolsWithMachineManagement:
        countRows("machineManagementReady"),
      protocolsWithMachineAction:
        countRows("machineActionReady"),
      protocolsWithMachineContent:
        countRows("machineContentReady"),
      machineClassificationDocs:
        bundle.counts.machineClassifications,
      machineManagementDocs:
        bundle.counts.machineManagement,
      machineActionDocs:
        bundle.counts.machineActions,
      machineContentDocs:
        bundle.counts.machineContent,
      legacyCompatibilityRecords:
        bundle.counts.legacyCompatibilityRecords,
      legacyClassificationEnvelopes:
        bundle.counts.legacyClassificationEnvelopes,
      legacyActionEnvelopes:
        bundle.counts.legacyActionEnvelopes,
    },
  });
}

function appendDryRunOps(
  operations,
  logicalCollection,
  docs,
) {
  for (const doc of docs) {
    operations.push({
      operation: "UPSERT_DRYRUN",
      logicalCollection,
      documentId: String(doc.id),
      dataSha256: sha256Json(doc.data),
    });
  }
}

function buildFirestoreDryRunPlan(bundle) {
  const operations = [];

  appendDryRunOps(
    operations,
    "identities",
    bundle.collections.identities,
  );
  appendDryRunOps(
    operations,
    "protocols",
    bundle.collections.protocols,
  );
  appendDryRunOps(
    operations,
    "classifications",
    bundle.collections.machineClassifications,
  );
  appendDryRunOps(
    operations,
    "managementRules",
    bundle.collections.machineManagement,
  );
  appendDryRunOps(
    operations,
    "actions",
    bundle.collections.machineActions,
  );
  appendDryRunOps(
    operations,
    "content",
    bundle.collections.machineContent,
  );

  return deepFreeze({
    schemaVersion:
      "clinical_registry_firestore_write_plan_phase9_v1",
    executionMode: "DRYRUN_ONLY",
    firebaseWriteAuthorized: false,
    deployAuthorized: false,
    remoteConfigWriteAuthorized: false,
    semanticInference: "NONE",
    operations,
    counts: {
      totalDryRunOperations: operations.length,
      identityOperations:
        bundle.counts.identities,
      protocolOperations:
        bundle.counts.protocols,
      machineClassificationOperations:
        bundle.counts.machineClassifications,
      machineManagementOperations:
        bundle.counts.machineManagement,
      machineActionOperations:
        bundle.counts.machineActions,
      machineContentOperations:
        bundle.counts.machineContent,
    },
  });
}

function buildShadowReadiness({
  bundle,
  coverage,
  appTransportReady,
  backendIdentityProtocolReady,
} = {}) {
  const protocolCount =
    coverage?.summary?.protocols || 0;

  const fullClassification =
    coverage?.summary
      ?.protocolsWithMachineClassification ===
    protocolCount;

  const fullManagement =
    coverage?.summary
      ?.protocolsWithMachineManagement ===
    protocolCount;

  const fullAction =
    coverage?.summary
      ?.protocolsWithMachineAction ===
    protocolCount;

  const fullContent =
    coverage?.summary
      ?.protocolsWithMachineContent ===
    protocolCount;

  const machineNativeComplete =
    protocolCount === 270 &&
    fullClassification &&
    fullManagement &&
    fullAction &&
    fullContent;

  // Non-visible shadow observation does not require complete clinical
  // cutover semantics. It only requires stable identity/protocol resolution
  // plus deterministic machine action and content coverage. Classification
  // and management remain required for visible/full machine-native cutover.
  const shadowObservationReady =
    appTransportReady === true &&
    backendIdentityProtocolReady === true &&
    bundle.counts.identities === 270 &&
    bundle.counts.protocols === 270 &&
    fullAction &&
    fullContent;

  return deepFreeze({
    schemaVersion:
      "clinical_context_shadow_activation_readiness_phase9_v1",
    appStructuredIdentityTransportReady:
      appTransportReady === true,
    backendIdentityProtocolReady:
      backendIdentityProtocolReady === true,
    remoteIdentityRegistryReady:
      bundle.counts.identities === 270,
    remoteProtocolRegistryReady:
      bundle.counts.protocols === 270,
    machineClassificationRegistryReady:
      bundle.counts.machineClassifications > 0,
    machineManagementRegistryReady:
      bundle.counts.machineManagement > 0,
    machineActionRegistryReady:
      bundle.counts.machineActions > 0,
    machineContentRegistryReady:
      bundle.counts.machineContent > 0,
    fullClassificationCoverage:
      fullClassification,
    fullManagementCoverage:
      fullManagement,
    fullActionCoverage:
      fullAction,
    fullContentCoverage:
      fullContent,
    machineNativeComplete,
    shadowObservationReady,
    shadowObservationAuthorized: false,
    firebaseWriteAuthorized: false,
    deployAuthorized: false,
    remoteConfigWriteAuthorized: false,
    runtimeActivationAuthorized: false,
    shadowActivationAuthorized: false,
    visibleCutoverAuthorized: false,
    shadowActivationReady:
      appTransportReady === true &&
      backendIdentityProtocolReady === true &&
      bundle.counts.identities === 270 &&
      bundle.counts.protocols === 270 &&
      machineNativeComplete,
    blocker:
      machineNativeComplete
        ? "firebase_write_and_activation_not_authorized"
        : "machine_native_protocol_coverage_incomplete",
  });
}

module.exports = {
  compileRemoteRegistryBundle,
  buildMachineNativeCoverage,
  buildFirestoreDryRunPlan,
  buildShadowReadiness,
};
