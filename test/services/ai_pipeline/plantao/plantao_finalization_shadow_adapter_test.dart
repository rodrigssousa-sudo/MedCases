import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai_pipeline/ai_response_finalization_processor.dart';
import 'package:medcases/services/ai_pipeline/ai_response_sanitizer.dart';
import 'package:medcases/services/ai_pipeline/ai_response_structure_parser.dart';
import 'package:medcases/services/ai_pipeline/ai_truncation_repair_coordinator.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_finalization_shadow_adapter.dart';
import 'package:medcases/services/ai_stream/truncation_inspector.dart';
import 'package:medcases/services/plantao_pipeline.dart';

class _Inspector implements AiTruncationInspectorPort {
  const _Inspector(this.result);
  final TruncationCheckResult result;
  @override
  TruncationCheckResult inspect(String text) => result;
}

class _Repair implements AiTruncationRepairPort {
  int calls = 0;
  @override
  Future<TruncationRepairResult> repair({
    required String originalText,
    required String requestId,
    required bool isPlantaoMode,
    required String appLanguage,
  }) async {
    calls++;
    return TruncationRepairResult.catastrophicFailure('shadow-disabled');
  }
}

class _Sanitizer implements AiResponseSanitizerPort {
  @override
  AiResponseSanitizationOutcome sanitize({
    required String text,
    required AiRequestMode mode,
    required AiRequestLocale locale,
  }) {
    return AiResponseSanitizationOutcome(
      originalText: text,
      text: text,
      mode: mode,
      locale: locale,
      hadMetaLeak: false,
      hadSevereLeak: false,
      isRecoverable: true,
    );
  }
}

class _Parser implements AiPlantaoParserPort {
  @override
  PlantaoResponse? parse(String text) {
    return const PlantaoResponse(
      conduta: 'Choque séptico',
      primeiraLinha: 'Noradrenalina 0,05 mcg/kg/min EV',
      monitorar: 'PAM e diurese',
    );
  }
}

PlantaoRequest request(String id) => PlantaoRequest(
      requestId: id,
      sessionId: 'session-1',
      question: 'Manejo de choque séptico',
      language: PlantaoLanguage.ptBr,
      trigger: PlantaoRequestTrigger.userInput,
      continuationType: PlantaoContinuationType.initial,
      requestedSections: const <PlantaoSection>[],
    );

void main() {
  test('canonical shadow finalization returns structured text without provider', () async {
    final repair = _Repair();
    final processor = AiResponseFinalizationProcessor(
      truncationCoordinator: AiTruncationRepairCoordinator(
        inspector: const _Inspector(
          TruncationCheckResult(
            isTruncated: false,
            confidenceLevel: TruncationConfidence.low,
            violationReason: 'none',
          ),
        ),
        repairPort: repair,
      ),
      sanitizer: AiResponseSanitizer(port: _Sanitizer()),
      structureParser: AiResponseStructureParser(plantaoParser: _Parser()),
    );
    final adapter = PlantaoFinalizationShadowAdapter(processor: processor);

    final snapshot = await adapter.finalize(
      request: request('req-ready'),
      finalText: '🟥 Choque séptico\n💊 Noradrenalina 0,05 mcg/kg/min EV',
    );

    expect(snapshot.status, PlantaoFinalizationShadowStatus.structured);
    expect(snapshot.structure, isNotNull);
    expect(snapshot.sanitizedText, isNotEmpty);
    expect(repair.calls, 0);
    expect(PlantaoFinalizationShadowAdapter.providerConnected, isFalse);
  });

  test('truncated output is observationally unavailable without repair provider', () async {
    final repair = _Repair();
    final processor = AiResponseFinalizationProcessor(
      truncationCoordinator: AiTruncationRepairCoordinator(
        inspector: const _Inspector(
          TruncationCheckResult(
            isTruncated: true,
            confidenceLevel: TruncationConfidence.high,
            violationReason: 'test-truncated',
          ),
        ),
        repairPort: repair,
      ),
      sanitizer: AiResponseSanitizer(port: _Sanitizer()),
      structureParser: AiResponseStructureParser(plantaoParser: _Parser()),
    );
    final adapter = PlantaoFinalizationShadowAdapter(processor: processor);

    final snapshot = await adapter.finalize(
      request: request('req-truncated'),
      finalText: 'Resposta interrompida...',
    );

    expect(snapshot.status, PlantaoFinalizationShadowStatus.repairUnavailable);
    expect(snapshot.failureCode, 'truncation_repair_failed');
    expect(repair.calls, 1);
  });
}
