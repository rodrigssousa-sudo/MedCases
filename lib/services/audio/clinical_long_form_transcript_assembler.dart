import 'clinical_long_form_batch_transcription_provider.dart';

final class ClinicalLongFormTranscriptAssembly {
  const ClinicalLongFormTranscriptAssembly({
    required this.text,
    required this.segmentCount,
    required this.expectedSegmentCount,
    required this.complete,
  });

  final String text;
  final int segmentCount;
  final int expectedSegmentCount;
  final bool complete;
}

final class ClinicalLongFormTranscriptAssembler {
  ClinicalLongFormTranscriptAssembler({
    required this.expectedSegmentCount,
  }) {
    if (expectedSegmentCount < 0) {
      throw ArgumentError.value(
        expectedSegmentCount,
        'expectedSegmentCount',
      );
    }
  }

  final int expectedSegmentCount;

  final Map<int, ClinicalLongFormBatchTranscriptionResult> _results =
      <int, ClinicalLongFormBatchTranscriptionResult>{};

  int get receivedSegmentCount => _results.length;

  bool get isComplete =>
      expectedSegmentCount > 0 &&
      _results.length == expectedSegmentCount &&
      List<int>.generate(
        expectedSegmentCount,
        (index) => index,
      ).every(_results.containsKey);

  void accept(
    ClinicalLongFormBatchTranscriptionResult result,
  ) {
    if (result.segmentIndex < 0 ||
        result.segmentIndex >= expectedSegmentCount) {
      throw RangeError.range(
        result.segmentIndex,
        0,
        expectedSegmentCount - 1,
        'segmentIndex',
      );
    }

    final existing = _results[result.segmentIndex];

    if (existing != null) {
      final sameIdentity = existing.deduplicationKey == result.deduplicationKey;

      final sameTranscript = _normalizeWhitespace(existing.transcript) ==
          _normalizeWhitespace(result.transcript);

      if (!sameIdentity || !sameTranscript) {
        throw StateError(
          'Conflicting transcript result for segment '
          '${result.segmentIndex}.',
        );
      }

      // Idempotent replay.
      return;
    }

    _results[result.segmentIndex] = result;
  }

  ClinicalLongFormTranscriptAssembly assemble({
    bool requireComplete = true,
  }) {
    if (requireComplete && !isComplete) {
      throw StateError(
        'Cannot assemble final transcript before all segments complete.',
      );
    }

    final indexes = _results.keys.toList(growable: false)..sort();

    final text = indexes
        .map((index) => _normalizeWhitespace(_results[index]!.transcript))
        .where((value) => value.isNotEmpty)
        .join('\n\n')
        .trim();

    return ClinicalLongFormTranscriptAssembly(
      text: text,
      segmentCount: indexes.length,
      expectedSegmentCount: expectedSegmentCount,
      complete: isComplete,
    );
  }

  String? trailingContext({
    int maxCharacters = 600,
  }) {
    if (_results.isEmpty) {
      return null;
    }
    if (maxCharacters < 1 || maxCharacters > 1200) {
      throw ArgumentError.value(maxCharacters, 'maxCharacters');
    }

    final lastIndex = _results.keys.reduce(
      (current, next) => current > next ? current : next,
    );

    final normalized = _normalizeWhitespace(
      _results[lastIndex]!.transcript,
    );

    if (normalized.length <= maxCharacters) {
      return normalized;
    }

    return normalized.substring(
      normalized.length - maxCharacters,
    );
  }

  static String _normalizeWhitespace(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
