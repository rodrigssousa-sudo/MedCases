'use strict';
const model = require('./model');

// Metadata only. Publication is determined by the active pointer, never by
// legacy inventory membership or the separate editorial Guide workflow.
async function loadActivePathologies(db, {previous = []} = {}) {
  const {hash} = await import('./clinical_publication.mjs');
  const pointerRef = db.doc('app_config/clinical_content');
  const pointer = (await pointerRef.get()).data();
  if (!pointer || pointer.status !== 'ACTIVE' || pointer.schemaVersion !== 2 ||
      !/^[A-Za-z0-9._-]{1,120}$/.test(pointer.activeVersion || '')) {
    throw Error('ACTIVE_CATALOG_UNAVAILABLE');
  }
  const path = 'clinical_content_versions/' + pointer.activeVersion;
  const manifest = (await db.doc(path).get()).data();
  if (!manifest || manifest.status !== 'ACTIVE' || manifest.schemaVersion !== 2 ||
      manifest.contentVersion !== pointer.activeVersion || hash(manifest) !== pointer.manifestSha256) {
    throw Error('ACTIVE_CATALOG_MANIFEST_MISMATCH');
  }
  const descriptors = manifest.chunks.filter(x => x.collection === 'clinical_identity_registry');
  if (!descriptors.length || !Array.isArray(manifest.owners)) throw Error('ACTIVE_CATALOG_IDENTITY_MISSING');
  const identities = [];
  for (const descriptor of descriptors) {
    if (!/^[A-Za-z0-9._-]{1,120}$/.test(descriptor.id)) throw Error('ACTIVE_CATALOG_CHUNK_INVALID');
    const chunk = (await db.doc(path + '/chunks/' + descriptor.id).get()).data();
    if (!chunk || typeof chunk.json !== 'string' || model.hash(chunk.json) !== descriptor.sha256) {
      throw Error('ACTIVE_CATALOG_IDENTITY_HASH_MISMATCH');
    }
    const rows = JSON.parse(chunk.json);
    if (!Array.isArray(rows) || rows.length !== descriptor.count) throw Error('ACTIVE_CATALOG_IDENTITY_COUNT_MISMATCH');
    identities.push(...rows);
  }
  const availability = new Map(manifest.owners.map(x => [x.ownerId, x]));
  const ids = new Set(identities.map(x => x.canonicalKey));
  if (ids.size !== identities.length || ids.size !== manifest.ownerCount ||
      availability.size !== ids.size || identities.some(x => x.enabled === false || !availability.has(x.canonicalKey))) {
    throw Error('ACTIVE_CATALOG_OWNER_MISMATCH');
  }
  const source = {repository: 'FIRESTORE_ACTIVE_CLINICAL_CATALOG', revision: pointer.manifestSha256.slice(0, 40),
    activeVersion: pointer.activeVersion, manifestSha256: pointer.manifestSha256};
  const prior = new Map(previous.map(x => [x.canonicalId, x]));
  const rows = identities.map(identity => {
    const owner = availability.get(identity.canonicalKey);
    const row = model.pathology(identity, {managementRules: [], content: [], mode: 'ACTIVE_REMOTE_SCHEMA_2'}, source,
      path, pointer.manifestSha256);
    row.recordId = prior.get(row.canonicalId)?.recordId || model.hash('pathologies:active:' + row.canonicalId).slice(0, 40);
    row.sourceUrl = 'https://console.firebase.google.com/project/medcases-pro/firestore';
    row.sourceVersion = pointer.activeVersion;
    row.namePt = identity.title?.pt || identity.displayName?.pt || 'UNKNOWN';
    row.nameEs = identity.title?.es || identity.displayName?.es || 'UNKNOWN';
    row.aliases = [...new Set([...row.aliases, identity.displayLabel].filter(x => typeof x === 'string'))];
    row.ptAvailable = Boolean(owner.availableModes?.study?.pt || owner.availableModes?.plantao?.pt);
    row.esAvailable = Boolean(owner.availableModes?.study?.es || owner.availableModes?.plantao?.es);
    row.status = 'PUBLISHED';
    row.publishedState = 'PUBLISHED';
    row.runtimePublicationStatus = 'PUBLISHED';
    row.studyStatus = owner.availableModes?.study?.pt && owner.availableModes?.study?.es ? 'PUBLISHED' : 'NOT_AVAILABLE';
    row.plantaoStatus = owner.availableModes?.plantao?.pt && owner.availableModes?.plantao?.es ? 'PUBLISHED' : 'NOT_AVAILABLE';
    row.availableModes = owner.availableModes;
    row.referenceState = owner.referenceState;
    row.reviewDate = identity.clinicalReviewDate || 'UNKNOWN';
    row.reviewer = identity.reviewer || 'UNKNOWN';
    row.activeVersion = pointer.activeVersion;
    row.catalogDisplayName = identity.displayLabel && identity.displayLabel !== identity.canonicalKey ?
      identity.displayLabel : identity.canonicalKey.replace(/_/g, ' ');
    return row;
  });
  const after = (await pointerRef.get()).data();
  if (hash(after) !== hash(pointer)) throw Error('ACTIVE_CATALOG_CHANGED_DURING_READ');
  return {source, rows, sourceMode: 'ACTIVE_REMOTE_SCHEMA_2', sourceVersion: pointer.activeVersion,
    itemsRead: rows.length, retainMissingRows: false, manifest};
}

