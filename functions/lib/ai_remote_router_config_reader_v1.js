'use strict';

const CONFIG_COLLECTION = 'ai_control_plane';
const CONFIG_DOCUMENT = 'router_v1';
const CONFIG_CONTRACT_VERSION = 'medcases-ai-control-plane-v1';
const CACHE_TTL_MS = 60 * 1000;
const ERROR_RETRY_TTL_MS = 15 * 1000;

let _cachedConfig = null;
let _expiresAtMs = 0;
let _refreshInFlight = null;

function _asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value
    : {};
}

function _safeAlias(value, nullable = false) {
  if (value == null && nullable) return null;
  if (typeof value !== 'string') return nullable ? null : '';
  const v = value.trim();
  if (!v || v.length > 80 || !/^[a-z0-9_]+$/i.test(v)) {
    return nullable ? null : '';
  }
  return v;
}

function _normalizeModeConfig(value) {
  const raw = _asObject(value);
  const responseOrder = Array.isArray(raw.responseOrder)
    ? raw.responseOrder
        .map((x) => _safeAlias(x))
        .filter(Boolean)
        .slice(0, 8)
    : [];

  const routeId = _safeAlias(raw.routeId);
  if (!routeId || responseOrder.length === 0) {
    return null;
  }

  return Object.freeze({
    routeId,
    classifier: _safeAlias(raw.classifier, true),
    responseOrder: Object.freeze(responseOrder),
    hardCaseModel: _safeAlias(raw.hardCaseModel, true),
  });
}

function normalizeRemoteAiRouterConfigV1(value) {
  const raw = _asObject(value);
  if (raw.contractVersion !== CONFIG_CONTRACT_VERSION) {
    return null;
  }

  const modesRaw = _asObject(raw.modes);
  const study = _normalizeModeConfig(modesRaw.study);
  const plantao = _normalizeModeConfig(modesRaw.plantao);
  if (!study || !plantao) {
    return null;
  }

  const policyRaw = _asObject(raw.policy);

  return Object.freeze({
    contractVersion: CONFIG_CONTRACT_VERSION,
    enabled: raw.enabled === true,
    shadowEnabled: raw.shadowEnabled !== false,
    modes: Object.freeze({
      study,
      plantao,
    }),
    policy: Object.freeze({
      fallbackOnTimeout: policyRaw.fallbackOnTimeout !== false,
      fallbackOnRateLimit: policyRaw.fallbackOnRateLimit !== false,
      fallbackOnProvider5xx: policyRaw.fallbackOnProvider5xx !== false,
      clientOverrideAllowed: false,
      unknownModeAction: 'preserve_live_behavior',
    }),
  });
}

function getCachedRemoteAiRouterConfigV1() {
  return _cachedConfig;
}

function _unwrapDocumentSnapshot(snapshot) {
  if (!snapshot) return {exists: false, data: null};
  if (typeof snapshot.data === 'function') {
    return {
      exists: snapshot.exists !== false,
      data: snapshot.data(),
    };
  }
  return {exists: true, data: snapshot};
}

async function _fetchConfigDocumentV1() {
  // Lazy require keeps unit tests network-free and avoids initializing Admin
  // SDK from this module. functions/index.js remains the runtime owner.
  const admin = require('firebase-admin');
  if (!Array.isArray(admin.apps) || admin.apps.length === 0) {
    return null;
  }

  return admin
    .firestore()
    .collection(CONFIG_COLLECTION)
    .doc(CONFIG_DOCUMENT)
    .get();
}

async function refreshRemoteAiRouterConfigV1(options = {}) {
  const nowMs = Number.isFinite(options.nowMs)
    ? options.nowMs
    : Date.now();
  const force = options.force === true;
  const fetchDocument =
    typeof options.fetchDocument === 'function'
      ? options.fetchDocument
      : _fetchConfigDocumentV1;

  if (!force && nowMs < _expiresAtMs) {
    return _cachedConfig;
  }

  if (_refreshInFlight) {
    return _refreshInFlight;
  }

  _refreshInFlight = (async () => {
    try {
      const snapshot = await fetchDocument();
      const unwrapped = _unwrapDocumentSnapshot(snapshot);

      if (!unwrapped.exists) {
        _cachedConfig = null;
        _expiresAtMs = nowMs + CACHE_TTL_MS;
        return null;
      }

      const normalized = normalizeRemoteAiRouterConfigV1(
        unwrapped.data,
      );

      // Invalid/malformed remote configuration is fail-closed to the
      // compiled shadow defaults. Never keep an invalid route active.
      _cachedConfig = normalized;
      _expiresAtMs = nowMs + CACHE_TTL_MS;
      return _cachedConfig;
    } catch (_) {
      // Firestore failure never affects the live response. Preserve the
      // last known-good shadow config, or null -> compiled defaults.
      _expiresAtMs = nowMs + ERROR_RETRY_TTL_MS;
      return _cachedConfig;
    } finally {
      _refreshInFlight = null;
    }
  })();

  return _refreshInFlight;
}

function resetRemoteAiRouterConfigCacheV1ForTest() {
  _cachedConfig = null;
  _expiresAtMs = 0;
  _refreshInFlight = null;
}

module.exports = {
  CONFIG_COLLECTION,
  CONFIG_DOCUMENT,
  CONFIG_CONTRACT_VERSION,
  CACHE_TTL_MS,
  normalizeRemoteAiRouterConfigV1,
  getCachedRemoteAiRouterConfigV1,
  refreshRemoteAiRouterConfigV1,
  resetRemoteAiRouterConfigCacheV1ForTest,
};
