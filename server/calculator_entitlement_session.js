'use strict';

const crypto = require('node:crypto');

const TOKEN_PREFIX = 'mcc1';
const DEFAULT_AUDIENCE = 'medcases-calculator';
const DEFAULT_TTL_SECONDS = 600;
const MAX_TTL_SECONDS = 900;

const FREE_CAPABILITIES = Object.freeze([
  'scores',
  'drug_catalog_free',
]);

const PREMIUM_CAPABILITIES = Object.freeze([
  'scores',
  'drug_catalog_free',
  'drug_catalog_full',
  'dose_by_weight',
  'renal_adjustment',
]);

function clean(value) {
  return String(value ?? '').trim();
}

function normalized(value) {
  return clean(value).toLowerCase();
}

function requireSecret(secret) {
  const normalizedSecret = clean(secret);
  if (Buffer.byteLength(normalizedSecret, 'utf8') < 32) {
    throw new Error('CALCULATOR_SESSION_SECRET_TOO_SHORT');
  }
  return normalizedSecret;
}

function signPayload(encodedPayload, secret) {
  return crypto
    .createHmac('sha256', requireSecret(secret))
    .update(encodedPayload)
    .digest('base64url');
}

function safeEqualBase64Url(left, right) {
  let a;
  let b;
  try {
    a = Buffer.from(String(left), 'base64url');
    b = Buffer.from(String(right), 'base64url');
  } catch (_) {
    return false;
  }
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function resolveMedCasesTier(userDoc = {}) {
  const plan = normalized(userDoc.plan);
  const subscriptionStatus = normalized(userDoc.subscriptionStatus);

  const premiumByPlan =
    plan === 'premium' ||
    plan === 'pro' ||
    plan === 'paid';

  const premiumBySubscription =
    subscriptionStatus === 'active' ||
    subscriptionStatus === 'premium' ||
    subscriptionStatus === 'paid';

  if (premiumByPlan || premiumBySubscription) {
    return Object.freeze({
      tier: 'premium',
      source: premiumByPlan ? 'server_plan' : 'server_subscription_status',
    });
  }

  return Object.freeze({
    tier: 'free',
    source:
      subscriptionStatus === 'trial'
        ? 'trial_not_authoritative_for_premium'
        : 'server_free_default',
  });
}

function capabilitiesForTier(tier) {
  return tier === 'premium'
    ? [...PREMIUM_CAPABILITIES]
    : [...FREE_CAPABILITIES];
}

function issueCalculatorSession({
  uid,
  userDoc,
  secret,
  nowEpoch = Math.floor(Date.now() / 1000),
  ttlSeconds = DEFAULT_TTL_SECONDS,
  audience = DEFAULT_AUDIENCE,
  sessionId,
} = {}) {
  const subject = clean(uid);
  if (!subject) throw new Error('CALCULATOR_SESSION_UID_REQUIRED');

  const now = Number(nowEpoch);
  const ttl = Number(ttlSeconds);

  if (!Number.isInteger(now) || now <= 0) {
    throw new Error('CALCULATOR_SESSION_INVALID_IAT');
  }

  if (!Number.isInteger(ttl) || ttl <= 0 || ttl > MAX_TTL_SECONDS) {
    throw new Error('CALCULATOR_SESSION_INVALID_TTL');
  }

  const aud = clean(audience);
  if (!aud) throw new Error('CALCULATOR_SESSION_AUDIENCE_REQUIRED');

  const entitlement = resolveMedCasesTier(userDoc);

  const claims = Object.freeze({
    v: 1,
    sub: subject,
    tier: entitlement.tier,
    cap: capabilitiesForTier(entitlement.tier),
    aud,
    iat: now,
    exp: now + ttl,
    jti: clean(sessionId) || crypto.randomUUID(),
  });

  const encoded = Buffer
    .from(JSON.stringify(claims), 'utf8')
    .toString('base64url');

  const signature = signPayload(encoded, secret);

  return Object.freeze({
    accessToken: `${TOKEN_PREFIX}.${encoded}.${signature}`,
    claims,
    entitlementSource: entitlement.source,
    expiresAtUtc: new Date(claims.exp * 1000).toISOString(),
  });
}

function verifyCalculatorSession(
  token,
  {
    secret,
    nowEpoch = Math.floor(Date.now() / 1000),
    audience = DEFAULT_AUDIENCE,
  } = {},
) {
  const parts = clean(token).split('.');

  if (parts.length !== 3 || parts[0] !== TOKEN_PREFIX) {
    throw new Error('CALCULATOR_SESSION_MALFORMED');
  }

  const [, encoded, signature] = parts;
  const expected = signPayload(encoded, secret);

  if (!safeEqualBase64Url(signature, expected)) {
    throw new Error('CALCULATOR_SESSION_BAD_SIGNATURE');
  }

  let claims;
  try {
    claims = JSON.parse(
      Buffer.from(encoded, 'base64url').toString('utf8'),
    );
  } catch (_) {
    throw new Error('CALCULATOR_SESSION_MALFORMED_PAYLOAD');
  }

  const now = Number(nowEpoch);

  if (
    claims.v !== 1 ||
    typeof claims.sub !== 'string' ||
    !claims.sub.trim() ||
    !Array.isArray(claims.cap) ||
    typeof claims.aud !== 'string' ||
    !Number.isInteger(claims.iat) ||
    !Number.isInteger(claims.exp) ||
    typeof claims.jti !== 'string' ||
    !claims.jti.trim()
  ) {
    throw new Error('CALCULATOR_SESSION_INVALID_CLAIMS');
  }

  if (claims.aud !== clean(audience)) {
    throw new Error('CALCULATOR_SESSION_WRONG_AUDIENCE');
  }

  if (claims.exp <= now) {
    throw new Error('CALCULATOR_SESSION_EXPIRED');
  }

  if (claims.iat > now + 30) {
    throw new Error('CALCULATOR_SESSION_IAT_IN_FUTURE');
  }

  if (
    claims.exp <= claims.iat ||
    claims.exp - claims.iat > MAX_TTL_SECONDS
  ) {
    throw new Error('CALCULATOR_SESSION_TTL_INVALID');
  }

  if (claims.tier !== 'free' && claims.tier !== 'premium') {
    throw new Error('CALCULATOR_SESSION_INVALID_TIER');
  }

  return Object.freeze({
    ...claims,
    cap: Object.freeze([...claims.cap]),
  });
}

module.exports = {
  TOKEN_PREFIX,
  DEFAULT_AUDIENCE,
  DEFAULT_TTL_SECONDS,
  MAX_TTL_SECONDS,
  FREE_CAPABILITIES,
  PREMIUM_CAPABILITIES,
  resolveMedCasesTier,
  capabilitiesForTier,
  issueCalculatorSession,
  verifyCalculatorSession,
};
