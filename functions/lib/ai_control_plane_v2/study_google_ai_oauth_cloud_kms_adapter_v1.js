'use strict';

const crypto = require('crypto');

const KMS_SCHEMA = 'medcases.study.oauth.kms.refresh-token.v1';

function requireNonEmptyString(value, name) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${name}_REQUIRED`);
  }
  return value;
}

function sha256Hex(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function buildAad({ medcasesUid, projectId }) {
  const uid = requireNonEmptyString(medcasesUid, 'MEDCASES_UID');
  const project = requireNonEmptyString(projectId, 'PROJECT_ID');
  const aadObject = {
    schema: KMS_SCHEMA,
    medcasesUidSha256: sha256Hex(uid),
    projectId: project,
  };
  return Buffer.from(JSON.stringify(aadObject), 'utf8');
}

function unwrapUnaryResponse(result, operation) {
  const response = Array.isArray(result) ? result[0] : result;
  if (!response || typeof response !== 'object') {
    throw new Error(`${operation}_EMPTY_RESPONSE`);
  }
  return response;
}

class StudyGoogleAiOAuthCloudKmsAdapterV1 {
  constructor({ kmsClient, keyName }) {
    if (!kmsClient || typeof kmsClient.encrypt !== 'function' || typeof kmsClient.decrypt !== 'function') {
      throw new TypeError('KMS_CLIENT_REQUIRED');
    }
    this.kmsClient = kmsClient;
    this.keyName = requireNonEmptyString(keyName, 'KMS_KEY_NAME');
  }

  async encryptRefreshToken({ refreshToken, medcasesUid, projectId }) {
    const token = requireNonEmptyString(refreshToken, 'REFRESH_TOKEN');
    const aad = buildAad({ medcasesUid, projectId });
    const response = unwrapUnaryResponse(
      await this.kmsClient.encrypt({
        name: this.keyName,
        plaintext: Buffer.from(token, 'utf8'),
        additionalAuthenticatedData: aad,
      }),
      'KMS_ENCRYPT',
    );
    const ciphertext = Buffer.from(response.ciphertext || []);
    if (ciphertext.length === 0) {
      throw new Error('KMS_ENCRYPT_EMPTY_CIPHERTEXT');
    }
    return Object.freeze({
      schema: KMS_SCHEMA,
      keyName: this.keyName,
      ciphertextB64: ciphertext.toString('base64'),
      aadSha256: sha256Hex(aad),
    });
  }

  async decryptRefreshToken({ encryptedRecord, medcasesUid, projectId }) {
    if (!encryptedRecord || typeof encryptedRecord !== 'object') {
      throw new TypeError('ENCRYPTED_RECORD_REQUIRED');
    }
    if (encryptedRecord.schema !== KMS_SCHEMA) {
      throw new Error('KMS_SCHEMA_MISMATCH');
    }
    if (encryptedRecord.keyName !== this.keyName) {
      throw new Error('KMS_KEY_NAME_MISMATCH');
    }
    const ciphertextB64 = requireNonEmptyString(encryptedRecord.ciphertextB64, 'CIPHERTEXT_B64');
    const aad = buildAad({ medcasesUid, projectId });
    if (encryptedRecord.aadSha256 !== sha256Hex(aad)) {
      throw new Error('KMS_AAD_MISMATCH');
    }
    const response = unwrapUnaryResponse(
      await this.kmsClient.decrypt({
        name: this.keyName,
        ciphertext: Buffer.from(ciphertextB64, 'base64'),
        additionalAuthenticatedData: aad,
      }),
      'KMS_DECRYPT',
    );
    const plaintext = Buffer.from(response.plaintext || []);
    if (plaintext.length === 0) {
      throw new Error('KMS_DECRYPT_EMPTY_PLAINTEXT');
    }
    return plaintext.toString('utf8');
  }
}

function createOfficialCloudKmsClient(options) {
  let KeyManagementServiceClient;
  try {
    ({ KeyManagementServiceClient } = require('@google-cloud/kms'));
  } catch (error) {
    const wrapped = new Error('OFFICIAL_CLOUD_KMS_PACKAGE_NOT_AVAILABLE');
    wrapped.cause = error;
    throw wrapped;
  }
  return new KeyManagementServiceClient(options || {});
}

module.exports = {
  KMS_SCHEMA,
  StudyGoogleAiOAuthCloudKmsAdapterV1,
  buildAad,
  createOfficialCloudKmsClient,
};
