'use strict';

const {
  buildLegacyLiveParityPlan,
} = require('./legacy_live_parity_planner');

const {
  getCachedV2ConfigState,
} = require('./config_reader');

const {
  evaluateRolloutCohort,
} = require('./cohort_rollout');

const EXECUTION_MARKER = '[AI_CONTROL_PLANE_V2_EXECUTION_GATE]';

const EXECUTION_KEYS = Object.freeze([
  'authority',
  'gateOpen',
  'gateReason',
  'provider',
  'model',
  'temperature',
  'shadowOnly',
  'liveProviderOverride',
  'rolloutEligible',
]);

function _serverGateEnabled(env) {
  return (
    env &&
    env.AI_CONTROL_PLANE_V2_LEGACY_PARITY_EXECUTION_ENABLED === 'true'
  );
}

function resolveLegacyParityExecutionGate(
  rawBody,
  {
    uid,
    geminiPaidModel,
    env = process.env,
    configState = null,
  } = {}
) {
  const state =
    configState && typeof configState === 'object'
      ? configState
      : getCachedV2ConfigState();

  const config =
    state && state.config && typeof state.config === 'object'
      ? state.config
      : {};

  const flags =
    config.featureFlags && typeof config.featureFlags === 'object'
      ? config.featureFlags
      : {};

  const rollout =
    config.rollout && typeof config.rollout === 'object'
      ? config.rollout
      : {};

  let gateReason = 'open';
  let rolloutEligible = false;

  if (!_serverGateEnabled(env)) {
    gateReason = 'server_env_off';
  } else if (state.executionAllowed !== true) {
    gateReason = 'config_execution_not_allowed';
  } else if (config.enabled !== true) {
    gateReason = 'config_disabled';
  } else if (config.legacyParityMode !== false) {
    gateReason = 'legacy_parity_mode_not_released';
  } else if (config.clientOverrideAllowed !== false) {
    gateReason = 'client_override_guard_failed';
  } else if (flags.legacy_parity_execution_v2 !== true) {
    gateReason = 'feature_flag_off';
  } else {
    const cohort = evaluateRolloutCohort({
      uid,
      cohortSaltVersion: rollout.cohortSaltVersion,
      percent: rollout.percent,
    });

    rolloutEligible = cohort.eligible === true;

    if (!rolloutEligible) {
      gateReason = cohort.reason;
    }
  }

  const gateOpen = gateReason === 'open';

  const plan = buildLegacyLiveParityPlan(rawBody, {
    geminiPaidModel,
  });

  if (!gateOpen) {
    return Object.freeze({
      authority: 'legacy_v1',
      gateOpen: false,
      gateReason,
      provider: null,
      model: null,
      temperature: null,
      shadowOnly: true,
      liveProviderOverride: false,
      rolloutEligible,
    });
  }

  return Object.freeze({
    authority: 'v2_legacy_parity',
    gateOpen: true,
    gateReason: 'open',
    provider: plan.plannedProvider,
    model: plan.plannedModel,
    temperature: plan.plannedTemperature,
    shadowOnly: false,
    liveProviderOverride: true,
    rolloutEligible: true,
  });
}

function observeExecutionGate(
  rawBody,
  {
    uid,
    geminiPaidModel,
    env = process.env,
    configState = null,
    logger = console.log,
  } = {}
) {
  const decision = resolveLegacyParityExecutionGate(rawBody, {
    uid,
    geminiPaidModel,
    env,
    configState,
  });

  logger(EXECUTION_MARKER, JSON.stringify(decision));
  return decision;
}

module.exports = {
  EXECUTION_MARKER,
  EXECUTION_KEYS,
  resolveLegacyParityExecutionGate,
  observeExecutionGate,
};
