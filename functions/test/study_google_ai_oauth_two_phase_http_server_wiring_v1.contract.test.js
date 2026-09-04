'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { Readable } = require('stream');

const ROOT = path.resolve(__dirname, '..');
const SERVER = path.join(
  ROOT,
  'lib/ai_control_plane_v2/study_google_ai_oauth_physical_canary_http_server_v1.js',
);

const source = fs.readFileSync(SERVER, 'utf8');

function expectSource(label, condition) {
  assert.strictEqual(Boolean(condition), true, label);
  console.log(`${label}=PASS`);
}

expectSource(
  'HTTP_SELECTION_ID_FORWARD',
  source.includes('selectionId: cleanString(body.selectionId)'),
);
expectSource(
  'HTTP_TWO_PHASE_ORCHESTRATOR_WIRED',
  source.includes('createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1'),
);
expectSource(
  'HTTP_PENDING_DOMAIN_WIRED',
  source.includes('new StudyGoogleAiOAuthPendingGrantV1({'),
);
expectSource(
  'HTTP_PENDING_FIRESTORE_STORE_WIRED',
  source.includes('new StudyGoogleAiOAuthPendingGrantFirestoreStoreV1({'),
);
expectSource(
  'HTTP_RUNTIME_PENDING_KMS_ADAPTER_WIRED',
  source.includes('kmsAdapter: runtime.pendingGrantKmsAdapter'),
);
expectSource(
  'HTTP_REFRESH_ACCESS_ADAPTER_WIRED',
  source.includes('createRefreshAccessTokenV1({'),
);
expectSource(
  'HTTP_WEB_SECRET_ENV_NAME_ONLY_WIRED',
  source.includes('MEDCASES_STUDY_GOOGLE_OAUTH_WEB_CLIENT_SECRET_V1'),
);
expectSource(
  'HTTP_FINAL_PERSISTENCE_ENCRYPTED_SHAPE_ADAPTER',
  source.includes('persistence.encryptedRefreshTokenPresent === true'),
);
expectSource(
  'HTTP_FIREBASE_AUTH_PRESERVED',
  source.includes('verifyFirebaseIdToken'),
);
expectSource(
  'HTTP_ARM_GUARD_PRESERVED',
  source.includes('constantTimeHexEquals(sha256Hex(providedArm), armSha)'),
);

const prodStart = source.indexOf('function createProductionServer()');
const prodEnd = source.indexOf('\nif (require.main === module)', prodStart);
assert(prodStart >= 0 && prodEnd > prodStart);
const production = source.slice(prodStart, prodEnd);
expectSource(
  'HTTP_LEGACY_ORCHESTRATOR_NOT_CALLED_IN_PRODUCTION',
  !production.includes('createStudyGoogleAiOAuthPhysicalCanaryOrchestratorInertV1'),
);

const {
  createPhysicalCanaryHttpHandler,
  sha256Hex,
} = require(SERVER);

function makeReq(payload, arm) {
  const req = Readable.from([Buffer.from(JSON.stringify(payload), 'utf8')]);
  req.method = 'POST';
  req.headers = {
    authorization: 'Bearer firebase-test-token',
    'x-medcases-canary-arm': arm,
  };
  return req;
}

function makeRes() {
  return {
    statusCode: 0,
    headers: {},
    body: '',
    setHeader(name, value) {
      this.headers[String(name).toLowerCase()] = String(value);
    },
    end(value) {
      this.body = value == null ? '' : String(value);
    },
  };
}

(async () => {
  const arm = 'test-arm-token';
  let captured = null;
  let issueCalls = 0;

  const handler = createPhysicalCanaryHttpHandler({
    verifyFirebaseIdToken: async () => ({ uid: 'uid-test' }),
    issueOAuthFlowChallenge: async () => {
      issueCalls += 1;
      throw new Error('PHASE2_MUST_NOT_ISSUE_CHALLENGE');
    },
    createOrchestrator: ({ medcasesUid }) => {
      assert.strictEqual(medcasesUid, 'uid-test');
      return async (input) => {
        captured = { ...input };
        return {
          accepted: true,
          safeReason: 'physical_canary_ready_path_completed',
          validatedProject: { projectId: 'project-b' },
        };
      };
    },
    webClientId: 'test.apps.googleusercontent.com',
    expectedArmSha256: sha256Hex(arm),
  });

  const req = makeReq(
    {
      action: 'exchange',
      selectionId: 'opaque-selection-id',
      requestedProjectId: 'project-b',
    },
    arm,
  );
  const res = makeRes();

  await handler(req, res);

  assert.strictEqual(issueCalls, 0);
  assert(captured);
  assert.strictEqual(captured.medcasesUid, 'uid-test');
  assert.strictEqual(captured.selectionId, 'opaque-selection-id');
  assert.strictEqual(captured.requestedProjectId, 'project-b');
  assert.strictEqual(captured.challengeId, '');
  assert.strictEqual(captured.state, '');
  assert.strictEqual(captured.nonce, '');
  assert.strictEqual(captured.serverAuthorizationCode, '');
  assert.strictEqual(res.statusCode, 200);

  const responseJson = JSON.parse(res.body);
  assert.strictEqual(responseJson.ok, true);

  console.log('HTTP_PHASE2_HANDLER_ISSUE_CALLS=0');
  console.log('HTTP_PHASE2_HANDLER_AUTH_CODE_FIELDS=EMPTY');
  console.log('HTTP_PHASE2_HANDLER_SELECTION_FORWARD=PASS');
  console.log('REAL_GOOGLE_OAUTH_CALLS=0');
  console.log('REAL_KMS_CALLS=0');
  console.log('REAL_FIRESTORE_WRITES=0');
  console.log(
    'RESULT=PASS_STUDY_OAUTH_TWO_PHASE_HTTP_SERVER_WIRING_CONTRACT',
  );
})().catch((error) => {
  console.error(error && error.stack ? error.stack : error);
  process.exitCode = 1;
});
