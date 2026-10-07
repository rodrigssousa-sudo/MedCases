'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {hash: digest} = require('../content_inventory/model');
const {loadActivePathologies, readActivePathologyInventory} = require('../content_inventory/active_pathologies');

async function fixture(ids = ['owner_a', 'owner_b']) {
  const {hash} = await import('../content_inventory/clinical_publication.mjs');
  const identities = ids.map(canonicalKey => ({canonicalKey, enabled: true, displayLabel: canonicalKey,
    aliases: ['Nome ' + canonicalKey], version: 'v1'}));
  const raw = JSON.stringify(identities), version = 'CATALOG_A';
  const manifest = {schemaVersion: 2, status: 'ACTIVE', contentVersion: version, ownerCount: ids.length,
    chunks: [{collection: 'clinical_identity_registry', id: 'identities.0', count: ids.length, sha256: digest(raw)}],
    owners: ids.map(ownerId => ({ownerId, availableModes: {study: {pt: true, es: true}, plantao: {pt: true, es: true}}, referenceState: {}}))};
  const documents = new Map([['app_config/clinical_content', {schemaVersion: 2, status: 'ACTIVE', activeVersion: version, manifestSha256: hash(manifest)}],
    ['clinical_content_versions/' + version, manifest], ['clinical_content_versions/' + version + '/chunks/identities.0', {json: raw}]]);
  const guides = [{status: 'draft', isPublished: false}, {status: 'published', isPublished: true}, {status: 'pending_review'}];
  const db = {doc: path => ({get: async () => ({data: () => documents.get(path)})}),
    collection: path => {assert.equal(path, 'clinical_guides'); return {select: () => ({get: async () => ({docs: guides.map(x => ({data: () => x}))})})};}};
  return {db, documents, manifest, identities, hash, version};
}

test('uses current active owners, not the stale legacy inventory count', async () => {
  const f = await fixture();
  const r = await readActivePathologyInventory(f.db, {limit: 100}, {counts: {total: 517}});
  assert.equal(r.meta.counts.total, 2);
  assert.equal(r.meta.counts.published, 2);
  assert.equal(r.meta.counts.guidesDraft, 1);
  assert.equal(r.meta.counts.guidesPublished, 1);
  assert.equal(r.meta.counts.guidesOther, 1);
  assert.ok(r.rows.every(x => x.status === 'PUBLISHED'));
});
test('future owners are included without a compiled owner allowlist', async () => {
  const f = await fixture(['owner_a', 'new_future_owner']);
  const r = await readActivePathologyInventory(f.db, {search: 'new future', limit: 30});
  assert.equal(r.rows.length, 1);
  assert.equal(r.rows[0].canonicalId, 'new_future_owner');
  assert.equal(r.meta.counts.total, 2);
});
test('aliases are searchable but do not increase the number of owners', async () => {
  const f = await fixture();
  const r = await readActivePathologyInventory(f.db, {search: 'nome owner a'});
  assert.equal(r.rows.length, 1);
  assert.equal(r.meta.counts.total, 2);
  assert.equal(r.rows[0].aliases, undefined);
});
test('pagination and owner details use the same active generation', async () => {
  const f = await fixture(['owner_a', 'owner_b', 'owner_c']);
  const a = await readActivePathologyInventory(f.db, {limit: 1});
  const b = await readActivePathologyInventory(f.db, {limit: 1, cursor: a.nextCursor, generation: a.generation});
  assert.notEqual(a.rows[0].canonicalId, b.rows[0].canonicalId);
  const detail = await readActivePathologyInventory(f.db, {action: 'detail', recordId: b.rows[0].recordId, generation: b.generation});
  assert.equal(detail.row.canonicalId, b.rows[0].canonicalId);
  await assert.rejects(readActivePathologyInventory(f.db, {generation: 'a'.repeat(40)}), /INVENTORY_VERSION_CHANGED/);
});
test('does not present a draft or unavailable catalog as published', async () => {
  const f = await fixture();
  f.documents.get('app_config/clinical_content').status = 'DRAFT';
  await assert.rejects(loadActivePathologies(f.db), /ACTIVE_CATALOG_UNAVAILABLE/);
});
test('fails closed on identity hash corruption', async () => {
  const f = await fixture();
  f.documents.get('clinical_content_versions/CATALOG_A/chunks/identities.0').json += ' ';
  await assert.rejects(loadActivePathologies(f.db), /ACTIVE_CATALOG_IDENTITY_HASH_MISMATCH/);
});
test('rejects a disabled owner even when included in a signed manifest', async () => {
  const f = await fixture();
  f.identities[0].enabled = false;
  const raw = JSON.stringify(f.identities);
  f.documents.set('clinical_content_versions/CATALOG_A/chunks/identities.0', {json: raw});
  f.manifest.chunks[0].sha256 = digest(raw);
  f.documents.get('app_config/clinical_content').manifestSha256 = f.hash(f.manifest);
  await assert.rejects(loadActivePathologies(f.db), /ACTIVE_CATALOG_OWNER_MISMATCH/);
});
