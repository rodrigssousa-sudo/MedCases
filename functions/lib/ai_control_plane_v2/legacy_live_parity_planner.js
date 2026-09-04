'use strict';

/**
 * Mirrors the CURRENT live selection semantics of geminiPaidProxy.
 *
 * This module is a parity planner only:
 * - no provider calls
 * - no response writes
 * - no request mutation
 * - no Firebase writes
 * - no authority over live routing
 *
 * It exists so the current behavior can be proven 1:1 before V2 ever takes
 * routing authority.
 */

const PARITY_MARKER = '[AI_CONTROL_PLANE_V2_LEGACY_PARITY]';

const PARITY_KEYS = Object.freeze([
  'mode',
  'plannedProvider',
  'plannedModel',
  'plannedTemperature',
  'plannedMaxOutputTokens',
  'legacyProviderDefaultApplied',
  'clientProviderHintPresent',
  'shadowOnly',
  'liveProviderOverride',
  'parityVersion',
]);

const PARITY_VERSION = 'legacy-geminiPaidProxy-parity-v1';

function _mode(raw) {
  const value =
    raw && typeof raw.mode === 'string'
      ? raw.mode.trim().toLowerCase()
      : '';

  return value === 'study' ? 'study' : 'plantao';
}

function _provider(raw) {
  return raw &&
    typeof raw.provider === 'string' &&
    raw.provider.trim().length > 0
    ? raw.provider.trim()
    : 'gemini';
}

function _maxOutputTokens(raw) {
  const value =
    raw && Number.isFinite(raw.maxOutputTokens)
      ? Math.trunc(raw.maxOutputTokens)
      : 800;

  return Math.max(200, Math.min(2048, value));
}

function buildLegacyLiveParityPlan(
  rawBody,
  {
    geminiPaidModel,
  } = {}
) {
  const body =
    rawBody && typeof rawBody === 'object'
      ? rawBody
      : {};

  const mode = _mode(body);
  const provider = _provider(body);
  const isPlantao = mode === 'plantao';

  const clientProviderHintPresent =
    Object.hasOwn(body, 'provider') &&
    typeof body.provider === 'string' &&
    body.provider.trim().length > 0;

  let plannedProvider;
  let plannedModel;

  if (provider === 'openai') {
    plannedProvider = 'openai';
    plannedModel = 'gpt-4o-mini';
  } else {
    plannedProvider = 'gemini';
    plannedModel =
      typeof geminiPaidModel === 'string' && geminiPaidModel
        ? geminiPaidModel
        : 'runtime_gemini_paid_model';
  }

  return Object.freeze({
    mode,
    plannedProvider,
    plannedModel,
    plannedTemperature: isPlantao ? 0.2 : 0.4,
    plannedMaxOutputTokens: _maxOutputTokens(body),
    legacyProviderDefaultApplied: !clientProviderHintPresent,
    clientProviderHintPresent,
    shadowOnly: true,
    liveProviderOverride: false,
    parityVersion: PARITY_VERSION,
  });
}

function assertParityTelemetrySchema(plan) {
  const actual = Object.keys(plan).sort();
  const expected = [...PARITY_KEYS].sort();

  if (
    actual.length !== expected.length ||
    actual.some((key, i) => key !== expected[i])
  ) {
    throw new Error('legacy_parity_schema_violation');
  }
}

function observeLegacyLiveParity(
  rawBody,
  {
    geminiPaidModel,
    logger = console.log,
  } = {}
) {
  const before = JSON.stringify(rawBody || null);

  const plan = buildLegacyLiveParityPlan(rawBody, {
    geminiPaidModel,
  });

  assertParityTelemetrySchema(plan);

  const after = JSON.stringify(rawBody || null);
  if (before !== after) {
    throw new Error('legacy_parity_planner_mutated_request');
  }

  logger(PARITY_MARKER, JSON.stringify(plan));
  return plan;
}

module.exports = {
  PARITY_MARKER,
  PARITY_KEYS,
  PARITY_VERSION,
  buildLegacyLiveParityPlan,
  assertParityTelemetrySchema,
  observeLegacyLiveParity,
};
