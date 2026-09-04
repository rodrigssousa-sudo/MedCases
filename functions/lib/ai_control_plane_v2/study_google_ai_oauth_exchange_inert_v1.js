'use strict';

const crypto = require('crypto');

const VERSION =
  'medcases_study_google_ai_oauth_exchange_inert_v1';

function safeString(value, max) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, max);
}

function sha256Hex(value) {
  return crypto
    .createHash('sha256')
    .update(value)
    .digest('hex');
}

/**
 * Inert server-side owner for the future Google OAuth authorization-code
 * exchange.
 *
 * Security properties in this phase:
 * - no HTTP/provider/token endpoint call;
 * - no code persistence;
 * - no raw code return;
 * - no raw code logging;
 * - no refresh/access token;
 * - no Gemini provider authority;
 * - explicit authenticated UID ownership required;
 * - disabled by default and unconditionally inert.
 */
function inspectStudyGoogleAiAuthCodeInert(input) {
  const body = input && typeof input === 'object'
    ? input
    : {};

  const authenticatedUid =
    safeString(body.authenticatedUid, 160);

  const requestedUid =
    safeString(body.requestedUid, 160);

  const serverAuthorizationCode =
    safeString(body.serverAuthorizationCode, 8192);

  const nonce =
    safeString(body.nonce, 256);

  const hasAuthenticatedUid =
    authenticatedUid.length > 0;

  const uidMatches =
    hasAuthenticatedUid &&
    requestedUid.length > 0 &&
    requestedUid === authenticatedUid;

  const codePresent =
    serverAuthorizationCode.length >= 12;

  const noncePresent =
    nonce.length >= 12;

  const codeFingerprint =
    codePresent
      ? sha256Hex(serverAuthorizationCode).slice(0, 16)
      : '';

  return Object.freeze({
    version: VERSION,
    enabled: false,
    inert: true,
    authenticated: hasAuthenticatedUid,
    uidMatches,
    codePresent,
    noncePresent,
    codeFingerprintPresent:
      codeFingerprint.length === 16,

    // Raw code is intentionally not present.
    authorizationCodeReturned: false,
    authorizationCodePersisted: false,
    authorizationCodeLogged: false,

    tokenExchangeAttempted: false,
    accessTokenReturned: false,
    refreshTokenReturned: false,
    tokenPersisted: false,

    providerCallAttempted: false,
    geminiAuthority: false,

    allowedToExchange:
      false,

    safeReason:
      !hasAuthenticatedUid
        ? 'auth_required'
        : !uidMatches
          ? 'uid_mismatch'
          : !codePresent
            ? 'server_auth_code_missing'
            : !noncePresent
              ? 'nonce_missing'
              : 'inert_disabled',
  });
}

module.exports = {
  VERSION,
  inspectStudyGoogleAiAuthCodeInert,
};
