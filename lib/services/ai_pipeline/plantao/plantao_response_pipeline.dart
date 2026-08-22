import 'contracts/plantao_pipeline_event.dart';
import 'contracts/plantao_request.dart';

class PlantaoResponsePipeline {
  const PlantaoResponsePipeline();

  static const bool productiveConnectionEnabled = false;
  static const String unavailableReasonCode = 'phase3b_unconnected_facade';

  Stream<PlantaoPipelineEvent> execute(PlantaoRequest request) async* {
    request.ensureValid();

    yield PlantaoPipelineStarted(
      requestId: request.requestId,
      sequence: 0,
      occurredAt: DateTime.now().toUtc(),
    );

    yield PlantaoPipelineUnavailable(
      requestId: request.requestId,
      sequence: 1,
      occurredAt: DateTime.now().toUtc(),
      reasonCode: unavailableReasonCode,
      message:
          'PlantaoResponsePipeline is intentionally not connected '
          'during Phase 3B.',
    );
  }
}
