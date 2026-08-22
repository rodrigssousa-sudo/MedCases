import 'plantao_continuation_type.dart';

enum PlantaoSourceMode {
  localRag,
  firestoreRag,
  modelNative,
  externalGrounding,
  mixed,
}

extension PlantaoSourceModeWire on PlantaoSourceMode {
  String get wireName {
    switch (this) {
      case PlantaoSourceMode.localRag:
        return 'local_rag';
      case PlantaoSourceMode.firestoreRag:
        return 'firestore_rag';
      case PlantaoSourceMode.modelNative:
        return 'model_native';
      case PlantaoSourceMode.externalGrounding:
        return 'external_grounding';
      case PlantaoSourceMode.mixed:
        return 'mixed';
    }
  }
}

PlantaoSourceMode plantaoSourceModeFromWire(String value) {
  switch (value) {
    case 'local_rag':
      return PlantaoSourceMode.localRag;
    case 'firestore_rag':
      return PlantaoSourceMode.firestoreRag;
    case 'model_native':
      return PlantaoSourceMode.modelNative;
    case 'external_grounding':
      return PlantaoSourceMode.externalGrounding;
    case 'mixed':
      return PlantaoSourceMode.mixed;
  }
  throw FormatException('Unknown PlantaoSourceMode: $value');
}

class PlantaoProvenance {
  PlantaoProvenance({
    required this.provider,
    required this.model,
    required this.sourceMode,
    required Iterable<String> matchedClinicalDocumentIds,
    required Iterable<String> matchedDrugDocumentIds,
    required this.validatedDose,
    required this.validatorReason,
    required this.usedExternalGrounding,
    required this.continuationType,
    required Map<String, String> documentVersions,
  }) : matchedClinicalDocumentIds = List<String>.unmodifiable(
         matchedClinicalDocumentIds,
       ),
       matchedDrugDocumentIds = List<String>.unmodifiable(
         matchedDrugDocumentIds,
       ),
       documentVersions = Map<String, String>.unmodifiable(documentVersions);

  final String provider;
  final String model;
  final PlantaoSourceMode sourceMode;
  final List<String> matchedClinicalDocumentIds;
  final List<String> matchedDrugDocumentIds;
  final bool validatedDose;
  final String validatorReason;
  final bool usedExternalGrounding;
  final PlantaoContinuationType continuationType;
  final Map<String, String> documentVersions;

  bool isStrictModeCompatible({required bool containsSensitivePharmacology}) {
    return !(containsSensitivePharmacology &&
        sourceMode == PlantaoSourceMode.modelNative);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'provider': provider,
      'model': model,
      'sourceMode': sourceMode.wireName,
      'matchedClinicalDocumentIds': matchedClinicalDocumentIds,
      'matchedDrugDocumentIds': matchedDrugDocumentIds,
      'validatedDose': validatedDose,
      'validatorReason': validatorReason,
      'usedExternalGrounding': usedExternalGrounding,
      'continuationType': continuationType.name,
      'documentVersions': documentVersions,
    };
  }

  factory PlantaoProvenance.fromJson(Map<String, Object?> json) {
    return PlantaoProvenance(
      provider: json['provider'] as String,
      model: json['model'] as String,
      sourceMode: plantaoSourceModeFromWire(json['sourceMode'] as String),
      matchedClinicalDocumentIds: _stringList(
        json['matchedClinicalDocumentIds'],
      ),
      matchedDrugDocumentIds: _stringList(json['matchedDrugDocumentIds']),
      validatedDose: json['validatedDose'] as bool,
      validatorReason: json['validatorReason'] as String,
      usedExternalGrounding: json['usedExternalGrounding'] as bool,
      continuationType: plantaoContinuationTypeFromWire(
        json['continuationType'] as String,
      ),
      documentVersions: _stringMap(json['documentVersions']),
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('Expected a string list');
  }
  return value.map((Object? item) => item as String).toList();
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected a string map');
  }
  return value.map(
    (Object? key, Object? item) =>
        MapEntry<String, String>(key as String, item as String),
  );
}
