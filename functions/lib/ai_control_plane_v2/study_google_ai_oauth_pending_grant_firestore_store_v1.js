'use strict';

const crypto = require('crypto');

const VAULT_COLLECTION = 'study_google_ai_oauth_vault';
const PENDING_SUBCOLLECTION = 'oauth_pending_grants';
const PENDING_SCHEMA = 'medcases.study.oauth.pending-grant.v1';
const PENDING_CLAIM_LEASE_MS = 2 * 60 * 1000;

const FORBIDDEN_PLAINTEXT_KEYS = new Set([
  'refreshtoken',
  'accesstoken',
  'authcode',
  'authorization',
  'serverauthorizationcode',
  'plaintext',
]);

function requireNonEmptyString(value, name) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${name}_REQUIRED`);
  }
  return value.trim();
}

function sha256Hex(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function uidDocId(medcasesUid) {
  return sha256Hex(requireNonEmptyString(medcasesUid, 'MEDCASES_UID'));
}

function requireSha256(value, name) {
  const out = requireNonEmptyString(value, name);
  if (!/^[a-f0-9]{64}$/.test(out)) {
    throw new Error(`${name}_INVALID`);
  }
  return out;
}

function assertNoPlaintextTokenMaterial(value, path) {
  const here = path || '$';
  if (Array.isArray(value)) {
    value.forEach((item, index) =>
      assertNoPlaintextTokenMaterial(item, `${here}[${index}]`),
    );
    return;
  }
  if (!value || typeof value !== 'object') return;

  for (const [key, child] of Object.entries(value)) {
    const normalized = key.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (FORBIDDEN_PLAINTEXT_KEYS.has(normalized)) {
      throw new Error(`PLAINTEXT_TOKEN_FIELD_FORBIDDEN:${here}.${key}`);
    }
    assertNoPlaintextTokenMaterial(child, `${here}.${key}`);
  }
}

function safeProjects(projects) {
  const seen = new Set();
  const out = [];
  for (const project of Array.isArray(projects) ? projects : []) {
    if (!project || typeof project !== 'object') continue;
    const projectId =
      typeof project.projectId === 'string' ? project.projectId.trim() : '';
    if (!projectId || seen.has(projectId)) continue;
    seen.add(projectId);
    out.push({
      projectId,
      projectNumber:
        typeof project.projectNumber === 'string' && project.projectNumber.trim()
          ? project.projectNumber.trim()
          : null,
      displayName:
        typeof project.displayName === 'string' && project.displayName.trim()
          ? project.displayName.trim()
          : null,
    });
  }
  return out;
}

function safeScopes(scopes) {
  return Array.from(
    new Set(
      (Array.isArray(scopes) ? scopes : [])
        .filter((x) => typeof x === 'string')
        .map((x) => x.trim())
        .filter(Boolean),
    ),
  ).sort();
}

class StudyGoogleAiOAuthPendingGrantFirestoreStoreV1 {
  constructor({ firestore, clock }) {
    if (
      !firestore ||
      typeof firestore.collection !== 'function' ||
      typeof firestore.runTransaction !== 'function'
    ) {
      throw new TypeError('FIRESTORE_REQUIRED');
    }
    this.firestore = firestore;
    this.clock = typeof clock === 'function' ? clock : Date.now;
  }

  pendingDoc(medcasesUid, selectionIdSha256) {
    const hash = requireSha256(selectionIdSha256, 'SELECTION_ID_SHA256');
    return this.firestore
      .collection(VAULT_COLLECTION)
      .doc(uidDocId(medcasesUid))
      .collection(PENDING_SUBCOLLECTION)
      .doc(hash);
  }

  async createPendingGrant({
    medcasesUid,
    selectionIdSha256,
    encryptedRefreshToken,
    discoveredProjects,
    grantedScopes,
    createdAtMs,
    expiresAtMs,
  }) {
    const uidHash = uidDocId(medcasesUid);
    const selectionHash = requireSha256(
      selectionIdSha256,
      'SELECTION_ID_SHA256',
    );

    if (!encryptedRefreshToken || typeof encryptedRefreshToken !== 'object') {
      throw new TypeError('ENCRYPTED_REFRESH_TOKEN_REQUIRED');
    }
    requireNonEmptyString(
      encryptedRefreshToken.ciphertextB64,
      'CIPHERTEXT_B64',
    );
    requireNonEmptyString(encryptedRefreshToken.keyName, 'KMS_KEY_NAME');
    requireNonEmptyString(encryptedRefreshToken.aadSha256, 'AAD_SHA256');

    const created = Number(createdAtMs);
    const expires = Number(expiresAtMs);
    if (
      !Number.isFinite(created) ||
      !Number.isFinite(expires) ||
      expires <= created
    ) {
      throw new Error('PENDING_GRANT_TIME_RANGE_INVALID');
    }

    const projects = safeProjects(discoveredProjects);
    if (projects.length < 2) {
      throw new Error('PENDING_GRANT_REQUIRES_MULTI_PROJECT_DISCOVERY');
    }

    const record = {
      schema: PENDING_SCHEMA,
      medcasesUidSha256: uidHash,
      selectionIdSha256: selectionHash,
      encryptedRefreshToken: {
        schema: encryptedRefreshToken.schema,
        keyName: encryptedRefreshToken.keyName,
        ciphertextB64: encryptedRefreshToken.ciphertextB64,
        aadSha256: encryptedRefreshToken.aadSha256,
      },
      discoveredProjects: projects,
      grantedScopes: safeScopes(grantedScopes),
      createdAtMs: created,
      expiresAtMs: expires,
      lifecycleState: 'active',
      claimIdSha256: null,
      claimedAtMs: null,
      claimExpiresAtMs: null,
      consumedAtMs: null,
      used: false,
      usedAtMs: null,
      selectedProjectId: null,
    };

    assertNoPlaintextTokenMaterial(record);

    const ref = this.pendingDoc(medcasesUid, selectionHash);
    await this.firestore.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (snapshot && snapshot.exists) {
        throw new Error('PENDING_GRANT_ALREADY_EXISTS');
      }
      tx.create(ref, record);
    });

    return Object.freeze({
      created: true,
      expiresAtMs: expires,
    });
  }

  async claimPendingGrant({
    medcasesUid,
    selectionIdSha256,
    selectedProjectId,
    claimIdSha256,
  }) {
    const selectionHash = requireSha256(
      selectionIdSha256,
      'SELECTION_ID_SHA256',
    );
    const selected = requireNonEmptyString(
      selectedProjectId,
      'SELECTED_PROJECT_ID',
    );
    const claimHash = requireSha256(claimIdSha256, 'CLAIM_ID_SHA256');
    const ref = this.pendingDoc(medcasesUid, selectionHash);
    const now = Number(this.clock());

    return this.firestore.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (!snapshot || !snapshot.exists) {
        throw new Error('PENDING_GRANT_NOT_FOUND');
      }

      const data = snapshot.data();
      assertNoPlaintextTokenMaterial(data);

      if (!data || data.schema !== PENDING_SCHEMA) {
        throw new Error('PENDING_GRANT_SCHEMA_MISMATCH');
      }
      if (!Number.isFinite(Number(data.expiresAtMs)) || now > Number(data.expiresAtMs)) {
        throw new Error('PENDING_GRANT_EXPIRED');
      }

      const lifecycleState =
        typeof data.lifecycleState === 'string' && data.lifecycleState.trim()
          ? data.lifecycleState.trim()
          : data.used === true
            ? 'consumed'
            : 'active';

      if (!['active', 'claimed', 'consumed'].includes(lifecycleState)) {
        throw new Error('PENDING_GRANT_LIFECYCLE_STATE_INVALID');
      }
      if (data.used === true || lifecycleState === 'consumed') {
        throw new Error('PENDING_GRANT_ALREADY_USED');
      }
      if (lifecycleState === 'claimed') {
        const existingLease = Number(data.claimExpiresAtMs);
        if (!Number.isFinite(existingLease)) {
          throw new Error('PENDING_GRANT_CLAIM_LEASE_INVALID');
        }
        if (now <= existingLease) {
          throw new Error('PENDING_GRANT_ALREADY_CLAIMED');
        }
      }

      const projects = safeProjects(data.discoveredProjects);
      if (!projects.some((p) => p.projectId === selected)) {
        throw new Error('SELECTED_PROJECT_NOT_IN_PENDING_DISCOVERY');
      }

      const claimExpiresAtMs = Math.min(
        now + PENDING_CLAIM_LEASE_MS,
        Number(data.expiresAtMs),
      );
      if (claimExpiresAtMs <= now) {
        throw new Error('PENDING_GRANT_EXPIRED');
      }

      tx.update(ref, {
        lifecycleState: 'claimed',
        claimIdSha256: claimHash,
        claimedAtMs: now,
        claimExpiresAtMs,
        selectedProjectId: selected,
        used: false,
        usedAtMs: null,
      });

      return Object.freeze({
        claimed: true,
        consumed: false,
        encryptedRefreshToken: data.encryptedRefreshToken,
        discoveredProjects: projects,
        grantedScopes: safeScopes(data.grantedScopes),
        createdAtMs: Number(data.createdAtMs),
        expiresAtMs: Number(data.expiresAtMs),
        claimedAtMs: now,
        claimExpiresAtMs,
      });
    });
  }

  async completePendingGrant({
    medcasesUid,
    selectionIdSha256,
    selectedProjectId,
    claimIdSha256,
  }) {
    const selectionHash = requireSha256(
      selectionIdSha256,
      'SELECTION_ID_SHA256',
    );
    const selected = requireNonEmptyString(
      selectedProjectId,
      'SELECTED_PROJECT_ID',
    );
    const claimHash = requireSha256(claimIdSha256, 'CLAIM_ID_SHA256');
    const ref = this.pendingDoc(medcasesUid, selectionHash);
    const now = Number(this.clock());

    return this.firestore.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (!snapshot || !snapshot.exists) {
        throw new Error('PENDING_GRANT_NOT_FOUND');
      }
      const data = snapshot.data();
      assertNoPlaintextTokenMaterial(data);
      if (!data || data.schema !== PENDING_SCHEMA) {
        throw new Error('PENDING_GRANT_SCHEMA_MISMATCH');
      }
      if (data.used === true || data.lifecycleState === 'consumed') {
        throw new Error('PENDING_GRANT_ALREADY_USED');
      }
      if (data.lifecycleState !== 'claimed') {
        throw new Error('PENDING_GRANT_NOT_CLAIMED');
      }
      if (data.claimIdSha256 !== claimHash) {
        throw new Error('PENDING_GRANT_CLAIM_OWNERSHIP_MISMATCH');
      }
      if (data.selectedProjectId !== selected) {
        throw new Error('PENDING_GRANT_SELECTED_PROJECT_CHANGED');
      }

      tx.update(ref, {
        lifecycleState: 'consumed',
        claimIdSha256: null,
        claimExpiresAtMs: null,
        consumedAtMs: now,
        used: true,
        usedAtMs: now,
        selectedProjectId: selected,
      });

      return Object.freeze({
        consumed: true,
        consumedAtMs: now,
      });
    });
  }

  async releasePendingGrantClaim({
    medcasesUid,
    selectionIdSha256,
    claimIdSha256,
  }) {
    const selectionHash = requireSha256(
      selectionIdSha256,
      'SELECTION_ID_SHA256',
    );
    const claimHash = requireSha256(claimIdSha256, 'CLAIM_ID_SHA256');
    const ref = this.pendingDoc(medcasesUid, selectionHash);

    return this.firestore.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (!snapshot || !snapshot.exists) {
        return Object.freeze({ released: false, missing: true });
      }
      const data = snapshot.data();
      assertNoPlaintextTokenMaterial(data);
      if (!data || data.schema !== PENDING_SCHEMA) {
        throw new Error('PENDING_GRANT_SCHEMA_MISMATCH');
      }
      if (data.used === true || data.lifecycleState === 'consumed') {
        return Object.freeze({ released: false, consumed: true });
      }
      if (
        data.lifecycleState !== 'claimed' ||
        data.claimIdSha256 !== claimHash
      ) {
        return Object.freeze({ released: false, ownerMismatch: true });
      }

      tx.update(ref, {
        lifecycleState: 'active',
        claimIdSha256: null,
        claimedAtMs: null,
        claimExpiresAtMs: null,
        selectedProjectId: null,
        used: false,
        usedAtMs: null,
      });

      return Object.freeze({ released: true });
    });
  }

  async consumePendingGrant(input) {
    return this.claimPendingGrant(input);
  }
}

module.exports = {
  PENDING_SCHEMA,
  PENDING_SUBCOLLECTION,
  StudyGoogleAiOAuthPendingGrantFirestoreStoreV1,
  assertNoPlaintextTokenMaterial,
  uidDocId,
};
