'use strict';

/**
 * MedCases AI Remote Control Plane — Shadow V1.
 *
 * IMPORTANT:
 * - This module does NOT call any provider.
 * - It does NOT change the live model/provider used by a request.
 * - It contains no patient text in telemetry.
 * - Its only job is to calculate the future remote routing decision.
 *
 * The names below are control-plane route identifiers. They are not assumed
 * to be public provider model IDs until a later activation phase binds them.
 */

const CONTRACT_VERSION = 'medcases-ai-control-plane-shadow-v1';

const ROUTES = Object.freeze({
  study: Object.freeze({
    routeId: 'study_v1',
    classifier: null,
    responseOrder: Object.freeze([
      'gemini_3_1_flash_lite_free',
      'gpt_5_nano',
      'gemini_3_1_flash_lite_paid',
    ]),
    hardCaseModel: null,
  }),
  plantao: Object.freeze({
    routeId: 'plantao_v1',
    classifier: 'gpt_5_nano',
    responseOrder: Object.freeze([
      'gpt_5_6_luna',
      'gemini_3_1_flash_lite_paid',
    ]),
    hardCaseModel: 'gpt_5_6_terra',
  }),
  unknown: Object.freeze({
    routeId: 'unknown_v1',
    classifier: null,
    responseOrder: Object.freeze([]),
    hardCaseModel: null,
  }),
});

function _asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value
    : {};
}

function _firstString(values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }
  return '';
}

function _extractPayload(input) {
  const root = _asObject(input);
  const data = _asObject(root.data);
  const body = _asObject(root.body);
  return Object.keys(data).length
    ? data
    : Object.keys(body).length
      ? body
      : root;
}

function _normalizeMode(input) {
  const payload = _extractPayload(input);
  const context = _asObject(payload.context);
  const metadata = _asObject(payload.metadata);
  const options = _asObject(payload.options);

  const raw = _firstString([
    payload.mode,
    payload.appMode,
    payload.aiMode,
    payload.assistantMode,
    payload.workspaceMode,
    context.mode,
    metadata.mode,
    options.mode,
  ]).toLowerCase();

  if (
    raw.includes('plantao') ||
    raw.includes('plantão') ||
    raw.includes('guardia') ||
    raw.includes('emergency') ||
    raw.includes('urgencia') ||
    raw.includes('urgência')
  ) {
    return 'plantao';
  }

  if (
    raw.includes('study') ||
    raw.includes('estudo') ||
    raw.includes('estudio')
  ) {
    return 'study';
  }

  return 'unknown';
}

function _routeFromRemoteConfigV1(mode, remoteConfig) {
  const cfg = _asObject(remoteConfig);

  // Remote config is allowed to change shadow decisions only.
  // `enabled` is intentionally ignored until a future live-activation phase.
  if (cfg.shadowEnabled !== true) {
    return null;
  }

  const modes = _asObject(cfg.modes);
  const candidate = _asObject(modes[mode]);
  const responseOrder = Array.isArray(candidate.responseOrder)
    ? candidate.responseOrder
        .filter((x) => typeof x === 'string' && x.trim())
        .slice(0, 8)
    : [];

  if (
    typeof candidate.routeId !== 'string' ||
    !candidate.routeId.trim() ||
    responseOrder.length === 0
  ) {
    return null;
  }

  return {
    routeId: candidate.routeId.trim(),
    classifier:
      typeof candidate.classifier === 'string'
        ? candidate.classifier.trim() || null
        : null,
    responseOrder,
    hardCaseModel:
      typeof candidate.hardCaseModel === 'string'
        ? candidate.hardCaseModel.trim() || null
        : null,
  };
}

function resolveRemoteAiRouteShadowV1(input, remoteConfig = null) {
  const mode = _normalizeMode(input);
  const route =
    _routeFromRemoteConfigV1(mode, remoteConfig) ||
    ROUTES[mode] ||
    ROUTES.unknown;

  return Object.freeze({
    contractVersion: CONTRACT_VERSION,
    mode,
    routeId: route.routeId,
    classifier: route.classifier,
    responseOrder: [...route.responseOrder],
    hardCaseModel: route.hardCaseModel,
    shadowOnly: true,
    liveProviderOverride: false,
  });
}

function toRemoteAiRouteShadowTelemetryV1(decision) {
  const safe = _asObject(decision);
  return {
    contractVersion: safe.contractVersion || CONTRACT_VERSION,
    mode: safe.mode || 'unknown',
    routeId: safe.routeId || 'unknown_v1',
    classifier:
      typeof safe.classifier === 'string' ? safe.classifier : null,
    responseOrder: Array.isArray(safe.responseOrder)
      ? safe.responseOrder.filter((x) => typeof x === 'string').slice(0, 8)
      : [],
    hardCaseModel:
      typeof safe.hardCaseModel === 'string' ? safe.hardCaseModel : null,
    shadowOnly: true,
    liveProviderOverride: false,
  };
}

function shouldEmitRemoteAiRouteShadowV1(remoteConfig = null) {
  const envEnabled = String(
    process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED || 'true',
  ).toLowerCase() !== 'false';

  if (!envEnabled) {
    return false;
  }

  // Fail closed on cold start or config-read failure: shadow telemetry
  // is OFF until a valid server-side config explicitly says
  // shadowEnabled=true. This guarantees a remote kill switch is honored
  // from the first observable shadow emission of an instance.
  const cfg = _asObject(remoteConfig);
  if (
    !Object.prototype.hasOwnProperty.call(cfg, 'shadowEnabled') ||
    cfg.shadowEnabled !== true
  ) {
    return false;
  }

  return true;
}

module.exports = {
  CONTRACT_VERSION,
  ROUTES,
  resolveRemoteAiRouteShadowV1,
  toRemoteAiRouteShadowTelemetryV1,
  shouldEmitRemoteAiRouteShadowV1,
};
