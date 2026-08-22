import 'ai_request_contract.dart';
import 'ai_response_event.dart';

abstract class AiResponsePipeline {
  Stream<AiResponseEvent> execute(AiRequestContract request);
}

typedef AiResponsePipelineRunner = Stream<AiResponseEvent> Function(
  AiRequestContract request,
);

class DelegatingAiResponsePipeline implements AiResponsePipeline {
  final AiResponsePipelineRunner runner;

  const DelegatingAiResponsePipeline(this.runner);

  @override
  Stream<AiResponseEvent> execute(AiRequestContract request) {
    return runner(request);
  }
}
