'use strict';
const crypto = require('node:crypto');

const VERSION = 'plantao_clinical_snapshot_v4';
const LANGUAGES = Object.freeze(['pt', 'es']);
const SECTION_LABELS = Object.freeze({
  immediate: {pt: 'Conduta imediata', es: 'Conducta inmediata'},
  indications: {pt: 'Indicações', es: 'Indicaciones'},
  treatment: {pt: 'Tratamento', es: 'Tratamiento'},
  reference_doses: {pt: 'Doses de referência', es: 'Dosis de referencia'},
  monitoring: {pt: 'Monitorização', es: 'Monitorización'},
  contraindications: {pt: 'Contraindicações importantes', es: 'Contraindicaciones importantes'},
  warning_signs: {pt: 'Sinais de alarme', es: 'Signos de alarma'},
  next_step: {pt: 'Próximo passo', es: 'Próximo paso'},
  explanation: {pt: 'Pontos essenciais', es: 'Puntos esenciales'},
});
const ACTIONS = new Set(['assess', 'treat', 'monitor', 'avoid', 'consider', 'explain', 'refer']);
const ID = /^[a-z][a-z0-9_]{0,79}$/;
// Clinical codes may carry a numeric grade or a threshold operator. They
// remain opaque, shared IDs; only template binding IDs use identifier syntax.
const CONCEPT_CODE = /^[a-z0-9][a-z0-9_≤≥<>=%.-]{0,99}$/;
function check(condition, code) { if (!condition) throw new Error('snapshot_' + code); }
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, stable(value[k])]));
  return value;
}
function hash(value) { return crypto.createHash('sha256').update(JSON.stringify(stable(value))).digest('hex'); }
function freeze(value) {
  if (value && typeof value === 'object') { Object.values(value).forEach(freeze); Object.freeze(value); }
  return value;
}
function language(code) { check(LANGUAGES.includes(code), 'unsupported_language'); return code; }
function keys(object, allowed) {
  check(object && typeof object === 'object' && !Array.isArray(object), 'object_required');
  check(Object.keys(object).every(k => allowed.includes(k)), 'unexpected_field');
  check(allowed.every(k => Object.hasOwn(object, k)), 'missing_field');
}
function localized(value) {
  keys(value, LANGUAGES);
  for (const lang of LANGUAGES) check(typeof value[lang] === 'string' && value[lang].trim().length > 0, 'missing_localization');
}
function placeholders(text) { return [...text.matchAll(/\{\{([a-z][a-z0-9_]*)\}\}/g)].map(m => m[1]).sort(); }

function lowerWireBindings(record) {
  if (record.type !== 'section' || !Array.isArray(record.facts)) return record;
  for (const fact of record.facts) {
    if (!Array.isArray(fact.slots)) continue;
    // Canonical slot order is the binding. Neither translation selects slots.
    if (!Object.hasOwn(fact,'template')) fact.template=fact.slots.map(s=>'{{'+s.id+'}}').join(' ');
    for(const slot of fact.slots) {
      if(slot.kind!=='quantity' || !Array.isArray(slot.value)) continue;
      let rendered='', previous=null;
      for(const token of slot.value) {
        keys(token,['kind','value']);
        check(['number','unit','operator'].includes(token.kind),'invalid_quantity_token');
        const units=['mg','mcg','g','kg','mL','L','mmol','mEq','mmHg','bpm','cm','m²','h','min','s','d','VO','IV','IM','SC','IO','UI'];
        check(token.kind==='number'?/^-?\d+(?:[.,]\d+)?$/.test(token.value):token.kind==='unit'?units.includes(token.value):['/','–','<','>','≤','≥','q','x','%','(',')','+'].includes(token.value),'invalid_quantity_token');
        const attached=['/','–','%','(',')','<','>','≤','≥'].includes(token.value) || ['q','/','–','(','<','>','≤','≥'].includes(previous);
        rendered+=(rendered && !attached?' ':'')+token.value;previous=token.value;
      }
      slot.value=rendered;
    }
  }
  return record;
}

