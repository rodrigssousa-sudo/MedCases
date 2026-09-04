import 'ai_response_result.dart';

abstract class AiResponseEvent {
  final String requestId;
  final String sessionId;

  const AiResponseEvent({
    required this.requestId,
    required this.sessionId,
  });
}

class AiResponseStarted extends AiResponseEvent {
  final String? provider;
  final int attempt;

  const AiResponseStarted({
    required super.requestId,
    required super.sessionId,
    this.provider,
    this.attempt = 1,
  }) : assert(attempt > 0);
}

class AiResponseDelta extends AiResponseEvent {
  final String delta;
  final String accumulatedText;
  final String? provider;
  final int attempt;

  /// Indica que o callback recebido não continuava o acumulador anterior.
  ///
  /// Nesse caso, [delta] contém o snapshot substituto completo, e não
  /// somente os novos caracteres.
  final bool replacesAccumulatedText;

  const AiResponseDelta({
    required super.requestId,
    required super.sessionId,
    required this.delta,
    required this.accumulatedText,
    this.provider,
    this.attempt = 1,
    this.replacesAccumulatedText = false,
  }) : assert(attempt > 0);
}

class AiResponseTerminal extends AiResponseEvent {
  final AiResponseResult result;

  const AiResponseTerminal({
    required super.requestId,
    required super.sessionId,
    required this.result,
  });
}
