import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'study_canonical_schema.dart';
import '../gemini_service_v2.dart';
import '../../models/study_clinical_snapshot.dart';
import 'study_canonical_response.dart';
import 'study_answer_first.dart';

/// Independent records: prose needs no snapshot; numeric records always pass
/// the unchanged strict canonical decoder (never its degraded presentation).
class StudyHybridResponse {
  static const version = 'study_hybrid_v1';
  static const maxOutputTokens = 12288;
  static const thinkingBudget = 2048;
  static Map<String, dynamic> get generationConfig => {
    'thinkingConfig': {'thinkingBudget': thinkingBudget},
    'responseMimeType': 'application/json',
    'responseJsonSchema': StudyCanonicalSchema.array({
      'anyOf': [
        StudyCanonicalSchema.object({
          'type': StudyCanonicalSchema.string(values: ['prose']),
          'sectionId': StudyCanonicalSchema.string(values: StudyClinicalSnapshot.headings.keys.toList()),
          'text': StudyCanonicalSchema.string(pattern: r'^[^0-9]+[.!?][*_]*$'),
        }),
        (StudyCanonicalSchema.schema['items'] as Map)['anyOf'][1],
        StudyCanonicalSchema.object({'type': StudyCanonicalSchema.string(values: ['end'])}),
      ],
    }),
  };
  static String prompt(String clinical, String language) =>
      'STUDY HYBRID v1\n$clinical\n'
      'WIRE CONTRACT: Emit one JSON array of independently complete blocks, one '
      'COMPLETE educational idea per object. No fences, title records or debug. '
      'Start with useful nonnumeric teaching prose in '
      '${language.startsWith('es') ? 'Spanish' : 'Portuguese'}. '
      'Use {"type":"prose","sectionId":"definition","text":"Complete explanation."} '
      'for nonnumeric explanation; do NOT encode nonnumeric explanations as facts. '
      'Each prose text and each assembled numeric fact MUST end with sentence '
      'punctuation. No standalone headings or unfinished clauses. SectionId uses '
      'the section enum below. Group content by section without repeating headings. '
      'For clinical numbers, doses, ranges, thresholds, frequency, duration, '
      'measurements or percentages, output an actual fact INSTANCE, NOT a schema. '
      'The literal type MUST be "fact", NEVER "type" or "object". '
      'Shape (replace placeholders with clinical information): '
      '{"type":"fact","id":"f_unique","clinical":{"section":"diagnosis",'
      '"conceptId":"clinical_concept","actionId":"assess","polarity":"positive",'
      '"conditionIds":[],"items":[{"id":"f_unique_a","kind":"concept",'
      '"code":"clinical_concept","localization":{"pt":"frase introdutória",'
      '"es":"frase introductoria"}},{"id":"f_unique_q","kind":"quantity",'
      '"amount":NUMBER,"upper":null,"operator":"","unit":"UNIT"},'
      '{"id":"f_unique_r","kind":"relation","code":"qualification",'
      '"localization":{"pt":"qualificação completa.","es":"calificación completa."}}]}} '
      'NUMBER and UNIT are placeholders to replace, not literal values. '
      'Schema for validating your fact INSTANCE: '
      '${jsonEncode((StudyCanonicalSchema.schema['items'] as Map)['anyOf'][1])}\n'
      'Every fact is self-contained: conditionIds refer to condition items IN THAT '
      'fact. IDs unique across the response. Localized item labels contain no '
      'digits; every numeric value is a shared quantity/frequency atom with amount, '
      'upper, operator and unit. Both labels express the SAME fact. Use no value '
      'string for numeric items. Route items use only allowed route symbols. '
      'Do not omit useful standard doses. Never invent patient-specific calculations. '
      'No provider-generated references; verified sources are attached separately. '
      'Use short unique IDs (f1, f1a, f1q); avoid verbose identifiers. '
      'Do not duplicate a clinical statement in prose and numeric facts. '
      'Close JSON strings and objects; no literal newlines inside quoted strings. '
      'Finish the array with {"type":"end"}]. This wire contract overrides output-format '
      'instructions above, preserving all clinical and safety rules.\n';

