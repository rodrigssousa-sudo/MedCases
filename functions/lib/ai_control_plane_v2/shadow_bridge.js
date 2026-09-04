'use strict';

const {
  CONTRACT_VERSION,
} = require('./contract');

const {
  adaptLegacyGeminiPaidProxyRequest,
} = require('./legacy_request_adapter');

const {
  getCachedV2ConfigState,
  refreshV2Config,
} = require('./config_reader');

const {
  SHADOW_ROUTER_MARKER,
  planStudyShadowRoute,
  planPlantaoShadowRoute,
  buildNextModelShadowTelemetry,
} = require('./next_model_shadow_routing_v1');

const TELEMETRY_MARKER = '[AI_CONTROL_PLANE_V2_SHADOW]';
const TELEMETRY_ERROR_MARKER = '[AI_CONTROL_PLANE_V2_SHADOW_ERROR]';

const NEXT_MODEL_SHADOW_TELEMETRY_ERROR_MARKER =
  '[AI_CONTROL_PLANE_V2_NEXT_MODEL_SHADOW_ROUTE_ERROR]';

const OBSERVATION_KEYS = Object.freeze([
  'contractVersion',
  'sourceContract',
  'adapted',
  'mode',
  'task',
  'configVersion',
  'configSource',
  'v2ConfigEnabled',
  'v2ExecutionAllowed',
  'ignoredClientRoutingHints',
  'shadowOnly',
  'livePath',
  'liveProviderOverride',
]);

function _buildObservation(rawBody, configState) {
  const adapted = adaptLegacyGeminiPaidProxyRequest(rawBody);

  const state =
    configState && typeof configState === 'object'
      ? configState
      : {};

  const config =
    state.config && typeof state.config === 'object'
      ? state.config
      : {};

  const request =
    adapted.ok === true && adapted.request
      ? adapted.request
      : null;

  return Object.freeze({
    contractVersion: CONTRACT_VERSION,
    sourceContract: 'geminiPaidProxy-v1',
    adapted: adapted.ok === true,
    mode: request ? request.mode : 'unknown',
    task: request ? request.task : 'unknown',
    configVersion:
      typeof config.configVersion === 'string'
        ? config.configVersion
        : '',
    configSource:
      typeof state.source === 'string'
        ? state.source
        : 'unknown',
    v2ConfigEnabled: config.enabled === true,
    v2ExecutionAllowed: state.executionAllowed === true,
    ignoredClientRoutingHints:
      adapted.metadata &&
      adapted.metadata.ignoredClientRoutingHints === true,
    shadowOnly: true,
    livePath: 'legacy_v1',
    liveProviderOverride: false,
  });
}

function _deriveStudyPrivacyState(request) {
  const flags =
    request &&
    request.context_flags &&
    typeof request.context_flags === 'object'
      ? request.context_flags
      : {};

  if (flags.sensitive_clinical_context_declared === true) {
    return 'sensitive_clinical_context';
  }

  if (flags.patient_context_present === true) {
    return 'patient_context';
  }

  // Backend observation cannot prove that arbitrary Study text is
  // educational + non-identifiable without inspecting/logging clinical text.
  // Fail safe: keep personal-free eligibility unknown/closed in backend shadow.
  return 'unknown';
}

function _buildNextModelShadowRouteTelemetry(rawBody) {
  const adapted = adaptLegacyGeminiPaidProxyRequest(rawBody);

  if (
    adapted.ok !== true ||
    !adapted.request ||
    typeof adapted.request !== 'object'
  ) {
    return null;
  }

  const request = adapted.request;

  if (request.mode === 'study') {
    return buildNextModelShadowTelemetry(
      planStudyShadowRoute({
        privacyState: _deriveStudyPrivacyState(request),
        personalFreeOutcome: 'backend_request_observed',
      })
    );
  }

  if (request.mode === 'plantao') {
    return buildNextModelShadowTelemetry(
      planPlantaoShadowRoute({
        technicalFailure: false,
        clinicalEscalation: false,
        terraAllowed: false,
      })
    );
  }

  return null;
}

function _assertObservationSchema(observation) {
  const actual = Object.keys(observation).sort();
  const expected = [...OBSERVATION_KEYS].sort();

  if (
    actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])
  ) {
    throw new Error('v2_shadow_observation_schema_violation');
  }
}

function observeLegacyRequestV2Shadow(
  rawBody,
  {
    firestore = null,
    env = process.env,
    logger = console.log,
    errorLogger = console.warn,
    nextModelLogger = null,
    nextModelErrorLogger = null,
    getStateFn = getCachedV2ConfigState,
    refreshFn = refreshV2Config,
  } = {}
) {
  const beforeJson = JSON.stringify(rawBody || null);

  const state = getStateFn();
  const observation = _buildObservation(rawBody, state);
  _assertObservationSchema(observation);

  let nextModelTelemetry = null;

  if (typeof nextModelLogger === 'function') {
    try {
      nextModelTelemetry =
        _buildNextModelShadowRouteTelemetry(rawBody);
    } catch (_) {
      if (typeof nextModelErrorLogger === 'function') {
        nextModelErrorLogger(
          NEXT_MODEL_SHADOW_TELEMETRY_ERROR_MARKER,
          JSON.stringify({
            code: 'next_model_shadow_route_failed',
            shadowOnly: true,
            liveExecutionAllowed: false,
            providerInferencePerformed: false,
          })
        );
      }
    }
  }

  const afterJson = JSON.stringify(rawBody || null);
  if (beforeJson !== afterJson) {
    throw new Error('v2_shadow_must_not_mutate_request_body');
  }

  logger(TELEMETRY_MARKER, JSON.stringify(observation));

  if (nextModelTelemetry) {
    nextModelLogger(
      SHADOW_ROUTER_MARKER,
      JSON.stringify(nextModelTelemetry)
    );
  }

  if (firestore && typeof firestore.collection === 'function') {
    Promise.resolve(
      refreshFn({
        firestore,
        env,
      })
    ).catch(() => {
      errorLogger(
        TELEMETRY_ERROR_MARKER,
        JSON.stringify({
          code: 'config_refresh_failed',
          shadowOnly: true,
          liveProviderOverride: false,
        })
      );
    });
  }

  return observation;
}

module.exports = {
  TELEMETRY_MARKER,
  TELEMETRY_ERROR_MARKER,
  NEXT_MODEL_SHADOW_TELEMETRY_ERROR_MARKER,
  OBSERVATION_KEYS,
  observeLegacyRequestV2Shadow,
};
