'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const {ClinicalContentRepository, ContentRepositoryError, validateLogicalPath, readBounded} = require('./clinical_content_repository');

class FilesystemClinicalContentRepository extends ClinicalContentRepository {
  constructor(root) { super(); this.root = root; }
  async readObject(logicalPath, {signal} = {}) {
    validateLogicalPath(logicalPath);
    if (!this.root) throw new ContentRepositoryError('NOT_CONFIGURED');
    const base = await fs.realpath(this.root);
    const file = await fs.realpath(path.join(base, logicalPath));
    if (!file.startsWith(base + path.sep)) throw new ContentRepositoryError('INVALID_PATH');
    const handle = await fs.open(file, 'r');
    try {
      const stat = await handle.stat();
      if (!stat.isFile()) throw new ContentRepositoryError('PAYLOAD_LIMIT');
      return await readBounded(handle.createReadStream({autoClose: false, signal}), stat.size);
    } finally { await handle.close(); }
  }
}
module.exports = {FilesystemClinicalContentRepository};