  /// Structural completeness is attested per record, independently of STOP.
  static bool complete(String text) {
    final t = text.trim();
    if (t.isEmpty || !RegExp(r'[.!?][*_]*$').hasMatch(t)) return false;
    for (final delimiter in ['**', '__', '`']) {
      if (delimiter.allMatches(t).length.isOdd) return false;
    }
    final stripped = t.replaceAll('**', '').replaceAll('__', '');
    if ('*'.allMatches(stripped).length.isOdd ||
        '_'.allMatches(stripped).length.isOdd) return false;
    for (final pair in [
      ['(', ')'],
      ['[', ']']
    ]) {
      if (pair[0].allMatches(t).length != pair[1].allMatches(t).length)
        return false;
    }
    return !RegExp(r'^\s*(?:[-*+]\s*|#{1,6}\s*)$', multiLine: true).hasMatch(t);
  }

  static bool sensitive(String text) => RegExp(
          r'\d|[٠-٩۰-۹０-９]|[%‰∞]|\b(?:NaN|Infinity|dose|doses|dosis|dosagem|concentra[çc]|frequ[eê]ncia|frecuencia|intervalo|dura[çc][aã]o|duraci[oó]n|limiar|umbral|mg|mcg|µg|g|ml|u|ui|meq|mmol|por cento|por ciento|miligramos?|miligramas?|microgramas?|microgramos?|mililitros?|litros?|gramas?|gramos?|quilogramas?|quilogramos?|kilogramos?|unidades?|dias?|días?|anos?|años?|meses?|horas?|minutos?|semanas?|diariamente|diário|diaria|semanalmente|mensalmente|mensualmente|anualmente|vezes ao dia|veces al día)\b',
          caseSensitive: false)
      .hasMatch(text);

  static String prose(String text) => text
      .split(RegExp(r'(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÀÂÊÔÇÑ¿])'))
      .where((s) =>
          !sensitive(s) && StudyAnswerFirst.safeFragment(s) && complete(s))
      .join(' ');

  static Stream<GeminiChunk> stream(Stream<GeminiChunk> source,
      {required String language}) async* {
    final decoder = StudyHybridDecoder(language);
    try {
      await for (final c in source) {
        final text = decoder.add(c.text);
        if (text.isNotEmpty)
          yield GeminiChunk(
              text: text,
              studyDelivery: decoder.delivery,
              groundedSources: c.groundedSources);
        if (c.isDone || c.isError) {
          // Only a normal STOP can finish the last framed record. An error
          // NEVER flushes the tail or commits a new block.
          if (!c.isError && c.finishReason == 'STOP') {
            final last = decoder.add('\n');
            if (last.isNotEmpty)
              yield GeminiChunk(
                  text: last,
                  studyDelivery: decoder.delivery,
                  groundedSources: c.groundedSources);
          }
          final delivery = decoder.close(
              normal: !c.isError && c.finishReason == 'STOP' && decoder.ended,
              terminal: (c.errorCode ?? '').contains('timeout')
                  ? StudyStreamState.timeout
                  : RegExp(r'5\d\d').hasMatch(c.errorCode ?? '')
                      ? StudyStreamState.serverError
                      : StudyStreamState.incomplete);
          yield GeminiChunk(
              text: '',
              isDone: true,
              finishReason: delivery.complete && delivery.blocks.isNotEmpty
                  ? 'STOP'
                  : 'INCOMPLETE_STREAM',
              errorCode:
                  delivery.complete && delivery.blocks.isNotEmpty ? null : (c.errorCode ?? 'stream_error'),
              studyDelivery: delivery,
              groundedSources: c.groundedSources);
          return;
        }
      }
    } on Object {
      // Transport exceptions preserve the same committed block identities.
    }
    yield GeminiChunk(
        text: '',
        isDone: true,
        errorCode: 'stream_error',
        studyDelivery: decoder.close(normal: false));
  }
}

