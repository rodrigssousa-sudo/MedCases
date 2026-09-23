import '../clinical_content/clinical_content_contract.dart';

/// Transport projection of the canonical clinical protocol registry, not a
/// second drug catalog. Clinical guides require a future explicit validator.
const therapeuticProtocolDomain = 'therapeuticProtocols';
const remoteKnowledgeTypes = {'clinical_protocol', 'prescription_protocol'};
String knowledgeText(Object? value, String language) {
  final map = contentObject(value);
  for (final lang in ['pt', 'es']) {
    requireContent(
        map[lang] is String && (map[lang] as String).trim().isNotEmpty,
        'LANGUAGE_INCOMPLETE');
  }
  requireContent(language == 'pt' || language == 'es', 'LANGUAGE_UNSUPPORTED');
  return map[language] as String;
}

String knowledgeId(Object? value) {
  requireContent(value is String && canonicalContentId.hasMatch(value),
      'IDENTITY_INVALID');
  return value as String;
}

const _clinicalKeys = [
  'schemaVersion',
  'contentType',
  'protocolId',
  'version',
  'languages',
  'title',
  'clinicalContext',
  'canonicalContextIds',
  'therapeuticOptions',
  'contextualFollowUps',
  'references'
];
String clinicalKnowledgeHash(Map<String, dynamic> value) =>
    contentHash({for (final key in _clinicalKeys) key: value[key]});

