"use strict";

const COLLECTIONS = Object.freeze({
  identities: "clinical_identity_registry",
  protocols: "clinical_protocols",
  classifications: "clinical_classification_registry",
  managementRules: "clinical_management_rules",
  actions: "clinical_action_registry",
  content: "clinical_content_registry",
});

const REQUIRED_KEYS = Object.freeze({
  identity: Object.freeze([
    "canonicalKey",
    "enabled",
    "priority",
    "version",
  ]),
  protocol: Object.freeze([
    "protocolKey",
    "canonicalPathologyKey",
    "enabled",
    "priority",
    "version",
  ]),
  classification: Object.freeze([
    "classificationKey",
    "canonicalPathologyKey",
    "mode",
    "enabled",
    "priority",
    "version",
  ]),
  managementRule: Object.freeze([
    "managementRuleKey",
    "canonicalPathologyKey",
    "enabled",
    "priority",
    "version",
  ]),
  action: Object.freeze([
    "actionKey",
    "kind",
    "actionType",
    "enabled",
    "priority",
    "version",
  ]),
  content: Object.freeze([
    "contentKey",
    "enabled",
    "version",
  ]),
});

const CLASSIFICATION_MODES = Object.freeze([
  "categorical",
  "score",
  "stage",
]);

const ACTION_TYPES = Object.freeze([
  "dispatch_prompt",
  "open_content_ref",
]);

const ACTION_KINDS = Object.freeze([
  "primary",
  "classification",
  "score",
  "stage",
]);

module.exports = {
  COLLECTIONS,
  REQUIRED_KEYS,
  CLASSIFICATION_MODES,
  ACTION_TYPES,
  ACTION_KINDS,
};
