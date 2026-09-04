'use strict';

const assert = require('assert');
const {
  VERSION,
  runReadinessCanaryV1,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_nonpublic_runtime_readiness_canary_v1');

(async () => {
  const calls = [];
  const base = {
    projectId: 'medcases-pro',
    expectedRuntimeSa: 'medcases-study-oauth-runtime@medcases-pro.iam.gserviceaccount.com',
    kmsKeyName: 'projects/medcases-pro/locations/us-central1/keyRings/medcases-study-oauth-vault/cryptoKeys/refresh-token-v1',
    secretName: 'medcases-study-google-oauth-web-client-secret-v1',
    secretVersion: '1',
    canaryId: 'contract-only',
    fetchImpl: async () => { throw new Error('FETCH_MUST_NOT_RUN_IN_CONTRACT'); },
  };

  const result = await runReadinessCanaryV1({
    ...base,
    probes: {
      metadataIdentity: async () => { calls.push('identity'); return base.expectedRuntimeSa; },
      kms: async () => { calls.push('kms'); return { encrypt: true, decrypt: true, plaintextLogged: false, ciphertextLogged: false, encryptedRecord: { keyName: base.kmsKeyName, ciphertextB64: 'AA==', aadSha256: '0'.repeat(64) }, syntheticUid: '__contract__' }; },
      firestore: async () => { calls.push('firestore'); return { write: true, read: true, flowConsume: true, replayRejected: true }; },
      secret: async () => { calls.push('secret'); return { accessed: true, valuePrinted: false, valuePersisted: false }; },
    },
  });

  assert.strictEqual(result.version, VERSION);
  assert.deepStrictEqual(calls, ['identity', 'kms', 'firestore', 'secret']);
  assert.strictEqual(result.realGoogleOAuth, false);
  assert.strictEqual(result.realGeminiCalls, 0);

  const blockedCalls = [];
  await assert.rejects(
    () => runReadinessCanaryV1({
      ...base,
      probes: {
        metadataIdentity: async () => { blockedCalls.push('identity'); return 'wrong@medcases-pro.iam.gserviceaccount.com'; },
        kms: async () => { blockedCalls.push('kms'); return { encrypt: true, decrypt: true }; },
        firestore: async () => { blockedCalls.push('firestore'); return { write: true, read: true, flowConsume: true, replayRejected: true }; },
        secret: async () => { blockedCalls.push('secret'); return { accessed: true, valuePrinted: false, valuePersisted: false }; },
      },
    }),
    /RUNTIME_SERVICE_ACCOUNT_MISMATCH/,
  );
  assert.deepStrictEqual(blockedCalls, ['identity']);

  console.log('NONPUBLIC_RUNTIME_IDENTITY_FIRST=PASS');
  console.log('SYNTHETIC_KMS_PROBE_CONTRACT=PASS');
  console.log('SYNTHETIC_FIRESTORE_FLOW_PROBE_CONTRACT=PASS');
  console.log('SECRET_NO_PRINT_CONTRACT=PASS');
  console.log('REAL_GOOGLE_OAUTH_CALLS=0');
  console.log('REAL_GEMINI_CALLS=0');
  console.log('RESULT=PASS_STUDY_OAUTH_NONPUBLIC_RUNTIME_READINESS_HARNESS_CONTRACT');
})().catch((error) => {
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
});
