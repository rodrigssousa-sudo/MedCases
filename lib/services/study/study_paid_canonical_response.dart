import 'dart:convert';
import '../../models/study_clinical_snapshot.dart';
import 'study_reference_boundary.dart';

/// Compact wire for the synchronous paid fallback only. Primary SSE stays v1.
/// Clinical fields never contain localized prose; localization cannot select,
/// reorder, invent or modify canonical IDs, quantities, conditions or references.
class StudyPaidCanonicalResponse {
  static const version = 'study_paid_snapshot_v2';
  static const maxOutputTokens = 12288;
  static const marker = 'STUDY PAID CANONICAL v2';
  static String prompt(String policy, String language) => '''$marker
Keep the clinical/educational/safety policy below. Decide ONE complete clinical
answer first. Encode it as clinical facts plus ONLY ${language.startsWith('es') ? 'Spanish' : 'Portuguese'} presentation.
This JSON encoding overrides Markdown/language wire instructions, not clinical scope.
$contract
CLINICAL POLICY:
$policy
''';
  static const contract = r'''
Root: clinical (ordered facts), presentation (title and labels), complete:true.
Fact: id (f1...), s (section), c (semantic concept code), a (action), p (polarity),
when (IDs of condition items, or []), items (ordered shared atoms).
Text atom: id, k (concept/condition/action/monitoring/warning/relation), c
(short semantic code encoding its actual meaning, including negation/qualification).
Its text occurs ONCE in presentation.labels as {id,text}, in requested language.
Numeric atom: id, k (quantity/frequency), n (number), hi (range end or null),
op (operator or empty), u (unit or empty). Every number, threshold, dose, duration
and interval belongs here, NEVER in a label. Frequency is rendered c/N h.
Route atom: id,k:route,v (VO/IV/IM/SC/IO/IN/SL/EV/ID/IT/PR).
Scientific symbol atom: id,k:neutral,v (schema enum, e.g. HbA1c).
All IDs unique, short lowercase ASCII. Each text atom has exactly one label.
presentation.labels IDs must equal the set of text-atom IDs exactly: no missing,
extra or duplicate IDs. Do NOT label quantities, frequencies, routes, neutral
symbols, fact IDs or the title. The title occurs only in presentation.title.
Split prose only around quantities, routes, symbols or independent conditions.
Use full useful educational explanations, standard treatments, reference doses,
monitoring, contraindications and warnings when relevant; no clinical truncation.
Do not create patient values. No clinical prose in numeric/route/symbol atoms.
Sections: definition,pathophysiology,causes,classification,manifestations,
diagnosis,differential,treatment,doses,monitoring,contraindications,warnings,
complications,key_points,summary. Only useful sections, in clinical order.
Actions: explain,assess,treat,monitor,avoid,consider,refer.
Polarity: positive,negative,conditional. Conditions bind to condition item IDs.
Title and labels have NO digits, URLs, DOI, PMID, bibliography or placeholders.
Reference identities are attached only from verified transport/catalog provenance.
Use compact JSON. No duplicate second language, UI, debug or extra metadata.
Close the complete object; complete:true is allowed only for a finished answer.
''';

  static StudyPaidSnapshot decode(String wire,
      {required String language,
      required String finishReason,
      required StudyReferenceBoundary references}) {
    if (finishReason != 'STOP') {
      throw const FormatException('study_paid_incomplete_termination');
    }
    try {
      final data = jsonDecode(wire) as Map<String, dynamic>;
      if (data['complete'] != true || data.length != 3) {
        throw const FormatException('study_paid_incomplete_snapshot');
      }
      return StudyPaidSnapshot._(jsonEncode(data),
          language.startsWith('es') ? 'es' : 'pt', references.records)
        ..snapshot;
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('study_paid_invalid_schema');
    }
  }
}

class StudyPaidSnapshot {
  StudyPaidSnapshot._(this._wire, this.language, this._references);
  final String _wire;
  final String language;
  final List<String> _references;
  Map<String, dynamic> get _data => jsonDecode(_wire) as Map<String, dynamic>;

  Map<String, String> _labels(Map presentation) {
    final result = <String, String>{};
    for (final entry in presentation['labels'] as List) {
      if (entry is! Map ||
          entry.length != 2 ||
          entry['id'] is! String ||
          entry['text'] is! String ||
          result.containsKey(entry['id'])) {
        throw const FormatException('study_paid_duplicate_or_invalid_label');
      }
      result[entry['id'] as String] = entry['text'] as String;
    }
    return result;
  }

