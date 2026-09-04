'use strict';

const {
  StudyGoogleAiOAuthCloudKmsAdapterV1,
  createOfficialCloudKmsClient,
} = require('./study_google_ai_oauth_cloud_kms_adapter_v1');
const {
  StudyGoogleAiOAuthFirestoreVaultAdapterV1,
} = require('./study_google_ai_oauth_firestore_vault_adapter_v1');
const {
  StudyGoogleAiOAuthFlowGuardV1,
} = require('./study_google_ai_oauth_flow_guard_v1');
const {
  StudyGoogleAiOAuthProjectDiscoveryValidationV1,
} = require('./study_google_ai_oauth_project_discovery_validation_v1');

const VERSION = 'medcases.study.oauth.runtime-composition.inert.v1';
const DEFAULT_PROJECT_ID = 'medcases-pro';
const DEFAULT_KMS_KEY_NAME = 'projects/medcases-pro/locations/us-central1/keyRings/medcases-study-oauth-vault/cryptoKeys/refresh-token-v1';
const CIPHERTEXT_ENVELOPE_PREFIX = 'kmsv1:';

function requireNonEmptyString(value, name) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${name}_REQUIRED`);
  }
  return value.trim();
}

function base64UrlEncode(value) {
  return Buffer.from(value, 'utf8').toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function base64UrlDecode(value) {
  const raw = requireNonEmptyString(value, 'BASE64URL');
  const normalized = raw.replace(/-/g, '+').replace(/_/g, '/');
  const pad = normalized.length % 4 === 0 ? '' : '='.repeat(4 - (normalized.length % 4));
  return Buffer.from(normalized + pad, 'base64').toString('utf8');
}

function encodeCiphertextEnvelope(encryptedRecord) {
  if (!encryptedRecord || typeof encryptedRecord !== 'object') {
    throw new TypeError('ENCRYPTED_RECORD_REQUIRED');
  }
  return CIPHERTEXT_ENVELOPE_PREFIX + base64UrlEncode(JSON.stringify(encryptedRecord));
}

function decodeCiphertextEnvelope(value) {
  const raw = requireNonEmptyString(value, 'ENCRYPTED_REFRESH_TOKEN');
  if (!raw.startsWith(CIPHERTEXT_ENVELOPE_PREFIX)) {
    throw new Error('KMS_CIPHERTEXT_ENVELOPE_PREFIX_MISMATCH');
  }
  let parsed;
  try {
    parsed = JSON.parse(base64UrlDecode(raw.slice(CIPHERTEXT_ENVELOPE_PREFIX.length)));
  } catch (error) {
    const wrapped = new Error('KMS_CIPHERTEXT_ENVELOPE_INVALID');
    wrapped.cause = error;
    throw wrapped;
  }
  if (!parsed || typeof parsed !== 'object' || !parsed.ciphertextB64 || !parsed.keyName || !parsed.aadSha256) {
    throw new Error('KMS_CIPHERTEXT_ENVELOPE_FIELDS_MISSING');
  }
  return parsed;
}

function parseLegacyVaultAad(aad) {
  let data;
  try {
    data = JSON.parse(requireNonEmptyString(aad, 'AAD'));
  } catch (error) {
    const wrapped = new Error('LEGACY_VAULT_AAD_INVALID');
    wrapped.cause = error;
    throw wrapped;
  }
  return {
    medcasesUid: requireNonEmptyString(data.medCasesUid, 'AAD_MEDCASES_UID'),
    projectId: requireNonEmptyString(data.validatedUserProjectId, 'AAD_VALIDATED_PROJECT_ID'),
  };
}

function projectCacheKey(medcasesUid, projectId) {
  return `${requireNonEmptyString(medcasesUid, 'MEDCASES_UID')}\n${requireNonEmptyString(projectId, 'PROJECT_ID')}`;
}

function defaultAuthorizedFetch(url, options) {
  if (typeof globalThis.fetch !== 'function') {
    throw new Error('GLOBAL_FETCH_NOT_AVAILABLE');
  }
  return globalThis.fetch(url, options);
}

function defaultFirestore(projectId) {
  const admin = require('firebase-admin');
  if (!admin.apps.length) admin.initializeApp({ projectId });
  return admin.firestore();
}

function createStudyGoogleAiOAuthRuntimeCompositionInertV1(options) {
  const opts = options || {};
  const projectId = opts.projectId || DEFAULT_PROJECT_ID;
  const kmsKeyName = opts.kmsKeyName || DEFAULT_KMS_KEY_NAME;
  const firestore = opts.firestore || (opts.firestoreAdapter ? null : defaultFirestore(projectId));
  const kmsClient = opts.kmsClient || (opts.kmsAdapter ? null : createOfficialCloudKmsClient(opts.kmsClientOptions || {}));
  const authorizedFetch = opts.authorizedFetch || defaultAuthorizedFetch;

  const firestoreAdapter = opts.firestoreAdapter || new StudyGoogleAiOAuthFirestoreVaultAdapterV1({
    firestore,
    clock: opts.clock,
  });
  const kmsAdapter = opts.kmsAdapter || new StudyGoogleAiOAuthCloudKmsAdapterV1({
    kmsClient,
    keyName: kmsKeyName,
  });
  const projectValidator = opts.projectValidator || new StudyGoogleAiOAuthProjectDiscoveryValidationV1({
    authorizedFetch,
    clock: opts.clock,
  });
  const flowGuard = opts.flowGuard || new StudyGoogleAiOAuthFlowGuardV1({
    store: firestoreAdapter,
    clock: opts.clock,
    randomBytes: opts.randomBytes,
    ttlMs: opts.ttlMs,
  });

  const validatedProjects = new Map();

  async function resolveValidatedUserProjectId({ accessToken, medCasesUid, serverSelectedProjectId }) {
    const uid = requireNonEmptyString(medCasesUid, 'MEDCASES_UID');
    const token = requireNonEmptyString(accessToken, 'ACCESS_TOKEN');
    let selected = typeof serverSelectedProjectId === 'string' ? serverSelectedProjectId.trim() : '';

    if (!selected) {
      const discovered = await projectValidator.discoverProjects({ accessToken: token });
      if (!Array.isArray(discovered) || discovered.length === 0) {
        throw new Error('NO_ACTIVE_GOOGLE_CLOUD_PROJECT_AVAILABLE');
      }
      if (discovered.length !== 1) {
        const error = new Error('PROJECT_SELECTION_REQUIRED_SERVER_DISCOVERED_MULTIPLE');
        error.safeProjectIds = discovered.map((item) => item && item.projectId).filter(Boolean).slice(0, 100);
        throw error;
      }
      selected = requireNonEmptyString(discovered[0].projectId, 'DISCOVERED_PROJECT_ID');
    }

    const validated = await projectValidator.validateProject({ accessToken: token, projectId: selected });
    if (!validated || validated.serverValidated !== true || validated.projectId !== selected) {
      throw new Error('SERVER_PROJECT_VALIDATION_FAILED');
    }
    validatedProjects.set(projectCacheKey(uid, selected), Object.freeze({ ...validated }));
    return selected;
  }

  async function encryptRefreshToken({ plaintext, aad }) {
    const legacy = parseLegacyVaultAad(aad);
    const encryptedRecord = await kmsAdapter.encryptRefreshToken({
      refreshToken: requireNonEmptyString(plaintext, 'REFRESH_TOKEN'),
      medcasesUid: legacy.medcasesUid,
      projectId: legacy.projectId,
    });
    return encodeCiphertextEnvelope(encryptedRecord);
  }

  async function encryptPendingRefreshToken({
    refreshToken,
    medcasesUid,
    projectId,
  }) {
    return kmsAdapter.encryptRefreshToken({
      refreshToken: requireNonEmptyString(
        refreshToken,
        'REFRESH_TOKEN',
      ),
      medcasesUid: requireNonEmptyString(
        medcasesUid,
        'MEDCASES_UID',
      ),
      projectId: requireNonEmptyString(
        projectId,
        'PROJECT_ID',
      ),
    });
  }

  async function decryptRefreshToken({
    encryptedRecord,
    medcasesUid,
    projectId,
  }) {
    if (!encryptedRecord || typeof encryptedRecord !== 'object') {
      throw new TypeError('ENCRYPTED_RECORD_REQUIRED');
    }
    return kmsAdapter.decryptRefreshToken({
      encryptedRecord,
      medcasesUid: requireNonEmptyString(
        medcasesUid,
        'MEDCASES_UID',
      ),
      projectId: requireNonEmptyString(
        projectId,
        'PROJECT_ID',
      ),
    });
  }

  const pendingGrantKmsAdapter = Object.freeze({
    encryptRefreshToken: encryptPendingRefreshToken,
    decryptRefreshToken,
  });

  async function storeEncryptedGrant({ medCasesUid, record }) {
    if (!record || typeof record !== 'object') throw new TypeError('VAULT_RECORD_REQUIRED');
    const uid = requireNonEmptyString(medCasesUid, 'MEDCASES_UID');
    if (record.medCasesUid !== uid) throw new Error('VAULT_RECORD_UID_MISMATCH');
    const project = requireNonEmptyString(record.validatedUserProjectId, 'VALIDATED_PROJECT_ID');
    const validatedProject = validatedProjects.get(projectCacheKey(uid, project));
    if (!validatedProject) throw new Error('VALIDATED_PROJECT_CONTEXT_MISSING');
    const encryptedRefreshToken = decodeCiphertextEnvelope(record.encryptedRefreshToken);
    return firestoreAdapter.upsertEncryptedCredential({
      medcasesUid: uid,
      validatedProject,
      encryptedRefreshToken,
    });
  }

  async function issueOAuthFlowChallenge({ medcasesUid }) {
    return flowGuard.issueChallenge({ medcasesUid });
  }

  async function consumeOAuthFlowChallenge({ medcasesUid, challengeId, state, nonce, authCode }) {
    return flowGuard.consumeChallenge({ medcasesUid, challengeId, state, nonce, authCode });
  }

  async function discoverProjects({ accessToken }) {
    return projectValidator.discoverProjects({ accessToken });
  }

  return Object.freeze({
    version: VERSION,
    resolveValidatedUserProjectId,
    encryptRefreshToken,
    encryptPendingRefreshToken,
    decryptRefreshToken,
    pendingGrantKmsAdapter,
    storeEncryptedGrant,
    issueOAuthFlowChallenge,
    consumeOAuthFlowChallenge,
    discoverProjects,
  });
}

module.exports = {
  CIPHERTEXT_ENVELOPE_PREFIX,
  DEFAULT_KMS_KEY_NAME,
  DEFAULT_PROJECT_ID,
  VERSION,
  createStudyGoogleAiOAuthRuntimeCompositionInertV1,
  decodeCiphertextEnvelope,
  encodeCiphertextEnvelope,
};