async function readActivePathologyInventory(db, params, previousMeta = {}) {
  const loaded = await loadActivePathologies(db);
  const generation = model.hash(loaded.sourceVersion + ':' + loaded.source.manifestSha256).slice(0, 40);
  if (params.generation && params.generation !== generation) throw Error('INVENTORY_VERSION_CHANGED');
  const rows = model.classify(loaded.rows).map(x => ({...x, displayName: x.catalogDisplayName}));
  const counts = model.summary(rows);
  counts.published = rows.length;
  const guides = (await db.collection('clinical_guides').select('status', 'isPublished').get()).docs.map(x => x.data());
  counts.guidesTotal = guides.length;
  counts.guidesDraft = guides.filter(x => String(x.status).toLowerCase() === 'draft' && x.isPublished !== true).length;
  counts.guidesPublished = guides.filter(x => String(x.status).toLowerCase() === 'published' && x.isPublished !== false).length;
  counts.guidesOther = guides.length - counts.guidesDraft - counts.guidesPublished;
  const meta = {counts, source: loaded.source, sourceMode: loaded.sourceMode, sourceVersion: loaded.sourceVersion,
    syncState: 'SYNCED_ACTIVE_CATALOG', generation, lastSyncAt: previousMeta.lastSyncAt || null};
  const publicRow = ({searchFacets, aliases, sortName, catalogDisplayName, ...row}) => row;
  if (params.action === 'detail') {
    const row = rows.find(x => x.recordId === params.recordId);
    if (!row) throw Error('NOT_FOUND');
    return {row: publicRow(row), meta};
  }
  const {FILTERS} = require('./store');
  const filter = params.filter || (params.action === 'queue' ? 'HAS_GAPS' : 'ALL');
  const term = model.normalize(params.search || ''), limit = params.limit ?? 30;
  if (!FILTERS.has(filter) || term.length > 100 || !Number.isInteger(limit) || limit < 1 || limit > 100 ||
      (params.cursor && !/^[a-f0-9]{40}$/.test(params.cursor))) throw Error('INVALID_FILTER');
  const selected = rows.filter(x => x.filters.includes(filter) &&
    [x.canonicalId, x.namePt, x.nameEs, x.catalogDisplayName, ...x.aliases].some(value => model.normalize(value).startsWith(term)))
    .sort((a, b) => a.recordId.localeCompare(b.recordId));
  const page = selected.filter(x => !params.cursor || x.recordId > params.cursor).slice(0, limit + 1);
  const pageRows = page.slice(0, limit).map(publicRow);
  return {meta, generation, rows: pageRows, nextCursor: page.length > limit ? page[limit - 1].recordId : null,
    workItems: pageRows.flatMap(row => row.queueReasons.map(reason => ({queueId: model.hash(`pathologies:${row.recordId}:${reason}`).slice(0, 40),
      canonicalId: row.canonicalId, name: row.displayName, reason, sourceVersion: row.sourceVersion,
      currentStatus: row.status, lastUpdated: row.lastUpdated, recordId: row.recordId})))};
}
module.exports = {loadActivePathologies, readActivePathologyInventory};
