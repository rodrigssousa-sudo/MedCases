import 'study_educational_degradation.dart';
import '../ai/safety/ai_stream_trace.dart';
import 'dart:convert';
import '../../models/study_clinical_snapshot.dart';
import '../gemini_service_v2.dart';
import 'study_reference_boundary.dart';

/// Study chat transport contract. It does not change provider selection, safety,
/// utilities that return JSON, or the renderer. The same adapter handles the
/// real transport and the real-QA harness.
class StudyCanonicalResponse {
  static String prompt(String clinicalPrompt) => '$wireContract\n\n'
      'CLINICAL POLICY INPUT (language locks describe the eventual UI, not the wire):\n'
      '$clinicalPrompt\n\n$wireContract';

  static const wireContract = r'''
STUDY CANONICAL TRANSPORT v1 — OUTPUT ENCODING (not visible to the reader).
Keep ALL preceding clinical/educational/safety rules and answer the actual
question. Encode ONE clinical answer, not two independent answers. First decide
the clinical facts, actions, conditions, quantities and order, then supply PT/ES
lexical labels for those SAME IDs. The app selects the display language later.
This wire encoding supersedes instructions to output plain Markdown or a single
language. Do not discuss the encoding. Do not use Markdown fences, comments, extra fields, citations, bibliography,
or tool/debug text.
Output ONE JSON ARRAY containing these compact records, in this order:
{"type":"title","id":"topic","localization":{"pt":"Título","es":"Título"}}
then fact records, then {"type":"end"}.
Each fact is one complete educational idea; preserve useful detail, explanation,
pathophysiology and evidence-based standard treatment/reference doses whenever
relevant. A narrow follow-up answers that question without repeating a textbook.
Group facts by section; do not reopen a previous section. Section IDs allowed:
definition,pathophysiology,causes,classification,manifestations,diagnosis,
differential,treatment,doses,monitoring,contraindications,warnings,complications,
key_points,summary. Include only sections that help answer the question.
FACT SCHEMA:
{"type":"fact","id":"f_unique","clinical":{"section":"treatment","conceptId":"clinical_concept_code","actionId":"treat","polarity":"conditional","conditionIds":["f_unique_condition"],"items":[{"id":"f_unique_condition","kind":"condition","code":"clinical_condition_code","localization":{"pt":"Quando indicado:","es":"Cuando esté indicado:"}},{"id":"f_unique_action","kind":"action","code":"clinical_action_code","localization":{"pt":"nome do fármaco e ação","es":"nombre del fármaco y acción"}},{"id":"f_unique_quantity","kind":"quantity","value":"500 mg"},{"id":"f_unique_route","kind":"route","value":"VO"},{"id":"f_unique_frequency","kind":"frequency","value":"c/24 h"},{"id":"f_unique_monitor","kind":"monitoring","code":"monitoring_code","localization":{"pt":"e monitorizar a resposta clínica.","es":"y monitorizar la respuesta clínica."}}]}}
The above schema is syntax ONLY, not a regimen or recommendation. Never copy
its dose into an unrelated answer. Use the actual relevant clinical knowledge.
Prefer SHORT stable IDs such as f1, f1_a, f1_q. Do not repeat the disease or
section name in every ID. This reduces wire overhead without shortening the answer.
IDs/codes use lowercase ASCII letters, digits and underscore, starting with a
letter. IDs must be unique across the whole answer. conceptId identifies the
clinical concept, actionId is explain/assess/treat/monitor/avoid/consider/refer.
polarity is positive/negative/conditional. conditionIds is [] or refers exactly
to condition items in that fact. Do not invent patient data.
items is the ONE shared ordered sequence used by BOTH languages, joined with
spaces. Kinds: concept,condition,action,monitoring,warning,relation require a
code and a localization pair on that same item (bound to its exact ID). Use as many slots as
needed to preserve the complete fact including qualifications and negation.
quantity,frequency,route instead have ONE shared value and
NO localization entry. Routes use VO/IV/IM/SC/IO/IN/SL/EV/ID/IT/PR.
EVERY digit, numeric threshold, range, percentage, dose, frequency and duration
MUST be in a shared quantity/frequency value, never in PT/ES localized prose.
Split a sentence into phrase + quantity + phrase where necessary. Example:
items: concept phrase, quantity value "3.5 g/24 h", relation phrase.
Even numbers without units must be shared quantities. B12/HbA1c may use the
neutral kind ONLY for those exact short scientific symbols. NEVER put prose or
a sentence in a neutral/shared value. All natural-language phrases require both
PT and ES labels. Proper names use paired identical labels when language-neutral. Write a
title without digits. No localized string may contain any digit.
Each localized slot MUST have both pt and es with the SAME meaning, negation,
condition and scope. Do NOT add clinical facts in a translation. No ID may be
omitted or repeated. Do not put placeholders into labels. Quantity values use
numbers/operators and neutral units, not natural-language sentences; frequency
notation is c/24 h (not q24 h). Do not abbreviate the educational explanation
merely to save JSON space. References are attached from verified transport or
catalog provenance by the application, not generated in these objects.
Always include conditionIds (even []). Do not invent alternative section IDs
such as mechanism, indications or adverse_effects; use the allowed list above.
Do not invent actionId values. No prose may be stored as a shared value.
Before emitting EACH fact, resolve every item ID to BOTH localizations, except
quantities and routes. Keep localization keys identical to corresponding IDs.
Localization is nested INSIDE each localized item, never duplicated outside.
A shared quantity, frequency or route item must NEVER have a localization.
Frequency without a number (e.g. periodically) is a localized relation item,
not a frequency quantity. Do not emit empty labels for grammatical connectors;
each item must contain real nonempty text in both languages. Prefer a complete
clinical phrase per concept/action slot, splitting only around shared numbers,
routes or independently meaningful conditions; do not tokenize individual words.
HbA1c, B12, SpO2, PaO2, P2Y12, COX1, COX2 and similar scientific symbols MUST be separate neutral
items. NEVER embed these symbols inside any PT/ES localization phrase. Prefer
the full localized term (hemoglobina glicada/hemoglobina glucosilada) if needed.
Even the numeric suffix of diabetes type belongs in a shared quantity item.
NATIVE NUMERIC ENCODING: quantity/frequency items use amount (JSON number),
upper (JSON number or null), operator ("",<,>,≤,≥,~) and unit (one enum unit).
They do NOT use a value string. Example quantity: {"id":"f_q","kind":"quantity",
"amount":500,"upper":null,"operator":"","unit":"mg"}.
Example frequency: {"id":"f_interval","kind":"frequency","amount":24,
"upper":null,"operator":"","unit":"h"}. Qualitative frequency such as
periodically or annually may use localized relation text with NO digit instead.
Neutral items allow ONLY the scientific symbol enum. A suffix such as type two
belongs to a quantity item with amount 2, upper null, operator "", unit "".
Finish the array with {"type":"end"}]; never stop in the middle of a fact.
''';