// Bind quantities embedded in a paired label to shared child IDs. This is a
// lossless syntax lowering, not clinical interpretation or a translation repair.
// Divergent values, units, order or one-sided prose cannot be lowered.
function bindSharedLabelQuantities(record) {
  if (record.type !== 'section' || !Array.isArray(record.facts)) return record;
  const pattern = /[<>≤≥]=?\s*[-+]?\d+(?:[.,]\d+)?(?:\s*[–−-]\s*\d+(?:[.,]\d+)?)?(?:\s*(?:mL|ml|mg|mcg|kg|mmol|mEq|g|L|h|min|s|d)(?:\/(?:kg|min|h|d|m2|m²))*(?![A-Za-zÀ-ÿ]))?|[-+]?\d+(?:[.,]\d+)?(?:\s*[–−-]\s*\d+(?:[.,]\d+)?)?(?:\s*(?:mL|ml|mg|mcg|kg|mmol|mEq|g|L|h|min|s|d)(?:\/(?:kg|min|h|d|m2|m²))*(?![A-Za-zÀ-ÿ]))?/g;
  const normalized = v => v.replace(/,/g,'.').replace(/\s/g,'').replace(/ml/gi,'mL').replace(/[−–]/g,'-');
  for (const fact of record.facts) {
    if (typeof fact.template !== 'string' || !Array.isArray(fact.slots)) continue;
    const lowered = [];
    for (const slot of fact.slots) {
      if (slot.kind === 'quantity' || !slot.labels || !LANGUAGES.every(l=>typeof slot.labels[l]==='string') ||
          !/\d/.test(slot.labels.pt+slot.labels.es) || /(?:^|_)type_[12](?:_|$)|^vitamin_b12$/.test(slot.value)) {
        lowered.push(slot); continue;
      }
      const matches=Object.fromEntries(LANGUAGES.map(l=>[l,[...slot.labels[l].matchAll(pattern)]]));
      check(matches.pt.length>0 && matches.pt.length===matches.es.length,'paired_quantity_mismatch');
      check(matches.pt.every((m,i)=>normalized(m[0])===normalized(matches.es[i][0])),'paired_quantity_mismatch');
      let positions={pt:0,es:0}; const bindings=[];
      for(let i=0;i<=matches.pt.length;i++) {
        const labels=Object.fromEntries(LANGUAGES.map(l=>[l,slot.labels[l].slice(positions[l],i<matches[l].length?matches[l][i].index:undefined)]));
        if(labels.pt.trim() || labels.es.trim()) {
          check(labels.pt.trim() && labels.es.trim(),'paired_quantity_word_order');
          const id=slot.id+'_text_'+i;
          lowered.push({...slot,id,value:slot.value.slice(0,60)+'_part_'+i,labels});bindings.push('{{'+id+'}}');
        } else if(labels.pt || labels.es) {
          // Whitespace belongs to the common expression, not a clinical label.
          bindings.push(' ');
        }
        if(i<matches.pt.length) {
          const id=slot.id+'_quantity_'+i;
          lowered.push({id,kind:'quantity',value:matches.pt[i][0]});bindings.push('{{'+id+'}}');
          positions=Object.fromEntries(LANGUAGES.map(l=>[l,matches[l][i].index+matches[l][i][0].length]));
        }
      }
      const old='{{'+slot.id+'}}';
      check(fact.template.split(old).length===2,'canonical_binding_mismatch');
      fact.template=fact.template.replace(old,bindings.join(''));
    }
    fact.slots=lowered;
  }
  return record;
}

