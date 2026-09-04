"use strict";

const {
  REQUIRED_KEYS,
  CLASSIFICATION_MODES,
  ACTION_TYPES,
  ACTION_KINDS,
} = require("./clinical_registry_schema");

function validateRegistrySeed(seed) {
  const errors = [];
  const warnings = [];

  const identities = asArray(seed?.identities);
  const protocols = asArray(seed?.protocols);
  const classifications = asArray(seed?.classifications);
  const managementRules = asArray(seed?.managementRules);
  const actions = asArray(seed?.actions);
  const content = asArray(seed?.content);

  validateRequired("identity", identities, REQUIRED_KEYS.identity, errors);
  validateRequired("protocol", protocols, REQUIRED_KEYS.protocol, errors);
  validateRequired(
    "classification",
    classifications,
    REQUIRED_KEYS.classification,
    errors,
  );
  validateRequired(
    "managementRule",
    managementRules,
    REQUIRED_KEYS.managementRule,
    errors,
  );
  validateRequired("action", actions, REQUIRED_KEYS.action, errors);
  validateRequired("content", content, REQUIRED_KEYS.content, errors);

  uniqueBy(identities, "canonicalKey", "identity", errors);
  uniqueBy(protocols, "protocolKey", "protocol", errors);
  uniqueBy(classifications, "classificationKey", "classification", errors);
  uniqueBy(managementRules, "managementRuleKey", "managementRule", errors);
  uniqueBy(actions, "actionKey", "action", errors);
  uniqueBy(content, "contentKey", "content", errors);

  const identityKeys = new Set(
    identities.map((x) => String(x.canonicalKey || "")).filter(Boolean),
  );
  const classificationKeys = new Set(
    classifications
      .map((x) => String(x.classificationKey || ""))
      .filter(Boolean),
  );
  const managementKeys = new Set(
    managementRules
      .map((x) => String(x.managementRuleKey || ""))
      .filter(Boolean),
  );
  const contentKeys = new Set(
    content.map((x) => String(x.contentKey || "")).filter(Boolean),
  );

  for (const protocol of protocols) {
    const pathologyKey = String(protocol.canonicalPathologyKey || "");
    if (pathologyKey && !identityKeys.has(pathologyKey)) {
      errors.push(`protocol_unknown_identity:${pathologyKey}`);
    }
  }

  for (const descriptor of classifications) {
    const pathologyKey = String(descriptor.canonicalPathologyKey || "");
    if (pathologyKey && !identityKeys.has(pathologyKey)) {
      errors.push(`classification_unknown_identity:${pathologyKey}`);
    }

    const mode = String(descriptor.mode || "").toLowerCase();
    if (!CLASSIFICATION_MODES.includes(mode)) {
      errors.push(`classification_invalid_mode:${mode}`);
    }
  }

  for (const rule of managementRules) {
    const pathologyKey = String(rule.canonicalPathologyKey || "");
    if (pathologyKey && !identityKeys.has(pathologyKey)) {
      errors.push(`management_unknown_identity:${pathologyKey}`);
    }

    const dependencyKey = String(rule.dependsOn?.classificationKey || "");
    if (dependencyKey && !classificationKeys.has(dependencyKey)) {
      errors.push(`management_unknown_classification:${dependencyKey}`);
    }
  }

  for (const action of actions) {
    const type = String(action.actionType || "");
    if (!ACTION_TYPES.includes(type)) {
      errors.push(`action_invalid_type:${type}`);
    }

    const kind = String(action.kind || "");
    if (!ACTION_KINDS.includes(kind)) {
      errors.push(`action_invalid_kind:${kind}`);
    }

    const match = action.match || {};
    const pathologyKey = String(match.canonicalPathologyKey || "");
    const classificationKey = String(match.classificationKey || "");
    const managementRuleKey = String(match.managementRuleKey || "");

    if (pathologyKey && !identityKeys.has(pathologyKey)) {
      errors.push(`action_unknown_identity:${pathologyKey}`);
    }
    if (classificationKey && !classificationKeys.has(classificationKey)) {
      errors.push(`action_unknown_classification:${classificationKey}`);
    }
    if (managementRuleKey && !managementKeys.has(managementRuleKey)) {
      errors.push(`action_unknown_management:${managementRuleKey}`);
    }

    if (type === "dispatch_prompt") {
      const prompts = action.prompts || {};
      if (!hasLocalizedValue(prompts)) {
        errors.push(`action_prompt_missing:${String(action.actionKey || "")}`);
      }
    }

    if (type === "open_content_ref") {
      const ref = String(action.contentRef || "");
      if (!ref) {
        errors.push(
          `action_content_ref_missing:${String(action.actionKey || "")}`,
        );
      } else if (!contentKeys.has(ref)) {
        errors.push(`action_unknown_content_ref:${ref}`);
      }
    }
  }

  for (const identity of identities) {
    const aliases = [
      ...(Array.isArray(identity.aliases) ? identity.aliases : []),
      ...(Array.isArray(identity.strongAliases)
        ? identity.strongAliases
        : []),
    ];
    if (!aliases.length) {
      warnings.push(`identity_without_aliases:${identity.canonicalKey || ""}`);
    }
  }

  return Object.freeze({
    ok: errors.length === 0,
    errors: Object.freeze([...new Set(errors)]),
    warnings: Object.freeze([...new Set(warnings)]),
    counts: Object.freeze({
      identities: identities.length,
      protocols: protocols.length,
      classifications: classifications.length,
      managementRules: managementRules.length,
      actions: actions.length,
      content: content.length,
    }),
  });
}

function validateRequired(type, rows, keys, errors) {
  rows.forEach((row, index) => {
    for (const key of keys) {
      if (row?.[key] == null || String(row[key]).trim() === "") {
        errors.push(`${type}_missing_${key}:${index}`);
      }
    }
  });
}

function uniqueBy(rows, key, type, errors) {
  const seen = new Set();
  for (const row of rows) {
    const value = String(row?.[key] || "");
    if (!value) continue;
    if (seen.has(value)) {
      errors.push(`${type}_duplicate_${key}:${value}`);
    }
    seen.add(value);
  }
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function hasLocalizedValue(value) {
  if (!value || typeof value !== "object") return false;
  return ["es", "pt", "en"].some(
    (key) => String(value[key] || "").trim().length > 0,
  );
}

module.exports = {
  validateRegistrySeed,
};
