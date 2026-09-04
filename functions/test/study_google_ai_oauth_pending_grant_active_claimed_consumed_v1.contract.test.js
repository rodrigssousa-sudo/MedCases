'use strict';

const assert = require('assert');
const crypto = require('crypto');

const {
  StudyGoogleAiOAuthPendingGrantV1,
  sha256Hex,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_pending_grant_v1');
const {
  StudyGoogleAiOAuthPendingGrantFirestoreStoreV1,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_pending_grant_firestore_store_v1');
const {
  createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1,
} = require('../lib/ai_control_plane_v2/study_google_ai_oauth_two_phase_physical_canary_orchestrator_inert_v1');

class FakeDocRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }
  collection(name) {
    return new FakeCollectionRef(this.db, `${this.path}/${name}`);
  }
}

class FakeCollectionRef {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }
  doc(id) {
    return new FakeDocRef(this.db, `${this.path}/${id}`);
  }
}

class FakeFirestore {
  constructor() {
    this.docs = new Map();
  }
  collection(name) {
    return new FakeCollectionRef(this, name);
  }
  async runTransaction(fn) {
    const tx = {
      get: async (ref) => {
        const value = this.docs.get(ref.path);
        return {
          exists: value !== undefined,
          data: () => value === undefined ? undefined : JSON.parse(JSON.stringify(value)),
        };
      },
      create: (ref, value) => {
        if (this.docs.has(ref.path)) throw new Error('FAKE_DOC_EXISTS');
        this.docs.set(ref.path, JSON.parse(JSON.stringify(value)));
      },
      update: (ref, patch) => {
        const current = this.docs.get(ref.path);
        if (!current) throw new Error('FAKE_DOC_MISSING');
        this.docs.set(ref.path, {
          ...current,
          ...JSON.parse(JSON.stringify(patch)),
        });
      },
    };
    return fn(tx);
  }
}

function encryptedRecord() {
  return {
    schema: 'medcases.study.oauth.kms.refresh-token.v1',
    keyName: 'projects/test/locations/us/keyRings/kr/cryptoKeys/key',
    ciphertextB64: Buffer.from('synthetic-ciphertext').toString('base64'),
    aadSha256: crypto.createHash('sha256').update('aad').digest('hex'),
  };
}

const projects = [
  { projectId: 'project-a' },
  { projectId: 'project-b' },
];