// No clinical fact, numeric quantity, section order or citation is selected here.
// A single frozen clinical record owns both localized presentations.
function validateRecord(input, knownSources = []) {
  const r = bindSharedLabelQuantities(lowerWireBindings(structuredClone(input)));
  if (r.type === 'title') {
    keys(r, ['type', 'id', 'labels']); check(ID.test(r.id), 'invalid_id'); localized(r.labels);
    check(JSON.stringify(r.labels.pt.match(/\d+(?:[.,]\d+)?/g)) ===
      JSON.stringify(r.labels.es.match(/\d+(?:[.,]\d+)?/g)), 'localized_title_value_changed');
  } else if (r.type === 'section') {
    keys(r, ['type', 'id', 'facts']);
    check(Object.hasOwn(SECTION_LABELS, r.id), 'unknown_section');
    check(Array.isArray(r.facts) && r.facts.length > 0 && r.facts.length <= 12, 'empty_or_oversized_section');
    const ids = new Set();
    for (const f of r.facts) {
      keys(f, ['id', 'action', 'polarity', 'conceptCodes', 'conditionCodes', 'slots', 'template']);
      check(ID.test(f.id) && !ids.has(f.id), 'duplicate_or_invalid_fact'); ids.add(f.id);
      check(ACTIONS.has(f.action) && ['affirmative', 'negative', 'conditional'].includes(f.polarity), 'invalid_action');
      check(Array.isArray(f.conceptCodes) && f.conceptCodes.length > 0 && f.conceptCodes.every(v => CONCEPT_CODE.test(v)), 'canonical_concepts_required');
      if (!Array.isArray(f.conditionCodes) || !f.conditionCodes.every(v => CONCEPT_CODE.test(v))) { const e=new Error('snapshot_canonical_conditions_required');e.diagnostic={array:Array.isArray(f.conditionCodes),invalid:(f.conditionCodes||[]).filter(v=>!CONCEPT_CODE.test(v)).map(v=>({type:typeof v,chars:String(v).length,invalidChars:[...new Set((String(v).match(/[^a-z0-9_]/g)||[]))].map(c=>c.charCodeAt(0))}))};throw e; }
      check(Array.isArray(f.slots), 'slots_required');
      const slotIds = new Set();
      for (const s of f.slots) {
        keys(s, s.kind === 'quantity' ? ['id', 'kind', 'value'] : ['id', 'kind', 'value', 'labels']);
        check(ID.test(s.id) && !slotIds.has(s.id), 'duplicate_slot'); slotIds.add(s.id);
        check(['clinical_concept', 'quantity', 'condition', 'relation'].includes(s.kind), 'invalid_slot_kind');
        // Numeric values/units/routes/frequency live only in the canonical record.
        check(typeof s.value === 'string' && s.value.length > 0 && s.value.length <= 500, 'invalid_slot_value');
        check(!/[\n{}]/.test(s.value), 'slot_structure_injection');
        if (s.kind === 'quantity') {
          const units = new Set(['mg','mcg','g','kg','ml','l','ui','iu','u','meq','mmol','mol','mosm','m','cm','mm','h','min','s','d','q','vo','po','iv','ev','im','sc','io','x','mmhg','bpm','µg','μg']);
          const unknown = (s.value.match(/[a-zµμ]+/gi) || []).filter(t => !units.has(t.toLowerCase()));
          // The schema also permits a shared unit/route slot beside a separate
          // numeric slot. Validate that syntax without inventing a missing value.
          // Clinical completeness and individualization remain safety concerns.
          const descriptorOnly = /^(?:mg|mcg|g|kg|mL|L|mmol|mEq|mmHg|bpm|cm|m²|h|min|s|d|VO|PO|IV|EV|IM|SC|IO|UI)(?:[ /]+(?:mg|mcg|g|kg|mL|L|mmol|mEq|mmHg|bpm|cm|m²|h|min|s|d|VO|PO|IV|EV|IM|SC|IO|UI))*$/.test(s.value);
          if ((!/\d/.test(s.value) && !descriptorOnly) || unknown.length) {
            const error = new Error('snapshot_quantity_must_be_language_neutral');
            const categories = {dia:'DAY_WORD',dias:'DAY_WORD',d:'DAY_WORD',a:'RANGE_WORD',cada:'INTERVAL_WORD',por:'PER_WORD',evacuaciones:'STOOL_COUNT_UNIT',deposiciones:'STOOL_COUNT_UNIT',dejecoes:'STOOL_COUNT_UNIT',oral:'ROUTE_WORD',veces:'TIMES_WORD',vezes:'TIMES_WORD',hora:'TIME_WORD',horas:'TIME_WORD',minuto:'TIME_WORD',minutos:'TIME_WORD'};
            error.diagnostic = {quantityHasNumber:/\d/.test(s.value), unknownTokens:unknown.map(t => categories[t.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase()] || 'OTHER_'+hash(t).slice(0,8)), valueChars:s.value.length};
            throw error;
          }
        } else {
          localized(s.labels);
          if (!CONCEPT_CODE.test(s.value)) {
            const error = new Error('snapshot_concept_code_required');
            error.diagnostic = {slotKind:s.kind, valueChars:s.value.length, hasWhitespace:/\s/.test(s.value), hasUppercase:/[A-Z]/.test(s.value), hasNonAscii:/[^\x00-\x7F]/.test(s.value), hasNumber:/\d/.test(s.value), startsWithNumber:/^\d/.test(s.value), invalidCodeChars:[...new Set((s.value.match(/[^a-z0-9_]/g)||[]))].map(c=>c.charCodeAt(0))};
            throw error;
          }
          check(!/[\n{}]/.test(s.labels.pt + s.labels.es), 'slot_structure_injection');
          const typeCode = s.value.match(/(?:^|_)type_([12])(?:_|$)/);
          const typeNumber = typeCode?.[1];
          const classifiedType = typeNumber && LANGUAGES.every(lang => {
            const numbers = s.labels[lang].match(/\d+/g) || [];
            return numbers.length === 1 && numbers[0] === typeNumber &&
              new RegExp('(?:tipo|type)\\s*' + typeNumber + '\\b','i').test(s.labels[lang]) &&
              !/[<>≤≥]/.test(s.labels[lang]);
          });
          if (s.kind === 'condition' && /\d/.test(s.labels.pt + s.labels.es) && !classifiedType) {
            const error = new Error('snapshot_condition_quantity_must_be_shared_slot');
            error.diagnostic = {typeClassification: /(?:type|tipo)[_ ]?[12]/i.test(s.value), vitaminCode:/b_?12/i.test(s.value), thresholdOperator:/[<>≤≥]/.test(s.labels.pt+s.labels.es), quantityUnits:/\d\s*(?:mg|ml|mmol|g|h)\b/i.test(s.labels.pt+s.labels.es), numericCount:(s.labels.pt.match(/\d+/g)||[]).length};
            throw error;
          }
          check(JSON.stringify(s.labels.pt.match(/\d+(?:[.,]\d+)?/g)) === JSON.stringify(s.labels.es.match(/\d+(?:[.,]\d+)?/g)), 'localized_condition_value_changed');
        }
      }
      // One ordered expression owns every binding. Locale selects a label by
      // canonical slot ID; it can no longer choose which clinical slots exist.
      check(typeof f.template === 'string', 'template_required');
      const expected = [...slotIds].sort();
      check(JSON.stringify(placeholders(f.template)) === JSON.stringify(expected), 'canonical_binding_mismatch');
      const punctuation = f.template.replace(/\{\{[a-z][a-z0-9_]*\}\}/g, '');
      if (!/^[\s.,;:()!?–—/\-*+=<>≤≥%×→]*$/.test(punctuation)) { const e=new Error('snapshot_template_must_be_language_neutral');e.diagnostic={proseLetters:(punctuation.match(/[a-z]/gi)||[]).length,numericCount:(punctuation.match(/\d/g)||[]).length,otherCodePoints:[...new Set((punctuation.match(/[^a-z\d\s.,;:()!?–—/\-*+=<>≤≥%×→]/gi)||[]))].map(c=>c.codePointAt(0))};throw e; }
      check(!/[\r\n]/.test(f.template), 'localization_structure_injection');
    }
  } else if (r.type === 'references') {
    keys(r, ['type', 'sourceIds']);
    check(Array.isArray(r.sourceIds) && new Set(r.sourceIds).size === r.sourceIds.length, 'invalid_references');
    const allowed = new Set(knownSources.map(s => s.id));
    check(r.sourceIds.every(id => allowed.has(id)), 'unprovided_reference');
  } else {
    throw new Error('snapshot_unknown_record');
  }
  return freeze(r);
}
function canonicalFacts(record) {
  if (record.type === 'title') return {type: record.type, id: record.id};
  if (record.type === 'references') return record;
  return {type: record.type, id: record.id, facts: record.facts.map(({slots, ...fact}) => ({...fact, slots: slots.map(({labels, ...slot}) => slot)}))};
}
function presentationOf(record) {
  if (record.type === 'title') return {labels: record.labels};
  if (record.type === 'references') return {};
  return {facts: record.facts.map(f => ({id:f.id,
    labels:Object.fromEntries(f.slots.filter(s => s.kind !== 'quantity').map(s => [s.id,s.labels]))}))};
}
function renderClinicalRecord(clinical, presentation, lang, knownSources = []) {
  language(lang);
  if (clinical.type === 'title') return '# ' + presentation.labels[lang] + '\n\n';
  if (clinical.type === 'references') {
    if (!clinical.sourceIds.length) return '';
    const refs = clinical.sourceIds.map(id => knownSources.find(s => s.id === id));
    check(refs.every(Boolean), 'missing_reference');
    return '## ' + (lang === 'pt' ? 'Referências' : 'Referencias') + '\n\n' + refs.map(s => `- [${s.title}](${s.url})`).join('\n') + '\n\n';
  }
  check(clinical.facts.length === presentation.facts.length, 'presentation_fact_count');
  return '## ' + SECTION_LABELS[clinical.id][lang] + '\n\n' + clinical.facts.map((f,index) => {
    const localized = presentation.facts[index];
    check(f.id === localized.id, 'presentation_fact_order');
    const values = Object.fromEntries(f.slots.map(s => [s.id, s.kind === 'quantity' ? s.value : localized.labels[s.id][lang]]));
    check(JSON.stringify(placeholders(f.template)) === JSON.stringify(Object.keys(values).sort()), 'presentation_slot_mismatch');
    return '- ' + f.template.replace(/\{\{([a-z][a-z0-9_]*)\}\}/g, (_, id) => values[id]);
  }).join('\n') + '\n\n';
}
function renderRecord(record, lang, knownSources = []) {
  const clinical = freeze(canonicalFacts(record));
  return renderClinicalRecord(clinical, presentationOf(record), lang, knownSources);
}
function renderSnapshot(snapshot, lang) {
  check(snapshot.clinical.length === snapshot.presentation.length, 'presentation_record_count');
  return snapshot.clinical.map((record,index) => renderClinicalRecord(record,snapshot.presentation[index],lang,snapshot.sources));
}

