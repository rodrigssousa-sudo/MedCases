'use strict';

const crypto = require('crypto');

const VERSION =
  'medcases_study_google_ai_oauth_refresh_token_project_vault_v1';

const SCHEMA_VERSION = 1;

function cleanString(value) {
  return typeof value === 'string'
    ? value.trim()
    : '';
}

function requireMedCasesUid(value) {
  const uid = cleanString(value);

  if (!uid || uid.length > 256) {
    throw new Error(
      'MEDCASES_UID_INVALID'
    );
  }

  return uid;
}

function requireValidatedProjectId(value) {
  const projectId =
    cleanString(value);

  if (
    !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(
      projectId
    )
  ) {
    throw new Error(
      'VALIDATED_GOOGLE_PROJECT_ID_INVALID'
    );
  }

  return projectId;
}

function requireRefreshToken(value) {
  const token = cleanString(value);

  if (token.length < 8) {
    throw new Error(
      'REFRESH_TOKEN_MISSING'
    );
  }

  return token;
}

function requireEncryptor(encryptRefreshToken) {
  if (
    typeof encryptRefreshToken
    !== 'function'
  ) {
    throw new TypeError(
      'ENCRYPT_REFRESH_TOKEN_ADAPTER_REQUIRED'
    );
  }

  return encryptRefreshToken;
}

function requireStore(storeEncryptedGrant) {
  if (
    typeof storeEncryptedGrant
    !== 'function'
  ) {
    throw new TypeError(
      'STORE_ENCRYPTED_GRANT_ADAPTER_REQUIRED'
    );
  }

  return storeEncryptedGrant;
}

function tokenFingerprint(token) {
  return crypto
    .createHash('sha256')
    .update(token, 'utf8')
    .digest('hex')
    .slice(0, 20);
}

function normalizeCiphertext(value) {
  const ciphertext =
    cleanString(value);

  if (ciphertext.length < 8) {
    throw new Error(
      'ENCRYPTED_REFRESH_TOKEN_INVALID'
    );
  }

  return ciphertext;
}

function normalizeIsoTime(value) {
  const raw =
    value instanceof Date
      ? value
      : new Date(value);

  if (
    Number.isNaN(raw.getTime())
  ) {
    throw new Error(
      'VAULT_TIMESTAMP_INVALID'
    );
  }

  return raw.toISOString();
}

async function buildEncryptedGrantRecord({
  medCasesUid,
  validatedUserProjectId,
  refreshToken,
  grantedScopes = [],
  encryptRefreshToken,
  now = new Date(),
}) {
  const uid =
    requireMedCasesUid(
      medCasesUid
    );

  const projectId =
    requireValidatedProjectId(
      validatedUserProjectId
    );

  const plaintextToken =
    requireRefreshToken(
      refreshToken
    );

  const encrypt =
    requireEncryptor(
      encryptRefreshToken
    );

  const encrypted =
    normalizeCiphertext(
      await encrypt({
        plaintext:
          plaintextToken,
        aad: JSON.stringify({
          schemaVersion:
            SCHEMA_VERSION,
          medCasesUid:
            uid,
          validatedUserProjectId:
            projectId,
        }),
      })
    );

  if (
    encrypted === plaintextToken
  ) {
    throw new Error(
      'ENCRYPTOR_RETURNED_PLAINTEXT'
    );
  }

  const scopes = Array
    .from(
      new Set(
        Array.isArray(grantedScopes)
          ? grantedScopes
              .map(cleanString)
              .filter(Boolean)
          : []
      )
    )
    .sort();

  return {
    schemaVersion:
      SCHEMA_VERSION,

    medCasesUid:
      uid,

    validatedUserProjectId:
      projectId,

    encryptedRefreshToken:
      encrypted,

    refreshTokenFingerprint:
      tokenFingerprint(
        plaintextToken
      ),

    grantedScopes:
      scopes,

    createdAt:
      normalizeIsoTime(now),

    updatedAt:
      normalizeIsoTime(now),

    accessTokenPersisted:
      false,

    refreshTokenPlaintextPersisted:
      false,

    projectSource:
      'server_validated',
  };
}

function assertRecordContainsNoPlaintext({
  record,
  refreshToken,
  accessToken,
}) {
  const serialized =
    JSON.stringify(record);

  if (
    refreshToken &&
    serialized.includes(
      refreshToken
    )
  ) {
    throw new Error(
      'PLAINTEXT_REFRESH_TOKEN_LEAK'
    );
  }

  if (
    accessToken &&
    serialized.includes(
      accessToken
    )
  ) {
    throw new Error(
      'ACCESS_TOKEN_PERSISTENCE_LEAK'
    );
  }

  return true;
}

async function persistEncryptedOAuthGrant({
  medCasesUid,
  validatedUserProjectId,
  refreshToken,
  accessToken = '',
  grantedScopes = [],
  encryptRefreshToken,
  storeEncryptedGrant,
  now = new Date(),
}) {
  const store =
    requireStore(
      storeEncryptedGrant
    );

  const record =
    await buildEncryptedGrantRecord({
      medCasesUid,
      validatedUserProjectId,
      refreshToken,
      grantedScopes,
      encryptRefreshToken,
      now,
    });

  assertRecordContainsNoPlaintext({
    record,
    refreshToken:
      cleanString(refreshToken),
    accessToken:
      cleanString(accessToken),
  });

  await store({
    medCasesUid:
      record.medCasesUid,
    record,
  });

  return {
    persisted: true,
    encryptedRefreshTokenPresent:
      true,
    medCasesUid:
      record.medCasesUid,
    validatedUserProjectId:
      record.validatedUserProjectId,
    refreshTokenPlaintextPersisted:
      false,
    accessTokenPersisted:
      false,
  };
}

module.exports = {
  VERSION,
  SCHEMA_VERSION,
  buildEncryptedGrantRecord,
  assertRecordContainsNoPlaintext,
  persistEncryptedOAuthGrant,
};