(async () => {
  let now = 1_000_000;
  const firestore = new FakeFirestore();
  const store = new StudyGoogleAiOAuthPendingGrantFirestoreStoreV1({
    firestore,
    clock: () => now,
  });
  const selectionHash = sha256Hex('opaque-selection');
  const claimA = sha256Hex('claim-a');
  const claimB = sha256Hex('claim-b');

  await store.createPendingGrant({
    medcasesUid: 'uid-1',
    selectionIdSha256: selectionHash,
    encryptedRefreshToken: encryptedRecord(),
    discoveredProjects: projects,
    grantedScopes: ['scope-a'],
    createdAtMs: now,
    expiresAtMs: now + 600_000,
  });

  const ref = store.pendingDoc('uid-1', selectionHash);
  let record = firestore.docs.get(ref.path);
  assert.strictEqual(record.lifecycleState, 'active');
  assert.strictEqual(record.used, false);
  assert.strictEqual(record.claimIdSha256, null);

  const claimed = await store.consumePendingGrant({
    medcasesUid: 'uid-1',
    selectionIdSha256: selectionHash,
    selectedProjectId: 'project-b',
    claimIdSha256: claimA,
  });
  assert.strictEqual(claimed.claimed, true);
  assert.strictEqual(claimed.consumed, false);
  record = firestore.docs.get(ref.path);
  assert.strictEqual(record.lifecycleState, 'claimed');
  assert.strictEqual(record.used, false);
  assert.strictEqual(record.claimIdSha256, claimA);

  await assert.rejects(
    () => store.consumePendingGrant({
      medcasesUid: 'uid-1',
      selectionIdSha256: selectionHash,
      selectedProjectId: 'project-b',
      claimIdSha256: claimB,
    }),
    /PENDING_GRANT_ALREADY_CLAIMED/,
  );

  const wrongRelease = await store.releasePendingGrantClaim({
    medcasesUid: 'uid-1',
    selectionIdSha256: selectionHash,
    claimIdSha256: claimB,
  });
  assert.strictEqual(wrongRelease.released, false);
  assert.strictEqual(firestore.docs.get(ref.path).lifecycleState, 'claimed');

  const released = await store.releasePendingGrantClaim({
    medcasesUid: 'uid-1',
    selectionIdSha256: selectionHash,
    claimIdSha256: claimA,
  });
  assert.strictEqual(released.released, true);
  record = firestore.docs.get(ref.path);
  assert.strictEqual(record.lifecycleState, 'active');
  assert.strictEqual(record.used, false);
  assert.strictEqual(record.selectedProjectId, null);

  await store.consumePendingGrant({
    medcasesUid: 'uid-1',
    selectionIdSha256: selectionHash,
    selectedProjectId: 'project-b',
    claimIdSha256: claimB,
  });
  now += 1_000;
  const completed = await store.completePendingGrant({
    medcasesUid: 'uid-1',
    selectionIdSha256: selectionHash,
    selectedProjectId: 'project-b',
    claimIdSha256: claimB,
  });
  assert.strictEqual(completed.consumed, true);
  record = firestore.docs.get(ref.path);
  assert.strictEqual(record.lifecycleState, 'consumed');
  assert.strictEqual(record.used, true);
  assert.strictEqual(record.claimIdSha256, null);

  await assert.rejects(
    () => store.consumePendingGrant({
      medcasesUid: 'uid-1',
      selectionIdSha256: selectionHash,
      selectedProjectId: 'project-b',
      claimIdSha256: sha256Hex('claim-c'),
    }),
    /PENDING_GRANT_ALREADY_USED/,
  );

  // An abandoned claim becomes reclaimable after its bounded lease.
  let leaseNow = 2_000_000;
  const leaseFirestore = new FakeFirestore();
  const leaseStore = new StudyGoogleAiOAuthPendingGrantFirestoreStoreV1({
    firestore: leaseFirestore,
    clock: () => leaseNow,
  });
  const leaseSelection = sha256Hex('lease-selection');
  const leaseClaimA = sha256Hex('lease-claim-a');
  const leaseClaimB = sha256Hex('lease-claim-b');
  await leaseStore.createPendingGrant({
    medcasesUid: 'uid-lease',
    selectionIdSha256: leaseSelection,
    encryptedRefreshToken: encryptedRecord(),
    discoveredProjects: projects,
    grantedScopes: [],
    createdAtMs: leaseNow,
    expiresAtMs: leaseNow + 600_000,
  });
  await leaseStore.consumePendingGrant({
    medcasesUid: 'uid-lease',
    selectionIdSha256: leaseSelection,
    selectedProjectId: 'project-b',
    claimIdSha256: leaseClaimA,
  });
  leaseNow += 120_001;
  const reclaimed = await leaseStore.consumePendingGrant({
    medcasesUid: 'uid-lease',
    selectionIdSha256: leaseSelection,
    selectedProjectId: 'project-b',
    claimIdSha256: leaseClaimB,
  });
  assert.strictEqual(reclaimed.claimed, true);
  const leaseRef = leaseStore.pendingDoc('uid-lease', leaseSelection);
  assert.strictEqual(
    leaseFirestore.docs.get(leaseRef.path).claimIdSha256,
    leaseClaimB,
  );

  // Domain must release a hardened claim if decrypt fails.
  let releaseOnDecryptFailure = 0;
  const domainStore = {
    async createPendingGrant() { return { created: true }; },
    async consumePendingGrant() {
      return {
        claimed: true,
        encryptedRefreshToken: encryptedRecord(),
        discoveredProjects: projects,
        grantedScopes: ['scope-a'],
      };
    },
    async completePendingGrant() { return { consumed: true }; },
    async releasePendingGrantClaim() {
      releaseOnDecryptFailure += 1;
      return { released: true };
    },
  };
  const failingDomain = new StudyGoogleAiOAuthPendingGrantV1({
    kmsAdapter: {
      async encryptRefreshToken() { return encryptedRecord(); },
      async decryptRefreshToken() { throw new Error('SYNTHETIC_DECRYPT_FAIL'); },
    },
    store: domainStore,
    randomBytes: () => Buffer.alloc(24, 3),
  });
  await assert.rejects(
    () => failingDomain.consumePendingGrant({
      medcasesUid: 'uid-1',
      selectionId: 'opaque-selection',
      selectedProjectId: 'project-b',
    }),
    /SYNTHETIC_DECRYPT_FAIL/,
  );
  assert.strictEqual(releaseOnDecryptFailure, 1);

  // Orchestrator: pre-persistence failure releases; success completes only after persist.
  const failureOrder = [];
  const failingPhase2 = createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1({
    consumeOAuthFlowChallenge: async () => { throw new Error('NO_AUTH_FLOW'); },
    exchangeAuthorizationCode: async () => { throw new Error('NO_AUTH_CODE'); },
    discoverProjects: async () => { throw new Error('NO_REDISCOVERY'); },
    validateProject: async () => { throw new Error('SHOULD_NOT_VALIDATE'); },
    persistEncryptedGrant: async () => { throw new Error('SHOULD_NOT_PERSIST'); },
    createPendingGrant: async () => { throw new Error('NO_CREATE_PENDING'); },
    consumePendingGrant: async () => {
      failureOrder.push('claim');
      return {
        refreshToken: 'synthetic-refresh',
        grantedScopes: [],
        pendingLifecycleHardened: true,
        completePendingGrant: async () => {
          failureOrder.push('complete');
          return { consumed: true };
        },
        releasePendingGrantClaim: async () => {
          failureOrder.push('release');
          return { released: true };
        },
      };
    },
    refreshAccessToken: async () => {
      failureOrder.push('refresh');
      throw new Error('SYNTHETIC_REFRESH_FAIL');
    },
  });
  await assert.rejects(
    () => failingPhase2({
      medcasesUid: 'uid-1',
      requestedProjectId: 'project-b',
      selectionId: 'opaque-selection',
    }),
    /SYNTHETIC_REFRESH_FAIL/,
  );
  assert.deepStrictEqual(failureOrder, ['claim', 'refresh', 'release']);

  const successOrder = [];
  const successPhase2 = createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1({
    consumeOAuthFlowChallenge: async () => { throw new Error('NO_AUTH_FLOW'); },
    exchangeAuthorizationCode: async () => { throw new Error('NO_AUTH_CODE'); },
    discoverProjects: async () => { throw new Error('NO_REDISCOVERY'); },
    validateProject: async ({ requestedProjectId }) => {
      successOrder.push('validate');
      return {
        serverValidated: true,
        projectId: requestedProjectId,
        geminiApiEnabled: true,
        serviceUsageUse: true,
      };
    },
    persistEncryptedGrant: async () => {
      successOrder.push('persist');
      return { persisted: true, encrypted: true };
    },
    createPendingGrant: async () => { throw new Error('NO_CREATE_PENDING'); },
    consumePendingGrant: async () => {
      successOrder.push('claim');
      return {
        refreshToken: 'synthetic-refresh',
        grantedScopes: ['scope-a'],
        pendingLifecycleHardened: true,
        completePendingGrant: async () => {
          successOrder.push('complete');
          return { consumed: true };
        },
        releasePendingGrantClaim: async () => {
          successOrder.push('release');
          return { released: true };
        },
      };
    },
    refreshAccessToken: async () => {
      successOrder.push('refresh');
      return { accessToken: 'synthetic-access' };
    },
  });
  const success = await successPhase2({
    medcasesUid: 'uid-1',
    requestedProjectId: 'project-b',
    selectionId: 'opaque-selection',
  });
  assert.strictEqual(success.accepted, true);
  assert.deepStrictEqual(
    successOrder,
    ['claim', 'refresh', 'validate', 'persist', 'complete'],
  );

  // If final vault persistence already succeeded, a completion failure must
  // not release/reopen the pending grant. Lease expiry is the only recovery
  // path, preventing an explicit rollback to active after persisted success.
  const completeFailureOrder = [];
  const completeFailurePhase2 = createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1({
    consumeOAuthFlowChallenge: async () => { throw new Error('NO_AUTH_FLOW'); },
    exchangeAuthorizationCode: async () => { throw new Error('NO_AUTH_CODE'); },
    discoverProjects: async () => { throw new Error('NO_REDISCOVERY'); },
    validateProject: async ({ requestedProjectId }) => {
      completeFailureOrder.push('validate');
      return {
        serverValidated: true,
        projectId: requestedProjectId,
        geminiApiEnabled: true,
        serviceUsageUse: true,
      };
    },
    persistEncryptedGrant: async () => {
      completeFailureOrder.push('persist');
      return { persisted: true, encrypted: true };
    },
    createPendingGrant: async () => { throw new Error('NO_CREATE_PENDING'); },
    consumePendingGrant: async () => {
      completeFailureOrder.push('claim');
      return {
        refreshToken: 'synthetic-refresh',
        grantedScopes: [],
        pendingLifecycleHardened: true,
        completePendingGrant: async () => {
          completeFailureOrder.push('complete');
          throw new Error('SYNTHETIC_COMPLETE_FAIL');
        },
        releasePendingGrantClaim: async () => {
          completeFailureOrder.push('release');
          return { released: true };
        },
      };
    },
    refreshAccessToken: async () => {
      completeFailureOrder.push('refresh');
      return { accessToken: 'synthetic-access' };
    },
  });
  await assert.rejects(
    () => completeFailurePhase2({
      medcasesUid: 'uid-1',
      requestedProjectId: 'project-b',
      selectionId: 'opaque-selection',
    }),
    /SYNTHETIC_COMPLETE_FAIL/,
  );
  assert.deepStrictEqual(
    completeFailureOrder,
    ['claim', 'refresh', 'validate', 'persist', 'complete'],
  );

  console.log('PENDING_LIFECYCLE_ACTIVE_CLAIMED_CONSUMED=PASS');
  console.log('PENDING_CLAIM_CONCURRENT_BLOCK=PASS');
  console.log('PENDING_CLAIM_LEASE_RECLAIM=PASS');
  console.log('PENDING_CLAIM_RELEASE_PREPERSIST_FAILURE=PASS');
  console.log('PENDING_CLAIM_COMPLETE_AFTER_PERSIST=PASS');
  console.log('PENDING_POSTPERSIST_COMPLETE_FAILURE_NOT_RELEASED=PASS');
  console.log('PENDING_USED_TRUE_ONLY_AFTER_COMPLETE=PASS');
  console.log('CLAIM_ID_AT_REST_SHA256_ONLY=PASS');
  console.log('PHASE2_SECOND_AUTH_CODE_REQUIRED=NO');
  console.log('REAL_GOOGLE_OAUTH_CALLS=0');
  console.log('REAL_KMS_CALLS=0');
  console.log('REAL_FIRESTORE_WRITES=0');
  console.log('REAL_GEMINI_CALLS=0');
  console.log('RESULT=PASS_STUDY_OAUTH_PENDING_GRANT_ACTIVE_CLAIMED_CONSUMED_CONTRACT');
})().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
