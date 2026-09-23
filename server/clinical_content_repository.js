'use strict';

const MAX_BYTES = 8 * 1024 * 1024;
const LOGICAL_PATH = /^(manifest\.json|snapshots\/[0-9]+\/[A-Za-z]+\/(index|[a-f0-9]{64})\.json)$/;
class ContentRepositoryError extends Error {
  constructor(code = 'CONTENT_UNAVAILABLE') { super(code); this.code = code; }
}
function validateLogicalPath(value) {
  if (typeof value !== 'string' || !LOGICAL_PATH.test(value)) {
    throw new ContentRepositoryError('INVALID_PATH');
  }
}
// Transport only: no publication, identity inference, or clinical authority.
class ClinicalContentRepository {
  async readObject() { throw new ContentRepositoryError('NOT_CONFIGURED'); }
}
async function readBounded(body, length) {
  if (length !== undefined && (!Number.isSafeInteger(length) || length < 0)) {
    body?.destroy?.(); throw new ContentRepositoryError();
  }
  if (length > MAX_BYTES) {
    body?.destroy?.(); throw new ContentRepositoryError('PAYLOAD_LIMIT');
  }
  if (!body || typeof body[Symbol.asyncIterator] !== 'function') throw new ContentRepositoryError();
  // A fixed buffer also bounds memory for a hostile stream of tiny chunks.
  const buffer = Buffer.allocUnsafe(MAX_BYTES); let size = 0;
  try {
    for await (const chunk of body) {
      if (!Buffer.isBuffer(chunk) && !(chunk instanceof Uint8Array)) throw new ContentRepositoryError();
      size += chunk.byteLength;
      if (size > MAX_BYTES) throw new ContentRepositoryError('PAYLOAD_LIMIT');
      buffer.set(chunk, size - chunk.byteLength);
    }
    if (length !== undefined && size !== length) throw new ContentRepositoryError();
    return Buffer.from(buffer.subarray(0, size));
  } finally { body.destroy?.(); }
}
function createClinicalContentRepository(env = process.env) {
  try {
    const backend = env.MEDCASES_CLINICAL_CONTENT_BACKEND;
    if (backend === undefined || backend === 'filesystem') {
      const {FilesystemClinicalContentRepository} = require('./filesystem_clinical_content_repository');
      return new FilesystemClinicalContentRepository(env.MEDCASES_CLINICAL_CONTENT_ROOT);
    }
    if (backend === 's3') {
      const {ObjectStorageClinicalContentRepository} = require('./object_storage_clinical_content_repository');
      return new ObjectStorageClinicalContentRepository(env);
    }
  } catch (_) { /* Invalid configuration never falls back or discloses secrets. */ }
  return new ClinicalContentRepository();
}
module.exports = {MAX_BYTES, ContentRepositoryError, ClinicalContentRepository,
  validateLogicalPath, readBounded, createClinicalContentRepository};
