'use strict';

const crypto = require('crypto');

const BUCKET_COUNT = 10000;

function _validUid(uid) {
  return typeof uid === 'string' && uid.trim().length > 0;
}

function _validSalt(salt) {
  return typeof salt === 'string' && salt.trim().length > 0;
}

function _validPercent(percent) {
  return (
    typeof percent === 'number' &&
    Number.isFinite(percent) &&
    percent >= 0 &&
    percent <= 100
  );
}

function deterministicBucket(uid, cohortSaltVersion) {
  if (!_validUid(uid)) {
    throw new Error('missing_or_invalid_uid');
  }

  if (!_validSalt(cohortSaltVersion)) {
    throw new Error('missing_or_invalid_cohort_salt');
  }

  const digest = crypto
    .createHash('sha256')
    .update(`${uid.trim()}|${cohortSaltVersion.trim()}`, 'utf8')
    .digest();

  // First 32 bits are enough for a deterministic 0..9999 bucket.
  return digest.readUInt32BE(0) % BUCKET_COUNT;
}

function evaluateRolloutCohort({
  uid,
  cohortSaltVersion,
  percent,
} = {}) {
  if (!_validUid(uid)) {
    return Object.freeze({
      eligible: false,
      reason: 'missing_or_invalid_uid',
    });
  }

  if (!_validSalt(cohortSaltVersion)) {
    return Object.freeze({
      eligible: false,
      reason: 'missing_or_invalid_cohort_salt',
    });
  }

  if (!_validPercent(percent)) {
    return Object.freeze({
      eligible: false,
      reason: 'invalid_rollout_percent',
    });
  }

  if (percent === 0) {
    return Object.freeze({
      eligible: false,
      reason: 'rollout_zero',
    });
  }

  if (percent === 100) {
    return Object.freeze({
      eligible: true,
      reason: 'rollout_selected',
    });
  }

  const bucket = deterministicBucket(uid, cohortSaltVersion);
  const threshold = Math.floor(percent * 100);

  return Object.freeze({
    eligible: bucket < threshold,
    reason: bucket < threshold
      ? 'rollout_selected'
      : 'rollout_not_selected',
  });
}

module.exports = {
  BUCKET_COUNT,
  deterministicBucket,
  evaluateRolloutCohort,
};
