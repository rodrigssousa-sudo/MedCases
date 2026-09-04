'use strict';

const {
  CONFIG_SCHEMA_VERSION,
} = require('./config_defaults');

function validateV2Config(config, registry) {
  const errors = [];

  if (!config || typeof config !== 'object') {
    return { ok: false, errors: ['config_missing'] };
  }

  if (config.schemaVersion !== CONFIG_SCHEMA_VERSION) {
    errors.push('invalid_schema_version');
  }

  if (typeof config.configVersion !== 'string' || !config.configVersion) {
    errors.push('missing_config_version');
  }

  if (config.clientOverrideAllowed !== false) {
    errors.push('client_override_must_be_false');
  }

  if (
    !config.rollout ||
    typeof config.rollout.percent !== 'number' ||
    config.rollout.percent < 0 ||
    config.rollout.percent > 100
  ) {
    errors.push('invalid_rollout_percent');
  }

  const aliases = config.aliases || {};
  for (const [slot, modelKey] of Object.entries(aliases)) {
    if (!registry[modelKey]) {
      errors.push(`unknown_model_registry_key:${slot}:${modelKey}`);
    }
  }

  const study = config.study || {};
  if (!study.privacyGuard || study.privacyGuard.enabled !== true) {
    errors.push('study_privacy_guard_required');
  }
  if (
    !study.privacyGuard ||
    study.privacyGuard.allowIdentifiableClinicalData !== false
  ) {
    errors.push('study_free_identifiable_data_must_be_false');
  }

  const studyPrimaryKey =
    aliases.study_primary;
  const studyPrimary =
    studyPrimaryKey ? registry[studyPrimaryKey] : null;
  if (
    studyPrimary &&
    studyPrimary.privacyClass === 'educational_non_identifiable_only' &&
    studyPrimary.identifiableClinicalDataAllowed !== false
  ) {
    errors.push('free_model_privacy_registry_violation');
  }

  const plantao = config.plantao || {};
  const routerKey = aliases[plantao.routerAlias];
  const routerModel = routerKey ? registry[routerKey] : null;
  if (!routerModel) {
    errors.push('plantao_router_missing');
  } else if (routerModel.respondsToUser !== false) {
    errors.push('plantao_router_must_not_respond_to_user');
  }

  if (plantao.routerMayRespondToUser !== false) {
    errors.push('plantao_router_response_guard_required');
  }

  if (!plantao.technicalFallback || !plantao.clinicalEscalation) {
    errors.push('fallback_and_escalation_must_be_separate');
  }

  if (
    plantao.technicalFallback &&
    plantao.technicalFallback.terraAllowed !== false
  ) {
    errors.push('terra_must_not_be_technical_fallback');
  }

  const complexKey = aliases[plantao.complexAlias];
  const complexModel = complexKey ? registry[complexKey] : null;
  if (!complexModel) {
    errors.push('plantao_complex_model_missing');
  } else {
    if (complexModel.clinicalEscalationOnly !== true) {
      errors.push('complex_model_must_be_clinical_escalation_only');
    }
    if (complexModel.technicalFallbackAllowed !== false) {
      errors.push('complex_model_technical_fallback_must_be_false');
    }
  }

  if (
    !config.telemetry ||
    config.telemetry.rawPromptLogging !== false ||
    config.telemetry.rawPatientTextLogging !== false
  ) {
    errors.push('raw_clinical_telemetry_must_be_disabled');
  }

  if (
    !config.telemetry ||
    config.telemetry.pseudonymousUserIdOnly !== true
  ) {
    errors.push('telemetry_pseudonymous_user_required');
  }

  if (config.enabled === true && config.legacyParityMode === true) {
    errors.push('v2_enabled_cannot_claim_legacy_parity_mode');
  }

  return {
    ok: errors.length === 0,
    errors,
  };
}

function validateRegistryNoSecrets(registry) {
  const forbidden = /api.?key|secret|password|bearer|credential/i;
  const serialized = JSON.stringify(registry);
  return {
    ok: !forbidden.test(serialized),
    errors: forbidden.test(serialized)
      ? ['registry_contains_secret_like_key']
      : [],
  };
}

function validateRegistryBindingsInactive(registry) {
  const errors = [];
  for (const [key, model] of Object.entries(registry)) {
    if (model.apiModelName !== null) {
      errors.push(`api_model_must_remain_unbound:${key}`);
    }
    if (model.bindingState !== 'unbound') {
      errors.push(`binding_state_must_be_unbound:${key}`);
    }
    if (model.enabled !== false) {
      errors.push(`model_must_start_disabled:${key}`);
    }
  }
  return { ok: errors.length === 0, errors };
}

module.exports = {
  validateV2Config,
  validateRegistryNoSecrets,
  validateRegistryBindingsInactive,
};