function validateSnapshot(snapshot) {
  check(snapshot?.version === VERSION, 'stored_version_mismatch');
  check(Array.isArray(snapshot.clinical) && snapshot.clinical.length > 1, 'incomplete_candidate');
  check(Array.isArray(snapshot.presentation) && snapshot.presentation.length === snapshot.clinical.length, 'presentation_record_count');
  check(Array.isArray(snapshot.sources), 'sources_required');
  check(snapshot.factsHash === hash(snapshot.clinical), 'stored_facts_hash_mismatch');
  const sections = new Set(); let referencesSeen = false;
  snapshot.clinical.forEach((record,index) => {
    const view = snapshot.presentation[index];
    check((index === 0) === (record.type === 'title'), 'title_order');
    check(!referencesSeen, 'references_must_be_last');
    let wire;
    if (record.type === 'title') wire = {...record,labels:view.labels};
    else if (record.type === 'references') {wire=record;referencesSeen=true;}
    else {
      check(!sections.has(record.id), 'duplicate_section'); sections.add(record.id);
      check(record.facts.length === view.facts.length, 'presentation_fact_count');
      wire={...record,facts:record.facts.map((fact,i) => {
        const localized=view.facts[i];check(fact.id === localized.id,'presentation_fact_order');
        return {...fact,slots:fact.slots.map(slot => slot.kind === 'quantity' ? slot : {...slot,labels:localized.labels[slot.id]})};
      })};
    }
    const validated=validateRecord(wire,snapshot.sources);
    check(hash(canonicalFacts(validated)) === hash(record),'stored_clinical_schema_mismatch');
  });
  check(sections.size > 0,'no_clinical_content');
  return freeze(structuredClone(snapshot));
}

