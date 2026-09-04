enum AiTerminalCause {
  completed,
  error,
  timeout,
  cancelled,
  partial,
  fallback,
}

enum AiPersistenceStatus {
  notAttempted,
  persisted,
  skipped,
  queuedOffline,
  authDenied,
  failed,
}

enum AiRepairStatus {
  notAttempted,
  notNeeded,
  repaired,
  failed,
}

class AiResponseResult {
  final String requestId;
  final String sessionId;
  final String finalText;
  final String displayText;
  final String? provider;
  final int attempt;
  final AiTerminalCause terminalCause;
  final bool isPartial;
  final bool isFallback;
  final AiRepairStatus repairStatus;
  final Object? structuredOutput;
  final List<Object?> references;
  final Object? toolResolution;
  final Object? nextAction;
  final AiPersistenceStatus persistenceStatus;
  final String? errorCode;
  final String? errorMessage;

  AiResponseResult({
    required this.requestId,
    required this.sessionId,
    required this.finalText,
    required this.displayText,
    required this.terminalCause,
    required this.persistenceStatus,
    this.provider,
    this.attempt = 1,
    this.isPartial = false,
    this.isFallback = false,
    this.repairStatus = AiRepairStatus.notAttempted,
    this.structuredOutput,
    List<Object?> references = const <Object?>[],
    this.toolResolution,
    this.nextAction,
    this.errorCode,
    this.errorMessage,
  })  : assert(requestId != ''),
        assert(sessionId != ''),
        assert(attempt > 0),
        references = List<Object?>.unmodifiable(references);
}
