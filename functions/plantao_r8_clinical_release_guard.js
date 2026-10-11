'use strict';

// Clinical review is independent of the account/cohort flag. Only this
// server-owned registry can supply a contract; never accept one from a request.
const registry = require('./plantao_r8_clinical_release_registry.json');
const {hash, validateRecord} = require('./plantao_clinical_snapshot');
const approvedContracts = new WeakSet();
const approvedPayloads = new WeakMap();
const SHA256 = /^[a-f0-9]{64}$/;
const fail = code => { throw Error('clinical_release_' + code); };

// Presence is not approval. Read every identity, including disabled/blocked
// owners, so missing output approvals never turn into a web bypass.
async function readCatalogIdentities(firestore) {
  const pointerPath = 'app_config/clinical_content';
  const pointer = await firestore.doc(pointerPath).get();
  const p = pointer.exists && pointer.data();
  if (!p || p.status !== 'ACTIVE' || p.schemaVersion !== 2 || !SHA256.test(p.manifestSha256 || ''))
    fail('catalog_unavailable');
  const root = 'clinical_content_versions/' + p.activeVersion;
  const doc = await firestore.doc(root).get();
  const manifest = doc.exists && doc.data();
  if (!manifest || manifest.status !== 'ACTIVE' || manifest.contentVersion !== p.activeVersion ||
      hash(manifest) !== p.manifestSha256) fail('manifest_integrity');
  const descriptors = manifest.chunks?.filter(c => c.collection === 'clinical_identity_registry');
  if (!descriptors?.length || new Set(descriptors.map(c => c.id)).size !== descriptors.length)
    fail('catalog_unavailable');
  const identities = [];
  for (const descriptor of descriptors) {
    const chunk = await firestore.doc(root + '/chunks/' + descriptor.id).get();
    const raw = chunk.exists && chunk.data().json;
    if (typeof raw !== 'string' || require('node:crypto').createHash('sha256').update(raw).digest('hex') !== descriptor.sha256)
      fail('chunk_integrity');
    const rows = JSON.parse(raw);
    if (!Array.isArray(rows) || rows.length !== descriptor.count || rows.some(r =>
      typeof r.canonicalKey !== 'string' || !Array.isArray(r.aliases) ||
      r.aliases.some(a => typeof a !== 'string'))) fail('catalog_unavailable');
    identities.push(...rows);
  }
  if (!identities.length || new Set(identities.map(r => r.canonicalKey)).size !== identities.length)
    fail('catalog_unavailable');
  const latest = await firestore.doc(pointerPath).get();
  if (!latest.exists || latest.data().status !== 'ACTIVE' || latest.data().activeVersion !== p.activeVersion ||
      latest.data().manifestSha256 !== p.manifestSha256) fail('source_version_changed');
  return {identities, activeVersion:p.activeVersion, manifestSha256:p.manifestSha256};
}

// Reading an unchanged, historically approved protocol is not generation.
// Only exact topic lookups qualify. Patient qualifiers, drug adjustments and
// ambiguous IAM must keep their own route/approval; never strip those qualifiers.
function sourceLookup(query) {
  const fold = s => String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'')
    .toLowerCase().trim().replace(/\s+/g,' ');
  const q = fold(query);
  return (registry.approvedSources || []).filter(s => s.aliases.some(alias =>
    [fold(alias), 'protocolo de '+fold(alias), 'protocolo completo de '+fold(alias)].includes(q)));
}

