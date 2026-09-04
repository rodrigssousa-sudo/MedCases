'use strict';

const assert = require('assert');

const {
  TOKEN_EXCHANGE_ENABLED,
  TOKEN_PERSISTENCE_ENABLED,
  CLIENT_SECRET_ENV,
  createStudyGoogleAiOAuthExchangeEndpointInert,
} = require(
  '../lib/ai_control_plane_v2/' +
  'study_google_ai_oauth_exchange_endpoint_inert_v1'
);

function fakeResponse() {
  const state = {
    statusCode: null,
    body: null,
    headers: {},
  };

  return {
    state,
    set(name, value) {
      state.headers[name] = value;
      return this;
    },
    status(code) {
      state.statusCode = code;
      return this;
    },
    json(body) {
      state.body = body;
      return body;
    },
  };
}

function requestBody() {
  return {
    medCasesUid:
      'uid-test-1',
    serverAuthorizationCode:
      'fake-server-auth-code',
    nonce:
      'nonce-12345678901234567890',
  };
}

async function run() {
  assert.strictEqual(
    TOKEN_EXCHANGE_ENABLED,
    false
  );

  assert.strictEqual(
    TOKEN_PERSISTENCE_ENABLED,
    false
  );

  assert.strictEqual(
    CLIENT_SECRET_ENV,
    'MEDCASES_STUDY_GOOGLE_OAUTH_WEB_CLIENT_SECRET_V1'
  );

  let exchangeCalls = 0;
  let resolverCalls = 0;
  let persistCalls = 0;
  let encryptCalls = 0;
  let storeCalls = 0;

  const disabledHandler =
    createStudyGoogleAiOAuthExchangeEndpointInert({
      verifyIdToken:
        async () => ({
          uid: 'uid-test-1',
        }),
      exchangeEnabled:
        false,
      tokenPersistenceEnabled:
        false,
      exchangeAuthorizationCode:
        async () => {
          exchangeCalls += 1;
          throw new Error(
            'MUST_NOT_RUN'
          );
        },
      resolveValidatedUserProjectId:
        async () => {
          resolverCalls += 1;
          return 'user-project-12345';
        },
      persistOAuthGrant:
        async () => {
          persistCalls += 1;
          return {
            persisted: true,
          };
        },
    });

  const disabledRes =
    fakeResponse();

  await disabledHandler(
    {
      method: 'POST',
      headers: {
        authorization:
          'Bearer fake-firebase-token',
      },
      body:
        requestBody(),
    },
    disabledRes
  );

  assert.strictEqual(
    exchangeCalls,
    0
  );

  assert.strictEqual(
    resolverCalls,
    0
  );

  assert.strictEqual(
    persistCalls,
    0
  );

  assert.strictEqual(
    disabledRes.state.body.tokenExchangeAttempted,
    false
  );

  const exchangedNoPersistHandler =
    createStudyGoogleAiOAuthExchangeEndpointInert({
      verifyIdToken:
        async () => ({
          uid: 'uid-test-1',
        }),
      exchangeEnabled:
        true,
      tokenPersistenceEnabled:
        false,
      exchangeAuthorizationCode:
        async () => {
          exchangeCalls += 1;
          return {
            accessToken:
              'fake-access-token',
            refreshToken:
              'fake-refresh-token',
            scope:
              'scope-a scope-b',
          };
        },
      publicWebClientId:
        '123456789-test.apps.googleusercontent.com',
      secretEnv: {
        [CLIENT_SECRET_ENV]:
          'fake-test-secret',
      },
    });

  const noPersistRes =
    fakeResponse();

  await exchangedNoPersistHandler(
    {
      method: 'POST',
      headers: {
        authorization:
          'Bearer fake-firebase-token',
      },
      body:
        requestBody(),
    },
    noPersistRes
  );

  assert.strictEqual(
    exchangeCalls,
    1
  );

  assert.strictEqual(
    noPersistRes.state.body.tokenPersisted,
    false
  );

  assert.strictEqual(
    noPersistRes.state.body.safeReason,
    'token_persistence_not_enabled'
  );

  const fullySyntheticHandler =
    createStudyGoogleAiOAuthExchangeEndpointInert({
      verifyIdToken:
        async () => ({
          uid: 'uid-test-1',
        }),
      exchangeEnabled:
        true,
      tokenPersistenceEnabled:
        true,
      exchangeAuthorizationCode:
        async () => {
          exchangeCalls += 1;
          return {
            accessToken:
              'fake-access-token',
            refreshToken:
              'fake-refresh-token',
            scope:
              'scope-b scope-a',
          };
        },
      resolveValidatedUserProjectId:
        async ({ accessToken, medCasesUid }) => {
          resolverCalls += 1;

          assert.strictEqual(
            accessToken,
            'fake-access-token'
          );

          assert.strictEqual(
            medCasesUid,
            'uid-test-1'
          );

          return 'user-project-12345';
        },
      encryptRefreshToken:
        async ({ plaintext }) => {
          encryptCalls += 1;

          assert.strictEqual(
            plaintext,
            'fake-refresh-token'
          );

          return (
            'kms-ciphertext:' +
            Buffer.from(
              plaintext
            ).toString('base64')
          );
        },
      storeEncryptedGrant:
        async ({ medCasesUid, record }) => {
          storeCalls += 1;

          assert.strictEqual(
            medCasesUid,
            'uid-test-1'
          );

          assert.strictEqual(
            record.validatedUserProjectId,
            'user-project-12345'
          );

          const serialized =
            JSON.stringify(record);

          assert.strictEqual(
            serialized.includes(
              'fake-refresh-token'
            ),
            false
          );

          assert.strictEqual(
            serialized.includes(
              'fake-access-token'
            ),
            false
          );
        },
      publicWebClientId:
        '123456789-test.apps.googleusercontent.com',
      secretEnv: {
        [CLIENT_SECRET_ENV]:
          'fake-test-secret',
      },
    });

  const fullRes =
    fakeResponse();

  await fullySyntheticHandler(
    {
      method: 'POST',
      headers: {
        authorization:
          'Bearer fake-firebase-token',
      },
      body:
        requestBody(),
    },
    fullRes
  );

  assert.strictEqual(
    resolverCalls,
    1
  );

  assert.strictEqual(
    encryptCalls,
    1
  );

  assert.strictEqual(
    storeCalls,
    1
  );

  assert.strictEqual(
    fullRes.state.body.tokenPersisted,
    true
  );

  assert.strictEqual(
    fullRes.state.body.projectBindingPersisted,
    true
  );

  assert.strictEqual(
    fullRes.state.body.refreshTokenPlaintextPersisted,
    false
  );

  assert.strictEqual(
    fullRes.state.body.accessTokenPersisted,
    false
  );

  const responseSerialized =
    JSON.stringify(fullRes.state);

  assert.strictEqual(
    responseSerialized.includes(
      'fake-refresh-token'
    ),
    false
  );

  assert.strictEqual(
    responseSerialized.includes(
      'fake-access-token'
    ),
    false
  );

  assert.strictEqual(
    responseSerialized.includes(
      'user-project-12345'
    ),
    false
  );

  console.log(
    'ENDPOINT_TOKEN_EXCHANGE_HARD_DISABLED_DEFAULT=PASS'
  );

  console.log(
    'ENDPOINT_TOKEN_PERSISTENCE_HARD_DISABLED_DEFAULT=PASS'
  );

  console.log(
    'DISABLED_PATH_EXCHANGE_RESOLVER_PERSIST_ZERO=PASS'
  );

  console.log(
    'SYNTHETIC_SERVER_VALIDATED_PROJECT_BINDING=PASS'
  );

  console.log(
    'SYNTHETIC_ENCRYPTED_REFRESH_TOKEN_PERSISTENCE=PASS'
  );

  console.log(
    'PLAINTEXT_TOKENS_NOT_RETURNED_TO_CLIENT=PASS'
  );

  console.log(
    'PROJECT_ID_NOT_RETURNED_TO_CLIENT=PASS'
  );

  console.log(
    'REAL_KMS_CALLS=0'
  );

  console.log(
    'REAL_FIRESTORE_WRITES=0'
  );

  console.log(
    'RESULT=PASS_STUDY_GOOGLE_AI_OAUTH_ENDPOINT_ENCRYPTED_VAULT_DISABLED_CONTRACT'
  );
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
