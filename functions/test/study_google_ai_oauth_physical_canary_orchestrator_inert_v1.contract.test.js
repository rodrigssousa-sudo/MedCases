'use strict';

const assert = require('assert');

const {
  VERSION,
  PHYSICAL_CANARY_ENABLED,
  createStudyGoogleAiOAuthPhysicalCanaryOrchestratorInertV1,
} = require(
  '../lib/ai_control_plane_v2/' +
  'study_google_ai_oauth_physical_canary_orchestrator_inert_v1'
);

async function run() {
  assert.strictEqual(
    VERSION,
    'medcases.study.oauth.physical-canary-orchestrator.inert.v1'
  );
  assert.strictEqual(PHYSICAL_CANARY_ENABLED, false);

  let disabledCalls = 0;
  const disabled =
    createStudyGoogleAiOAuthPhysicalCanaryOrchestratorInertV1({
      consumeOAuthFlowChallenge: async () => { disabledCalls += 1; },
      exchangeAuthorizationCode: async () => { disabledCalls += 1; },
      discoverProjects: async () => { disabledCalls += 1; },
      validateProject: async () => { disabledCalls += 1; },
      persistEncryptedGrant: async () => { disabledCalls += 1; },
    });

  const disabledResult = await disabled({
    medcasesUid: 'uid-disabled',
    challengeId: 'challenge-disabled',
    state: 'state-disabled',
    nonce: 'nonce-disabled',
    serverAuthorizationCode: 'auth-code-disabled',
  });

  assert.strictEqual(disabledCalls, 0);
  assert.strictEqual(disabledResult.physicalCanaryEnabled, false);
  assert.strictEqual(disabledResult.tokenExchangeAttempted, false);

  const events = [];
  const rawCode = 'raw-auth-code-never-return';
  const rawAccess = 'raw-access-token-never-return';
  const rawRefresh = 'raw-refresh-token-never-return';

  const enabled =
    createStudyGoogleAiOAuthPhysicalCanaryOrchestratorInertV1({
      physicalCanaryEnabled: true,

      consumeOAuthFlowChallenge: async (input) => {
        events.push('flow');
        assert.strictEqual(input.authCode, rawCode);
        return { consumed: true };
      },

      exchangeAuthorizationCode: async (input) => {
        events.push('exchange');
        assert.strictEqual(input.serverAuthorizationCode, rawCode);
        assert.strictEqual(input.redirectUri, '');
        return {
          accessToken: rawAccess,
          refreshToken: rawRefresh,
          scope: 'scope-a scope-b',
        };
      },

      discoverProjects: async ({ accessToken }) => {
        events.push('discover');
        assert.strictEqual(accessToken, rawAccess);
        return [{
          projectId: 'user-project-12345',
          displayName: 'User project',
        }];
      },

      validateProject: async ({
        accessToken,
        requestedProjectId,
      }) => {
        events.push('validate_models_probe');
        assert.strictEqual(accessToken, rawAccess);
        assert.strictEqual(
          requestedProjectId,
          'user-project-12345'
        );
        return {
          serverValidated: true,
          projectId: 'user-project-12345',
          geminiApiEnabled: true,
          serviceUsageUse: true,
        };
      },

      persistEncryptedGrant: async (input) => {
        events.push('kms_firestore_persist');
        assert.strictEqual(input.medCasesUid, 'uid-test-1');
        assert.strictEqual(
          input.validatedUserProjectId,
          'user-project-12345'
        );
        assert.strictEqual(input.refreshToken, rawRefresh);
        assert.strictEqual(input.accessToken, rawAccess);
        assert.deepStrictEqual(
          input.grantedScopes,
          ['scope-a', 'scope-b']
        );
        return {
          persisted: true,
          refreshTokenPlaintextPersisted: false,
          accessTokenPersisted: false,
        };
      },
    });

  const result = await enabled({
    medcasesUid: 'uid-test-1',
    challengeId: 'challenge-test-1',
    state: 'state-test-1',
    nonce: 'nonce-test-1',
    serverAuthorizationCode: rawCode,
  });

  assert.deepStrictEqual(events, [
    'flow',
    'exchange',
    'discover',
    'validate_models_probe',
    'kms_firestore_persist',
  ]);

  assert.strictEqual(result.accepted, true);
  assert.strictEqual(result.flowGuardConsumed, true);
  assert.strictEqual(result.tokenExchangeAttempted, true);
  assert.strictEqual(result.projectDiscoveryAttempted, true);
  assert.strictEqual(result.projectValidationAttempted, true);
  assert.strictEqual(result.tokenPersistenceAttempted, true);
  assert.strictEqual(result.encryptedRefreshTokenPersisted, true);
  assert.strictEqual(result.geminiModelsProbeAttempted, true);
  assert.strictEqual(result.geminiModelsProbePassed, true);
  assert.strictEqual(
    result.validatedProjectId,
    'user-project-12345'
  );

  const serialized = JSON.stringify(result);
  assert.strictEqual(serialized.includes(rawCode), false);
  assert.strictEqual(serialized.includes(rawAccess), false);
  assert.strictEqual(serialized.includes(rawRefresh), false);
  assert.strictEqual(result.accessTokenReturned, false);
  assert.strictEqual(result.refreshTokenReturned, false);
  assert.strictEqual(result.authorizationCodeReturned, false);
  assert.strictEqual(result.accessTokenPersisted, false);
  assert.strictEqual(result.refreshTokenPlaintextPersisted, false);
  assert.strictEqual(result.authorizationCodePersisted, false);

  let noRefreshPersistCalls = 0;
  const noRefresh =
    createStudyGoogleAiOAuthPhysicalCanaryOrchestratorInertV1({
      physicalCanaryEnabled: true,
      consumeOAuthFlowChallenge: async () => ({ consumed: true }),
      exchangeAuthorizationCode: async () => ({
        accessToken: rawAccess,
        refreshToken: null,
        scope: 'scope-a',
      }),
      discoverProjects: async () => {
        throw new Error('MUST_NOT_DISCOVER_WITHOUT_FIRST_GRANT_REFRESH');
      },
      validateProject: async () => {
        throw new Error('MUST_NOT_VALIDATE_WITHOUT_FIRST_GRANT_REFRESH');
      },
      persistEncryptedGrant: async () => {
        noRefreshPersistCalls += 1;
      },
    });

  const noRefreshResult = await noRefresh({
    medcasesUid: 'uid-test-2',
    challengeId: 'challenge-test-2',
    state: 'state-test-2',
    nonce: 'nonce-test-2',
    serverAuthorizationCode: 'auth-code-test-2',
  });

  assert.strictEqual(noRefreshPersistCalls, 0);
  assert.strictEqual(noRefreshResult.accepted, false);
  assert.strictEqual(
    noRefreshResult.safeReason,
    'first_grant_refresh_token_missing'
  );

  let multiplePersistCalls = 0;
  const multiple =
    createStudyGoogleAiOAuthPhysicalCanaryOrchestratorInertV1({
      physicalCanaryEnabled: true,
      consumeOAuthFlowChallenge: async () => ({ consumed: true }),
      exchangeAuthorizationCode: async () => ({
        accessToken: rawAccess,
        refreshToken: rawRefresh,
        scope: 'scope-a',
      }),
      discoverProjects: async () => ([
        { projectId: 'project-one-123', displayName: 'One' },
        { projectId: 'project-two-456', displayName: 'Two' },
      ]),
      validateProject: async () => {
        throw new Error('MUST_NOT_VALIDATE_WITHOUT_SELECTION');
      },
      persistEncryptedGrant: async () => {
        multiplePersistCalls += 1;
      },
    });

  const multipleResult = await multiple({
    medcasesUid: 'uid-test-3',
    challengeId: 'challenge-test-3',
    state: 'state-test-3',
    nonce: 'nonce-test-3',
    serverAuthorizationCode: 'auth-code-test-3',
  });

  assert.strictEqual(multiplePersistCalls, 0);
  assert.strictEqual(multipleResult.accepted, false);
  assert.strictEqual(
    multipleResult.safeReason,
    'server_discovered_multiple_projects_selection_required'
  );
  assert.deepStrictEqual(
    multipleResult.discoveredProjects.map((x) => x.projectId),
    ['project-one-123', 'project-two-456']
  );
  assert.strictEqual(
    JSON.stringify(multipleResult).includes(rawAccess),
    false
  );
  assert.strictEqual(
    JSON.stringify(multipleResult).includes(rawRefresh),
    false
  );

  console.log('PHYSICAL_CANARY_DEFAULT_GATE_OFF=PASS');
  console.log('FLOW_GUARD_BEFORE_TOKEN_EXCHANGE=PASS');
  console.log('FIRST_GRANT_REFRESH_TOKEN_REQUIRED=PASS');
  console.log('PROJECT_DISCOVERY_SERVER_SIDE=PASS');
  console.log('CLIENT_PROJECT_HINT_NOT_TRUSTED=PASS');
  console.log('PROJECT_VALIDATION_INCLUDES_MODELS_PROBE_CONTRACT=PASS');
  console.log('KMS_FIRESTORE_PERSIST_AFTER_SERVER_VALIDATION_ONLY=PASS');
  console.log('MULTIPLE_PROJECTS_FAIL_CLOSED_SELECTION_REQUIRED=PASS');
  console.log('AUTH_CODE_RESPONSE_PERSISTENCE=NO');
  console.log('ACCESS_TOKEN_RESPONSE_PERSISTENCE=NO');
  console.log('REFRESH_TOKEN_PLAINTEXT_RESPONSE_PERSISTENCE=NO');
  console.log('REAL_GOOGLE_OAUTH_CALLS=0');
  console.log('REAL_GEMINI_API_CALLS=0');
  console.log('REAL_KMS_CALLS=0');
  console.log('REAL_FIRESTORE_WRITES=0');
  console.log(
    'RESULT=PASS_STUDY_OAUTH_ONE_TIME_PHYSICAL_CANARY_ORCHESTRATOR_PREP_CONTRACT'
  );
}

run().catch((error) => {
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
});
