'use strict';

/**
 * MedCases AI Control Plane V2 — server-only, versioned config reader.
 *
 * Firestore layout:
 *
 *   ai_config/current
 *     schemaVersion: "ai-config-v2"
 *     activeVersion: "AI_CONFIG_V12"
 *
 *   ai_config_versions/AI_CONFIG_V12
 *     ...immutable V2 config document...
 *
 * The current pointer can move forward/backward for rollout/rollback.
 * Version documents are treated as immutable by convention and validation.
 *
 * This module performs READS ONLY.
 */

const {
  makeSafeBootstrapConfig,
  CONFIG_SCHEMA_VERSION,
} = require('./config_defaults');

const {
  getModelRegistry,
} = require('./model_registry');

const {
  validateV2Config,
} = require('./validator');

const POINTER_COLLECTION = 'ai_config';
const POINTER_DOCUMENT = 'current';
const VERSION_COLLECTION = 'ai_config_versions';

const DEFAULT_CACHE_TTL_MS = 30_000;

let _cachedState = Object.freeze({
  config: makeSafeBootstrapConfig(),
  source: 'compiled_bootstrap',
  pointerVersion: '',
  loadedAtMs: 0,
  validUntilMs: 0,
  executionAllowed: false,
  errorCode: '',
});

let _refreshPromise = null;

function _deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

function _freezeDeep(value) {
  if (!value || typeof value !== 'object' || Object.isFrozen(value)) {
    return value;
  }
  for (const key of Object.keys(value)) {
    _freezeDeep(value[key]);
  }
  return Object.freeze(value);
}

function _safeState({
  source = 'compiled_bootstrap',
  pointerVersion = '',
  nowMs = Date.now(),
  ttlMs = DEFAULT_CACHE_TTL_MS,
  errorCode = '',
} = {}) {
  return Object.freeze({
    config: makeSafeBootstrapConfig(),
    source,
    pointerVersion,
    loadedAtMs: nowMs,
    validUntilMs: nowMs + ttlMs,
    executionAllowed: false,
    errorCode,
  });
}

function _envHardGate(env = process.env) {
  return env.AI_CONTROL_PLANE_V2_ENABLED === 'true';
}

function _computeExecutionAllowed(config, env = process.env) {
  return (
    _envHardGate(env) &&
    config &&
    config.enabled === true &&
    config.legacyParityMode === false &&
    config.clientOverrideAllowed === false &&
    config.rollout &&
    config.rollout.enabled === true &&
    config.rollout.percent > 0
  );
}

function getCachedV2ConfigState(nowMs = Date.now()) {
  if (_cachedState.validUntilMs > nowMs) {
    return _cachedState;
  }
  return Object.freeze({
    ..._cachedState,
    executionAllowed: false,
  });
}

async function _readPointer(firestore) {
  const snap = await firestore
    .collection(POINTER_COLLECTION)
    .doc(POINTER_DOCUMENT)
    .get();

  if (!snap || snap.exists !== true) {
    return { ok: false, errorCode: 'pointer_missing' };
  }

  const data = snap.data() || {};

  if (data.schemaVersion !== CONFIG_SCHEMA_VERSION) {
    return { ok: false, errorCode: 'pointer_schema_invalid' };
  }

  if (
    typeof data.activeVersion !== 'string' ||
    data.activeVersion.trim().length === 0
  ) {
    return { ok: false, errorCode: 'pointer_active_version_missing' };
  }

  return {
    ok: true,
    activeVersion: data.activeVersion.trim(),
  };
}

async function _readVersion(firestore, activeVersion) {
  const snap = await firestore
    .collection(VERSION_COLLECTION)
    .doc(activeVersion)
    .get();

  if (!snap || snap.exists !== true) {
    return { ok: false, errorCode: 'version_missing' };
  }

  const data = snap.data() || {};
  return {
    ok: true,
    data,
  };
}