async function resolveApprovedProtocol({firestore, query, language}) {
  const candidates = sourceLookup(query);
  if (candidates.length !== 1 || !['pt','es'].includes(language)) return null;
  const source = candidates[0];
  if (!source.review?.recordId || !source.review.reviewerId || !source.review.reviewedAt ||
      !SHA256.test(source.review.evidenceSha256) || !SHA256.test(source.payloadSha256)) fail('source_not_reviewed');
  const pointerPath = 'app_config/clinical_content';
  const pointer = await firestore.doc(pointerPath).get();
  const p = pointer.exists && pointer.data();
  if (!p || p.status !== 'ACTIVE' || p.activeVersion !== source.activeVersion || p.schemaVersion !== 2) fail('source_version_changed');
  const root = 'clinical_content_versions/'+source.activeVersion;
  const manifestDoc = await firestore.doc(root).get();
  const manifest = manifestDoc.exists && manifestDoc.data();
  if (!manifest || manifest.status !== 'ACTIVE' || manifest.contentVersion !== p.activeVersion) fail('source_version_changed');
  // The active pointer binds the complete published document (same contract as
  // ClinicalCatalogValidator); the manifest's embedded authoring hash has a
  // different scope and must not be confused with the pointer hash.
  if (hash(manifest) !== p.manifestSha256) fail('manifest_integrity');
  const descriptors = manifest.chunks.filter(c => c.collection === 'clinical_projection_registry' && c.id === source.chunkId);
  if (descriptors.length !== 1) fail('source_missing');
  const doc = await firestore.doc(root+'/chunks/'+source.chunkId).get();
  const raw = doc.exists && doc.data().json;
  const sha = text => require('node:crypto').createHash('sha256').update(text).digest('hex');
  if (typeof raw !== 'string' || sha(raw) !== descriptors[0].sha256) fail('chunk_integrity');
  const rows = JSON.parse(raw).filter(r => (r.contentKey || r.id) === source.sourceKey);
  if (rows.length !== 1) fail('source_ambiguous');
  const row = rows[0], payload = row.payload?.approvedClinicalPayloadJson;
  if (row.enabled !== true || row.canonicalPathologyKey !== source.owner || row.version !== source.version ||
      typeof payload !== 'string' || sha(payload) !== source.payloadSha256 ||
      row.approvedClinicalPayloadSha256 !== source.payloadSha256 ||
      row.payload.approvedClinicalPayloadSha256 !== source.payloadSha256) fail('source_integrity');
  const content = JSON.parse(payload);
  if ((content.owner || content.ownerId || content.ownerCandidate) !== source.owner || content.version !== source.version) fail('source_scope');
  const approvedProjections = {}, projectionSha256 = {};
  for (const lang of ['pt','es']) {
    const projection=row.payload[lang]?.plantaoProjection;
    const structured=projection?.format==='structured' && source.projectionFormat==='structured';
    if(structured && (typeof projection.title!=='string' || projection.sections?.length!==1 ||
        projection.sections[0].type!=='paragraph' || typeof projection.sections[0].text!=='string')) fail('source_projection_changed');
    // Existing published lossless adapter: title + single unchanged body.
    const text=structured ? '# '+projection.title+'\n\n'+projection.sections[0].text : projection?.markdown;
    if (typeof text !== 'string' || !text.trim() || (!structured && text !== row.payload[lang]?.plantaoMarkdown))
      fail('source_projection_changed');
    // Authoring schemas may keep the reviewed projection separately from facts.
    // Both languages must match their exact historical projection approval.
    const embedded = content[lang]?.plantao;
    if (typeof embedded === 'string' ? embedded !== text :
        !SHA256.test(source.projectionSha256?.[lang] || '') || sha(text) !== source.projectionSha256[lang])
      fail('source_projection_changed');
    approvedProjections[lang] = text;
    projectionSha256[lang] = sha(text);
  }
  const current = await firestore.doc(pointerPath).get();
  if (!current.exists || current.data().activeVersion !== p.activeVersion ||
      current.data().manifestSha256 !== p.manifestSha256 || current.data().status !== 'ACTIVE') fail('source_version_changed');
  return {owner:source.owner,version:source.version,activeVersion:p.activeVersion,
    payloadSha256:source.payloadSha256,approvedClinicalPayloadJson:payload,
    review:source.review,approvedProjections,projectionSha256,scope:'UNCHANGED_GENERAL_PROTOCOL_NOT_INDIVIDUAL_PRESCRIPTION'};
}

function requestBinding({query, internalContext, history = []}) {
  // Exact context/history isolation, not semantic similarity or a response cache.
  return hash({query, internalContext, history});
}

function checkedContract(candidate, binding, activeVersion) {
  if (!candidate || candidate.status !== 'REVIEWED' ||
      !candidate.review?.recordId || !candidate.review?.reviewerId ||
      !candidate.review?.reviewedAt) fail('not_reviewed');
  if (candidate.activeVersion !== activeVersion ||
      !candidate.requestBindings?.includes(binding)) fail('scope_mismatch');
  if (!Array.isArray(candidate.sourceBindings) || !candidate.sourceBindings.length ||
      candidate.sourceBindings.some(s => !s.owner || !s.version ||
        !SHA256.test(s.payloadSha256) || s.status !== 'REVIEWED')) fail('source_not_reviewed');
  if (!Array.isArray(candidate.records) || !candidate.records.length ||
      hash(candidate.records) !== candidate.review.recordsSha256) fail('review_hash_mismatch');
  // Review binds the entire bilingual record, including the template, labels,
  // qualifiers and all shared quantities. A model-supplied concept ID alone
  // cannot prove that a contraindication was displayed.
  const records = candidate.records.map(r => validateRecord(r, candidate.sources || []));
  if (records[0].type !== 'title' || !records.some(r => r.type === 'section')) fail('invalid_records');
  const ids = new Set();
  records.forEach((r, i) => {
    if ((i === 0) !== (r.type === 'title') || ids.has(r.id) ||
        (r.type === 'references' && i !== records.length - 1)) fail('invalid_records');
    if (r.id) ids.add(r.id);
  });
  const contract = Object.freeze({recordHashes: Object.freeze(records.map(hash)),
    sourcesHash: hash(candidate.sources || []), binding, activeVersion,
    approvalStates: approvalStates(candidate, binding, activeVersion)});
  approvedContracts.add(contract);
  approvedPayloads.set(contract, JSON.stringify({records, sources:candidate.sources || [],
    recordsSha256:hash(records)}));
  return contract;
}

