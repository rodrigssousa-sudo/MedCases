'use strict';

const assert = require('assert');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');

const {
  StudyGoogleAiOAuthPendingGrantV1,
  pendingAadProjectBinding,
  sha256Hex,
} = require(path.join(
  ROOT,
  'lib/ai_control_plane_v2/study_google_ai_oauth_pending_grant_v1.js',
));

const {
  createRefreshAccessTokenV1,
} = require(path.join(
  ROOT,
  'lib/ai_control_plane_v2/study_google_ai_oauth_refresh_access_token_secret_bound_v1.js',
));

const {
  createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1,
} = require(path.join(
  ROOT,
  'lib/ai_control_plane_v2/study_google_ai_oauth_two_phase_physical_canary_orchestrator_inert_v1.js',
));

function noSecretMaterial(value) {
  const json = JSON.stringify(value);
  assert(!json.includes('refresh-token-secret'));
  assert(!json.includes('access-token-secret'));
  assert(!json.includes('server-auth-code-secret'));
}

(async () => {
  const projects = [
    { projectId: 'project-a', displayName: 'A' },
    { projectId: 'project-b', displayName: 'B' },
  ];

  let storedPending = null;
  let decryptedBinding = null;

  const fakeKms = {
    async encryptRefreshToken({ refreshToken, medcasesUid, projectId }) {
      assert.strictEqual(refreshToken, 'refresh-token-secret');
      assert.strictEqual(medcasesUid, 'uid-1');
      assert(projectId.startsWith('__medcases_pending_oauth__:'));
      return {
        schema: 'medcases.study.oauth.kms.refresh-token.v1',
        keyName: 'fake-key',
        ciphertextB64: 'ZW5jcnlwdGVk',
        aadSha256: sha256Hex(projectId),
      };
    },
    async decryptRefreshToken({ encryptedRecord, medcasesUid, projectId }) {
      assert.strictEqual(medcasesUid, 'uid-1');
      assert.strictEqual(encryptedRecord.ciphertextB64, 'ZW5jcnlwdGVk');
      decryptedBinding = projectId;
      return 'refresh-token-secret';
    },
  };

  const fakeStore = {
    async createPendingGrant(input) {
      storedPending = JSON.parse(JSON.stringify(input));
      noSecretMaterial(storedPending);
      assert.strictEqual(
        storedPending.selectionIdSha256.length,
        64,
      );
      assert.strictEqual(storedPending.discoveredProjects.length, 2);
      return { created: true };
    },
    async consumePendingGrant({
      selectionIdSha256,
      selectedProjectId,
    }) {
      assert(storedPending);
      assert.strictEqual(
        selectionIdSha256,
        storedPending.selectionIdSha256,
      );
      assert.strictEqual(selectedProjectId, 'project-b');
      return {
        consumed: true,
        encryptedRefreshToken:
          storedPending.encryptedRefreshToken,
        discoveredProjects:
          storedPending.discoveredProjects,
        grantedScopes:
          storedPending.grantedScopes,
      };
    },
  };

  const deterministicRandom = () => Buffer.alloc(24, 7);
  const pendingDomain = new StudyGoogleAiOAuthPendingGrantV1({
    kmsAdapter: fakeKms,
    store: fakeStore,
    randomBytes: deterministicRandom,
    clock: () => 1_000_000,
    ttlMs: 600_000,
  });

  const pending = await pendingDomain.createPendingGrant({
    medcasesUid: 'uid-1',
    refreshToken: 'refresh-token-secret',
    discoveredProjects: projects,
    grantedScopes: ['scope-b', 'scope-a', 'scope-a'],
  });

  assert(pending.selectionId);
  assert.strictEqual(pending.expiresAtMs, 1_600_000);
  assert.strictEqual(pending.discoveredProjects.length, 2);
  noSecretMaterial(pending);

  const consumed = await pendingDomain.consumePendingGrant({
    medcasesUid: 'uid-1',
    selectionId: pending.selectionId,
    selectedProjectId: 'project-b',
  });

  assert.strictEqual(consumed.refreshToken, 'refresh-token-secret');
  assert.strictEqual(consumed.selectedProjectId, 'project-b');
  assert.strictEqual(
    decryptedBinding,
    pendingAadProjectBinding(sha256Hex(pending.selectionId)),
  );

  let refreshHttpBody = '';
  const refreshAccessToken = createRefreshAccessTokenV1({
    fetchImpl: async (_url, init) => {
      refreshHttpBody = String(init.body || '');
      return {
        ok: true,
        async json() {
          return {
            access_token: 'access-token-secret',
            scope: 'scope-a scope-b',
            expires_in: 3600,
          };
        },
      };
    },
    clientId: 'web-client-id',
    clientSecret: 'web-client-secret-runtime-only',
  });

  const refreshed = await refreshAccessToken({
    refreshToken: 'refresh-token-secret',
  });
  assert.strictEqual(refreshed.accessToken, 'access-token-secret');
  assert(refreshHttpBody.includes('grant_type=refresh_token'));
  assert(refreshHttpBody.includes('refresh_token=refresh-token-secret'));

  let phase1FlowConsume = 0;
  let phase1Exchange = 0;
  let pendingCreated = 0;
  let finalPersist = 0;

  const phase1 = createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1({
    consumeOAuthFlowChallenge: async () => {
      phase1FlowConsume += 1;
      return { consumed: true };
    },
    exchangeAuthorizationCode: async () => {
      phase1Exchange += 1;
      return {
        accessToken: 'access-token-secret',
        refreshToken: 'refresh-token-secret',
        scope: 'scope-a scope-b',
      };
    },
    discoverProjects: async () => projects,
    validateProject: async () => {
      throw new Error('PHASE1_MULTI_PROJECT_MUST_NOT_VALIDATE');
    },
    persistEncryptedGrant: async () => {
      finalPersist += 1;
      throw new Error('PHASE1_MULTI_PROJECT_MUST_NOT_FINAL_PERSIST');
    },
    createPendingGrant: async (input) => {
      pendingCreated += 1;
      assert.strictEqual(input.refreshToken, 'refresh-token-secret');
      return {
        selectionId: 'opaque-selection-id',
        expiresAtMs: 123456,
        discoveredProjects: projects,
      };
    },
    consumePendingGrant: async () => {
      throw new Error('PHASE1_MUST_NOT_CONSUME_PENDING');
    },
    refreshAccessToken: async () => {
      throw new Error('PHASE1_MUST_NOT_REFRESH_ACCESS');
    },
  });

  const phase1Result = await phase1({
    medcasesUid: 'uid-1',
    challengeId: 'challenge',
    state: 'state',
    nonce: 'nonce',
    serverAuthorizationCode: 'server-auth-code-secret',
  });

  assert.strictEqual(phase1FlowConsume, 1);
  assert.strictEqual(phase1Exchange, 1);
  assert.strictEqual(pendingCreated, 1);
  assert.strictEqual(finalPersist, 0);
  assert.strictEqual(phase1Result.accepted, false);
  assert.strictEqual(phase1Result.selectionRequired, true);
  assert.strictEqual(
    phase1Result.safeReason,
    'server_discovered_multiple_projects_pending_selection',
  );
  assert.strictEqual(
    phase1Result.pendingEncryptedRefreshTokenPersisted,
    true,
  );
  noSecretMaterial(phase1Result);

  let phase2AuthExchange = 0;
  let phase2FlowConsume = 0;
  let phase2PendingConsume = 0;
  let phase2Refresh = 0;
  let phase2Validate = 0;
  let phase2Persist = 0;

  const phase2 = createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1({
    consumeOAuthFlowChallenge: async () => {
      phase2FlowConsume += 1;
      throw new Error('PHASE2_MUST_NOT_CONSUME_AUTH_FLOW');
    },
    exchangeAuthorizationCode: async () => {
      phase2AuthExchange += 1;
      throw new Error('PHASE2_MUST_NOT_EXCHANGE_AUTH_CODE');
    },
    discoverProjects: async () => {
      throw new Error('PHASE2_MUST_NOT_REDISCOVER_WITH_OLD_ACCESS_TOKEN');
    },
    validateProject: async ({ accessToken, requestedProjectId }) => {
      phase2Validate += 1;
      assert.strictEqual(accessToken, 'access-token-secret');
      assert.strictEqual(requestedProjectId, 'project-b');
      return {
        serverValidated: true,
        projectId: 'project-b',
        projectNumber: '22',
        displayName: 'B',
        geminiApiEnabled: true,
        serviceUsageUse: true,
      };
    },
    persistEncryptedGrant: async (input) => {
      phase2Persist += 1;
      assert.strictEqual(input.refreshToken, 'refresh-token-secret');
      assert.strictEqual(input.accessToken, 'access-token-secret');
      assert.strictEqual(input.validatedUserProjectId, 'project-b');
      return {
        persisted: true,
        encrypted: true,
      };
    },
    createPendingGrant: async () => {
      throw new Error('PHASE2_MUST_NOT_CREATE_NEW_PENDING');
    },
    consumePendingGrant: async ({
      selectionId,
      selectedProjectId,
    }) => {
      phase2PendingConsume += 1;
      assert.strictEqual(selectionId, 'opaque-selection-id');
      assert.strictEqual(selectedProjectId, 'project-b');
      return {
        refreshToken: 'refresh-token-secret',
        grantedScopes: ['scope-a', 'scope-b'],
        discoveredProjects: projects,
      };
    },
    refreshAccessToken: async ({ refreshToken }) => {
      phase2Refresh += 1;
      assert.strictEqual(refreshToken, 'refresh-token-secret');
      return {
        accessToken: 'access-token-secret',
      };
    },
  });

  const phase2Result = await phase2({
    medcasesUid: 'uid-1',
    requestedProjectId: 'project-b',
    selectionId: 'opaque-selection-id',
  });

  assert.strictEqual(phase2AuthExchange, 0);
  assert.strictEqual(phase2FlowConsume, 0);
  assert.strictEqual(phase2PendingConsume, 1);
  assert.strictEqual(phase2Refresh, 1);
  assert.strictEqual(phase2Validate, 1);
  assert.strictEqual(phase2Persist, 1);
  assert.strictEqual(phase2Result.accepted, true);
  assert.strictEqual(phase2Result.pendingSelectionConsumed, true);
  assert.strictEqual(
    phase2Result.safeReason,
    'physical_canary_ready_path_completed',
  );
  noSecretMaterial(phase2Result);

  let phase2CodeRejected = false;
  try {
    await phase2({
      medcasesUid: 'uid-1',
      requestedProjectId: 'project-b',
      selectionId: 'opaque-selection-id',
      serverAuthorizationCode: 'must-not-be-accepted',
    });
  } catch (error) {
    phase2CodeRejected =
      error &&
      error.message ===
        'PHASE2_MUST_NOT_INCLUDE_AUTHORIZATION_CODE_FLOW_FIELDS';
  }
  assert.strictEqual(phase2CodeRejected, true);

  console.log('PENDING_GRANT_TTL=PASS');
  console.log('OPAQUE_SELECTION_ID=PASS');
  console.log('SELECTION_ID_PERSISTENCE=SHA256_ONLY_CONTRACT');
  console.log('PENDING_REFRESH_TOKEN_ENCRYPTED=PASS');
  console.log('PENDING_ACCESS_TOKEN_PERSISTENCE=NO');
  console.log('PENDING_AUTH_CODE_PERSISTENCE=NO');
  console.log('PHASE1_MULTI_PROJECT_CREATES_PENDING_GRANT=PASS');
  console.log('PHASE1_MULTI_PROJECT_FINAL_VAULT_WRITE=NO');
  console.log('PHASE2_SECOND_AUTH_CODE_REQUIRED=NO');
  console.log('PHASE2_AUTH_CODE_EXCHANGE_CALLS=0');
  console.log('PHASE2_REFRESH_ACCESS_TOKEN=PASS');
  console.log('PHASE2_SERVER_PROJECT_VALIDATION=PASS');
  console.log('PHASE2_FINAL_ENCRYPTED_GRANT_PERSISTENCE=PASS');
  console.log('TOKEN_RESPONSE_PLAINTEXT=NO');
  console.log('REAL_GOOGLE_OAUTH_CALLS=0');
  console.log('REAL_KMS_CALLS=0');
  console.log('REAL_FIRESTORE_WRITES=0');
  console.log('RESULT=PASS_STUDY_OAUTH_TWO_PHASE_PENDING_ENCRYPTED_GRANT_FOUNDATION_CONTRACT');
})().catch((error) => {
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
});
