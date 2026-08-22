import '../../../../models/clinical_structured_output.dart';
import '../contracts/plantao_response_structure.dart';

enum PlantaoFinalizationShadowStatus {
  structured,
  textOnly,
  repairUnavailable,
  rejected,
  failed,
}

class PlantaoFinalizationShadowSnapshot {
  const PlantaoFinalizationShadowSnapshot({
    required this.requestId,
    required this.status,
    required this.rawText,
    required this.sanitizedText,
    required this.canonicalStatus,
    required this.usedBackendStructuredOutput,
    required this.usedLocalClinicalAdapter,
    required this.usedPlantaoParser,
    required this.deferredMedicationCount,
    required this.missingRequestedSections,
    required this.observedAt,
    this.structure,
    this.clinicalOutput,
    this.failureCode,
    this.failureReason,
  });

  static const bool productiveExecutionEnabled = false;
  static const bool providerConnected = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;
  static const bool ragConnected = false;

  final String requestId;
  final PlantaoFinalizationShadowStatus status;
  final String rawText;
  final String sanitizedText;
  final String canonicalStatus;
  final PlantaoResponseStructure? structure;
  final ClinicalStructuredOutput? clinicalOutput;
  final bool usedBackendStructuredOutput;
  final bool usedLocalClinicalAdapter;
  final bool usedPlantaoParser;
  final int deferredMedicationCount;
  final List<String> missingRequestedSections;
  final DateTime observedAt;
  final String? failureCode;
  final String? failureReason;

  bool get isReady =>
      status == PlantaoFinalizationShadowStatus.structured ||
      status == PlantaoFinalizationShadowStatus.textOnly;
}