class SnapshotDecoder {
  constructor({language: lang, sources = [], onBlock, framing = 'ndjson'}) {
    this.language = language(lang); this.sources = sources; this.onBlock = onBlock;
    this.framing = framing; this.envelopeState = 'header';
    this.buffer = ''; this.records = []; this.sectionIds = new Set(); this.finished = false;
  }
  accept(delta) {
    check(!this.finished, 'already_finished'); this.buffer += delta;
    check(this.buffer.length < 128000, 'record_too_large');
    // Providers may pretty-print JSON despite a NDJSON instruction. Frame by
    // balanced objects, respecting string escapes; never split clinical strings.
    for (;;) {
      this.buffer = this.buffer.trimStart();
      if (!this.buffer) return;
      if (this.framing === 'json') {
        if (this.envelopeState === 'header') {
          const header=this.buffer.match(/^\{\s*"records"\s*:\s*\[/);
          if (!header) {check(this.buffer.length<64,'invalid_envelope');return;}
          this.buffer=this.buffer.slice(header[0].length);this.envelopeState='record';continue;
        }
        if (this.envelopeState === 'separator') {
          if (this.buffer[0]===',') {this.buffer=this.buffer.slice(1);this.envelopeState='record';continue;}
          check(this.buffer[0]===']','invalid_envelope_separator');
          this.buffer=this.buffer.slice(1);this.envelopeState='closing';continue;
        }
        if (this.envelopeState === 'closing') {
          check(this.buffer[0]==='}','invalid_envelope_end');
          this.buffer=this.buffer.slice(1);this.envelopeState='closed';continue;
        }
        check(this.envelopeState !== 'closed','trailing_envelope_data');
      }
      if (this.buffer.startsWith('```')) {
        const newline = this.buffer.indexOf('\n');
        if (newline < 0) return;
        check(/^```(?:jsonl?|ndjson)?\s*$/.test(this.buffer.slice(0, newline)), 'invalid_fence');
        this.buffer = this.buffer.slice(newline + 1); continue;
      }
      if ('```'.startsWith(this.buffer)) return;
      check(this.buffer[0] === '{', 'non_json_record');
      let depth = 0, quoted = false, escaped = false, end = -1;
      for (let i = 0; i < this.buffer.length; i++) {
        const c = this.buffer[i];
        if (quoted) {
          if (escaped) escaped = false;
          else if (c === '\\') escaped = true;
          else if (c === '"') quoted = false;
        } else if (c === '"') quoted = true;
        else if (c === '{') depth++;
        else if (c === '}' && --depth === 0) { end = i + 1; break; }
      }
      if (end < 0) return;
      let value;
      try { value = JSON.parse(this.buffer.slice(0, end)); }
      catch (_) { throw new Error('snapshot_invalid_record_json'); }
      this.buffer = this.buffer.slice(end); this.add(value);
      if (this.framing === 'json') this.envelopeState='separator';
    }
  }
  add(raw) {
    const r = validateRecord(raw, this.sources);
    check((this.records.length === 0) === (r.type === 'title'), 'title_order');
    if (r.type === 'section') { check(!this.sectionIds.has(r.id), 'duplicate_section'); this.sectionIds.add(r.id); }
    check(!this.records.some(v => v.type === 'references'), 'references_must_be_last');
    this.records.push(r);
    this.onBlock(renderRecord(r, this.language, this.sources), {recordIndex: this.records.length - 1, factsHash: hash(canonicalFacts(r))});
  }
  complete() {
    check(!this.finished, 'already_finished');
    if (this.framing === 'json') check(this.envelopeState === 'closed','incomplete_envelope');
    if (this.buffer.trim() === '```') this.buffer = '';
    check(this.buffer.trim().length === 0, 'incomplete_record');
    check(this.sectionIds.size > 0, 'no_clinical_content'); this.buffer = ''; this.finished = true;
    const clinical = this.records.map(canonicalFacts);
    return freeze({version: VERSION, clinical, presentation:this.records.map(presentationOf), sources: structuredClone(this.sources), factsHash: hash(clinical)});
  }
}

// An explicit semantic frame is an input contract, never an authorization gate.
// Callers must include every context/history/knowledge dependency. Locale is
// intentionally absent; a locale switch does not create a new clinical answer.
function snapshotKey({uid, requestFrame, context, history, knowledgeVersion, grounding, policyVersion, modelContractVersion = VERSION}) {
  check(typeof uid === 'string' && uid.length > 0, 'uid_required');
  check(requestFrame && typeof requestFrame === 'object', 'request_frame_required');
  check(typeof knowledgeVersion === 'string' && knowledgeVersion.length > 0, 'knowledge_version_required');
  check(typeof policyVersion === 'string' && policyVersion.length > 0, 'policy_version_required');
  check(context !== undefined && history !== undefined && grounding !== undefined, 'context_dependencies_required');
  return hash({version: VERSION, uid, requestFrame, context, history, knowledgeVersion, grounding, policyVersion, modelContractVersion});
}

// In-flight coalescing only. Durability is supplied by the caller's UID-scoped
// store; this coordinator never uses an unscoped global answer cache.
class SnapshotCoordinator {
  constructor(store) { this.store = store; this.pending = new Map(); }
  async getOrCreate(context, create) {
    const key = snapshotKey(context);
    if (this.pending.has(key)) return this.pending.get(key);
    // The store holds an exclusive lease BEFORE generation/emission; a loser
    // must wait for the winning snapshot, never stream a conflicting candidate.
    const task = this.store.withLease(context.uid, key, async lease => {
      const existing = await this.store.get(context.uid, key);
      if (existing) return validateSnapshot(existing);
      const candidate = await create();
      const validated = validateSnapshot(candidate);
      await this.store.put(context.uid, key, validated, lease);
      return validated;
    }, context.signal);
    this.pending.set(key, task);
    try { return await task; } finally { this.pending.delete(key); }
  }
}

const GENERATION_CONTRACT = `Return one JSON object matching the supplied schema: {"records":[title, section, ...]}. Complete each record before the next, to permit progressive streaming. Never emit Markdown outside the JSON.
Construct ONE language-neutral clinical answer, then pair Portuguese and Spanish labels for exactly those SAME facts. Never generate two clinical answers.
First record is a title with one canonical topic ID and its PT/ES labels. Nonempty sections follow in clinical priority using the allowed canonical IDs. Every fact owns its action, polarity, conceptCodes, conditionCodes and an ORDERED array of slots. The renderer inserts EVERY slot once, in that order, using one space between slots. There is NO per-language template and no separate template field. Include punctuation inside paired labels when needed.
Each non-quantity slot has a stable id, kind (clinical_concept, condition or relation), language-neutral concept code in value, and paired labels.pt/labels.es expressing exactly the same meaning. Verbs, negations, conditions and qualifiers must agree with the canonical action/polarity. A relation slot carries wording that connects the same clinical facts; it cannot introduce independent facts. Never place a digit in a localized fact label. All numbers, even classification grades or counts, belong to a shared quantity slot. Use an unambiguous nonnumeric concept label when possible (for example cobalamin), never omit the clinical concept.
Every dose, route, interval, duration, numeric threshold and target count belongs to a shared quantity slot. quantity.value is an ORDERED array of typed tokens. Example of schema syntax ONLY, not a clinical regimen: [{"kind":"number","value":"42"},{"kind":"unit","value":"mg"},{"kind":"unit","value":"VO"},{"kind":"operator","value":"q"},{"kind":"number","value":"12"},{"kind":"unit","value":"h"}]. The renderer combines these canonical tokens; never produce translated dose values. Non-numeric directions such as per-protocol, repeat when indicated, or clinical judgment belong to relation labels, never quantity tokens. Express target counts as numbers in quantity slots and their noun in a clinical_concept slot. Use only supported units; do not invent a dose when it is not established.
Keep the answer clinically useful and focused: usually 3–5 short relevant sections for a general question, fewer for a simple mechanism question. Preserve principal treatment, supported standard reference doses, essential monitoring, important contraindications and critical alerts. Do not produce an encyclopedic review or repeated disclaimers. General educational questions do not require patient data first; label regimens as reference doses. Exact individualized calculations still require missing relevant context. Preserve all clinical safety constraints.
A final references record may cite ONLY source IDs provided in the context; otherwise omit it. The same source set applies to PT/ES. A next_step fact, when helpful, owns the semantic next action; do not generate an unrelated CTA. No raw patient facts, invented citations or unsupported regimens. End the object after the last record.`;

module.exports = {VERSION, LANGUAGES, SECTION_LABELS, SnapshotDecoder, SnapshotCoordinator, snapshotKey, validateRecord, renderRecord, renderClinicalRecord, renderSnapshot, validateSnapshot, canonicalFacts, hash, GENERATION_CONTRACT};
