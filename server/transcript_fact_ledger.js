'use strict';
const {isDeepStrictEqual}=require('node:util');
const {hash, DerivativeError} = require('./derivative_contract');
const VERSION = 'evidence_spans_r1';
const FACT_TYPES = Object.freeze(['SYMPTOM','DIAGNOSIS_MENTION','MEDICATION','DOSE','ALLERGY',
  'NEGATION','PAST_HISTORY','PROCEDURE','DATE','TIME','ACTION','PLAN','EXAM_FINDING','OTHER_EXPLICIT_FACT']);
const freeze = value => { if (value && typeof value === 'object') { Object.values(value).forEach(freeze); Object.freeze(value); } return value; };

// A fact is an extractive evidence unit, not a model's inferred atomic proposition.
// Keep whole paragraphs: splitting a sentence can detach a negation, speaker,
// correction or unit. Untyped narrative remains OTHER_EXPLICIT_FACT.
function sourceSpans(raw) {
  const spans=[];let start=0;
  for (const match of raw.matchAll(/\n[\t ]*\n/g)) {
    const end=match.index+match[0].length;
    spans.push({start,end});start=end;
  }
  if(start<raw.length) spans.push({start,end:raw.length});
  return spans;
}
function explicitMetadata(value) {
  // No inherited speaker/time across facts. Only literal leading metadata.
  const speaker=value.match(/^\s*(?:Falante|Hablante|Speaker)\s+([^:\n]{1,80}):/iu)?.[0].trim() ?? null;
  const timestamp=value.match(/^\s*\[(\d{1,2}:\d{2}(?::\d{2})?)\](?=\s)/u);
  const timeMentions=[...value.matchAll(/\b\d{1,2}:\d{2}(?::\d{2})?\b/gu)];
  return {speaker,timestampIfExplicit:timestamp && timeMentions.length===1 ? timestamp[1] : null};
}
function factFor(raw,span,transcriptHash) {
  const value=raw.slice(span.start,span.end);const metadata=explicitMetadata(value);
  return {factId:hash(JSON.stringify([VERSION,transcriptHash,span.start,span.end])),
    factType:'OTHER_EXPLICIT_FACT',value,sourceStartOffset:span.start,sourceEndOffset:span.end,
    sourceQuoteHash:hash(value),...metadata,confidence:1,confidenceMeaning:'EXACT_SPAN_NOT_CLINICAL_CERTAINTY'};
}
class TranscriptFactLedger {
  static extract(rawTranscript) {
    if(typeof rawTranscript!=='string'||!rawTranscript.trim()||!rawTranscript.isWellFormed()||rawTranscript.includes('\0')) throw new DerivativeError('invalid_input');
    const transcriptHash=hash(rawTranscript);
    const facts=sourceSpans(rawTranscript).map(s=>factFor(rawTranscript,s,transcriptHash));
    const payload={version:VERSION,offsetUnit:'utf16',transcriptHash,facts};
    return freeze({...payload,ledgerHash:hash(JSON.stringify(payload))});
  }
  static validateFact(raw,fact) {
    if(!fact||!FACT_TYPES.includes(fact.factType)||!Number.isInteger(fact.sourceStartOffset)||
      !Number.isInteger(fact.sourceEndOffset)||fact.sourceStartOffset<0||fact.sourceEndOffset>raw.length||
      fact.sourceEndOffset<=fact.sourceStartOffset) return false;
    const expected=factFor(raw,{start:fact.sourceStartOffset,end:fact.sourceEndOffset},hash(raw));
    // Exact value validation is intentionally stricter than matching a medication
    // or dose somewhere in the quote: substring checks can lose negation.
    return fact.value===expected.value && fact.sourceQuoteHash===expected.sourceQuoteHash &&
      fact.factId===expected.factId && fact.speaker===expected.speaker &&
      fact.timestampIfExplicit===expected.timestampIfExplicit && fact.confidence===1 &&
      fact.confidenceMeaning===expected.confidenceMeaning && fact.factType==='OTHER_EXPLICIT_FACT';
  }
  static validate(raw,ledger) {
    if(!ledger||ledger.version!==VERSION||ledger.offsetUnit!=='utf16'||ledger.transcriptHash!==hash(raw)||!Array.isArray(ledger.facts)) return false;
    const canonical=TranscriptFactLedger.extract(raw);
    // The independently re-extracted ledger prevents cherry-picked subspans,
    // overlaps, reordered facts, hidden deleted negations and forged metadata.
    return isDeepStrictEqual(ledger,canonical);
  }
}
module.exports={TranscriptFactLedger,FACT_TYPES,explicitMetadata};
