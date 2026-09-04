'use strict';

const assert = require('assert');
const {
  createPhysicalCanaryHttpHandler,
  sha256Hex,
} = require(
  '../lib/ai_control_plane_v2/' +
  'study_google_ai_oauth_physical_canary_http_server_v1'
);

function fakeReq({
  method = 'POST',
  headers = {},
  body = {},
} = {}) {
  const data = Buffer.from(JSON.stringify(body), 'utf8');

  return {
    method,
    headers,
    async *[Symbol.asyncIterator]() {
      if (data.length) yield data;
    },
  };
}

function fakeRes() {
  return {
    statusCode: 0,
    headers: {},
    body: '',
    setHeader(k, v) {
      this.headers[String(k).toLowerCase()] = String(v);
    },
    end(v) {
      this.body = String(v || '');
    },
  };
}

async function run() {
  const arm = 'synthetic-canary-arm-test-only';
  const expectedArmSha256 = sha256Hex(arm);
  const webClientId =
    '1234567890-test.apps.googleusercontent.com';

  let verifyCalls = 0;
  let issueCalls = 0;
  let createOrchestratorCalls = 0;
  let orchestratorCalls = 0;

  const handler = createPhysicalCanaryHttpHandler({
    expectedArmSha256,
    webClientId,

    verifyFirebaseIdToken: async (token) => {
      verifyCalls += 1;
      if (token !== 'firebase-id-token-synthetic') {
        throw new Error('INVALID_ID_TOKEN');
      }
      return { uid: 'uid-synthetic-1' };
    },

    issueOAuthFlowChallenge: async ({ medcasesUid }) => {
      issueCalls += 1;
      assert.strictEqual(medcasesUid, 'uid-synthetic-1');
      return {
        challengeId: 'challenge-synthetic',
        state: 'state-synthetic',
        nonce: 'nonce-synthetic',
        expiresAtMs: 123456789,
      };
    },

    createOrchestrator: ({ medcasesUid }) => {
      createOrchestratorCalls += 1;
      assert.strictEqual(medcasesUid, 'uid-synthetic-1');

      return async (input) => {
        orchestratorCalls += 1;
        assert.strictEqual(
          input.serverAuthorizationCode,
          'auth-code-synthetic'
        );
        return {
          accepted: true,
          accessTokenReturned: false,
          refreshTokenReturned: false,
          authorizationCodeReturned: false,
          accessTokenPersisted: false,
          refreshTokenPlaintextPersisted: false,
          authorizationCodePersisted: false,
          validatedProjectId: 'user-project-12345',
        };
      };
    },
  });

  {
    const req = fakeReq({ body: { action: 'issue' } });
    const res = fakeRes();
    await handler(req, res);
    assert.strictEqual(res.statusCode, 401);
    assert.strictEqual(JSON.parse(res.body).safeReason, 'firebase_auth_required');
    assert.strictEqual(verifyCalls, 0);
    assert.strictEqual(issueCalls, 0);
  }

  {
    const req = fakeReq({
      headers: {
        authorization: 'Bearer firebase-id-token-synthetic',
        'x-medcases-canary-arm': 'wrong-arm',
      },
      body: { action: 'issue' },
    });
    const res = fakeRes();
    await handler(req, res);
    assert.strictEqual(res.statusCode, 403);
    assert.strictEqual(JSON.parse(res.body).safeReason, 'canary_arm_rejected');
    assert.strictEqual(issueCalls, 0);
  }

  {
    const req = fakeReq({
      headers: {
        authorization: 'Bearer firebase-id-token-synthetic',
        'x-medcases-canary-arm': arm,
      },
      body: { action: 'issue' },
    });
    const res = fakeRes();
    await handler(req, res);
    assert.strictEqual(res.statusCode, 200);
    const parsed = JSON.parse(res.body);
    assert.strictEqual(parsed.ok, true);
    assert.strictEqual(parsed.challengeId, 'challenge-synthetic');
    assert.strictEqual(parsed.oauth.webClientId, webClientId);
    assert.strictEqual(parsed.oauth.forceCodeForRefreshToken, true);
    assert.deepStrictEqual(parsed.oauth.scopes, [
      'https://www.googleapis.com/auth/cloud-platform',
      'https://www.googleapis.com/auth/generative-language.retriever',
    ]);
    assert.strictEqual(parsed.generalStudyTrafficEnabled, false);
    assert.strictEqual(issueCalls, 1);
  }

  {
    const rawCode = 'auth-code-synthetic';
    const req = fakeReq({
      headers: {
        authorization: 'Bearer firebase-id-token-synthetic',
        'x-medcases-canary-arm': arm,
      },
      body: {
        action: 'exchange',
        challengeId: 'challenge-synthetic',
        state: 'state-synthetic',
        nonce: 'nonce-synthetic',
        serverAuthorizationCode: rawCode,
      },
    });
    const res = fakeRes();
    await handler(req, res);
    assert.strictEqual(res.statusCode, 200);
    const parsed = JSON.parse(res.body);
    assert.strictEqual(parsed.ok, true);
    assert.strictEqual(parsed.generalStudyTrafficEnabled, false);
    assert.strictEqual(
      JSON.stringify(parsed).includes(rawCode),
      false
    );
    assert.strictEqual(
      parsed.result.refreshTokenPlaintextPersisted,
      false
    );
    assert.strictEqual(parsed.result.accessTokenPersisted, false);
    assert.strictEqual(parsed.result.authorizationCodePersisted, false);
    assert.strictEqual(createOrchestratorCalls, 1);
    assert.strictEqual(orchestratorCalls, 1);
  }

  console.log('FIREBASE_AUTH_REQUIRED_BEFORE_CANARY_ARM=PASS');
  console.log('CANARY_ARM_SHA256_ONLY_CONTRACT=PASS');
  console.log('FLOW_CHALLENGE_ISSUE_AUTH_BOUND=PASS');
  console.log('EXCHANGE_AUTH_BOUND=PASS');
  console.log('SERVER_AUTH_CODE_NOT_RETURNED=PASS');
  console.log('GENERAL_STUDY_TRAFFIC_FALSE_IN_RESPONSE=PASS');
  console.log('REAL_GOOGLE_OAUTH_CALLS=0');
  console.log('REAL_GEMINI_API_CALLS=0');
  console.log('REAL_KMS_CALLS=0');
  console.log('REAL_FIRESTORE_WRITES=0');
  console.log(
    'RESULT=PASS_STUDY_OAUTH_TEMP_FIREBASE_AUTH_PHYSICAL_CANARY_HTTP_SERVER_CONTRACT'
  );
}

run().catch((error) => {
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
});
