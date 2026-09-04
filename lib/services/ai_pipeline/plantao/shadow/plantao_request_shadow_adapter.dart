import '../contracts/plantao_continuation_type.dart';
import '../contracts/plantao_request.dart';
import '../contracts/plantao_section.dart';

/// Pure Phase 3C adapter. It only constructs a typed request for observation.
/// It never invokes providers, persistence, rendering, RAG or the public
/// pipeline execution entrypoint.
class PlantaoRequestShadowAdapter {
  const PlantaoRequestShadowAdapter._();

  static const bool productiveExecutionEnabled = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;

  static PlantaoRequest build({
    required String requestId,
    required String sessionId,
    required String question,
    required String languageCode,
    required bool fromButton,
    required PlantaoContinuationType continuationType,
    required Iterable<PlantaoSection> requestedSections,
    Map<String, Object?>? patientContext,
    Map<String, Object?>? memoryContext,
    Map<String, Object?>? clientContext,
  }) {
    final effectiveContinuation = fromButton
        ? continuationType
        : PlantaoContinuationType.initial;
    final effectiveSections = fromButton
        ? List<PlantaoSection>.unmodifiable(requestedSections)
        : const <PlantaoSection>[];

    final request = PlantaoRequest(
      requestId: requestId,
      sessionId: sessionId,
      question: question,
      language: _languageFromAppCode(languageCode),
      trigger: fromButton
          ? PlantaoRequestTrigger.nextAction
          : PlantaoRequestTrigger.userInput,
      continuationType: effectiveContinuation,
      requestedSections: effectiveSections,
      strictClinicalMode: true,
      patientContext: patientContext,
      memoryContext: memoryContext,
      clientContext: <String, Object?>{
        ...?clientContext,
        'shadowMode': true,
        'productiveExecutionEnabled': productiveExecutionEnabled,
        'renderingEnabled': renderingEnabled,
        'persistenceEnabled': persistenceEnabled,
      },
    );

    request.ensureValid();
    return request;
  }

  static PlantaoLanguage _languageFromAppCode(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'es' || normalized.startsWith('es_')) {
      return PlantaoLanguage.es;
    }
    return PlantaoLanguage.ptBr;
  }
}
