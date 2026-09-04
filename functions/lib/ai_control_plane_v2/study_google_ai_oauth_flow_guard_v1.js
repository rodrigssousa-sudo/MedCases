'use strict';

const crypto = require('crypto');

const DEFAULT_TTL_MS = 10 * 60 * 1000;

function requireNonEmptyString(value, name) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${name}_REQUIRED`);
  }
  return value;
}

function sha256Hex(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function base64Url(buffer) {
  return Buffer.from(buffer)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

class StudyGoogleAiOAuthFlowGuardV1 {
  constructor({ store, clock, randomBytes, ttlMs }) {
    if (!store || typeof store.createFlowGuard !== 'function' || typeof store.consumeFlowGuard !== 'function') {
      throw new TypeError('FLOW_GUARD_STORE_REQUIRED');
    }
    this.store = store;
    this.clock = typeof clock === 'function' ? clock : Date.now;
    this.randomBytes = typeof randomBytes === 'function' ? randomBytes : crypto.randomBytes;
    this.ttlMs = Number(ttlMs || DEFAULT_TTL_MS);
    if (!Number.isFinite(this.ttlMs) || this.ttlMs < 60_000 || this.ttlMs > 15 * 60 * 1000) {
      throw new Error('FLOW_GUARD_TTL_OUT_OF_RANGE');
    }
  }

  async issueChallenge({ medcasesUid }) {
    requireNonEmptyString(medcasesUid, 'MEDCASES_UID');
    const challengeId = base64Url(this.randomBytes(18));
    const state = base64Url(this.randomBytes(32));
    const nonce = base64Url(this.randomBytes(32));
    const createdAtMs = Number(this.clock());
    const expiresAtMs = createdAtMs + this.ttlMs;
    await this.store.createFlowGuard({
      medcasesUid,
      challengeId,
      stateSha256: sha256Hex(state),
      nonceSha256: sha256Hex(nonce),
      createdAtMs,
      expiresAtMs,
    });
    return Object.freeze({ challengeId, state, nonce, expiresAtMs });
  }

  async consumeChallenge({ medcasesUid, challengeId, state, nonce, authCode }) {
    requireNonEmptyString(medcasesUid, 'MEDCASES_UID');
    requireNonEmptyString(challengeId, 'CHALLENGE_ID');
    requireNonEmptyString(state, 'STATE');
    requireNonEmptyString(nonce, 'NONCE');
    requireNonEmptyString(authCode, 'AUTH_CODE');
    const result = await this.store.consumeFlowGuard({
      medcasesUid,
      challengeId,
      stateSha256: sha256Hex(state),
      nonceSha256: sha256Hex(nonce),
      authCodeSha256: sha256Hex(authCode),
      nowMs: Number(this.clock()),
    });
    return Object.freeze({ consumed: result && result.consumed === true, usedAtMs: result.usedAtMs });
  }
}

module.exports = {
  DEFAULT_TTL_MS,
  StudyGoogleAiOAuthFlowGuardV1,
  sha256Hex,
};
