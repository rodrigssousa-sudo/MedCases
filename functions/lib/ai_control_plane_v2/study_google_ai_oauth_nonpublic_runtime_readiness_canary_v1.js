'use strict';

const crypto = require('crypto');
const {
  StudyGoogleAiOAuthCloudKmsAdapterV1,
  createOfficialCloudKmsClient,
} = require('./study_google_ai_oauth_cloud_kms_adapter_v1');
const {
  FLOW_SUBCOLLECTION,
  VAULT_COLLECTION,
  StudyGoogleAiOAuthFirestoreVaultAdapterV1,
  uidDocId,
} = require('./study_google_ai_oauth_firestore_vault_adapter_v1');
const {
  StudyGoogleAiOAuthFlowGuardV1,
} = require('./study_google_ai_oauth_flow_guard_v1');

const VERSION = 'study-google-ai-oauth-nonpublic-runtime-readiness-canary-v1';
const METADATA_BASE = 'http://metadata.google.internal/computeMetadata/v1';

function required(value, name) {
  if (typeof value !== 'string' || value.trim() === '') throw new TypeError(`${name}_REQUIRED`);
  return value.trim();
}

function safeEqual(left, right) {
  const a = Buffer.from(String(left), 'utf8');
  const b = Buffer.from(String(right), 'utf8');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

async function metadataText(path, fetchImpl) {
  const response = await fetchImpl(`${METADATA_BASE}/${path}`, {
    headers: { 'Metadata-Flavor': 'Google' },
  });
  if (!response || response.status < 200 || response.status >= 300) {
    throw new Error(`METADATA_HTTP_${response && response.status}`);
  }
  return required(await response.text(), 'METADATA_TEXT');
}

async function metadataAccessToken(fetchImpl) {
  const response = await fetchImpl(`${METADATA_BASE}/instance/service-accounts/default/token`, {
    headers: { 'Metadata-Flavor': 'Google' },
  });
  if (!response || response.status < 200 || response.status >= 300) {
    throw new Error(`METADATA_TOKEN_HTTP_${response && response.status}`);
  }
  const body = await response.json();
  return required(body && body.access_token, 'METADATA_ACCESS_TOKEN');
}

async function realMetadataIdentityProbe({ fetchImpl }) {
  return metadataText('instance/service-accounts/default/email', fetchImpl);
}

async function realKmsProbe({ kmsKeyName, projectId, canaryId }) {
  const client = createOfficialCloudKmsClient();
  const adapter = new StudyGoogleAiOAuthCloudKmsAdapterV1({ kmsClient: client, keyName: kmsKeyName });
  const syntheticUid = `__medcases_readiness__:${canaryId}`;
  const syntheticToken = `synthetic-refresh-token:${crypto.randomBytes(32).toString('hex')}`;
  try {
    const encryptedRecord = await adapter.encryptRefreshToken({
      refreshToken: syntheticToken,
      medcasesUid: syntheticUid,
      projectId,
    });
    const decrypted = await adapter.decryptRefreshToken({
      encryptedRecord,
      medcasesUid: syntheticUid,
      projectId,
    });
    if (!safeEqual(decrypted, syntheticToken)) throw new Error('KMS_SYNTHETIC_ROUNDTRIP_MISMATCH');
    return Object.freeze({ encrypt: true, decrypt: true, plaintextLogged: false, ciphertextLogged: false, encryptedRecord, syntheticUid });
  } finally {
    if (typeof client.close === 'function') await client.close();
  }
}

async function realFirestoreProbe({ projectId, kmsKeyName, canaryId, kmsResult }) {
  const admin = require('firebase-admin');
  if (!admin.apps.length) admin.initializeApp({ projectId });
  const firestore = admin.firestore();
  const store = new StudyGoogleAiOAuthFirestoreVaultAdapterV1({ firestore });
  const flow = new StudyGoogleAiOAuthFlowGuardV1({ store });
  if (!kmsResult || !kmsResult.encryptedRecord || !kmsResult.syntheticUid) {
    throw new Error('KMS_RESULT_REQUIRED_FOR_FIRESTORE_BRIDGE');
  }
  const syntheticUid = kmsResult.syntheticUid;
  const encryptedRecord = kmsResult.encryptedRecord;
  const vaultRef = firestore.collection(VAULT_COLLECTION).doc(uidDocId(syntheticUid));
  let challenge = null;
  try {
    await store.upsertEncryptedCredential({
      medcasesUid: syntheticUid,
      validatedProject: {
        serverValidated: true,
        projectId,
        projectNumber: null,
        displayName: null,
        geminiApiEnabled: true,
        serviceUsageUse: true,
        validatedAtMs: Date.now(),
      },
      encryptedRefreshToken: encryptedRecord,
    });
    const readBack = await store.readEncryptedCredential({ medcasesUid: syntheticUid });
    if (
      !readBack ||
      !readBack.encryptedRefreshToken ||
      readBack.encryptedRefreshToken.keyName !== kmsKeyName ||
      readBack.encryptedRefreshToken.ciphertextB64 !== encryptedRecord.ciphertextB64 ||
      readBack.encryptedRefreshToken.aadSha256 !== encryptedRecord.aadSha256
    ) {
      throw new Error('FIRESTORE_KMS_CIPHERTEXT_BRIDGE_READBACK_MISMATCH');
    }

    challenge = await flow.issueChallenge({ medcasesUid: syntheticUid });
    const consumed = await flow.consumeChallenge({
      medcasesUid: syntheticUid,
      challengeId: challenge.challengeId,
      state: challenge.state,
      nonce: challenge.nonce,
      authCode: `synthetic-auth-code:${canaryId}`,
    });
    if (!consumed || consumed.consumed !== true) throw new Error('FLOW_GUARD_SYNTHETIC_CONSUME_FAILED');

    let replayRejected = false;
    try {
      await flow.consumeChallenge({
        medcasesUid: syntheticUid,
        challengeId: challenge.challengeId,
        state: challenge.state,
        nonce: challenge.nonce,
        authCode: `synthetic-auth-code:${canaryId}`,
      });
    } catch (error) {
      replayRejected = error && error.message === 'FLOW_REPLAY_REJECTED';
    }
    if (!replayRejected) throw new Error('FLOW_GUARD_SYNTHETIC_REPLAY_NOT_REJECTED');
    return Object.freeze({ write: true, read: true, flowConsume: true, replayRejected: true });
  } finally {
    if (challenge && challenge.challengeId) {
      await vaultRef.collection(FLOW_SUBCOLLECTION).doc(challenge.challengeId).delete().catch(() => {});
    }
    await vaultRef.delete().catch(() => {});
    if (admin.apps.length) await admin.app().delete().catch(() => {});
  }
}

async function realSecretProbe({ projectId, secretName, secretVersion, fetchImpl }) {
  const accessToken = await metadataAccessToken(fetchImpl);
  const url = `https://secretmanager.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
    `/secrets/${encodeURIComponent(secretName)}/versions/${encodeURIComponent(secretVersion)}:access`;
  const response = await fetchImpl(url, {
    headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' },
  });
  if (!response || response.status < 200 || response.status >= 300) {
    throw new Error(`SECRET_ACCESS_HTTP_${response && response.status}`);
  }
  const body = await response.json();
  const data = body && body.payload && body.payload.data;
  if (typeof data !== 'string' || data.length === 0) throw new Error('SECRET_PAYLOAD_EMPTY');
  const secretBuffer = Buffer.from(data, 'base64');
  try {
    if (secretBuffer.length === 0) throw new Error('SECRET_DECODED_EMPTY');
  } finally {
    secretBuffer.fill(0);
  }
  return Object.freeze({ accessed: true, valuePrinted: false, valuePersisted: false });
}

async function runReadinessCanaryV1(options) {
  const opts = options || {};
  const projectId = required(opts.projectId || process.env.MEDCASES_CANARY_PROJECT, 'PROJECT_ID');
  const expectedRuntimeSa = required(opts.expectedRuntimeSa || process.env.MEDCASES_CANARY_RUNTIME_SA, 'EXPECTED_RUNTIME_SA');
  const kmsKeyName = required(opts.kmsKeyName || process.env.MEDCASES_CANARY_KMS_KEY, 'KMS_KEY_NAME');
  const secretName = required(opts.secretName || process.env.MEDCASES_CANARY_SECRET, 'SECRET_NAME');
  const secretVersion = required(opts.secretVersion || process.env.MEDCASES_CANARY_SECRET_VERSION || '1', 'SECRET_VERSION');
  const canaryId = required(opts.canaryId || process.env.MEDCASES_CANARY_ID, 'CANARY_ID');
  const fetchImpl = opts.fetchImpl || globalThis.fetch;
  if (typeof fetchImpl !== 'function') throw new Error('GLOBAL_FETCH_NOT_AVAILABLE');

  const probes = opts.probes || {};
  const metadataProbe = probes.metadataIdentity || realMetadataIdentityProbe;
  const kmsProbe = probes.kms || realKmsProbe;
  const firestoreProbe = probes.firestore || realFirestoreProbe;
  const secretProbe = probes.secret || realSecretProbe;

  const actualIdentity = await metadataProbe({ fetchImpl });
  if (!safeEqual(actualIdentity, expectedRuntimeSa)) throw new Error('RUNTIME_SERVICE_ACCOUNT_MISMATCH');

  const kms = await kmsProbe({ kmsKeyName, projectId, canaryId });
  if (!kms || kms.encrypt !== true || kms.decrypt !== true) throw new Error('KMS_READINESS_FAILED');

  const firestore = await firestoreProbe({ projectId, kmsKeyName, canaryId, kmsResult: kms });
  if (!firestore || firestore.write !== true || firestore.read !== true || firestore.flowConsume !== true || firestore.replayRejected !== true) {
    throw new Error('FIRESTORE_FLOW_READINESS_FAILED');
  }

  const secret = await secretProbe({ projectId, secretName, secretVersion, fetchImpl });
  if (!secret || secret.accessed !== true || secret.valuePrinted !== false || secret.valuePersisted !== false) {
    throw new Error('SECRET_READINESS_FAILED');
  }

  return Object.freeze({
    version: VERSION,
    runtimeIdentity: true,
    kmsEncryptDecrypt: true,
    firestoreWriteReadCleanup: true,
    flowGuardOneTimeReplayReject: true,
    secretAccessNoPrint: true,
    realGoogleOAuth: false,
    realGeminiCalls: 0,
  });
}

async function main() {
  try {
    const result = await runReadinessCanaryV1();
    console.log(`CANARY_VERSION=${result.version}`);
    console.log('CANARY_RUNTIME_IDENTITY=PASS');
    console.log('CANARY_KMS_ENCRYPT_DECRYPT=PASS');
    console.log('CANARY_FIRESTORE_VAULT_WRITE_READ_DELETE=PASS');
    console.log('CANARY_FLOW_GUARD_ONE_TIME_REPLAY_REJECT=PASS');
    console.log('CANARY_SECRET_ACCESS=PASS_VALUE_NOT_PRINTED');
    console.log('CANARY_REAL_GOOGLE_OAUTH=NOT_RUN');
    console.log('CANARY_REAL_GEMINI_CALLS=0');
    console.log('RESULT=PASS_STUDY_OAUTH_NONPUBLIC_RUNTIME_READINESS_CANARY');
  } catch (error) {
    console.error(`CANARY_SAFE_ERROR=${error && error.message ? error.message : 'UNKNOWN'}`);
    console.error('RESULT=FAIL_STUDY_OAUTH_NONPUBLIC_RUNTIME_READINESS_CANARY');
    process.exitCode = 1;
  }
}

if (require.main === module) main();

module.exports = {
  VERSION,
  runReadinessCanaryV1,
};
