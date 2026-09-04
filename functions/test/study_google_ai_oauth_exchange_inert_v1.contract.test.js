'use strict';

const assert = require('assert');

const {
  VERSION,
  inspectStudyGoogleAiAuthCodeInert,
} = require(
  '../lib/ai_control_plane_v2/' +
  'study_google_ai_oauth_exchange_inert_v1'
);

function pass(label) {
  console.log(`${label}=PASS`);
}

const rawCode =
  'temporary-server-auth-code-secret-value';

const good = inspectStudyGoogleAiAuthCodeInert({
  authenticatedUid: 'uid-123',
  requestedUid: 'uid-123',
  serverAuthorizationCode: rawCode,
  nonce: 'nonce-1234567890',
});

assert.strictEqual(
  VERSION,
  'medcases_study_google_ai_oauth_exchange_inert_v1'
);
pass('SERVER_EXCHANGE_VERSION');

assert.strictEqual(good.enabled, false);
assert.strictEqual(good.inert, true);
assert.strictEqual(good.allowedToExchange, false);
pass('SERVER_EXCHANGE_INERT_DISABLED');

assert.strictEqual(good.authenticated, true);
assert.strictEqual(good.uidMatches, true);
assert.strictEqual(good.codePresent, true);
assert.strictEqual(good.noncePresent, true);
pass('SERVER_EXCHANGE_INPUT_GUARDS');

assert.strictEqual(good.authorizationCodeReturned, false);
assert.strictEqual(good.authorizationCodePersisted, false);
assert.strictEqual(good.authorizationCodeLogged, false);
pass('RAW_AUTH_CODE_NOT_RETURNED_PERSISTED_OR_LOGGED');

assert.strictEqual(good.tokenExchangeAttempted, false);
assert.strictEqual(good.accessTokenReturned, false);
assert.strictEqual(good.refreshTokenReturned, false);
assert.strictEqual(good.tokenPersisted, false);
pass('TOKEN_EXCHANGE_ZERO');

assert.strictEqual(good.providerCallAttempted, false);
assert.strictEqual(good.geminiAuthority, false);
pass('PROVIDER_AUTHORITY_ZERO');

const serialized = JSON.stringify(good);
assert.strictEqual(serialized.includes(rawCode), false);
pass('RAW_AUTH_CODE_ABSENT_FROM_RESULT');

const wrongUid = inspectStudyGoogleAiAuthCodeInert({
  authenticatedUid: 'uid-a',
  requestedUid: 'uid-b',
  serverAuthorizationCode: rawCode,
  nonce: 'nonce-1234567890',
});

assert.strictEqual(wrongUid.uidMatches, false);
assert.strictEqual(wrongUid.safeReason, 'uid_mismatch');
assert.strictEqual(wrongUid.allowedToExchange, false);
pass('UID_MISMATCH_FAILS_CLOSED');

const noAuth = inspectStudyGoogleAiAuthCodeInert({
  authenticatedUid: '',
  requestedUid: 'uid-a',
  serverAuthorizationCode: rawCode,
  nonce: 'nonce-1234567890',
});

assert.strictEqual(noAuth.authenticated, false);
assert.strictEqual(noAuth.safeReason, 'auth_required');
assert.strictEqual(noAuth.allowedToExchange, false);
pass('AUTH_REQUIRED_FAILS_CLOSED');

console.log(
  'RESULT=PASS_STUDY_GOOGLE_AI_OAUTH_' +
  'SERVER_AUTH_CODE_INERT_OWNER_CONTRACT'
);
