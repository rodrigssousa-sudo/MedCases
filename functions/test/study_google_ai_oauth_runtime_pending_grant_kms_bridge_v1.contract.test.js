'use strict';

const assert = require('assert');

const {
  CIPHERTEXT_ENVELOPE_PREFIX,
  createStudyGoogleAiOAuthRuntimeCompositionInertV1,
  decodeCiphertextEnvelope,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_runtime_composition_inert_v1');

(async () => {
  let kmsEncryptCalls = 0;
  let kmsDecryptCalls = 0;
  let firestoreWrites = 0;
  let googleCalls = 0;

  const fakeKmsAdapter = {
    async encryptRefreshToken({
      refreshToken,
      medcasesUid,
      projectId,
    }) {
      kmsEncryptCalls += 1;
      assert(refreshToken);
      assert(medcasesUid);
      assert(projectId);
      return {
        schema: 'medcases.study.oauth.kms.refresh-token.v1',
        keyName: 'fake-key',
        ciphertextB64: 'ZmFrZS1jaXBoZXJ0ZXh0',
        aadSha256: 'a'.repeat(64),
      };
    },

    async decryptRefreshToken({
      encryptedRecord,
      medcasesUid,
      projectId,
    }) {
      kmsDecryptCalls += 1;
      assert.strictEqual(
        encryptedRecord.ciphertextB64,
        'ZmFrZS1jaXBoZXJ0ZXh0',
      );
      assert.strictEqual(medcasesUid, 'uid-test');
      assert.strictEqual(projectId, 'pending-binding-test');
      return 'refresh-token-plaintext-test-only';
    },
  };

  const fakeFirestoreAdapter = {
    async upsertEncryptedCredential() {
      firestoreWrites += 1;
      throw new Error('UNEXPECTED_FIRESTORE_WRITE');
    },
  };

  const fakeProjectValidator = {
    async discoverProjects() {
      googleCalls += 1;
      throw new Error('UNEXPECTED_GOOGLE_DISCOVERY');
    },
    async validateProject() {
      googleCalls += 1;
      throw new Error('UNEXPECTED_GOOGLE_VALIDATION');
    },
  };

  const fakeFlowGuard = {
    async issueChallenge() {
      throw new Error('UNEXPECTED_FLOW_ISSUE');
    },
    async consumeChallenge() {
      throw new Error('UNEXPECTED_FLOW_CONSUME');
    },
  };

  const runtime =
    createStudyGoogleAiOAuthRuntimeCompositionInertV1({
      kmsAdapter: fakeKmsAdapter,
      firestoreAdapter: fakeFirestoreAdapter,
      projectValidator: fakeProjectValidator,
      flowGuard: fakeFlowGuard,
    });

  assert(runtime);
  assert.strictEqual(
    typeof runtime.encryptRefreshToken,
    'function',
  );
  assert.strictEqual(
    typeof runtime.encryptPendingRefreshToken,
    'function',
  );
  assert.strictEqual(
    typeof runtime.decryptRefreshToken,
    'function',
  );
  assert(runtime.pendingGrantKmsAdapter);
  assert.strictEqual(
    typeof runtime.pendingGrantKmsAdapter.encryptRefreshToken,
    'function',
  );
  assert.strictEqual(
    typeof runtime.pendingGrantKmsAdapter.decryptRefreshToken,
    'function',
  );

  // New pending-grant direct bridge.
  const encrypted =
    await runtime.pendingGrantKmsAdapter.encryptRefreshToken({
      refreshToken: 'pending-refresh-token-test-only',
      medcasesUid: 'uid-test',
      projectId: 'pending-binding-test',
    });

  assert.strictEqual(kmsEncryptCalls, 1);
  assert.strictEqual(
    encrypted.ciphertextB64,
    'ZmFrZS1jaXBoZXJ0ZXh0',
  );

  const decrypted =
    await runtime.pendingGrantKmsAdapter.decryptRefreshToken({
      encryptedRecord: encrypted,
      medcasesUid: 'uid-test',
      projectId: 'pending-binding-test',
    });

  assert.strictEqual(kmsDecryptCalls, 1);
  assert.strictEqual(
    decrypted,
    'refresh-token-plaintext-test-only',
  );

  // Existing legacy encrypt contract remains intact and still returns
  // the ciphertext envelope expected by the preexisting final-vault path.
  const legacyEnvelope =
    await runtime.encryptRefreshToken({
      plaintext: 'legacy-refresh-token-test-only',
      aad: JSON.stringify({
        medCasesUid: 'uid-test',
        validatedUserProjectId: 'project-test',
      }),
    });

  assert.strictEqual(kmsEncryptCalls, 2);
  assert(
    legacyEnvelope.startsWith(CIPHERTEXT_ENVELOPE_PREFIX),
  );

  const decoded=decodeCiphertextEnvelope(legacyEnvelope);
  assert.strictEqual(
    decoded.ciphertextB64,
    'ZmFrZS1jaXBoZXJ0ZXh0',
  );

  assert.strictEqual(firestoreWrites, 0);
  assert.strictEqual(googleCalls, 0);

  console.log('RUNTIME_LEGACY_ENCRYPT_CONTRACT_PRESERVED=PASS');
  console.log('RUNTIME_PENDING_DIRECT_ENCRYPT=PASS');
  console.log('RUNTIME_PENDING_DIRECT_DECRYPT=PASS');
  console.log('RUNTIME_PENDING_GRANT_KMS_ADAPTER=PASS');
  console.log('PENDING_KMS_BRIDGE_REAL_KMS_CALLS=0');
  console.log('PENDING_KMS_BRIDGE_REAL_FIRESTORE_WRITES=0');
  console.log('PENDING_KMS_BRIDGE_REAL_GOOGLE_CALLS=0');
  console.log('RESULT=PASS_STUDY_OAUTH_RUNTIME_PENDING_GRANT_KMS_BRIDGE_CONTRACT');
})().catch((error) => {
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
});