  static Stream<GeminiChunk> localize(
    Stream<GeminiChunk> source, {
    required String language,
    required StudyReferenceBoundary references,
  }) async* {
    final decoder = StudyCanonicalDecoder(language);
    bool firstUsefulBlock = true;
    await for (final chunk in source) {
      references.addGrounding(chunk.groundedSources);
      final visible = decoder.add(chunk.text);
      if (firstUsefulBlock && decoder.hasPresentableFacts) {
        firstUsefulBlock = false;
        AiStreamTrace.mark('STUDY_FIRST_VALIDATED_BLOCK', visible.length);
      }
      if (visible.isNotEmpty || chunk.groundedSources.isNotEmpty) {
        yield GeminiChunk(
            text: visible, groundedSources: chunk.groundedSources);
      }
      if (chunk.isDone || chunk.isError) {
        final tail = decoder.finish();
        if (tail.isNotEmpty) yield GeminiChunk(text: tail);
        final snapshot = decoder.presentationSnapshot(references: references.records);
        if (snapshot != null) {
          yield GeminiChunk(text: '${snapshot.continuationMetadata}\n\n');
        }
        yield GeminiChunk(
            text: '',
            isDone: chunk.isDone,
            errorCode: chunk.errorCode,
            finishReason: chunk.finishReason,
            studySnapshot: snapshot,
            studyCanonicalIssues: List.unmodifiable(decoder.issues));
      }
    }
  }

