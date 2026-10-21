import 'dart:convert';
import 'canonical_clinical_snapshot.dart';
import 'plantao_lossless_source_layout.dart';

/// Presentation only: does not grant admission, approval or request authority.
/// The caller must supply the expected digest from its validated catalog, never
/// from the response/history object being decoded.
class PlantaoPresentationContract {
  PlantaoPresentationContract._(this._json);
  final String _json;
  Map<String, dynamic> get data => jsonDecode(_json) as Map<String, dynamic>;
  String get locale => data['locale'] as String;
  String get fullText => data['fullProtocolRef']['text'] as String;
  bool get isExecutive => data['level'] == 'EXECUTIVE';
  bool get hasLosslessSourceLayout => data['losslessSourceLayout'] is Map;
  String get contentHash => data['contentHash'] as String;
  static String textHash(String text) =>
      CanonicalClinicalSnapshot.textHash(text);
  static String digest(Map<String, dynamic> value) =>
      CanonicalClinicalSnapshot.hash({...value}..remove('contentHash'));

  factory PlantaoPresentationContract.fromCatalog(Map<String, dynamic> value,
      {required String expectedHash}) {
    void require(bool condition, String reason) {
      if (!condition) throw FormatException(reason);
    }

    bool text(dynamic v) => v is String && v.trim().isNotEmpty;
    bool strings(dynamic v) => v is List && v.every(text);
    require(
        RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash) &&
            value['contentHash'] == expectedHash &&
            digest(value) == expectedHash,
        'presentation_integrity');
    require(
        value['schemaVersion'] == 1 &&
            ['pt', 'es'].contains(value['locale']) &&
            ['EXECUTIVE', 'FULL'].contains(value['level']) &&
            text(value['clinicalTitle']) &&
            text(value['sourceVersion']),
        'presentation_identity');
    final full = value['fullProtocolRef'];
    final approval = value['clinicalApproval'];
    require(
        full is Map &&
            text(full['id']) &&
            text(full['text']) &&
            full['locale'] == value['locale'] &&
            full['sourceVersion'] == value['sourceVersion'] &&
            textHash(full['text']) == full['contentHash'],
        'full_protocol_integrity');
    require(
        approval is Map &&
            approval['status'] == 'APPROVED' &&
            text(approval['recordId']) &&
            approval['level'] == value['level'] &&
            approval['sourceHash'] == full['contentHash'],
        'presentation_approval');
    for (final field in [
      'immediateActions',
      'monitoring',
      'criticalAlerts',
      'references'
    ]) {
      require(strings(value[field]), 'presentation_$field');
    }
    require(value['medications'] is List, 'presentation_medications');
    for (final drug in value['medications']) {
      require(drug is Map, 'medication_object');
      for (final field in [
        'name',
        'dose',
        'unit',
        'route',
        'frequency',
        'strategy'
      ]) {
        require(text(drug[field]), 'medication_$field');
      }
      // Absence is allowed only as part of the exact approved presentation.
      // A supplied duration must remain nonempty; hashes prevent stripping it.
      require(!drug.containsKey('duration') || text(drug['duration']),
          'medication_duration');
      for (final field in ['conditions', 'alternatives', 'clinicalLimits']) {
        require(strings(drug[field]), 'medication_$field');
      }
      require(
          ['concomitant', 'alternative', 'conditional']
              .contains(drug['relation']),
          'medication_relation');
    }
    // FULL is exact source text. No inferred summary/dose extraction is allowed.
    if (value['level'] == 'FULL') {
      require(
          (value['medications'] as List).isEmpty &&
              (value['immediateActions'] as List).isEmpty &&
              (value['monitoring'] as List).isEmpty &&
              (value['criticalAlerts'] as List).isEmpty,
          'full_projection_not_exact');
    }
    if (value.containsKey('losslessSourceLayout')) {
      final proof = value['losslessSourceLayout'];
      require(
          value['level'] == 'FULL' &&
              proof is Map &&
              proof['payloadJson'] is String &&
              proof['projection'] is String &&
              textHash(proof['payloadJson']) ==
                  approval['catalogPayloadHash'] &&
              (full['text'] as String).endsWith(proof['projection']),
          'lossless_source_integrity');
      final derived = PlantaoLosslessSourceLayout.derive(
          proof['payloadJson'], proof['projection'], value['locale']);
      require(
          derived != null &&
              CanonicalClinicalSnapshot.hash(derived) ==
                  CanonicalClinicalSnapshot.hash(proof['layout']),
          'lossless_source_layout');
    }
    return PlantaoPresentationContract._(jsonEncode(value));
  }

  /// Adapter for the existing authenticated integral catalog format. Approval
  /// remains the upstream catalog's responsibility; this validates transport and
  /// preserves all bytes, without synthesizing medications or an executive.
  factory PlantaoPresentationContract.fromApprovedSource(
      Map<String, dynamic> source,
      {required String expectedSourceHash,
      required String locale,
      bool allowLosslessLayout = false}) {
    if (!['pt', 'es'].contains(locale)) {
      throw const FormatException('presentation_locale');
    }
    final snapshot = CanonicalClinicalSnapshot.fromApprovedProtocol(
        source, expectedSourceHash);
    final text = snapshot.blocks(locale).join();
    final value = <String, dynamic>{
      'schemaVersion': 1,
      'level': 'FULL',
      'clinicalTitle': source['owner'],
      'immediateActions': <String>[],
      'medications': <Object>[],
      'monitoring': <String>[],
      'criticalAlerts': <String>[],
      // References remain embedded in the exact validated full document.
      'references': <String>[],
      'locale': locale,
      'sourceVersion': source['version'],
      'clinicalApproval': {
        'status': 'APPROVED',
        'level': 'FULL',
        'recordId': source['review']['recordId'],
        'sourceHash': textHash(text),
        'catalogPayloadHash': expectedSourceHash,
      },
      'fullProtocolRef': {
        'id': source['owner'],
        'locale': locale,
        'sourceVersion': source['version'],
        'text': text,
        'contentHash': textHash(text),
      },
    };
    final projection = source['approvedProjections']?[locale];
    if (allowLosslessLayout && projection is String) {
      final layout = PlantaoLosslessSourceLayout.derive(
          source['approvedClinicalPayloadJson'], projection, locale);
      if (layout != null) {
        // This remains a FULL-source approval: no executive review is invented.
        // All clinical facts are visible; only bibliography is in the integral.
        value['losslessSourceLayout'] = {
          'payloadJson': source['approvedClinicalPayloadJson'],
          'projection': projection,
          'layout': layout,
        };
      }
    }
    value['contentHash'] = digest(value);
    return PlantaoPresentationContract.fromCatalog(value,
        expectedHash: value['contentHash'] as String);
  }

  /// Versioned optional history attachment. Legacy records need no migration.
  /// No transport or model call is available in this decoder.
  Map<String, dynamic> historyAttachment(String question, String requestId) {
    if (question.trim().isEmpty || requestId.isEmpty) {
      throw const FormatException('history_identity');
    }
    return {
      'schemaVersion': 1,
      'requestId': requestId,
      'originalQuestion': question,
      'presentation': data
    };
  }
}