// Diagnostic states are independent evidence, never authorization tokens. In
// particular, UI review and a source review cannot authorize a generated output.
function approvalStates(candidate, binding, activeVersion) {
  const scoped = Boolean(candidate && candidate.activeVersion === activeVersion &&
    candidate.requestBindings?.includes(binding));
  const sources = Boolean(scoped && candidate.sourceBindings?.length &&
    candidate.sourceBindings.every(s => s.owner && s.version &&
      SHA256.test(s.payloadSha256) && s.status === 'REVIEWED'));
  let validated = false;
  try {
    const records = candidate?.records;
    if (Array.isArray(records) && records.length && records[0].type === 'title' &&
        records.some(r => r.type === 'section')) {
      const ids = new Set();
      for (const [i, record] of records.entries()) {
        validateRecord(record, candidate.sources || []);
        if ((i === 0) !== (record.type === 'title') || ids.has(record.id) ||
            (record.type === 'references' && i !== records.length - 1)) throw Error('order');
        if (record.id) ids.add(record.id);
      }
      validated = true;
    }
  } catch (_) { /* no raw record or clinical content in diagnostics */ }
  const boundReview = record => Boolean(record?.recordId && record?.reviewerId &&
    record?.reviewedAt && candidate?.records &&
    record.recordsSha256 === hash(candidate.records));
  const clinical = Boolean(scoped && candidate.status === 'REVIEWED' &&
    boundReview(candidate.review));
  const physical = Boolean(scoped && candidate.physicalUx?.status === 'VALIDATED' &&
    candidate.physicalUx.buildId && boundReview(candidate.physicalUx));
  const release = Boolean(sources && validated && clinical && physical &&
    candidate.release?.status === 'APPROVED' && boundReview(candidate.release));
  return Object.freeze({SOURCE_APPROVED:sources,
    OUTPUT_CONTRACT_VALIDATED:validated, OUTPUT_CLINICALLY_APPROVED:clinical,
    PHYSICAL_UX_VALIDATED:physical, RELEASE_APPROVED:release});
}

async function resolveClinicalApproval({firestore, query, internalContext, history}) {
  const binding = requestBinding({query, internalContext, history});
  const scoped = registry.contracts.filter(c => c.requestBindings?.includes(binding));
  // Empty registry is deliberate: draft findings are not clinical approvals.
  if (registry.schemaVersion !== 1 || !scoped.length) fail('approval_required');
  const pointer = await firestore.doc('app_config/clinical_content').get();
  if (!pointer.exists) fail('version_unavailable');
  const activeVersion = pointer.data().activeVersion;
  const current = scoped.filter(c => c.activeVersion === activeVersion);
  if (!current.length) fail('scope_mismatch');
  // Historical, draft or explicitly revoked rows cannot veto a different,
  // individually reviewed current contract. Multiple reviewed rows remain
  // ambiguous; never pick one by registry order or bypass a malformed review.
  const candidates = current.filter(c => c.status === 'REVIEWED');
  if (candidates.length !== 1) fail('approval_required');
  return checkedContract(candidates[0], binding, activeVersion);
}

function assertClinicalApproval(contract, request) {
  if (!approvedContracts.has(contract)) fail('approval_required');
  if (contract.binding !== requestBinding(request)) fail('scope_mismatch');
}

function approvedPayload(contract, request) {
  assertClinicalApproval(contract, request);
  // A fresh copy of exact reviewed records, never a shared patient response cache.
  return JSON.parse(approvedPayloads.get(contract));
}

function createReleaseValidation(contract, request, sources) {
  assertClinicalApproval(contract, request);
  if (contract.sourcesHash !== hash(sources)) fail('evidence_changed');
  let cursor = 0;
  return {
    validateRecord(record) {
      if (cursor >= contract.recordHashes.length ||
          hash(record) !== contract.recordHashes[cursor]) fail('record_not_reviewed');
      cursor++;
    },
    complete() {
      if (cursor !== contract.recordHashes.length) fail('missing_required_record');
    },
  };
}

module.exports = {readCatalogIdentities, sourceLookup, resolveApprovedProtocol, approvedPayload, approvalStates, requestBinding, resolveClinicalApproval, assertClinicalApproval, createReleaseValidation};