async function loadV2ConfigFromFirestore({
  firestore,
  env = process.env,
  nowMs = Date.now(),
  ttlMs = DEFAULT_CACHE_TTL_MS,
} = {}) {
  if (!firestore || typeof firestore.collection !== 'function') {
    return _safeState({
      source: 'compiled_bootstrap',
      nowMs,
      ttlMs,
      errorCode: 'firestore_unavailable',
    });
  }

  let pointer;
  try {
    pointer = await _readPointer(firestore);
  } catch (_) {
    return _safeState({
      source: 'compiled_bootstrap',
      nowMs,
      ttlMs,
      errorCode: 'pointer_read_failed',
    });
  }

  if (!pointer.ok) {
    return _safeState({
      source: 'compiled_bootstrap',
      nowMs,
      ttlMs,
      errorCode: pointer.errorCode,
    });
  }

  let version;
  try {
    version = await _readVersion(firestore, pointer.activeVersion);
  } catch (_) {
    return _safeState({
      source: 'compiled_bootstrap',
      pointerVersion: pointer.activeVersion,
      nowMs,
      ttlMs,
      errorCode: 'version_read_failed',
    });
  }

  if (!version.ok) {
    return _safeState({
      source: 'compiled_bootstrap',
      pointerVersion: pointer.activeVersion,
      nowMs,
      ttlMs,
      errorCode: version.errorCode,
    });
  }

  const candidate = _deepClone(version.data);

  if (candidate.configVersion !== pointer.activeVersion) {
    return _safeState({
      source: 'compiled_bootstrap',
      pointerVersion: pointer.activeVersion,
      nowMs,
      ttlMs,
      errorCode: 'version_identity_mismatch',
    });
  }

  const validation = validateV2Config(candidate, getModelRegistry());
  if (!validation.ok) {
    return _safeState({
      source: 'compiled_bootstrap',
      pointerVersion: pointer.activeVersion,
      nowMs,
      ttlMs,
      errorCode: `version_invalid:${validation.errors.join('|')}`,
    });
  }

  const frozenConfig = _freezeDeep(candidate);

  return Object.freeze({
    config: frozenConfig,
    source: 'firestore_version',
    pointerVersion: pointer.activeVersion,
    loadedAtMs: nowMs,
    validUntilMs: nowMs + ttlMs,
    executionAllowed: _computeExecutionAllowed(frozenConfig, env),
    errorCode: '',
  });
}

async function refreshV2Config(options = {}) {
  if (_refreshPromise) {
    return _refreshPromise;
  }

  _refreshPromise = (async () => {
    const next = await loadV2ConfigFromFirestore(options);
    _cachedState = next;
    return next;
  })();

  try {
    return await _refreshPromise;
  } finally {
    _refreshPromise = null;
  }
}

/**
 * Returns a config state suitable for LIVE execution authority.
 *
 * Hot cache:
 *   - zero Firestore read
 *   - returns current cached state immediately
 *
 * Expired/cold cache:
 *   - waits for refreshV2Config()
 *   - refresh remains single-flight through _refreshPromise
 *   - any Firestore/config failure still resolves to the existing safe
 *     bootstrap state with executionAllowed=false (fail closed)
 *
 * This deliberately does NOT reuse an expired last-known-good state as live
 * authority, preserving emergency disable / rollback semantics.
 */
async function getV2ConfigStateForExecution({
  firestore,
  env = process.env,
  nowMs = Date.now(),
  ttlMs = DEFAULT_CACHE_TTL_MS,
} = {}) {
  const cached = getCachedV2ConfigState(nowMs);

  if (cached.validUntilMs > nowMs) {
    return cached;
  }

  return refreshV2Config({
    firestore,
    env,
    nowMs,
    ttlMs,
  });
}

function resetV2ConfigCacheForTests() {
  _cachedState = Object.freeze({
    config: makeSafeBootstrapConfig(),
    source: 'compiled_bootstrap',
    pointerVersion: '',
    loadedAtMs: 0,
    validUntilMs: 0,
    executionAllowed: false,
    errorCode: '',
  });
  _refreshPromise = null;
}

module.exports = {
  POINTER_COLLECTION,
  POINTER_DOCUMENT,
  VERSION_COLLECTION,
  DEFAULT_CACHE_TTL_MS,
  getCachedV2ConfigState,
  loadV2ConfigFromFirestore,
  refreshV2Config,
  getV2ConfigStateForExecution,
  resetV2ConfigCacheForTests,
};