class StudyHybridDecoder {
  StudyHybridDecoder(this.language);
  final String language;
  final List<StudyCommittedBlock> _committed = [];
  bool _closed = false;
  StudyStreamState _terminal = StudyStreamState.active;
  int receivedBlocks = 0;
  int discardedIncompleteBlocks = 0;
  final List<Map<String, Object?>> diagnostics = [];
  final Map<int, StudyBlockState> _states = {};
  Map<int, StudyBlockState> get blockStates => Map.unmodifiable(_states);
  StudyBlockState? get bufferedState =>
      _pending.trim().isEmpty ? null : StudyBlockState.buffering;
  void _reject(String reason,
      {Map<String, dynamic>? record, bool incomplete = false}) {
    if (incomplete) discardedIncompleteBlocks++;
    if (receivedBlocks > 0 &&
        _states[receivedBlocks - 1] != StudyBlockState.committed) {
      _states[receivedBlocks - 1] = StudyBlockState.rejected;
    }
    diagnostics.add(Map.unmodifiable({
      'state': StudyBlockState.rejected.name,
      'reasonCode': reason,
      'recordIndex': receivedBlocks - 1,
      'sectionId': record?['clinical'] is Map
          ? record!['clinical']['section']
          : record?['sectionId'],
      'factIdHash':
          sha256.convert(utf8.encode('${record?['id'] ?? ''}')).toString(),
    }));
  }

  StudyDelivery get delivery => StudyDelivery._(_committed,
      terminal: _terminal,
      received: receivedBlocks,
      discardedIncomplete: discardedIncompleteBlocks);
  StudyDelivery close(
      {required bool normal,
      StudyStreamState terminal = StudyStreamState.incomplete}) {
    if (_closed) return delivery;
    _closed = true;
    _terminal = normal ? StudyStreamState.stop : terminal;
    final remainder = _pending.trim();
    final closingFrameOnly = normal && ended && remainder == ']';
    if (remainder.isNotEmpty && !closingFrameOnly)
      _reject('incomplete_transport_tail', incomplete: true);
    _pending = ''; // Discard ONLY uncommitted transport bytes.
    return delivery;
  }

  void _commit(String text, StringBuffer output,
      {StudyClinicalSnapshot? binding, String sectionId = 'explanation'}) {
    if (text.trim().isEmpty) return;
    _states[receivedBlocks - 1] = StudyBlockState.validatedSafe;
    _committed.add(
        StudyCommittedBlock._(_committed.length, text, binding, sectionId));
    _states[receivedBlocks - 1] = StudyBlockState.committed;
    output.write(text);
  }

  String _pending = '';
  bool ended = false;
  int blockedNumericRecords = 0;
  int validatedNumericRecords = 0;
  final Set<String> _ids = {};
  final List<String> numericValues = [];
  int _framedNewline() {
    var depth = 0;
    var quoted = false;
    var escape = false;
    for (var i = 0; i < _pending.length; i++) {
      final c = _pending[i];
      if (quoted) {
        if (escape) {
          escape = false;
        } else if (c == r'\') {
          escape = true;
        } else if (c == '"') {
          quoted = false;
        }
      } else {
        if (c == '"') {
          quoted = true;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
        } else if ((c == '\n' || c == ',' || c == ']') && depth <= 0) {
          return i;
        }
      }
    }
    return -1;
  }

