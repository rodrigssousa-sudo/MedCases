import '../services/study/study_canonical_continuation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Clinical identity and ordering are independent of the selected language.
/// This object is immutable and request-scoped; it is never stored globally.
class StudyClinicalSnapshot {
  static const version = 'study_clinical_snapshot_v1';
  static const headings = {
    'definition': ['Definição', 'Definición'],
    'pathophysiology': ['Fisiopatologia', 'Fisiopatología'],
    'causes': ['Etiologia', 'Etiología'],
    'classification': ['Classificação', 'Clasificación'],
    'manifestations': ['Manifestações clínicas', 'Manifestaciones clínicas'],
    'diagnosis': ['Diagnóstico', 'Diagnóstico'],
    'differential': ['Diagnóstico diferencial', 'Diagnóstico diferencial'],
    'treatment': ['Tratamento', 'Tratamiento'],
    'doses': ['Doses de referência', 'Dosis de referencia'],
    'monitoring': ['Monitorização', 'Monitorización'],
    'contraindications': ['Contraindicações', 'Contraindicaciones'],
    'warnings': ['Sinais de alarme', 'Signos de alarma'],
    'complications': ['Complicações', 'Complicaciones'],
    'key_points': ['Pontos-chave', 'Puntos clave'],
    'summary': ['Síntese', 'Síntesis'],
  };
  final String _encoded;
  StudyClinicalSnapshot._(this._encoded);

  static String hash(Object? value) {
    Object? sort(Object? v) {
      if (v is List) return v.map(sort).toList();
      if (v is Map) {
        final keys = v.keys.cast<String>().toList()..sort();
        return {for (final k in keys) k: sort(v[k])};
      }
      return v;
    }

    return sha256.convert(utf8.encode(jsonEncode(sort(value)))).toString();
  }

