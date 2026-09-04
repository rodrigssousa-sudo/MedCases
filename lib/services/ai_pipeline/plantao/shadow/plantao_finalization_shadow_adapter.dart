import '../../../../models/clinical_structured_output.dart';
import '../../../ai/ai_finalization_transaction.dart';
import '../../../ai_stream/truncation_inspector.dart';
import '../../ai_request_contract.dart';
import '../../ai_response_finalization_processor.dart';
import '../../ai_truncation_repair_coordinator.dart';
import '../../plantao_local_clinical_output_adapter.dart';
import '../contracts/plantao_request.dart';
import 'plantao_finalization_shadow_snapshot.dart';
import 'plantao_response_structure_shadow_adapter.dart';

export 'plantao_finalization_shadow_snapshot.dart';

class _ShadowRepairDisabledPort implements AiTruncationRepairPort {
  const _ShadowRepairDisabledPort();

  @override
  Future<TruncationRepairResult> repair({
    required String originalText,
    required String requestId,
    required bool isPlantaoMode,
    required String appLanguage,
  }) async {
    return TruncationRepairResult.catastrophicFailure(
      'phase3d_shadow_repair_disabled',
    );
  }
}

/// Observes a productive final text using the canonical finalization components.
/// It never calls a provider, the public Plantão facade, Firestore, rendering or
/// persistence. Truncated output is reported as unavailable because repair is
/// intentionally disabled until provider ports are introduced.
class PlantaoFinalizationShadowAdapter {
  PlantaoFinalizationShadowAdapter({required this.processor});

  factory PlantaoFinalizationShadowAdapter.withExistingImplementations() {
    return PlantaoFinalizationShadowAdapter(
      processor: AiResponseFinalizationProcessor(
        truncationCoordinator: AiTruncationRepairCoordinator(
          repairPort: const _ShadowRepairDisabledPort(),
        ),
      ),
    );
  }

  static const bool productiveExecutionEnabled = false;
  static const bool providerConnected = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;
  static const bool ragConnected = false;

  final AiResponseFinalizationProcessor processor;

  Future<PlantaoFinalizationShadowSnapshot> finalize({
    required PlantaoRequest request,
    required String finalText,
    ClinicalStructuredOutput? structuredOutput,
    String providerLabel = 'shadow_observed_output',
    int attempt = 1,
    String? providerFinishReason,
  }) async {
    request.ensureValid();
    final observedAt = DateTime.now().toUtc();

    try {
      final outcome = await processor.process(
        snapshot: FinalOutputSnapshot(
          rawOutput: finalText,
          sessionId: request.sessionId,
          parentRequestId: request.requestId,
          frozenAt: observedAt,
        ),
        mode: AiRequestMode.plantao,
        locale: request.language == PlantaoLanguage.es
            ? AiRequestLocale.es
            : AiRequestLocale.pt,
        provider: providerLabel,
        attempt: attempt,
        providerFinishReason: providerFinishReason,
        structuredOutput: structuredOutput,
      );

      if (!outcome.isReady) {
        return PlantaoFinalizationShadowSnapshot(
          requestId: request.requestId,
          status: outcome.status == AiResponseFinalizationStatus.repairFailed
              ? PlantaoFinalizationShadowStatus.repairUnavailable
              : PlantaoFinalizationShadowStatus.rejected,
          rawText: finalText,
          sanitizedText: outcome.sanitization?.text ?? '',
          canonicalStatus: outcome.status.name,
          usedBackendStructuredOutput: structuredOutput != null,
          usedLocalClinicalAdapter: false,
          usedPlantaoParser: outcome.structure?.plantaoResponse != null,
          deferredMedicationCount: 0,
          missingRequestedSections: request.requestedSections
              .map((item) => item.name)
              .toList(growable: false),
          observedAt: observedAt,
          failureCode: outcome.failureCode,
          failureReason: outcome.failureReason,
        );
      }

      final sanitizedText = outcome.result!.finalText;
      var clinicalOutput = outcome.structure?.clinicalOutput;
      var usedLocalClinicalAdapter = false;
      if (clinicalOutput == null) {
        clinicalOutput = PlantaoLocalClinicalOutputAdapter.fromValidatedText(
          sanitizedText,
        );
        usedLocalClinicalAdapter = clinicalOutput != null;
      }

      final structured = PlantaoResponseStructureShadowAdapter.build(
        request: request,
        parsed: outcome.structure!,
        clinicalOutput: clinicalOutput,
      );

      return PlantaoFinalizationShadowSnapshot(
        requestId: request.requestId,
        status: structured.hasSections
            ? PlantaoFinalizationShadowStatus.structured
            : PlantaoFinalizationShadowStatus.textOnly,
        rawText: finalText,
        sanitizedText: sanitizedText,
        canonicalStatus: outcome.status.name,
        structure: structured.structure,
        clinicalOutput: clinicalOutput,
        usedBackendStructuredOutput: structuredOutput != null,
        usedLocalClinicalAdapter: usedLocalClinicalAdapter,
        usedPlantaoParser: structured.usedPlantaoParser,
        deferredMedicationCount: structured.deferredMedicationCount,
        missingRequestedSections: structured.missingRequestedSections
            .map((item) => item.name)
            .toList(growable: false),
        observedAt: observedAt,
      );
    } catch (error) {
      return PlantaoFinalizationShadowSnapshot(
        requestId: request.requestId,
        status: PlantaoFinalizationShadowStatus.failed,
        rawText: finalText,
        sanitizedText: '',
        canonicalStatus: 'exception',
        usedBackendStructuredOutput: structuredOutput != null,
        usedLocalClinicalAdapter: false,
        usedPlantaoParser: false,
        deferredMedicationCount: 0,
        missingRequestedSections: request.requestedSections
            .map((item) => item.name)
            .toList(growable: false),
        observedAt: observedAt,
        failureCode: 'phase3d_shadow_exception',
        failureReason: error.runtimeType.toString(),
      );
    } finally {
      processor.release(request.requestId);
    }
  }
}
