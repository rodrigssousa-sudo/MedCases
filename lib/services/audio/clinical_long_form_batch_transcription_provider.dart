final class ClinicalLongFormBatchTranscriptionRequest {
  const ClinicalLongFormBatchTranscriptionRequest({
    required this.sessionId,
    required this.locale,
    required this.segmentIndex,
    required this.segmentPath,
    required this.deduplicationKey,
    this.previousContext,
  });

  final String sessionId;
  final String locale;
  final int segmentIndex;
  final String segmentPath;
  final String deduplicationKey;

  /// Contexto textual opcional e limitado de segmento anterior.
  /// Não é obrigatório e nenhum provider real existe nesta build.
  final String? previousContext;

  void validate() {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    if (locale.trim().isEmpty) {
      throw ArgumentError.value(locale, 'locale');
    }
    if (segmentIndex < 0) {
      throw ArgumentError.value(segmentIndex, 'segmentIndex');
    }
    if (!segmentPath.toLowerCase().endsWith('.m4a')) {
      throw ArgumentError.value(segmentPath, 'segmentPath');
    }
    if (deduplicationKey.trim().isEmpty) {
      throw ArgumentError.value(
        deduplicationKey,
        'deduplicationKey',
      );
    }

    final context = previousContext;
    if (context != null && context.length > 1200) {
      throw ArgumentError.value(
        context.length,
        'previousContext.length',
      );
    }
  }
}

final class ClinicalLongFormBatchTranscriptionResult {
  const ClinicalLongFormBatchTranscriptionResult({
    required this.segmentIndex,
    required this.deduplicationKey,
    required this.transcript,
    required this.resultRef,
  });

  final int segmentIndex;
  final String deduplicationKey;
  final String transcript;

  /// Referência opaca para futura camada de persistência/backend.
  final String resultRef;

  void validateAgainst(
    ClinicalLongFormBatchTranscriptionRequest request,
  ) {
    if (segmentIndex != request.segmentIndex) {
      throw StateError('Batch result segment mismatch.');
    }
    if (deduplicationKey != request.deduplicationKey) {
      throw StateError('Batch result deduplication mismatch.');
    }
    if (transcript.trim().isEmpty) {
      throw StateError('Batch transcript cannot be empty.');
    }
    if (resultRef.trim().isEmpty || resultRef.length > 240) {
      throw StateError('Invalid opaque resultRef.');
    }
  }
}

final class ClinicalLongFormBatchTranscriptionException implements Exception {
  const ClinicalLongFormBatchTranscriptionException(
    this.code, {
    this.retryable = true,
  });

  final String code;
  final bool retryable;

  @override
  String toString() => 'ClinicalLongFormBatchTranscriptionException('
      'code: $code, retryable: $retryable)';
}

abstract interface class ClinicalLongFormBatchTranscriptionProvider {
  String get providerId;

  Future<ClinicalLongFormBatchTranscriptionResult> transcribeSegment(
    ClinicalLongFormBatchTranscriptionRequest request,
  );

  Future<void> dispose();
}