  factory StudyClinicalSnapshot.fromRecords(List<Map<String, dynamic>> records,
      {Iterable<String> verifiedReferences = const [],
      List<String> languages = const ['pt', 'es']}) {
    _check(
        languages.isNotEmpty &&
            languages.toSet().length == languages.length &&
            languages.every((l) => ['pt', 'es'].contains(l)),
        'languages');
    final ids = <String>{};
    final sections = <String>{};
    String? currentSection;
    var facts = 0;
    var ended = false;
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      validateRecord(record, languages: languages);
      _check(!ended, 'record_after_end');
      if (record['type'] == 'end') {
        ended = true;
        continue;
      }
      _check((i == 0) == (record['type'] == 'title'), 'title_order');
      _check(ids.add(record['id'] as String), 'duplicate_id');
      if (record['type'] == 'fact') {
        facts++;
        final clinical = record['clinical'] as Map;
        final section = clinical['section'] as String;
        if (section != currentSection) {
          // A later return to a section preserves canonical order in both
          // views. Never reorder earlier visible blocks to merge headings.
          sections.add(section);
          currentSection = section;
        }
        for (final raw in clinical['items'] as List) {
          _check(ids.add((raw as Map)['id'] as String), 'duplicate_id');
        }
      }
    }
    _check(ended && facts > 0, 'incomplete_snapshot');
    // Only transport/catalog provenance enters references, never model URLs.
    final sources = verifiedReferences
        .toSet()
        .map((text) => {
              'referenceId': 'ref_${hash(text)}',
              'text': text,
            })
        .toList();
    return StudyClinicalSnapshot._(jsonEncode({
      'version': version,
      'languages': languages,
      'records': records,
      'references': sources,
      'ctaId': StudyCanonicalContinuation.select(sections),
    }));
  }

  static final _id = RegExp(r'^[a-z][a-z0-9_]{0,159}$');
  // A semantic code may preserve a scientific symbol's case; binding IDs stay strict.
  static final _semanticCode = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,159}$');
  static final _number = RegExp(r'\d');
  static const _kinds = {
    'concept',
    'condition',
    'action',
    'monitoring',
    'warning',
    'relation',
    'quantity',
    'route',
    'frequency',
    'neutral',
    'proper_name',
  };
  static void _check(bool condition, String code) {
    if (!condition) throw FormatException('study_snapshot_$code');
  }

  static void validateRecord(Map<String, dynamic> record,
      {List<String> languages = const ['pt', 'es']}) {
    final type = record['type'];
    _check(['title', 'fact', 'end'].contains(type), 'record_type');
    if (type == 'end') return;
    _check(record['id'] is String && _id.hasMatch(record['id']), 'record_id');
    if (type == 'title') {
      _labels(record['localization'], languages);
      return;
    }
    final clinical = record['clinical'];
    _check(clinical is Map, 'clinical_missing');
    _check(headings.containsKey(clinical['section']), 'section_unknown');
    _check(
        clinical['conceptId'] is String && _id.hasMatch(clinical['conceptId']),
        'concept_id');
    _check(
        ['explain', 'assess', 'treat', 'monitor', 'avoid', 'consider', 'refer']
            .contains(clinical['actionId']),
        'action_id');
    _check(
        ['positive', 'negative', 'conditional'].contains(clinical['polarity']),
        'polarity');
    final conditions = clinical['conditionIds'];
    _check(
        conditions is List &&
            conditions.every((c) => c is String && _id.hasMatch(c)),
        'conditions');
    final items = clinical['items'];
    final labels = record['localization'];
    _check(items is List && items.isNotEmpty && labels is Map, 'items_missing');
    final bound = <String>{};
    final localizedIds = <String>{};
    for (final item in items) {
      _check(item is Map && item['id'] is String && _id.hasMatch(item['id']),
          'item_id');
      _check(bound.add(item['id']), 'duplicate_binding');
      _check(_kinds.contains(item['kind']), 'item_kind');
      final kind = item['kind'];
      if (['quantity', 'frequency', 'route', 'neutral', 'proper_name']
          .contains(kind)) {
        _check(
            item['value'] is String &&
                (item['value'] as String).trim().isNotEmpty,
            'shared_value_missing');
        if (kind == 'neutral') {
          _check(
              RegExp(r'^(?:[A-Za-z][A-Za-z0-9+−-]{0,29}|[0-9]+[.,;:]?)$')
                  .hasMatch(item['value']),
              'neutral_prose');
        }
        if (kind == 'proper_name') {
          _check(
              !(item['value'] as String).contains(RegExp(r'[.;!?]')) &&
                  (item['value'] as String).split(RegExp(r'\s+')).length <= 3,
              'proper_name_prose');
        }
        if (kind == 'quantity' || kind == 'frequency') {
          _check(_number.hasMatch(item['value']), 'quantity_missing');
          const units = {
            'mg',
            'mcg',
            'g',
            'kg',
            'ng',
            'pg',
            'L',
            'mL',
            'dl',
            'dL',
            'ml',
            'mmol',
            'mEq',
            'mmHg',
            'bpm',
            'rpm',
            'cm',
            'mm',
            'm',
            'h',
            'min',
            's',
            'd',
            'a',
            'mo',
            'UI',
            'IU',
            'U',
            'c',
            'x',
            'C',
            'µg',
            'μg',
            'mol',
            'kPa'
          };
          _check(
              RegExp(r'[A-Za-zµμ]+')
                  .allMatches(item['value'])
                  .every((m) => units.contains(m[0])),
              'quantity_prose');
          // The entire quantity is shared, including unit, range and operator.
          _check(
              RegExp(r'^[\d\s.,+\-–−/%²³^×=<>≤≥~µμa-zA-Z()]+$')
                  .hasMatch(item['value']),
              'quantity_syntax');
        }
        if (kind == 'route') {
          _check(
              ['VO', 'IV', 'IM', 'SC', 'IO', 'IN', 'SL', 'EV', 'ID', 'IT', 'PR']
                  .contains(item['value']),
              'route');
        }
      } else {
        _check(item['code'] is String && _semanticCode.hasMatch(item['code']),
            'item_code');
        localizedIds.add(item['id']);
        _labels(labels[item['id']], languages);
      }
    }
    _check(
        labels.keys.toSet().difference(localizedIds).isEmpty &&
            localizedIds.difference(labels.keys.cast<String>().toSet()).isEmpty,
        'localization_id_binding');
    _check(
        (conditions as List).every((id) => (items as List)
            .any((i) => i['id'] == id && i['kind'] == 'condition')),
        'condition_binding');
  }

  static void _labels(dynamic labels, List<String> languages) {
    _check(
        labels is Map &&
            labels.keys.toSet().length == languages.length &&
            languages.every(labels.containsKey),
        'localization_missing');
    for (final lang in languages) {
      _check(
          labels[lang] is String && (labels[lang] as String).trim().isNotEmpty,
          'localization_missing');
      _check(!_number.hasMatch(labels[lang]), 'unbound_numeric');
      _check(
          !RegExp(r'https?://|\bdoi:|\bPMID|\{\{', caseSensitive: false)
              .hasMatch(labels[lang]),
          'unbound_reference');
    }
  }

  /// Render all bindings in canonical order. Language cannot select an item.
  static String renderRecord(Map<String, dynamic> record, String lang,
      {bool includeHeading = true, bool recoverLocalization = false}) {
    lang = lang.startsWith('es') ? 'es' : 'pt';
    String label(dynamic pair) {
      if (pair is! Map) return '';
      final selected = pair[lang];
      if (selected is String && selected.isNotEmpty) return selected;
      if (recoverLocalization) {
        final other = pair[lang == 'pt' ? 'es' : 'pt'];
        if (other is String) return other;
      }
      throw const FormatException('study_snapshot_localization_missing');
    }

    if (record['type'] == 'title')
      return '# ${label(record['localization'])}\n\n';
    if (record['type'] != 'fact') return '';
    final clinical = record['clinical'] as Map;
    final labels = record['localization'] as Map;
    final pieces = <String>[];
    for (final item in clinical['items'] as List) {
      pieces.add(item['value'] is String
          ? item['value'] as String
          : label(labels[item['id']]));
    }
    final section = clinical['section'];
    final heading = headings[section]?[lang == 'es' ? 1 : 0];
    return '${includeHeading && heading != null ? '## $heading\n\n' : ''}'
        '${record['_educationalFallback'] == true ? '' : '- '}${pieces.join(' ').replaceAllMapped(RegExp(r'\s+([,.;:)])'), (m) => m[1]!).trim()}\n\n';
  }

  Map<String, dynamic> get _data =>
      jsonDecode(_encoded) as Map<String, dynamic>;
  /// Read-only canonical quantities for retention gates; no localized prose.
  List<({String id, String value})> get quantities => List.unmodifiable(
      (_data['records'] as List).where((r) => r['type'] == 'fact')
          .expand((r) => r['clinical']['items'] as List)
          .where((i) => ['quantity', 'frequency'].contains(i['kind']))
          .map((i) => (id: i['id'] as String, value: i['value'] as String)));

  String get continuationMetadata =>
      StudyCanonicalContinuation.metadata(_data['ctaId'] as String);

  List<String> blocks(String lang, {bool includeContinuation = false}) {
    final data = _data;
    final result = <String>[];
    String? section;
    for (final raw in data['records'] as List) {
      final r = raw as Map<String, dynamic>;
      final next = (r['clinical'] as Map?)?['section'] as String?;
      final text = renderRecord(r, lang, includeHeading: next != section);
      if (text.isNotEmpty) result.add(text);
      if (next != null) section = next;
    }
    if (includeContinuation) result.add('$continuationMetadata\n\n');
    final refs = data['references'] as List;
    if (refs.isNotEmpty)
      result
          .add('## ${lang.startsWith('es') ? 'Referencias' : 'Referências'}\n\n'
              '${refs.map((r) => '- ${r['text']}').join('\n')}\n\n');
    return List.unmodifiable(result);
  }

  /// Audit the IDs actually traversed by the localization, not translated text.
  Map<String, Object> audit(String lang) {
    blocks(lang); // Resolve every localization before asserting coverage.
    final data = _data;
    final facts =
        (data['records'] as List).cast<Map>().where((r) => r['type'] == 'fact');
    final clinical =
        facts.map((r) => {'factId': r['id'], ...r['clinical'] as Map}).toList();
    final items =
        clinical.expand((r) => r['items'] as List).cast<Map>().toList();
    return {
      'canonicalAuditPassed': !facts.any((r) => r['_educationalFallback'] == true),
      'fallbackFactCount': facts.where((r) => r['_educationalFallback'] == true).length,
      'factHash': hash(clinical),
      'quantityHash': hash(items
          .where((i) => ['quantity', 'frequency'].contains(i['kind']))
          .toList()),
      'orderHash':
          hash(facts.map((f) => [f['id'], f['clinical']['section']]).toList()),
      'referenceHash': hash(data['references']),
      'ctaId': data['ctaId'],
      'factCount': facts.length,
      'quantityCount': items
          .where((i) => ['quantity', 'frequency'].contains(i['kind']))
          .length,
      'monitoringCount':
          clinical.where((r) => r['section'] == 'monitoring').length,
      'droppedFacts': 0,
      'resolutions': {
        for (final i in items)
          i['id']: i['kind'] == 'proper_name'
              ? 'PROPER_NOUN_PRESERVED'
              : i.containsKey('value')
                  ? 'LANGUAGE_NEUTRAL_TERM'
                  : 'LOCALIZED'
      },
    };
  }
}
