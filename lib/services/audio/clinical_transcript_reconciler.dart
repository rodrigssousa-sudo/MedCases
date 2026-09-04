enum ClinicalTranscriptUpdateKind {
  partial,
  finalResult,
}

final class ClinicalTranscriptUpdate {
  const ClinicalTranscriptUpdate({
    required this.kind,
    required this.sequence,
    required this.itemId,
    required this.contentIndex,
    required this.text,
  });

  final ClinicalTranscriptUpdateKind kind;
  final int sequence;
  final String itemId;
  final int contentIndex;

  /// Partial deve ser cumulativo para o item; final é autoritativo.
  final String text;

  String get key => '$itemId:$contentIndex';

  void validate() {
    if (sequence < 1) {
      throw ArgumentError.value(sequence, 'sequence');
    }
    if (itemId.trim().isEmpty) {
      throw ArgumentError.value(itemId, 'itemId');
    }
    if (contentIndex < 0) {
      throw ArgumentError.value(contentIndex, 'contentIndex');
    }
  }
}

final class ClinicalTranscriptSegment {
  const ClinicalTranscriptSegment({
    required this.itemId,
    required this.contentIndex,
    required this.firstSeenSequence,
    required this.lastSeenSequence,
    required this.partialText,
    required this.finalText,
  });

  final String itemId;
  final int contentIndex;
  final int firstSeenSequence;
  final int lastSeenSequence;
  final String partialText;
  final String? finalText;

  bool get isFinal => finalText != null;

  String get canonicalText => finalText ?? partialText;
}

/// Reconciliador provider-agnostic.
///
/// Regras:
/// - identidade = itemId + contentIndex;
/// - ordem final = primeira aparição do item;
/// - partial é snapshot cumulativo, não concatenação cega;
/// - final substitui partial como canônico;
/// - completed fora de ordem não reordena a consulta;
/// - repetição idêntica é idempotente;
/// - sequência global regressiva é rejeitada.
final class ClinicalTranscriptReconciler {
  final Map<String, _MutableClinicalTranscriptSegment> _segments =
      <String, _MutableClinicalTranscriptSegment>{};

  int _lastSequence = 0;

  int get segmentCount => _segments.length;

  bool get hasFinalSegments =>
      _segments.values.any((segment) => segment.finalText != null);

  void ingest(ClinicalTranscriptUpdate update) {
    update.validate();

    if (update.sequence <= _lastSequence) {
      throw StateError(
        'Transcript sequence must be strictly increasing: '
        '${update.sequence} <= $_lastSequence',
      );
    }
    _lastSequence = update.sequence;

    final normalizedText = _normalizeWhitespace(update.text);

    final segment = _segments.putIfAbsent(
      update.key,
      () => _MutableClinicalTranscriptSegment(
        itemId: update.itemId,
        contentIndex: update.contentIndex,
        firstSeenSequence: update.sequence,
      ),
    );

    segment.lastSeenSequence = update.sequence;

    if (update.kind == ClinicalTranscriptUpdateKind.partial) {
      if (segment.finalText == null) {
        segment.partialText = normalizedText;
      }
      return;
    }

    segment.finalText = normalizedText;
  }

  List<ClinicalTranscriptSegment> get segments {
    final result = _segments.values
        .map((segment) => segment.freeze())
        .toList(growable: false);

    result.sort(
      (a, b) => a.firstSeenSequence.compareTo(b.firstSeenSequence),
    );

    return List<ClinicalTranscriptSegment>.unmodifiable(result);
  }

  String get canonicalText {
    return segments
        .map((segment) => segment.canonicalText)
        .where((text) => text.isNotEmpty)
        .join(' ')
        .trim();
  }

  void reset() {
    _segments.clear();
    _lastSequence = 0;
  }

  static String _normalizeWhitespace(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

final class _MutableClinicalTranscriptSegment {
  _MutableClinicalTranscriptSegment({
    required this.itemId,
    required this.contentIndex,
    required this.firstSeenSequence,
  }) : lastSeenSequence = firstSeenSequence;

  final String itemId;
  final int contentIndex;
  final int firstSeenSequence;
  int lastSeenSequence;
  String partialText = '';
  String? finalText;

  ClinicalTranscriptSegment freeze() => ClinicalTranscriptSegment(
        itemId: itemId,
        contentIndex: contentIndex,
        firstSeenSequence: firstSeenSequence,
        lastSeenSequence: lastSeenSequence,
        partialText: partialText,
        finalText: finalText,
      );
}
