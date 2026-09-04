'use strict';

const crypto = require('crypto');

const VAULT_COLLECTION = 'study_google_ai_oauth_vault';
const FLOW_SUBCOLLECTION = 'oauth_flow_guard';
const VAULT_SCHEMA = 'medcases.study.oauth.firestore-vault.v1';
const FLOW_SCHEMA = 'medcases.study.oauth.flow-guard.v1';
const FORBIDDEN_PLAINTEXT_KEYS = new Set([
  'refreshtoken',
  'accesstoken',
  'authcode',
  'authorization',
  'plaintext',
]);

function requireNonEmptyString(value, name) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${name}_REQUIRED`);
  }
  return value;
}

function sha256Hex(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function assertNoPlaintextTokenMaterial(value, path) {
  const here = path || '$';
  if (Array.isArray(value)) {
    value.forEach((item, index) => assertNoPlaintextTokenMaterial(item, `${here}[${index}]`));
    return;
  }
  if (!value || typeof value !== 'object') return;
  Object.keys(value).forEach((key) => {
    const normalized = key.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (FORBIDDEN_PLAINTEXT_KEYS.has(normalized)) {
      throw new Error(`PLAINTEXT_TOKEN_FIELD_FORBIDDEN:${here}.${key}`);
    }
    assertNoPlaintextTokenMaterial(value[key], `${here}.${key}`);
  });
}

function safeHexEqual(left, right) {
  if (typeof left !== 'string' || typeof right !== 'string') return false;
  if (!/^[a-f0-9]{64}$/.test(left) || !/^[a-f0-9]{64}$/.test(right)) return false;
  return crypto.timingSafeEqual(Buffer.from(left, 'hex'), Buffer.from(right, 'hex'));
}

function uidDocId(medcasesUid) {
  return sha256Hex(requireNonEmptyString(medcasesUid, 'MEDCASES_UID'));
}

class StudyGoogleAiOAuthFirestoreVaultAdapterV1 {
  constructor({ firestore, clock }) {
    if (!firestore || typeof firestore.collection !== 'function' || typeof firestore.runTransaction !== 'function') {
      throw new TypeError('FIRESTORE_REQUIRED');
    }
    this.firestore = firestore;
    this.clock = typeof clock === 'function' ? clock : Date.now;
  }

  vaultDoc(medcasesUid) {
    return this.firestore.collection(VAULT_COLLECTION).doc(uidDocId(medcasesUid));
  }

  flowDoc(medcasesUid, challengeId) {
    const id = requireNonEmptyString(challengeId, 'CHALLENGE_ID');
    return this.vaultDoc(medcasesUid).collection(FLOW_SUBCOLLECTION).doc(id);
  }

  async upsertEncryptedCredential({ medcasesUid, validatedProject, encryptedRefreshToken }) {
    if (!validatedProject || validatedProject.serverValidated !== true) {
      throw new Error('SERVER_VALIDATED_PROJECT_REQUIRED');
    }
    if (!encryptedRefreshToken || typeof encryptedRefreshToken !== 'object') {
      throw new TypeError('ENCRYPTED_REFRESH_TOKEN_REQUIRED');
    }
    assertNoPlaintextTokenMaterial(validatedProject, '$.validatedProjectInput');
    assertNoPlaintextTokenMaterial(encryptedRefreshToken, '$.encryptedRefreshTokenInput');
    requireNonEmptyString(validatedProject.projectId, 'PROJECT_ID');
    requireNonEmptyString(encryptedRefreshToken.ciphertextB64, 'CIPHERTEXT_B64');
    requireNonEmptyString(encryptedRefreshToken.keyName, 'KMS_KEY_NAME');
    requireNonEmptyString(encryptedRefreshToken.aadSha256, 'AAD_SHA256');

    const now = Number(this.clock());
    const ref = this.vaultDoc(medcasesUid);
    const record = {
      schema: VAULT_SCHEMA,
      medcasesUidSha256: uidDocId(medcasesUid),
      validatedProject: {
        serverValidated: true,
        projectId: validatedProject.projectId,
        projectNumber: validatedProject.projectNumber || null,
        displayName: validatedProject.displayName || null,
        geminiApiEnabled: validatedProject.geminiApiEnabled === true,
        serviceUsageUse: validatedProject.serviceUsageUse === true,
        validatedAtMs: Number(validatedProject.validatedAtMs || now),
      },
      encryptedRefreshToken: {
        schema: encryptedRefreshToken.schema,
        keyName: encryptedRefreshToken.keyName,
        ciphertextB64: encryptedRefreshToken.ciphertextB64,
        aadSha256: encryptedRefreshToken.aadSha256,
      },
      updatedAtMs: now,
    };
    assertNoPlaintextTokenMaterial(record);

    await this.firestore.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const existing = snapshot && snapshot.exists ? snapshot.data() : null;
      const toWrite = {
        ...record,
        createdAtMs: existing && Number(existing.createdAtMs) > 0 ? Number(existing.createdAtMs) : now,
      };
      tx.set(ref, toWrite, { merge: true });
    });
    return { vaultDocumentId: uidDocId(medcasesUid), updatedAtMs: now };
  }

  async readEncryptedCredential({ medcasesUid }) {
    const snapshot = await this.vaultDoc(medcasesUid).get();
    if (!snapshot || !snapshot.exists) return null;
    const data = snapshot.data();
    assertNoPlaintextTokenMaterial(data);
    return data;
  }

  async createFlowGuard({ medcasesUid, challengeId, stateSha256, nonceSha256, createdAtMs, expiresAtMs }) {
    const ref = this.flowDoc(medcasesUid, challengeId);
    const record = {
      schema: FLOW_SCHEMA,
      medcasesUidSha256: uidDocId(medcasesUid),
      stateSha256: requireNonEmptyString(stateSha256, 'STATE_SHA256'),
      nonceSha256: requireNonEmptyString(nonceSha256, 'NONCE_SHA256'),
      createdAtMs: Number(createdAtMs),
      expiresAtMs: Number(expiresAtMs),
      used: false,
      usedAtMs: null,
      authCodeSha256: null,
    };
    if (!/^[a-f0-9]{64}$/.test(record.stateSha256) || !/^[a-f0-9]{64}$/.test(record.nonceSha256)) {
      throw new Error('FLOW_HASH_FORMAT_INVALID');
    }
    assertNoPlaintextTokenMaterial(record);
    await this.firestore.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (snapshot && snapshot.exists) {
        throw new Error('FLOW_CHALLENGE_ALREADY_EXISTS');
      }
      tx.set(ref, record, { merge: false });
    });
    return { challengeId, expiresAtMs: record.expiresAtMs };
  }

  async consumeFlowGuard({ medcasesUid, challengeId, stateSha256, nonceSha256, authCodeSha256, nowMs }) {
    const ref = this.flowDoc(medcasesUid, challengeId);
    const now = Number(nowMs);
    return this.firestore.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (!snapshot || !snapshot.exists) throw new Error('FLOW_CHALLENGE_NOT_FOUND');
      const data = snapshot.data();
      if (data.schema !== FLOW_SCHEMA) throw new Error('FLOW_SCHEMA_MISMATCH');
      if (data.medcasesUidSha256 !== uidDocId(medcasesUid)) throw new Error('FLOW_UID_MISMATCH');
      if (data.used === true) throw new Error('FLOW_REPLAY_REJECTED');
      if (!Number.isFinite(now) || now > Number(data.expiresAtMs)) throw new Error('FLOW_CHALLENGE_EXPIRED');
      if (!safeHexEqual(data.stateSha256, stateSha256)) throw new Error('FLOW_STATE_MISMATCH');
      if (!safeHexEqual(data.nonceSha256, nonceSha256)) throw new Error('FLOW_NONCE_MISMATCH');
      if (!/^[a-f0-9]{64}$/.test(authCodeSha256 || '')) throw new Error('AUTH_CODE_HASH_INVALID');
      tx.set(ref, {
        used: true,
        usedAtMs: now,
        authCodeSha256,
      }, { merge: true });
      return { consumed: true, usedAtMs: now };
    });
  }
}

module.exports = {
  FLOW_SCHEMA,
  FLOW_SUBCOLLECTION,
  VAULT_COLLECTION,
  VAULT_SCHEMA,
  StudyGoogleAiOAuthFirestoreVaultAdapterV1,
  assertNoPlaintextTokenMaterial,
  uidDocId,
};
