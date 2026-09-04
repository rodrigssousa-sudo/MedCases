"use strict";

class ClinicalContextCutoverGate {
  constructor({
    enabled = false,
    allowedModes = ["plantao"],
    allowedUserIds = [],
    allowedPercent = 0,
  } = {}) {
    this.enabled = enabled === true;
    this.allowedModes = new Set(
      (allowedModes || []).map((x) => String(x || "").toLowerCase()),
    );
    this.allowedUserIds = new Set(
      (allowedUserIds || []).map((x) => String(x || "")),
    );
    this.allowedPercent = clampPercent(allowedPercent);
  }

  evaluate({
    mode,
    userId = "",
    requestKey = "",
  }) {
    if (!this.enabled) {
      return deny("cutover_disabled");
    }

    const normalizedMode = String(mode || "").toLowerCase();
    if (!this.allowedModes.has(normalizedMode)) {
      return deny("mode_not_allowed");
    }

    const uid = String(userId || "");
    if (uid && this.allowedUserIds.has(uid)) {
      return allow("explicit_user_allowlist");
    }

    if (this.allowedPercent <= 0) {
      return deny("rollout_percent_zero");
    }

    const bucket = stableBucket(`${uid}|${requestKey}|${normalizedMode}`);
    if (bucket >= this.allowedPercent) {
      return deny("rollout_bucket_outside_allowance", bucket);
    }

    return allow("rollout_bucket_allowed", bucket);
  }
}

function stableBucket(value) {
  let hash = 2166136261;
  for (const char of String(value || "")) {
    hash ^= char.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) % 100;
}

function clampPercent(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return 0;
  return Math.max(0, Math.min(100, Math.floor(number)));
}

function allow(reason, bucket = null) {
  return Object.freeze({ allowed: true, reason, bucket });
}

function deny(reason, bucket = null) {
  return Object.freeze({ allowed: false, reason, bucket });
}

module.exports = {
  ClinicalContextCutoverGate,
  stableClinicalContextRolloutBucket: stableBucket,
};
