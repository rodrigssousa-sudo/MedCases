'use strict';

const assert = require('assert');

const {
  VERSION,
  TOKEN_ENDPOINT,
  CLIENT_SECRET_ENV,
  readBoundClientSecret,
  exchangeServerAuthorizationCode,
  exchangeWithBoundSecret,
} = require(
  '../lib/ai_control_plane_v2/' +
  'study_google_ai_oauth_token_exchange_secret_bound_v1'
);

async function run() {
  assert.strictEqual(
    VERSION,
    'medcases_study_google_ai_oauth_token_exchange_secret_bound_v1'
  );

  assert.strictEqual(
    TOKEN_ENDPOINT,
    'https://oauth2.googleapis.com/token'
  );

  assert.strictEqual(
    CLIENT_SECRET_ENV,
    'MEDCASES_STUDY_GOOGLE_OAUTH_WEB_CLIENT_SECRET_V1'
  );

  const fakeSecret =
    'fake-test-client-secret-not-real';

  assert.strictEqual(
    readBoundClientSecret({
      [CLIENT_SECRET_ENV]: fakeSecret,
    }),
    fakeSecret
  );

  assert.throws(
    () => readBoundClientSecret({}),
    /OAUTH_CLIENT_SECRET_BOUND_ENV_MISSING/
  );

  let requestSeen = null;

  const fakeFetch = async (
    url,
    options
  ) => {
    requestSeen = {
      url,
      options,
    };

    return {
      ok: true,
      status: 200,
      async json() {
        return {
          access_token:
            'fake-access-token-test-only',
          refresh_token:
            'fake-refresh-token-test-only',
          id_token:
            'fake-id-token-test-only',
          expires_in: 3600,
          token_type: 'Bearer',
          scope:
            'scope-a scope-b',
        };
      },
    };
  };

  const result =
    await exchangeWithBoundSecret({
      serverAuthorizationCode:
        'fake-server-auth-code-test-only',
      clientId:
        '123456789-test.apps.googleusercontent.com',
      redirectUri: '',
      fetchImpl: fakeFetch,
      env: {
        [CLIENT_SECRET_ENV]:
          fakeSecret,
      },
    });

  assert.ok(requestSeen);
  assert.strictEqual(
    requestSeen.url,
    TOKEN_ENDPOINT
  );

  assert.strictEqual(
    requestSeen.options.method,
    'POST'
  );

  const parsed =
    new URLSearchParams(
      requestSeen.options.body
    );

  assert.strictEqual(
    parsed.get('code'),
    'fake-server-auth-code-test-only'
  );

  assert.strictEqual(
    parsed.get('client_secret'),
    fakeSecret
  );

  assert.strictEqual(
    parsed.get('grant_type'),
    'authorization_code'
  );

  assert.strictEqual(
    parsed.get('redirect_uri'),
    ''
  );

  assert.strictEqual(
    result.accessToken,
    'fake-access-token-test-only'
  );

  assert.strictEqual(
    result.refreshToken,
    'fake-refresh-token-test-only'
  );

  assert.strictEqual(
    result.expiresInSeconds,
    3600
  );

  const failedFetch =
    async () => ({
      ok: false,
      status: 400,
      async json() {
        return {
          error: 'invalid_grant',
        };
      },
    });

  let failed = null;

  try {
    await exchangeServerAuthorizationCode({
      serverAuthorizationCode:
        'fake-invalid-code-test-only',
      clientId:
        '123456789-test.apps.googleusercontent.com',
      clientSecret:
        fakeSecret,
      fetchImpl:
        failedFetch,
    });
  } catch (error) {
    failed = error;
  }

  assert.ok(failed);

  assert.strictEqual(
    failed.message,
    'OAUTH_TOKEN_EXCHANGE_FAILED'
  );

  assert.strictEqual(
    failed.safeOAuthError,
    'invalid_grant'
  );

  assert.strictEqual(
    failed.httpStatus,
    400
  );

  console.log(
    'SECRET_BOUND_ENV_READER_CONTRACT=PASS'
  );

  console.log(
    'TOKEN_EXCHANGE_REQUEST_SHAPE_CONTRACT=PASS'
  );

  console.log(
    'TOKEN_EXCHANGE_SUCCESS_PARSE_CONTRACT=PASS'
  );

  console.log(
    'TOKEN_EXCHANGE_SAFE_ERROR_CONTRACT=PASS'
  );

  console.log(
    'REAL_NETWORK_PROVIDER_CALLS=0'
  );

  console.log(
    'REAL_SECRET_VALUES_USED=0'
  );

  console.log(
    'RESULT=PASS_STUDY_GOOGLE_AI_OAUTH_TOKEN_EXCHANGE_SECRET_BOUND_CONTRACT'
  );
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
