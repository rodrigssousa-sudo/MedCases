"use strict";

const {
  ClinicalRegistryAdapter,
} = require("./clinical_registry_adapter");
const {
  ClinicalActionRegistryAdapter,
} = require("./clinical_action_registry_adapter");
const {
  ClinicalContextCutoverGate,
} = require("./clinical_context_cutover_gate");
const {
  ClinicalContextEndpointAdapter,
} = require("./clinical_context_endpoint_adapter");
const {
  ClinicalContentRegistryReader,
  createReadOnlyClinicalDbFacade,
} = require("./clinical_context_firestore_readers");

function createClinicalContextBackendIntegration({
  db,
  cutoverConfig = {},
} = {}) {
  const readOnlyDb = createReadOnlyClinicalDbFacade(db);

  const registryAdapter = new ClinicalRegistryAdapter({
    db: readOnlyDb,
  });

  const actionAdapter = new ClinicalActionRegistryAdapter({
    db: readOnlyDb,
  });

  const contentReader = new ClinicalContentRegistryReader({
    db: readOnlyDb,
  });

  const cutoverGate = new ClinicalContextCutoverGate({
    enabled: cutoverConfig.enabled === true,
    allowedModes: Array.isArray(cutoverConfig.allowedModes)
      ? cutoverConfig.allowedModes
      : ["plantao"],
    allowedUserIds: Array.isArray(cutoverConfig.allowedUserIds)
      ? cutoverConfig.allowedUserIds
      : [],
    allowedPercent: Number(cutoverConfig.allowedPercent || 0),
  });

  const endpoint = new ClinicalContextEndpointAdapter({
    registryLoader: () => registryAdapter.loadSnapshot(),
    actionLoader: () => actionAdapter.loadActions(),
    contentLoader: (contentRef) => contentReader.loadContentRef(contentRef),
    cutoverGate,
  });

  return Object.freeze({
    endpoint,
    cutoverGate,
    registryAdapter,
    actionAdapter,
    contentReader,
  });
}

module.exports = {
  createClinicalContextBackendIntegration,
};