  static String localizeComplete(String wire,
      {required String language, required StudyReferenceBoundary references}) {
    final decoder = StudyCanonicalDecoder(language);
    final text = decoder.add(wire) + decoder.finish();
    // Validation is observable through the streaming result/tests. A bad label
    // must not replace the educational answer with a global refusal template.
    final snapshot = decoder.presentationSnapshot(references: references.records);
    return snapshot == null
        ? text
        : '$text${snapshot.continuationMetadata}\n\n';
  }
}

/// Incremental balanced-object framing handles arbitrary SSE/token boundaries,
/// escaped braces and pretty-printed JSON. Only complete records reach the UI.
class StudyCanonicalDecoder {
  StudyCanonicalDecoder(this.language);
  final String language;
  final List<Map<String, dynamic>> _records = [];
  final List<String> issues = [];
  final List<Map<String, Object?>> diagnostics = [];
  final List<Map<String, dynamic>> _presentableRecords = [];
  final Set<String> _presentableIds = {};
  String _pending = '';
  String? _section;
  bool? _structured;
  bool _finished = false;
  int _cursor = 0;
  int _depth = 0;
  bool _quoted = false;
  bool _escape = false;
  int _start = -1;

  String add(String text) {
    if (_finished || text.isEmpty) return '';
    _pending += text;
    if (_pending.length > 512000) {
      if (!issues.contains('wire_limit')) issues.add('wire_limit');
      return '';
    }
    if (_structured == null) {
      final first = _pending.trimLeft();
      if (first.isEmpty || (first.startsWith('`') && !first.contains('\n')))
        return '';
      _structured = first.startsWith('{') ||
          first.startsWith('[') ||
          first.startsWith('```');
      if (_structured == false) issues.add('plaintext_fallback');
    }
    if (_structured == false) {
      final plain = _pending;
      _pending = '';
      return plain; // Existing clinical path remains available.
    }
    final output = StringBuffer();
    for (; _cursor < _pending.length; _cursor++) {
      final c = _pending[_cursor];
      if (_start < 0) {
        if (c == '{') {
          _start = _cursor;
          _depth = 1;
        }
        continue;
      }
      if (_quoted) {
        if (_escape) {
          _escape = false;
        } else if (c == '\\') {
          _escape = true;
        } else if (c == '"') {
          _quoted = false;
        }
      } else if (c == '"') {
        _quoted = true;
      } else if (c == '{') {
        _depth++;
      } else if (c == '}' && --_depth == 0) {
        try {
          final record = jsonDecode(_pending.substring(_start, _cursor + 1))
              as Map<String, dynamic>;
          if (record['type'] == 'fact' &&
              record['localization'] == null &&
              record['clinical'] is Map) {
            final labels = <String, dynamic>{};
            for (final item in record['clinical']['items'] as List) {
              if (item is Map && item.containsKey('localization')) {
                if (labels.containsKey(item['id']))
                  throw const FormatException(
                      'study_snapshot_duplicate_localization_id');
                labels[item['id'] as String] = item.remove('localization');
              }
            }
            record['localization'] = labels;
          }
          if (record['type'] == 'fact' && record['localization'] is List) {
            final labels = <String, dynamic>{};
            for (final entry in record['localization'] as List) {
              if (entry is! Map ||
                  entry['id'] is! String ||
                  labels.containsKey(entry['id'])) {
                throw const FormatException(
                    'study_snapshot_duplicate_localization_id');
              }
              labels[entry['id'] as String] = {
                'pt': entry['pt'],
                'es': entry['es']
              };
            }
            record['localization'] = labels;
          }
          if (record['type'] == 'fact') {
            for (final item in record['clinical']['items'] as List) {
              if (['quantity', 'frequency'].contains(item['kind']) &&
                  item['amount'] is num) {
                final amount = item['amount'] as num;
                final upper = item['upper'] as num?;
                String number(num n) => n == n.roundToDouble()
                    ? n.toInt().toString()
                    : n.toString();
                item['value'] =
                    '${item['kind'] == 'frequency' ? 'c/' : ''}${item['operator'] ?? ''}'
                    '${number(amount)}${upper == null ? '' : '–${number(upper)}'}'
                    '${item['unit'] == '' ? '' : ' ${item['unit']}'}';
              }
              // A shared numeric atom is already language-neutral. Correct its
              // wire tag without inspecting or matching either translation.
              if (item['kind'] == 'neutral' &&
                  item['value'] is String &&
                  RegExp(r'^[0-9]+[.,;:]?$').hasMatch(item['value'])) {
                item['kind'] = 'quantity';
              }
            }
          }
          _records.add(record);
          var valid = true;
          var displayRecord = record;
          try {
            StudyClinicalSnapshot.validateRecord(record);
            if (!StudyEducationalDegradation.safeAtoms(record)) {
              throw const FormatException('study_snapshot_unsafe_atom');
            }
            final ids = <String>[
              if (record['id'] is String) record['id'] as String,
              if (record['type'] == 'fact')
                for (final item in record['clinical']['items'] as List)
                  item['id'] as String,
            ];
            if (ids.toSet().length != ids.length ||
                ids.any(_presentableIds.contains)) {
              throw const FormatException('study_snapshot_duplicate_id');
            }
            if ((record['type'] == 'title' && _presentableRecords.isNotEmpty) ||
                (record['type'] == 'fact' && _presentableRecords.isEmpty) ||
                _presentableRecords.any((r) => r['type'] == 'end')) {
              throw const FormatException('study_snapshot_record_order');
            }
            _presentableIds.addAll(ids);
            _presentableRecords.add(record);
          } on FormatException catch (e) {
            issues.add(e.message.toString());
            final recovered = StudyEducationalDegradation.recover(record, e.message.toString());
            final ids = recovered == null ? <String>[] : <String>[
              recovered['id'] as String,
              for (final i in recovered['clinical']['items'] as List) i['id'] as String,
            ];
            final canRecover = recovered != null && ids.toSet().length == ids.length &&
                !ids.any(_presentableIds.contains) && _presentableRecords.isNotEmpty &&
                !_presentableRecords.any((r) => r['type'] == 'end');
            diagnostics.add({
              'reasonCode': e.message.toString(),
              'sectionId': (record['clinical'] as Map?)?['section'],
              'recordIndex': _records.length - 1,
              'factIdHash': StudyClinicalSnapshot.hash(record['id']),
              'numeric': StudyEducationalDegradation.numeric(record),
              'fallbackRenderUsed': canRecover,
            });
            if (canRecover) {
              displayRecord = recovered;
              _presentableIds.addAll(ids);
              _presentableRecords.add(recovered);
            }
            valid = canRecover;
          }
          final section = (record['clinical'] as Map?)?['section'] as String?;
          // Preserve presentation-safe educational prose while retaining strict audit failures.
          if (valid) {
            output.write(StudyClinicalSnapshot.renderRecord(displayRecord, language,
                includeHeading: section != _section));
            if (section != null) _section = section;
          }
        } on Object {
          issues.add('malformed_record');
        }
        _pending = _pending.substring(_cursor + 1);
        _cursor = -1;
        _start = -1;
      }
    }
    return output.toString();
  }

  String finish() {
    if (_finished) return '';
    _finished = true;
    if (_start >= 0) issues.add('incomplete_record');
    if (_structured == null && _pending.trim().isNotEmpty)
      issues.add('incomplete_wire');
    return '';
  }

  bool get hasPresentableFacts => _presentableRecords.any((r) => r['type'] == 'fact');

  /// Same ordered facts/quantities for PT and ES. Coverage and an unrelated
  /// malformed fact are diagnostics, not authorization for the whole answer.
  /// A missing end marker remains a transport/truncation failure.
  StudyClinicalSnapshot? presentationSnapshot({Iterable<String> references = const []}) {
    try {
      return StudyClinicalSnapshot.fromRecords(_presentableRecords,
          verifiedReferences: references);
    } on FormatException {
      return null;
    }
  }

  StudyClinicalSnapshot? snapshot({Iterable<String> references = const []}) {
    if (issues.isNotEmpty) return null;
    try {
      return StudyClinicalSnapshot.fromRecords(_records,
          verifiedReferences: references);
    } on FormatException catch (e) {
      issues.add(e.message.toString());
      return null;
    }
  }
}
