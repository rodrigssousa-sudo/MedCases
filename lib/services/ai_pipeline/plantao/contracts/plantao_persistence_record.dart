import 'plantao_continuation_type.dart';
import 'plantao_provenance.dart';
import 'plantao_request.dart';
import 'plantao_response_structure.dart';
import 'plantao_section.dart';

enum PlantaoPersistenceRecordStatus {
  prepared,
  blocked,
  unavailable,
  failed,
}

class PlantaoPersistenceRecordValidationException implements Exception {
  PlantaoPersistenceRecordValidationException(this.violations);

  final List<String> violations;

  @override
  String toString() {
    return 'PlantaoPersistenceRecordValidationException('
        '${violations.join(', ')})';
  }
}

class PlantaoPersistenceRecord {
  PlantaoPersistenceRecord({
    this.schemaVersion = currentSchemaVersion,
    required this.recordId,
    required this.requestId,
    required this.sessionId,
    required this.language,
    required this.trigger,
    required this.continuationType,
    required Iterable<PlantaoSection> requestedSections,
    required this.status,
    required this.finalizationStatus,
    required this.validationStatus,
    required this.sanitizedText,
    required this.structure,
    required this.provenance,
    required Iterable<String> reasons,
    required this.strictModeCompatible,
    required this.futurePersistenceEligible,
    required this.observedAt,
  })  : requestedSections =
            List<PlantaoSection>.unmodifiable(requestedSections),
        reasons = List<String>.unmodifiable(reasons);

  static const int currentSchemaVersion = 1;
  static const String mode = 'plantao';
  static const bool productionHistoryEligible = false;
  static const bool containsRawQuestion = false;
  static const bool containsPatientContext = false;

  final int schemaVersion;
  final String recordId;
  final String requestId;
  final String sessionId;
  final PlantaoLanguage language;
  final PlantaoRequestTrigger trigger;
  final PlantaoContinuationType continuationType;
  final List<PlantaoSection> requestedSections;
  final PlantaoPersistenceRecordStatus status;
  final String finalizationStatus;
  final String validationStatus;
  final String sanitizedText;
  final PlantaoResponseStructure? structure;
  final PlantaoProvenance provenance;
  final List<String> reasons;
  final bool strictModeCompatible;
  final bool futurePersistenceEligible;
  final DateTime observedAt;

  List<String> validate() {
    final violations = <String>[];
    if (schemaVersion != currentSchemaVersion) {
      violations.add('unsupported schemaVersion');
    }
    if (recordId.trim().isEmpty) violations.add('recordId must not be empty');
    if (requestId.trim().isEmpty) {
      violations.add('requestId must not be empty');
    }
    if (sessionId.trim().isEmpty) {
      violations.add('sessionId must not be empty');
    }
    if (provenance.continuationType != continuationType) {
      violations.add('provenance continuationType mismatch');
    }
    if (futurePersistenceEligible && !strictModeCompatible) {
      violations.add('future persistence requires strict mode compatibility');
    }
    if (futurePersistenceEligible && sanitizedText.trim().isEmpty) {
      violations.add('future persistence requires sanitized text');
    }
    if (futurePersistenceEligible && status != PlantaoPersistenceRecordStatus.prepared) {
      violations.add('future persistence requires prepared status');
    }
    return List<String>.unmodifiable(violations);
  }

  void ensureValid() {
    final violations = validate();
    if (violations.isNotEmpty) {
      throw PlantaoPersistenceRecordValidationException(violations);
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'recordId': recordId,
      'requestId': requestId,
      'sessionId': sessionId,
      'language': language.wireName,
      'mode': mode,
      'trigger': trigger.wireName,
      'continuationType': continuationType.name,
      'requestedSections': requestedSections
          .map((PlantaoSection section) => section.name)
          .toList(growable: false),
      'status': status.name,
      'finalizationStatus': finalizationStatus,
      'validationStatus': validationStatus,
      'sanitizedText': sanitizedText,
      'structure': structure?.toJson(),
      'provenance': provenance.toJson(),
      'reasons': reasons,
      'strictModeCompatible': strictModeCompatible,
      'futurePersistenceEligible': futurePersistenceEligible,
      'observedAt': observedAt.toUtc().toIso8601String(),
      'productionHistoryEligible': productionHistoryEligible,
      'containsRawQuestion': containsRawQuestion,
      'containsPatientContext': containsPatientContext,
    };
  }

  factory PlantaoPersistenceRecord.fromJson(Map<String, Object?> json) {
    if (json['mode'] != mode) {
      throw const FormatException('PlantaoPersistenceRecord mode must be plantao');
    }
    final rawSections = json['requestedSections'];
    final rawReasons = json['reasons'];
    if (rawSections is! List<Object?> || rawReasons is! List<Object?>) {
      throw const FormatException('requestedSections and reasons must be lists');
    }
    final rawStructure = json['structure'];
    final record = PlantaoPersistenceRecord(
      schemaVersion: json['schemaVersion'] as int,
      recordId: json['recordId'] as String,
      requestId: json['requestId'] as String,
      sessionId: json['sessionId'] as String,
      language: plantaoLanguageFromWire(json['language'] as String),
      trigger: plantaoRequestTriggerFromWire(json['trigger'] as String),
      continuationType: plantaoContinuationTypeFromWire(
        json['continuationType'] as String,
      ),
      requestedSections: rawSections.map(
        (Object? item) => plantaoSectionFromWire(item as String),
      ),
      status: PlantaoPersistenceRecordStatus.values.byName(
        json['status'] as String,
      ),
      finalizationStatus: json['finalizationStatus'] as String,
      validationStatus: json['validationStatus'] as String,
      sanitizedText: json['sanitizedText'] as String,
      structure: rawStructure == null
          ? null
          : PlantaoResponseStructure.fromJson(_objectMap(rawStructure)),
      provenance: PlantaoProvenance.fromJson(
        _objectMap(json['provenance']),
      ),
      reasons: rawReasons.map((Object? item) => item as String),
      strictModeCompatible: json['strictModeCompatible'] as bool,
      futurePersistenceEligible: json['futurePersistenceEligible'] as bool,
      observedAt: DateTime.parse(json['observedAt'] as String).toUtc(),
    );
    record.ensureValid();
    return record;
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected an object map');
  }
  return value.map(
    (Object? key, Object? item) =>
        MapEntry<String, Object?>(key as String, item),
  );
}
