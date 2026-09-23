import 'dart:convert';
import 'package:cryptography/dart.dart';

const clinicalDomains = <String, String>{
  'therapeuticProtocols': 'clinical_protocol_registry',
  'guides': 'clinical_guides',
  'drugs': 'medcases-calculadora',
  'protocols': 'clinical_protocol_registry',
  'cases': 'clinical_case_registry',
  'contexts': 'clinical_context_registry',
  'simulations': 'active_simulation_registry',
  'references': 'clinical_evidence_registry',
  'interactions': 'medcases-calculadora',
  'drugEvidence': 'medcases-calculadora',
  'clinicalRules': 'clinical_management_rules',
  'reviewMetadata': 'clinical_review_registry',
};
const publicationStates = {
  'DRAFT',
  'REVIEWED',
  'CANARY',
  'PRODUCTION',
  'REVOKED'
};
final canonicalContentId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,199}$');

class ContentFailure implements Exception {
  const ContentFailure(this.code);
  final String code;
  @override
  String toString() => 'ContentFailure($code)';
}

void requireContent(bool valid, String code) {
  if (!valid) throw ContentFailure(code);
}

Object? canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: canonicalJson(value[key])};
  }
  if (value is List) return value.map(canonicalJson).toList();
  return value;
}

String contentHash(Object? value) => const DartSha256()
    .hashSync(utf8.encode(jsonEncode(canonicalJson(value))))
    .bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();
String itemContentHash(Map<String, dynamic> item) =>
    contentHash({...item}..remove('contentHash'));
Map<String, dynamic> contentObject(Object? value) {
  requireContent(value is Map<String, dynamic>, 'INVALID_OBJECT');
  return value as Map<String, dynamic>;
}

Object? freezeContent(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
        value.map((key, v) => MapEntry(key, freezeContent(v))));
  }
  if (value is List) return List.unmodifiable(value.map(freezeContent));
  return value;
}

void validateVersionedContent(Map<String, dynamic> data, int appSchema,
    {bool item = false}) {
  requireContent(data['schemaVersion'] == '1.0', 'SCHEMA_MISMATCH');
  requireContent(
      data['contentVersion'] is String &&
          (data['contentVersion'] as String).isNotEmpty,
      'VERSION_MISSING');
  requireContent(
      data['contentHash'] is String &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(data['contentHash']),
      'HASH_INVALID');
  requireContent(publicationStates.contains(data['publicationStatus']),
      'PUBLICATION_INVALID');
  requireContent(
      DateTime.tryParse('${data[item ? 'updatedAt' : 'generatedAt']}') != null,
      'TIMESTAMP_MISSING');
  if (item) {
    requireContent(
        data['canonicalId'] is String &&
            canonicalContentId.hasMatch(data['canonicalId']),
        'INVALID_CANONICAL_ID');
  } else {
    requireContent(
        data['minimumAppSchema'] is int &&
            data['minimumAppSchema'] >= 1 &&
            data['minimumAppSchema'] <= appSchema,
        'INCOMPATIBLE_MINIMUM_SCHEMA');
    requireContent(
        data['itemCount'] is int && data['itemCount'] >= 0, 'COUNT_INVALID');
  }
}

/// Structural parity only. No automatic translation or clinical equivalence.
void validateLanguageParity(Map<String, dynamic> payload) {
  void walk(Object? node) {
    if (node is Map) {
      if (node.containsKey('pt') || node.containsKey('es')) {
        requireContent(
            node.containsKey('pt') && node.containsKey('es'), 'PT_ES_MISSING');
        Object? shape(Object? v) {
          if (v is Map) return {for (final k in v.keys) k: shape(v[k])};
          if (v is List) return v.map(shape).toList();
          if (v is String) {
            requireContent(v.trim().isNotEmpty, 'PT_ES_EMPTY');
            return 'text';
          }
          return v.runtimeType.toString();
        }

        requireContent(
            contentHash(shape(node['pt'])) == contentHash(shape(node['es'])),
            'PT_ES_STRUCTURE');
        if (node['pt'] is Map && node['es'] is Map) {
          for (final field in ['canonicalId', 'contentVersion', 'references']) {
            final a = node['pt'][field], b = node['es'][field];
            if (a != null || b != null) {
              requireContent(contentHash(a) == contentHash(b), 'PT_ES_$field');
            }
          }
        }
      }
      for (final child in node.values) {
        walk(child);
      }
    } else if (node is List) {
      for (final child in node) {
        walk(child);
      }
    }
  }

  walk(payload);
}

class ClinicalContentItem {
  ClinicalContentItem(Map<String, dynamic> envelope)
      : envelope = freezeContent(envelope) as Map<String, dynamic>;
  final Map<String, dynamic> envelope;
  String get canonicalId => envelope['canonicalId'] as String;
  Map<String, dynamic> get payload =>
      envelope['payload'] as Map<String, dynamic>;
  bool get catalogVisible => true;
  bool get clinicalAuthority => false;
  bool get calculationAuthorized => false;
  bool get infusionAuthority => false;
  bool get doseAuthority => false;
  String get infusionBindingStatus => 'FAIL_CLOSED_UNRESOLVED_BINDING';
}