class RemoteKnowledgeProtocol {
  RemoteKnowledgeProtocol._(this.json);
  final Map<String, dynamic> json;
  String get id => json['protocolId'] as String;
  String get version => json['version'] as String;
  String get hash => json['clinicalContentSha256'] as String;
  List<String> get contextIds => List<String>.from(json['canonicalContextIds']);
  List<Map<String, dynamic>> get options =>
      (json['therapeuticOptions'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic> get primary =>
      options.singleWhere((o) => o['type'] == 'PRIMARY');
  List<Map<String, dynamic>> get alternatives => options
      .where((o) => o['type'] == 'ALTERNATIVE')
      .toList()
    ..sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));
  static RemoteKnowledgeProtocol parse(Map<String, dynamic> raw) {
    final j = contentObject(freezeContent(raw));
    requireContent(j['schemaVersion'] == 1, 'SCHEMA_UNSUPPORTED');
    requireContent(remoteKnowledgeTypes.contains(j['contentType']),
        'CONTENT_TYPE_UNSUPPORTED');
    knowledgeId(j['protocolId']);
    knowledgeId(j['version']);
    requireContent(
        j['languages'] is List &&
            (j['languages'] as List).length == 2 &&
            (j['languages'] as List).toSet().containsAll(['pt', 'es']),
        'LANGUAGE_INCOMPLETE');
    for (final key in ['title', 'clinicalContext']) {
      knowledgeText(j[key], 'pt');
    }
    final contexts = j['canonicalContextIds'];
    requireContent(contexts is List && contexts.isNotEmpty, 'CONTEXT_REQUIRED');
    for (final id in contexts as List) {
      knowledgeId(id);
    }
    final review = contentObject(j['clinicalReview']);
    requireContent(review['approved'] == true, 'NOT_APPROVED');
    requireContent(
        review['reviewer'] is String &&
            (review['reviewer'] as String).trim().isNotEmpty &&
            review['result'] is String &&
            (review['result'] as String).trim().isNotEmpty &&
            DateTime.tryParse('${review['reviewedAt']}') != null,
        'REVIEW_METADATA_REQUIRED');
    final pub = contentObject(j['publication']);
    requireContent(
        pub['status'] == 'PUBLISHED' &&
            pub['revokedAt'] == null &&
            pub['supersededBy'] == null,
        'NOT_PUBLISHED');
    requireContent(DateTime.tryParse('${pub['publishedAt']}') != null,
        'PUBLICATION_DATE_REQUIRED');
    requireContent(j['clinicalContentSha256'] == clinicalKnowledgeHash(j),
        'CLINICAL_HASH_MISMATCH');
    _rejectAuthority(j);
    if (j['contextualFollowUps'] != null) {
      requireContent(j['contextualFollowUps'] is List, 'FOLLOW_UP_INVALID');
      final followUpIds = <String>{};
      for (final rawFollowUp in j['contextualFollowUps'] as List) {
        final followUp = contentObject(rawFollowUp);
        requireContent(followUpIds.add(knowledgeId(followUp['id'])),
            'DUPLICATE_FOLLOW_UP');
        requireContent(
            {
              'allergy_alternative',
              'renal_adjustment',
              'hepatic_adjustment',
              'oral_alternative',
              'drug_unavailable',
              'pregnancy_context',
              'pediatric_context'
            }.contains(followUp['kind']),
            'FOLLOW_UP_KIND_INVALID');
        requireContent(
            followUp['applicable'] is bool, 'FOLLOW_UP_APPLICABILITY_REQUIRED');
        knowledgeText(followUp['label'], 'pt');
      }
    }
    final refs = j['references'];
    requireContent(refs is List && refs.isNotEmpty, 'REFERENCES_REQUIRED');
    final ids = <String>{};
    for (final rawRef in refs as List) {
      final ref = contentObject(rawRef);
      requireContent(
          ids.add(knowledgeId(ref['referenceId'])), 'DUPLICATE_REFERENCE');
      knowledgeText(ref['title'], 'pt');
      final uri = Uri.tryParse('${ref['url']}');
      requireContent(
          uri != null &&
              uri.scheme == 'https' &&
              uri.host.isNotEmpty &&
              uri.userInfo.isEmpty,
          'REFERENCE_INVALID');
    }
    final options = j['therapeuticOptions'];
    requireContent(
        options is List && options.isNotEmpty && options.length <= 20,
        'OPTIONS_INVALID');
    final optionIds = <String>{};
    var primary = 0;
    for (final rawOption in options as List) {
      final o = contentObject(rawOption);
      requireContent(
          optionIds.add(knowledgeId(o['optionId'])), 'DUPLICATE_OPTION');
      requireContent(o['type'] == 'PRIMARY' || o['type'] == 'ALTERNATIVE',
          'OPTION_TYPE_INVALID');
      if (o['type'] == 'PRIMARY') primary++;
      requireContent(
          o['priority'] is int && o['priority'] >= 0, 'PRIORITY_INVALID');
      requireContent(
          {'single_administration', 'scheduled', 'continuous_infusion'}
              .contains(o['prescriptionKind']),
          'PRESCRIPTION_KIND_REQUIRED');
      for (final key in ['label', 'indication', 'whenToConsider']) {
        knowledgeText(o[key], 'pt');
      }
      _references(o['references'], ids);
      final drugs = o['drugs'];
      requireContent(drugs is List && drugs.isNotEmpty && drugs.length <= 30,
          'DRUGS_INVALID');
      final drugIds = <String>{};
      for (final rawDrug in drugs as List) {
        final d = contentObject(rawDrug);
        requireContent(drugIds.add(knowledgeId(d['drugId'])), 'DUPLICATE_DRUG');
        knowledgeText(d['drugName'], 'pt');
        _references(d['references'], ids);
        for (final key in [
          'presentation',
          'route',
          'frequency',
          'duration',
          'preparation',
          'diluent',
          'renalAdjustment',
          'hepaticAdjustment',
          'contraindications',
          'warnings',
          'practicalPrescription'
        ]) {
          if (d[key] != null) knowledgeText(d[key], 'pt');
        }
        for (final key in ['dose', 'loadingDose', 'maintenanceDose']) {
          if (d[key] != null) {
            final dose = contentObject(d[key]);
            requireContent(dose['value'] is String && dose['unit'] is String,
                'DOSE_STRUCTURE_INVALID');
          }
        }
        for (final key in ['diluentVolumeMl', 'infusionMinutes']) {
          if (d[key] != null)
            requireContent(
                d[key] is num && (d[key] as num).isFinite && d[key] > 0,
                'NUMERIC_FIELD_INVALID');
        }
      }
    }
    requireContent(primary == 1, 'PRIMARY_COUNT_INVALID');
    return RemoteKnowledgeProtocol._(j);
  }

