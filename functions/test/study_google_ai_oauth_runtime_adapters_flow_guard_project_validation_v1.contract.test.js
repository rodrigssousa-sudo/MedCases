'use strict';

const assert = require('assert');
const {
  StudyGoogleAiOAuthCloudKmsAdapterV1,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_cloud_kms_adapter_v1');
const {
  StudyGoogleAiOAuthFirestoreVaultAdapterV1,
  VAULT_COLLECTION,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_firestore_vault_adapter_v1');
const {
  StudyGoogleAiOAuthFlowGuardV1,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_flow_guard_v1');
const {
  StudyGoogleAiOAuthProjectDiscoveryValidationV1,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_project_discovery_validation_v1');

function clone(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

class FakeSnapshot {
  constructor(value) {
    this._value = value;
    this.exists = value !== undefined;
  }
  data() { return clone(this._value); }
}

class FakeDocRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }
  collection(name) { return new FakeCollectionRef(this.db, `${this.path}/${name}`); }
  async get() { return new FakeSnapshot(this.db.map.get(this.path)); }
}

class FakeCollectionRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }
  doc(id) { return new FakeDocRef(this.db, `${this.path}/${id}`); }
}

class FakeFirestore {
  constructor() { this.map = new Map(); }
  collection(name) { return new FakeCollectionRef(this, name); }
  async runTransaction(callback) {
    const writes = [];
    const tx = {
      get: async (ref) => new FakeSnapshot(this.map.get(ref.path)),
      set: (ref, value, options) => writes.push({ ref, value: clone(value), options: options || {} }),
    };
    const result = await callback(tx);
    writes.forEach(({ ref, value, options }) => {
      if (options.merge && this.map.has(ref.path)) {
        this.map.set(ref.path, { ...this.map.get(ref.path), ...value });
      } else {
        this.map.set(ref.path, value);
      }
    });
    return result;
  }
}

class FakeKmsClient {
  constructor() { this.encryptCalls = 0; this.decryptCalls = 0; }
  async encrypt(request) {
    this.encryptCalls += 1;
    assert(Buffer.isBuffer(request.plaintext));
    assert(Buffer.isBuffer(request.additionalAuthenticatedData));
    const payload = Buffer.concat([Buffer.from('kms:'), request.plaintext]);
    return [{ ciphertext: payload }];
  }
  async decrypt(request) {
    this.decryptCalls += 1;
    assert(Buffer.isBuffer(request.ciphertext));
    assert(Buffer.isBuffer(request.additionalAuthenticatedData));
    const raw = request.ciphertext;
    assert.strictEqual(raw.subarray(0, 4).toString('utf8'), 'kms:');
    return [{ plaintext: raw.subarray(4) }];
  }
}

function fakeResponse(status, data) {
  return { status, json: async () => clone(data) };
}

(async () => {
  const uid = 'medcases-user-123';
  const projectId = 'user-gemini-project-123';
  const keyName = 'projects/medcases-pro/locations/us-central1/keyRings/medcases-study-oauth-vault/cryptoKeys/refresh-token-v1';
  const refreshSecret = 'REFRESH_SECRET_MUST_NEVER_PERSIST';

  const kmsClient = new FakeKmsClient();
  const kms = new StudyGoogleAiOAuthCloudKmsAdapterV1({ kmsClient, keyName });
  const encrypted = await kms.encryptRefreshToken({ refreshToken: refreshSecret, medcasesUid: uid, projectId });
  assert.strictEqual(kmsClient.encryptCalls, 1);
  assert(!JSON.stringify(encrypted).includes(refreshSecret));
  const decrypted = await kms.decryptRefreshToken({ encryptedRecord: encrypted, medcasesUid: uid, projectId });
  assert.strictEqual(decrypted, refreshSecret);
  assert.strictEqual(kmsClient.decryptCalls, 1);

  const firestore = new FakeFirestore();
  let now = 1_800_000_000_000;
  const vault = new StudyGoogleAiOAuthFirestoreVaultAdapterV1({ firestore, clock: () => now });
  const validatedProject = {
    serverValidated: true,
    projectId,
    projectNumber: '123456789',
    displayName: 'User Gemini Project',
    geminiApiEnabled: true,
    serviceUsageUse: true,
    validatedAtMs: now,
  };
  await vault.upsertEncryptedCredential({ medcasesUid: uid, validatedProject, encryptedRefreshToken: encrypted });
  const storedCredential = await vault.readEncryptedCredential({ medcasesUid: uid });
  assert.strictEqual(storedCredential.validatedProject.serverValidated, true);
  assert(!JSON.stringify(storedCredential).includes(refreshSecret));
  assert([...firestore.map.keys()].some((path) => path.startsWith(`${VAULT_COLLECTION}/`)));

  await assert.rejects(
    () => vault.upsertEncryptedCredential({
      medcasesUid: uid,
      validatedProject,
      encryptedRefreshToken: { ...encrypted, accessToken: 'FORBIDDEN' },
    }),
    /PLAINTEXT_TOKEN_FIELD_FORBIDDEN/,
  );

  let randomCounter = 1;
  const deterministicRandom = (size) => {
    const buffer = Buffer.alloc(size, randomCounter);
    randomCounter += 1;
    return buffer;
  };
  const guard = new StudyGoogleAiOAuthFlowGuardV1({
    store: vault,
    clock: () => now,
    randomBytes: deterministicRandom,
    ttlMs: 5 * 60 * 1000,
  });
  const challenge = await guard.issueChallenge({ medcasesUid: uid });
  assert(challenge.state && challenge.nonce && challenge.challengeId);
  const serializedStoreBeforeConsume = JSON.stringify([...firestore.map.entries()]);
  assert(!serializedStoreBeforeConsume.includes(challenge.state));
  assert(!serializedStoreBeforeConsume.includes(challenge.nonce));

  await assert.rejects(
    () => guard.consumeChallenge({
      medcasesUid: uid,
      challengeId: challenge.challengeId,
      state: challenge.state,
      nonce: `${challenge.nonce}wrong`,
      authCode: 'AUTH_CODE_ONE',
    }),
    /FLOW_NONCE_MISMATCH/,
  );

  now += 1000;
  const consumed = await guard.consumeChallenge({
    medcasesUid: uid,
    challengeId: challenge.challengeId,
    state: challenge.state,
    nonce: challenge.nonce,
    authCode: 'AUTH_CODE_ONE',
  });
  assert.strictEqual(consumed.consumed, true);
  const serializedStoreAfterConsume = JSON.stringify([...firestore.map.entries()]);
  assert(!serializedStoreAfterConsume.includes('AUTH_CODE_ONE'));
  await assert.rejects(
    () => guard.consumeChallenge({
      medcasesUid: uid,
      challengeId: challenge.challengeId,
      state: challenge.state,
      nonce: challenge.nonce,
      authCode: 'AUTH_CODE_ONE',
    }),
    /FLOW_REPLAY_REJECTED/,
  );

  const fetchCalls = [];
  const accessToken = 'ACCESS_TOKEN_IN_MEMORY_ONLY';
  const authorizedFetch = async (url, options) => {
    fetchCalls.push({ url, options });
    assert.strictEqual(options.headers.Authorization, `Bearer ${accessToken}`);
    if (url.includes('/v3/projects:search')) {
      return fakeResponse(200, {
        projects: [{ name: 'projects/123456789', projectId, displayName: 'User Gemini Project', state: 'ACTIVE' }],
      });
    }
    if (url.endsWith(`/v3/projects/${projectId}`)) {
      return fakeResponse(200, { name: 'projects/123456789', projectId, displayName: 'User Gemini Project', state: 'ACTIVE' });
    }
    if (url.endsWith(`/v1/projects/${projectId}:testIamPermissions`)) {
      return fakeResponse(200, { permissions: ['serviceusage.services.use'] });
    }
    if (url.endsWith('/v1/projects/123456789/services/generativelanguage.googleapis.com')) {
      return fakeResponse(200, { name: 'projects/123456789/services/generativelanguage.googleapis.com', state: 'ENABLED' });
    }
    if (url === 'https://generativelanguage.googleapis.com/v1/models') {
      assert.strictEqual(options.headers['x-goog-user-project'], projectId);
      return fakeResponse(200, { models: [{ name: 'models/example' }] });
    }
    return fakeResponse(404, {});
  };

  const projectValidator = new StudyGoogleAiOAuthProjectDiscoveryValidationV1({
    authorizedFetch,
    clock: () => now,
  });
  const discovered = await projectValidator.discoverProjects({ accessToken });
  assert.strictEqual(discovered.length, 1);
  assert.strictEqual(discovered[0].projectId, projectId);
  const validation = await projectValidator.validateProject({ accessToken, projectId });
  assert.strictEqual(validation.serverValidated, true);
  assert.strictEqual(validation.geminiApiEnabled, true);
  assert.strictEqual(validation.serviceUsageUse, true);
  assert(!JSON.stringify(validation).includes(accessToken));
  assert(fetchCalls.some((call) => call.url.includes(':testIamPermissions')));
  assert(fetchCalls.some((call) => call.url.endsWith('/services/generativelanguage.googleapis.com')));
  assert(fetchCalls.some((call) => call.url === 'https://generativelanguage.googleapis.com/v1/models'));

  process.stdout.write('KMS_ADAPTER_CONTRACT=PASS\n');
  process.stdout.write('FIRESTORE_VAULT_ADAPTER_CONTRACT=PASS\n');
  process.stdout.write('FLOW_NONCE_CSRF_ONE_TIME_REPLAY_GUARD=PASS\n');
  process.stdout.write('PROJECT_DISCOVERY_SERVER_VALIDATION=PASS\n');
  process.stdout.write('REFRESH_TOKEN_PLAINTEXT_PERSISTENCE=NO\n');
  process.stdout.write('ACCESS_TOKEN_PERSISTENCE=NO\n');
  process.stdout.write('AUTH_CODE_PLAINTEXT_PERSISTENCE=NO\n');
  process.stdout.write('REAL_KMS_CALLS=0\n');
  process.stdout.write('REAL_FIRESTORE_WRITES=0\n');
  process.stdout.write('REAL_GOOGLE_API_CALLS=0\n');
})().catch((error) => {
  process.stderr.write(`${error && error.stack ? error.stack : error}\n`);
  process.exit(1);
});
