'use strict';

const {createHash} = require('node:crypto');
const hash = value => createHash('sha256').update(value, 'utf8').digest('hex');
const text = {type: 'string'};
const list = items => ({type: 'array', items});
const object = properties => ({type: 'object', properties,
  required: Object.keys(properties), additionalProperties: false});
const section = object({title: text, body: text});
const nullable = {anyOf: [{type: 'string'}, {type: 'null'}]};

// Independent versions allow a prompt/schema change without invalidating other types.
const CONTRACTS = Object.freeze({
  SUMMARY: {version: 'summary_prompt_v3', schema: object({title: text, sections: list(section)}),
    direct: 'Summarize all substantive topics. Preserve diagnoses, medications, doses, allergies, negations and relevant times. Match detail to source breadth; never pad to a word target.',
    map: 'Summarize this source section with all substantive facts and explicit uncertainty.',
    reduce: 'Merge the section summaries into a complete topical summary. Remove repetition without losing distinct facts.'},
  ANAMNESIS: {version: 'anamnesis_prompt_v3', schema: object(Object.fromEntries([
    'chiefComplaint', 'historyOfPresentIllness', 'pastMedicalHistory', 'medications',
    'allergies', 'familyHistory', 'socialHistory', 'reviewOfSystems', 'otherRelevantInformation',
  ].map(k => [k, nullable]))),
    direct: 'Extract only explicitly stated history into the specified fields. Use null for absent information. Absence of a symptom report is not a denial.',
    map: 'Extract explicitly stated history and preserve speaker attribution, negations and temporal context. Use null for absent fields.',
    reduce: 'Merge history fields without converting missing values into negatives. Preserve disagreements and their source times; do not choose an unsupported interpretation.'},
  EVOLUTION: {version: 'evolution_prompt_v3', schema: object({entries: list(object({time: nullable, findings: nullable, actions: nullable}))}),
    direct: 'Organize the documented evolution chronologically. Separate findings from actions. Do not add a clinical plan.',
    map: 'Extract chronological findings and actions, keeping exact stated times and doses.',
    reduce: 'Merge chronological entries. Keep source order where times are unknown. Do not turn an observation time into a scheduled appointment.'},
  ORGANIZATION: {version: 'organization_prompt_v3', schema: object({sections: list(section)}),
    direct: 'Improve readability of the entire text without summarizing away semantic information. Preserve all distinct assertions and their attribution.',
    map: 'Organize this section without shortening away any semantic information.',
    reduce: 'Concatenate organized sections in source order. Only remove exact duplication, never compress distinct assertions.'},
  VISUAL_SUMMARY: {version: 'visual_summary_prompt_v3', schema: object({title: text, overview: text,
    sections: list(section), keyPoints: list(text), takeaway: text}),
    direct: 'Create a visual summary using the schema. Every clinical assertion must be in the source; do not infer absence of severity or add recommendations.',
    map: 'Extract source concepts into visual sections, preserving explicit negations and uncertainty.',
    reduce: 'Merge visual sections and key points by topic, retaining distinct facts. Do not infer clinical conclusions.'},
  KEY_POINTS: {version: 'key_points_prompt_v3', schema: object({points: list(text)}),
    direct: 'Extract the most important source-supported points. Preserve important numbers, medication doses, allergies and negations. Avoid duplicate points.',
    map: 'Extract candidate key points including important numbers and explicit negatives.',
    reduce: 'Deduplicate and rank candidate points. Retain important unique facts, doses, allergies and negations.'},
  ORAL_EXAM: {version: 'oral_exam_prompt_v3', schema: object({questions: list(object({question: text,
    expectedAnswer: text, keyPoints: list(text), difficulty: {type: 'string', enum: ['easy', 'medium', 'hard']}, sourceSection: text}))}),
    direct: 'Create questions answerable solely from the source. Include supported expected answers, key points, difficulty and a source-section reference. No outside medical knowledge.',
    map: 'Create candidate questions and answers grounded only in this section. Preserve source references.',
    reduce: 'Deduplicate and balance questions across source sections. Reject unsupported answers; retain valid source references.'},
});

class DerivativeError extends Error {
  constructor(code, retryable = false, metadata = {}) {
    super(code); this.code = code; this.retryable = retryable; this.metadata = metadata;
  }
}