  static void _references(Object? value, Set<String> ids) {
    requireContent(
        value is List &&
            value.isNotEmpty &&
            value.every((v) => v is String && ids.contains(v)),
        'REFERENCE_BINDING_INVALID');
  }

  static void _rejectAuthority(Object? value) {
    if (value is Map) {
      for (final key in value.keys) {
        requireContent(
            !{
              'doseAuthority',
              'calculationAuthorized',
              'infusionAuthority',
              'pediatricAuthority',
              'clinicalAuthority'
            }.contains(key),
            'AUTHORITY_OVERRIDE_REJECTED');
        _rejectAuthority(value[key]);
      }
    } else if (value is List) {
      for (final child in value) {
        _rejectAuthority(child);
      }
    }
  }
}

/// Deterministic data projection. Formatting is never clinical authorization.
class PracticalPrescriptionFormatter {
  static String? format(Map<String, dynamic> option, String language) {
    try {
      if (language != 'pt' && language != 'es') return null;
      final kind = option['prescriptionKind'];
      if (!{'single_administration', 'scheduled', 'continuous_infusion'}
          .contains(kind)) return null;
      final es = language == 'es';
      final lines = [es ? 'PRESCRIPCIÓN PRÁCTICA' : 'PRESCRIÇÃO PRÁTICA', ''];
      final drugs = option['drugs'];
      if (drugs is! List || drugs.isEmpty) return null;
      var i = 0;
      for (final raw in drugs) {
        final d = contentObject(raw);
        final dose = contentObject(d['dose']);
        if (kind == 'scheduled' && d['duration'] == null) return null;
        if (kind == 'continuous_infusion' &&
            ['preparation', 'diluent', 'diluentVolumeMl', 'infusionMinutes']
                .any((k) => d[k] == null)) return null;
        for (final key in ['value', 'unit']) {
          if (dose[key] is! String || (dose[key] as String).trim().isEmpty)
            return null;
        }
        final name = knowledgeText(d['drugName'], language),
            presentation = knowledgeText(d['presentation'], language),
            route = knowledgeText(d['route'], language),
            frequency = knowledgeText(d['frequency'], language);
        if ([
          name,
          presentation,
          route,
          frequency,
          dose['value'],
          dose['unit']
        ].any((v) => '$v'.contains('\n') || '$v'.contains('\r'))) return null;
        lines.addAll([
          '${++i}. $name',
          '   ${es ? 'Presentación' : 'Apresentação'}: $presentation',
          '   ${es ? 'Dosis' : 'Dose'}: ${dose['value']} ${dose['unit']}'
        ]);
        for (final e in <String, String>{
          'preparation': es ? 'Preparación' : 'Preparo',
          'diluent': es ? 'Dilución' : 'Diluição'
        }.entries) {
          if (d[e.key] != null)
            lines.add('   ${e.value}: ${knowledgeText(d[e.key], language)}');
        }
        if (d['diluentVolumeMl'] != null)
          lines.add(
              '   ${es ? 'Volumen' : 'Volume'}: ${d['diluentVolumeMl']} mL');
        lines.add('   ${es ? 'Vía' : 'Via'}: $route');
        if (d['infusionMinutes'] != null)
          lines.add(
              '   ${es ? 'Infusión' : 'Infusão'}: ${d['infusionMinutes']} min');
        lines.add('   ${es ? 'Frecuencia' : 'Frequência'}: $frequency');
        if (d['duration'] != null)
          lines.add(
              '   ${es ? 'Duración' : 'Duração'}: ${knowledgeText(d['duration'], language)}');
        // Complex regimens need a dedicated typed copy contract; omission is unsafe.
        if ([
          'loadingDose',
          'maintenanceDose',
          'renalAdjustment',
          'hepaticAdjustment'
        ].any((k) => d[k] != null)) return null;
        lines.add('');
      }
      return lines.join('\n').trimRight();
    } catch (_) {
      return null;
    }
  }
}
