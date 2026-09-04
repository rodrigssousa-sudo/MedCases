"use strict";

const {
  ClinicalRegistryAdapter,
} = require("./clinical_registry_adapter");
const {
  ClinicalActionRegistryAdapter,
} = require("./clinical_action_registry_adapter");
const {
  ClinicalContentRegistryReader,
  createReadOnlyClinicalDbFacade,
} = require("./clinical_context_firestore_readers");
const {
  validateRegistrySeed,
} = require("./clinical_registry_seed_validator");

async function exportClinicalRegistrySeed({
  db,
  asOf,
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

  const [snapshot, actions, content] = await Promise.all([
    registryAdapter.loadSnapshot({ asOf }),
    actionAdapter.loadActions({ asOf }),
    contentReader.loadAll(),
  ]);

  const seed = Object.freeze({
    exportedAt: new Date().toISOString(),
    identities: snapshot.identities,
    protocols: snapshot.protocols,
    classifications: snapshot.classifications,
    managementRules: snapshot.managementRules,
    actions,
    content,
  });

  const validation = validateRegistrySeed(seed);

  return Object.freeze({
    seed,
    validation,
  });
}

module.exports = {
  exportClinicalRegistrySeed,
};