  String add(String delta) {
    if (ended || _closed) return '';
    _pending += delta;
    // Native JSON array is transport framing only, never a full-answer gate.
    // Each balanced child is validated and committed independently.
    if (_pending.trimLeft().startsWith('[')) {
      _pending = _pending.trimLeft().substring(1);
    }
    if (_pending.length > 512000) {
      _pending = '';
      return '';
    }
    final output = StringBuffer();
    int newline;
    while ((newline = _framedNewline()) >= 0) {
      final line = _pending.substring(0, newline).trim();
      _pending = _pending.substring(newline + 1);
      if (line.isEmpty) continue;
      try {
        final r = jsonDecode(line) as Map<String, dynamic>;
        if (r['type'] == 'end') {
          ended = true;
          break;
        }
        _states[receivedBlocks++] = StudyBlockState.completeUnvalidated;
        if (r['type'] == 'prose' && r['text'] is String) {
          final safe = StudyHybridResponse.prose(r['text']);
          if (safe.isNotEmpty) {
            _commit('$safe\n\n', output,
                sectionId:
                    r['sectionId'] is String ? r['sectionId'] : 'explanation');
          } else {
            _reject('prose_not_attested',
                record: r,
                incomplete: !StudyHybridResponse.complete(
                    r['text'] is String ? r['text'] : ''));
          }
        } else if (r['type'] == 'fact') {
          final ids = [
            r['id'],
            for (final i in r['clinical']['items']) i['id']
          ];
          if (ids.toSet().length != ids.length || ids.any(_ids.contains)) {
            blockedNumericRecords++;
            _reject('duplicate_id', record: r);
            continue;
          }
          final d = StudyCanonicalDecoder(language);
          d.add(jsonEncode([
            {
              'type': 'title',
              'id': 'hybrid_title',
              'localization': {'pt': 'Estudo', 'es': 'Estudio'}
            },
            r,
            {'type': 'end'}
          ]));
          d.finish();
          final StudyClinicalSnapshot? s = d.snapshot();
          if (s == null || d.issues.isNotEmpty) {
            blockedNumericRecords++;
            for (final issue in d.issues) {
              _reject(issue, record: r);
            }
            // Recover only independent, complete, quantity-free prose slots.
            final labels = r['localization'];
            if (labels is Map) {
              for (final pair in labels.values) {
                if (pair is Map && pair[language] is String) {
                  final safe = StudyHybridResponse.prose(pair[language]);
                  if (safe.isNotEmpty) {
                    _commit('$safe\n\n', output,
                        sectionId: r['sectionId'] is String
                            ? r['sectionId']
                            : 'explanation');
                  } else {
                    _reject('prose_not_attested',
                        record: r,
                        incomplete: !StudyHybridResponse.complete(
                            r['text'] is String ? r['text'] : ''));
                  }
                }
              }
            }
            continue;
          }
          _ids.addAll(ids.cast<String>());
          final rendered = s.blocks(language).skip(1).join();
          // Strict binding has already succeeded. A final atomic quantity or
          // route is complete without sentence punctuation; prose is not.
          final items = r['clinical']['items'] as List;
          final endsInBoundAtom = s.quantities.isNotEmpty &&
              const ['quantity', 'frequency', 'route']
                  .contains((items.last as Map)['kind']);
          final structurallyComplete = StudyHybridResponse.complete(
              endsInBoundAtom ? '${rendered.trim()}.' : rendered);
          if (!structurallyComplete ||
              !StudyAnswerFirst.safeFragment(rendered)) {
            blockedNumericRecords++;
            _reject('fact_not_complete_or_safe',
                record: r, incomplete: !structurallyComplete);
            continue;
          }
          numericValues.addAll(s.quantities.map((q) => q.value));
          if (s.quantities.isNotEmpty) validatedNumericRecords++;
          _commit(rendered, output,
              binding: s, sectionId: r['clinical']['section']);
        } else {
          _reject('unsupported_record_type', record: r);
        }
      } on Object catch (error) {
        _reject('malformed_record_${error.runtimeType}', incomplete: true);
        // Broken transport is never rendered as prose or numeric content.
      }
    }
    return output.toString();
  }
}

/// Created only after validation of one complete block, never by a terminal.
class StudyCommittedBlock {
  StudyCommittedBlock._(
      this.index, this.text, this.numericBinding, this.sectionId);
  final String sectionId;
  StudyBlockState get state => StudyBlockState.committed;
  bool get blockComplete => true;
  bool get blockSanitized => true;
  bool get blockDebugFree => true;
  bool get numericBindingValid => numericBinding != null;
  final int index;
  final String text;
  final StudyClinicalSnapshot? numericBinding;
}

/// Transport outcome is separate from immutable, already validated blocks.
class StudyDelivery {
  StudyDelivery._(List<StudyCommittedBlock> blocks,
      {required this.terminal,
      required this.received,
      required this.discardedIncomplete})
      : blocks = List.unmodifiable(blocks);
  final List<StudyCommittedBlock> blocks;
  final StudyStreamState terminal;
  final int received;
  final int discardedIncomplete;
  int get attested => blocks.length;
  int get committed => blocks.length;
  bool get complete => terminal == StudyStreamState.stop;
  bool get interrupted =>
      terminal != StudyStreamState.stop && terminal != StudyStreamState.active;
  Set<String> get sectionIds =>
      Set.unmodifiable(blocks.map((b) => b.sectionId));
  String get text => blocks.map((b) => b.text).join();
  bool get canContinue => interrupted;
}

enum StudyBlockState {
  buffering,
  completeUnvalidated,
  validatedSafe,
  committed,
  rejected
}

enum StudyStreamState { active, stop, timeout, serverError, incomplete }
