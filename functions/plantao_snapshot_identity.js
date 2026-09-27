'use strict';
const {hash, VERSION} = require('./plantao_clinical_snapshot');

const IDENTITY_VERSION = 'plantao_request_identity_v1';
const POLICY_VERSION = 'general_reference_personalized_context_1709_v1';
const MODEL_CONTRACT_VERSION = 'nano_router_luna_primary_gemini_technical_v1';

function normalize(text) {
  return String(text || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/\s+/g, ' ').trim();
}
const TOPICS = [
  [/\bencefalopatia hepatica\b/g, 'hepatic_encephalopathy'],
  [/\bmetformina\b/g, 'metformin'],
  [/\binfarto agudo (?:de|do) miocardio\b|\biam\b/g, 'acute_myocardial_infarction'],
  [/\bhiper(?:c|k)alemia\b|\bhiperpotasemia\b/g, 'hyperkalemia'],
  [/\b(?:sepsis|sepse)\b/g, 'sepsis'],
];

// A conservative semantic normalizer. Only a fully recognized, general query
// is collapsed to a shared frame. Unknown qualifiers, negations and patient
// values remain verbatim dependencies; similarity never authorizes cache reuse.
function semanticQuery(query) {
  let remaining = normalize(query);
  const topics = [];
  for (const [pattern, id] of TOPICS) {
    remaining = remaining.replace(pattern, () => { topics.push(id); return ' '; });
  }
  const intents = [];
  for (const [pattern, id] of [
    [/\b(?:tratamento|tratamiento)\b/g, 'treatment'],
    [/\b(?:dose|doses|dosis)\b/g, 'reference_doses'],
    [/\b(?:indicacoes|indicaciones)\b/g, 'indications'],
    [/\b(?:mecanismo de (?:acao|accion)|mecanismo da)\b/g, 'mechanism'],
  ]) remaining = remaining.replace(pattern, () => { intents.push(id); return ' '; });
  remaining = remaining.replace(/\b(?:e|y)\b/g, ' ').replace(/[:;,?.]/g, '').trim();
  if (topics.length === 1 && !remaining) {
    return {version: IDENTITY_VERSION, topic: topics[0], intents: [...new Set(intents)].sort(), scope: 'general'};
  }
  return {version: IDENTITY_VERSION, opaqueQuery: String(query || '').normalize('NFC').trim()};
}

function freshnessRequested(query) {
  return /\b(?:20[2-9]\d|latest|updated|current|atual\w*|actual\w*|recente\w*|reciente\w*|vigente\w*|ultim\w*)\b/.test(normalize(query));
}

function requestIdentity({uid, query, internalContext = '', history = [], clinicalContext = {},
  knowledgeVersion, policyVersion = POLICY_VERSION, modelContractVersion = MODEL_CONTRACT_VERSION,
  grounding = [], freshnessNonce}) {
  const refresh = freshnessRequested(query);
  if (refresh && !freshnessNonce) throw Error('snapshot_freshness_nonce_required');
  return {
    uid,
    requestFrame: {query: semanticQuery(query), mode: 'plantao', ...(refresh ? {freshnessNonce} : {})},
    // Do not discard a caller's unstructured clinical guidance to increase hit
    // rate. Unknown/localized guidance misses safely instead of reusing facts
    // under a different patient or guideline context.
    context: {clinicalContext, internalContextHash: hash(internalContext)},
    history: history.map(turn => ({role: turn.role, content: String(turn.content || turn.text || '')})),
    knowledgeVersion,
    grounding,
    policyVersion,
    modelContractVersion: modelContractVersion + ':' + VERSION,
  };
}

module.exports = {semanticQuery, freshnessRequested, requestIdentity, IDENTITY_VERSION, POLICY_VERSION, MODEL_CONTRACT_VERSION};
