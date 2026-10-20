// Local adapter to the existing schema-2 preparer. No SDK, network or publishing.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {prepare, validate, hash, collections} from './publication.mjs';
import {extraCollections} from './functional_schema.mjs';
const input = JSON.parse(fs.readFileSync(0, 'utf8'));
try {
  if (input.action === 'verifySnapshot') {
    // Same wire hashes/counts as the R15 reader. An already active snapshot can
    // retain disabled identities; do not delete them or grant them eligibility.
    const {manifest, chunks} = input.release;
    if (manifest.schemaVersion !== 2 || manifest.status !== 'ACTIVE' ||
        !Array.isArray(manifest.chunks) || !manifest.chunks.length) throw Error('snapshot_shape');
    const ids = new Set(), counts = {};
    const allowed = new Set([...collections, ...extraCollections]);
    for (const descriptor of manifest.chunks) {
      if (ids.has(descriptor.id) || !allowed.has(descriptor.collection)) throw Error('chunk_descriptor');
      ids.add(descriptor.id);
      const raw = chunks[descriptor.id]?.json;
      if (typeof raw !== 'string' ||
          createHash('sha256').update(raw).digest('hex') !== descriptor.sha256) throw Error('chunk_hash');
      const rows = JSON.parse(raw);
      if (!Array.isArray(rows) || rows.length !== descriptor.count) throw Error('row_count');
      counts[descriptor.collection] = (counts[descriptor.collection] || 0) + rows.length;
    }
    if (Object.keys(chunks).length !== ids.size) throw Error('extra_chunk');
    for (const key of allowed) if (manifest.counts?.[key] !== counts[key]) throw Error('collection_count');
    process.stdout.write(JSON.stringify({ok: true, manifestSha256: hash(manifest)}));
    process.exit(0);
  }
  const release = input.action === 'prepare'
    ? prepare(input.version, input.registries, {schemaVersion: 2})
    : input.release;
  if (release.manifest.schemaVersion !== 2) throw Error('schema_2_required');
  const validation = validate(release);
  process.stdout.write(JSON.stringify({ok: true, validation, release, manifestSha256: hash(release.manifest)}));
} catch (error) {
  process.stdout.write(JSON.stringify({ok: false, code: error.message}));
  process.exitCode = 1;
}