function validateSchema(value, schema) {
  if (schema.anyOf) return schema.anyOf.some(s => validateSchema(value, s));
  const types = [].concat(schema.type);
  const type = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value;
  if (!types.includes(type)) return false;
  if (schema.enum && !schema.enum.includes(value)) return false;
  if (type === 'array') return value.every(v => validateSchema(v, schema.items));
  if (type === 'object') return schema.required.every(k => Object.hasOwn(value, k)) &&
    Object.keys(value).every(k => Object.hasOwn(schema.properties, k) && validateSchema(value[k], schema.properties[k]));
  return true;
}

function validateInput(input) {
  const contract = CONTRACTS[input?.derivativeType];
  if (!contract || input.promptVersion !== contract.version || !['pt', 'es'].includes(input.locale) ||
      !['sourceId', 'operationId', 'ownerUid'].every(k => typeof input[k] === 'string' && input[k].length > 0 && input[k].length <= 256) ||
      typeof input.rawTranscript !== 'string' || !input.rawTranscript.trim() || input.rawTranscript.includes('\0') ||
      !input.rawTranscript.isWellFormed() || hash(input.rawTranscript) !== input.transcriptHash) {
    throw new DerivativeError('invalid_input');
  }
  return contract;
}

function isCompleteResult(type, value) {
  if (!CONTRACTS[type] || !validateSchema(value, CONTRACTS[type].schema)) return false;
  const meaningful = v => typeof v === 'string' && v.trim().length > 0;
  switch (type) {
    case 'SUMMARY': return meaningful(value.title) && value.sections.some(s => meaningful(s.body));
    case 'ORGANIZATION': return value.sections.some(s => meaningful(s.body));
    case 'VISUAL_SUMMARY': return meaningful(value.title) &&
      (meaningful(value.overview) || value.sections.some(s => meaningful(s.body)));
    case 'KEY_POINTS': return value.points.length > 0 && value.points.every(meaningful);
    case 'ORAL_EXAM': return value.questions.length > 0 && value.questions.every(q =>
      meaningful(q.question) && meaningful(q.expectedAnswer) && meaningful(q.sourceSection) &&
      q.keyPoints.length > 0 && q.keyPoints.every(meaningful));
    case 'EVOLUTION': return value.entries.length > 0 &&
      value.entries.every(e => meaningful(e.findings) || meaningful(e.actions));
    // An educational source can truthfully contain no patient history.
    case 'ANAMNESIS': return Object.values(value).every(v => v === null || meaningful(v));
    default: return false;
  }
}

function identities(input) {
  validateInput(input);
  // Include owner and locale: cross-account and cross-language cache hits are forbidden.
  return {operationKey: hash(JSON.stringify([input.ownerUid, input.sourceId, input.derivativeType,
    input.operationId, input.promptVersion])), cacheKey: hash(JSON.stringify([input.ownerUid,
    input.transcriptHash, input.derivativeType, input.promptVersion, input.locale]))};
}

class TranscriptChunker {
  // UTF-8 bytes are a conservative token upper bound for supported byte-level tokenizers.
  // This deliberately does not mistake chars/4 for a guaranteed context limit.
  static split(sourceId, rawTranscript, maxEstimatedTokens = 12000) {
    if (!Number.isInteger(maxEstimatedTokens) || maxEstimatedTokens < 256) throw new DerivativeError('invalid_chunk_budget');
    const chunks = []; let start = 0;
    while (start < rawTranscript.length) {
      let end = start; let bytes = 0; let boundary = start;
      for (const cp of rawTranscript.slice(start)) {
        const size = Buffer.byteLength(cp);
        if (bytes + size > maxEstimatedTokens) break;
        bytes += size; end += cp.length;
        if (/\s/u.test(cp)) boundary = end;
      }
      if (end < rawTranscript.length && boundary > start + (end - start) / 2) end = boundary;
      const content = rawTranscript.slice(start, end);
      chunks.push({sourceId, chunkIndex: chunks.length, startOffset: start, endOffset: end,
        offsetUnit: 'utf16', estimatedTokens: Buffer.byteLength(content), hash: hash(content), content});
      start = end;
    }
    return chunks;
  }
}

module.exports = {CONTRACTS, DerivativeError, TranscriptChunker, hash, identities, validateInput, validateSchema, isCompleteResult};