  StudyClinicalSnapshot _build({Map<String, dynamic>? alternate}) {
    final data = _data;
    final presentation = data['presentation'] as Map;
    final labels = _labels(presentation);
    final other = language == 'es' ? 'pt' : 'es';
    final translated = alternate == null ? null : _labels(alternate);
    if (translated != null &&
        (translated.keys.toSet().difference(labels.keys.toSet()).isNotEmpty ||
            labels.keys
                .toSet()
                .difference(translated.keys.toSet())
                .isNotEmpty)) {
      throw const FormatException('study_paid_translation_binding');
    }
    final consumed = <String>{};
    final records = <Map<String, dynamic>>[
      {
        'type': 'title',
        'id': 'topic',
        'localization': {
          language: presentation['title'],
          if (alternate != null) other: alternate['title']
        }
      }
    ];
    for (final f in data['clinical'] as List) {
      final localized = <String, dynamic>{};
      final items = <Map<String, dynamic>>[];
      for (final i in f['items'] as List) {
        final k = i['k'];
        final atom = <String, dynamic>{'id': i['id'], 'kind': k};
        if (k == 'quantity' || k == 'frequency') {
          final n = i['n'] as num;
          final hi = i['hi'] as num?;
          if (!n.isFinite || (hi != null && (!hi.isFinite || hi < n))) {
            throw const FormatException('study_paid_invalid_quantity');
          }
          String number(num v) =>
              v == v.roundToDouble() ? v.toInt().toString() : v.toString();
          if (!['', '<', '>', '≤', '≥', '~'].contains(i['op'])) {
            throw const FormatException('study_paid_invalid_operator');
          }
          atom['value'] =
              '${k == 'frequency' ? 'c/' : ''}${i['op']}${number(n)}'
              '${hi == null ? '' : '–${number(hi)}'}${i['u'] == '' ? '' : ' ${i['u']}'}';
        } else if (k == 'route' || k == 'neutral') {
          atom['value'] = i['v'];
        } else {
          atom['code'] = i['c'];
          if (!consumed.add(i['id'] as String) ||
              !labels.containsKey(i['id'])) {
            throw const FormatException('study_paid_label_binding');
          }
          localized[i['id'] as String] = {
            language: labels[i['id']],
            if (translated != null) other: translated[i['id']]
          };
        }
        items.add(atom);
      }
      records.add({
        'type': 'fact',
        'id': f['id'],
        'clinical': {
          'section': f['s'],
          'conceptId': f['c'],
          'actionId': f['a'],
          'polarity': f['p'],
          'conditionIds': f['when'],
          'items': items
        },
        'localization': localized
      });
    }
    if (labels.keys.toSet().difference(consumed).isNotEmpty) {
      throw const FormatException('study_paid_unbound_label');
    }
    records.add({'type': 'end'});
    return StudyClinicalSnapshot.fromRecords(records,
        verifiedReferences: _references,
        languages: alternate == null ? [language] : [language, other]);
  }

  StudyClinicalSnapshot get snapshot => _build();
  String get text =>
      snapshot.blocks(language, includeContinuation: true).join();

  /// Translation receives only frozen lexical bindings. It cannot return facts,
  /// doses, routes, section selection, references or a new clinical answer.
  String get localizationPrompt => '''${StudyPaidCanonicalResponse.marker}
LOCALIZATION ONLY. Translate the supplied title and labels into ${language == 'es' ? 'Portuguese' : 'Spanish'}.
Return exactly title and labels:[{id,text}]. Preserve every ID, meaning, negation,
condition and qualification. No new clinical advice, numbers, routes, references,
sections, omitted labels or extra keys. Never regenerate the clinical answer.
Frozen source presentation:
${jsonEncode(_data['presentation'])}
''';
  StudyClinicalSnapshot withLocalization(String wire,
      {required String finishReason}) {
    if (finishReason != 'STOP')
      throw const FormatException('study_paid_incomplete_localization');
    final translated = jsonDecode(wire) as Map<String, dynamic>;
    if (translated.length != 2 ||
        !translated.containsKey('title') ||
        !translated.containsKey('labels')) {
      throw const FormatException('study_paid_translation_schema');
    }
    return _build(alternate: translated);
  }
}
