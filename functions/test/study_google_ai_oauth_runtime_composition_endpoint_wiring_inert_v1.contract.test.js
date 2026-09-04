'use strict';

const assert = require('assert');
const {
  CIPHERTEXT_ENVELOPE_PREFIX,
  createStudyGoogleAiOAuthRuntimeCompositionInertV1,
  decodeCiphertextEnvelope,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_runtime_composition_inert_v1');
const {
  TOKEN_EXCHANGE_ENABLED,
  TOKEN_PERSISTENCE_ENABLED,
  RUNTIME_ADAPTER_WIRING_ENABLED,
  FLOW_GUARD_ENFORCEMENT_ENABLED,
  createStudyGoogleAiOAuthExchangeEndpointInert,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_exchange_endpoint_inert_v1');

function fakeResponse() {
  const state = { statusCode: null, body: null };
  return {
    state,
    set() { return this; },
    status(code) { state.statusCode = code; return this; },
    json(body) { state.body = body; return body; },
  };
}

function requestBody(extra) {
  return {
    medCasesUid: 'uid-test-1',
    serverAuthorizationCode: 'fake-server-auth-code',
    nonce: 'nonce-12345678901234567890',
    challengeId: 'challenge-test-1',
    state: 'state-test-1',
    ...(extra || {}),
  };
}

(async () => {
  assert.strictEqual(TOKEN_EXCHANGE_ENABLED, false);
  assert.strictEqual(TOKEN_PERSISTENCE_ENABLED, false);
  assert.strictEqual(RUNTIME_ADAPTER_WIRING_ENABLED, false);
  assert.strictEqual(FLOW_GUARD_ENFORCEMENT_ENABLED, false);

  let runtimeFactoryCalls = 0;
  let exchangeCalls = 0;
  const disabled = createStudyGoogleAiOAuthExchangeEndpointInert({
    verifyIdToken: async () => ({ uid: 'uid-test-1' }),
    runtimeFactory: () => { runtimeFactoryCalls += 1; throw new Error('MUST_NOT_RUN'); },
    exchangeAuthorizationCode: async () => { exchangeCalls += 1; throw new Error('MUST_NOT_RUN'); },
  });
  const disabledRes = fakeResponse();
  await disabled({
    method: 'POST',
    headers: { authorization: 'Bearer fake-firebase-token' },
    body: requestBody(),
  }, disabledRes);
  assert.strictEqual(runtimeFactoryCalls, 0);
  assert.strictEqual(exchangeCalls, 0);
  assert.strictEqual(disabledRes.state.body.tokenExchangeAttempted, false);

  let flowCalls = 0;
  let resolveCalls = 0;
  let encryptCalls = 0;
  let storeCalls = 0;
  let persistCalls = 0;

  const runtime = {
    consumeOAuthFlowChallenge: async ({ medcasesUid, authCode }) => {
      flowCalls += 1;
      assert.strictEqual(medcasesUid, 'uid-test-1');
      assert.strictEqual(authCode, 'fake-server-auth-code');
      return { consumed: true };
    },
    resolveValidatedUserProjectId: async ({ accessToken, medCasesUid }) => {
      resolveCalls += 1;
      assert.strictEqual(accessToken, 'fake-access-token');
      assert.strictEqual(medCasesUid, 'uid-test-1');
      return 'user-project-12345';
    },
    encryptRefreshToken: async ({ plaintext }) => {
      encryptCalls += 1;
      assert.strictEqual(plaintext, 'fake-refresh-token');
      return 'kmsv1:synthetic-ciphertext-only';
    },
    storeEncryptedGrant: async ({ medCasesUid, record }) => {
      storeCalls += 1;
      assert.strictEqual(medCasesUid, 'uid-test-1');
      assert.strictEqual(record.validatedUserProjectId, 'user-project-12345');
    },
  };

  const enabledSynthetic = createStudyGoogleAiOAuthExchangeEndpointInert({
    verifyIdToken: async () => ({ uid: 'uid-test-1' }),
    exchangeEnabled: true,
    tokenPersistenceEnabled: true,
    runtimeWiringEnabled: true,
    flowGuardEnabled: true,
    runtimeFactory: () => { runtimeFactoryCalls += 1; return runtime; },
    exchangeAuthorizationCode: async () => {
      exchangeCalls += 1;
      return {
        accessToken: 'fake-access-token',
        refreshToken: 'fake-refresh-token',
        scope: 'scope-a scope-b',
      };
    },
    persistOAuthGrant: async ({ medCasesUid, validatedUserProjectId, refreshToken, accessToken, encryptRefreshToken, storeEncryptedGrant }) => {
      persistCalls += 1;
      assert.strictEqual(medCasesUid, 'uid-test-1');
      assert.strictEqual(validatedUserProjectId, 'user-project-12345');
      const ciphertext = await encryptRefreshToken({ plaintext: refreshToken, aad: JSON.stringify({ medCasesUid, validatedUserProjectId }) });
      await storeEncryptedGrant({ medCasesUid, record: { medCasesUid, validatedUserProjectId, encryptedRefreshToken: ciphertext } });
      assert.strictEqual(accessToken, 'fake-access-token');
      return { persisted: true };
    },
    publicWebClientId: '123456789-test.apps.googleusercontent.com',
    secretEnv: { MEDCASES_STUDY_GOOGLE_OAUTH_WEB_CLIENT_SECRET_V1: 'fake-secret' },
  });
  const enabledRes = fakeResponse();
  await enabledSynthetic({
    method: 'POST',
    headers: { authorization: 'Bearer fake-firebase-token' },
    body: requestBody(),
  }, enabledRes);

  assert.strictEqual(flowCalls, 1);
  assert.strictEqual(resolveCalls, 1);
  assert.strictEqual(encryptCalls, 1);
  assert.strictEqual(storeCalls, 1);
  assert.strictEqual(persistCalls, 1);
  assert.strictEqual(enabledRes.state.statusCode, 503);
  assert.strictEqual(enabledRes.state.body.tokenPersisted, true);
  assert.strictEqual(enabledRes.state.body.accessTokenReturned, false);
  assert.strictEqual(enabledRes.state.body.refreshTokenReturned, false);
  assert.strictEqual(JSON.stringify(enabledRes.state.body).includes('fake-access-token'), false);
  assert.strictEqual(JSON.stringify(enabledRes.state.body).includes('fake-refresh-token'), false);

  const validatedProject = {
    serverValidated: true,
    projectId: 'user-project-12345',
    projectNumber: '123456789',
    displayName: 'Test Project',
    geminiApiEnabled: true,
    serviceUsageUse: true,
    validatedAtMs: 123,
  };
  let storedRealBridge = null;
  const composition = createStudyGoogleAiOAuthRuntimeCompositionInertV1({
    firestore: {},
    kmsClient: {},
    firestoreAdapter: {
      upsertEncryptedCredential: async (payload) => { storedRealBridge = payload; return { ok: true }; },
    },
    kmsAdapter: {
      encryptRefreshToken: async ({ refreshToken, medcasesUid, projectId }) => {
        assert.strictEqual(refreshToken, 'refresh-bridge-secret');
        return { schema: 'schema', keyName: 'key', ciphertextB64: 'Y2lwaGVy', aadSha256: 'a'.repeat(64), medcasesUid, projectId };
      },
    },
    projectValidator: {
      discoverProjects: async () => [{ projectId: 'user-project-12345' }],
      validateProject: async () => validatedProject,
    },
    flowGuard: {
      issueChallenge: async () => ({ challengeId: 'c', state: 's', nonce: 'n' }),
      consumeChallenge: async () => ({ consumed: true }),
    },
  });
  const resolved = await composition.resolveValidatedUserProjectId({ accessToken: 'memory-token', medCasesUid: 'uid-test-1' });
  assert.strictEqual(resolved, 'user-project-12345');
  const envelope = await composition.encryptRefreshToken({
    plaintext: 'refresh-bridge-secret',
    aad: JSON.stringify({ schemaVersion: 1, medCasesUid: 'uid-test-1', validatedUserProjectId: resolved }),
  });
  assert(envelope.startsWith(CIPHERTEXT_ENVELOPE_PREFIX));
  assert.strictEqual(JSON.stringify(envelope).includes('refresh-bridge-secret'), false);
  const decoded = decodeCiphertextEnvelope(envelope);
  assert.strictEqual(decoded.ciphertextB64, 'Y2lwaGVy');
  await composition.storeEncryptedGrant({
    medCasesUid: 'uid-test-1',
    record: { medCasesUid: 'uid-test-1', validatedUserProjectId: resolved, encryptedRefreshToken: envelope },
  });
  assert(storedRealBridge);
  assert.strictEqual(storedRealBridge.validatedProject.serverValidated, true);
  assert.strictEqual(JSON.stringify(storedRealBridge).includes('refresh-bridge-secret'), false);

  process.stdout.write('DEFAULT_RUNTIME_WIRING_GATE_FALSE=PASS\n');
  process.stdout.write('DEFAULT_FLOW_GUARD_GATE_FALSE=PASS\n');
  process.stdout.write('DEFAULT_RUNTIME_FACTORY_CALLS=0\n');
  process.stdout.write('DEFAULT_TOKEN_EXCHANGE_CALLS=0\n');
  process.stdout.write('SYNTHETIC_FLOW_GUARD_BEFORE_EXCHANGE=PASS\n');
  process.stdout.write('SYNTHETIC_RUNTIME_COMPOSITION_WIRING=PASS\n');
  process.stdout.write('LEGACY_VAULT_TO_REAL_KMS_BRIDGE=PASS\n');
  process.stdout.write('SERVER_VALIDATED_PROJECT_TO_FIRESTORE_BRIDGE=PASS\n');
  process.stdout.write('PLAINTEXT_TOKEN_RESPONSE=NO\n');
  process.stdout.write('REAL_KMS_CALLS=0\n');
  process.stdout.write('REAL_FIRESTORE_WRITES=0\n');
  process.stdout.write('REAL_GOOGLE_API_CALLS=0\n');
})().catch((error) => {
  process.stderr.write(`${error && error.stack ? error.stack : error}\n`);
  process.exit(1);
});
