import 'clinical_long_form_recording_manifest.dart';

enum ClinicalLongFormBatchItemStatus {
  pending,
  processing,
  completed,
  failed,
}

final class ClinicalLongFormBatchItem {
  const ClinicalLongFormBatchItem({
    required this.segmentIndex,
    required this.segmentPath,
    required this.status,
    required this.attempts,
    required this.deduplicationKey,
    this.resultRef,
    this.lastErrorCode,
  });

  final int segmentIndex;
  final String segmentPath;
  final ClinicalLongFormBatchItemStatus status;
  final int attempts;

  /// Estável entre retries/restarts para permitir deduplicação futura
  /// no backend/transcriber.
  final String deduplicationKey;

  /// Referência opaca para resultado futuro; nenhum transcript é persistido
  /// nesta foundation.
  final String? resultRef;
  final String? lastErrorCode;

  bool get isRetryable =>
      status == ClinicalLongFormBatchItemStatus.pending ||
      status == ClinicalLongFormBatchItemStatus.failed;

  Map<String, Object?> toJson() => <String, Object?>{
        'segmentIndex': segmentIndex,
        'segmentPath': segmentPath,
        'status': status.name,
        'attempts': attempts,
        'deduplicationKey': deduplicationKey,
        'resultRef': resultRef,
        'lastErrorCode': lastErrorCode,
      };

  factory ClinicalLongFormBatchItem.fromJson(
    Map<String, Object?> json,
  ) {
    final statusName = json['status']! as String;
    final status = ClinicalLongFormBatchItemStatus.values.firstWhere(
      (value) => value.name == statusName,
    );

    return ClinicalLongFormBatchItem(
      segmentIndex: json['segmentIndex']! as int,
      segmentPath: json['segmentPath']! as String,
      status: status,
      attempts: json['attempts']! as int,
      deduplicationKey: json['deduplicationKey']! as String,
      resultRef: json['resultRef'] as String?,
      lastErrorCode: json['lastErrorCode'] as String?,
    );
  }

  ClinicalLongFormBatchItem copyWith({
    ClinicalLongFormBatchItemStatus? status,
    int? attempts,
    String? resultRef,
    bool clearResultRef = false,
    String? lastErrorCode,
    bool clearLastError = false,
  }) {
    return ClinicalLongFormBatchItem(
      segmentIndex: segmentIndex,
      segmentPath: segmentPath,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      deduplicationKey: deduplicationKey,
      resultRef: clearResultRef ? null : resultRef ?? this.resultRef,
      lastErrorCode:
          clearLastError ? null : lastErrorCode ?? this.lastErrorCode,
    );
  }
}

final class ClinicalLongFormBatchQueue {
  ClinicalLongFormBatchQueue({
    required this.sessionId,
    required Iterable<ClinicalLongFormBatchItem> items,
    this.maxAttempts = 3,
  }) : _items = List<ClinicalLongFormBatchItem>.from(items) {
    _validate();
  }

  factory ClinicalLongFormBatchQueue.fromManifest(
    ClinicalLongFormRecordingManifest manifest, {
    int maxAttempts = 3,
  }) {
    final completed = manifest.segments
        .where((segment) => segment.completed)
        .toList(growable: false)
      ..sort((a, b) => a.index.compareTo(b.index));

    return ClinicalLongFormBatchQueue(
      sessionId: manifest.sessionId,
      maxAttempts: maxAttempts,
      items: completed.map(
        (segment) => ClinicalLongFormBatchItem(
          segmentIndex: segment.index,
          segmentPath: segment.path,
          status: ClinicalLongFormBatchItemStatus.pending,
          attempts: 0,
          deduplicationKey: '${manifest.sessionId}:segment:${segment.index}',
        ),
      ),
    );
  }

  final String sessionId;
  final int maxAttempts;
  final List<ClinicalLongFormBatchItem> _items;

  List<ClinicalLongFormBatchItem> get items =>
      List<ClinicalLongFormBatchItem>.unmodifiable(_items);

  int get totalCount => _items.length;

  int get completedCount => _items
      .where(
        (item) => item.status == ClinicalLongFormBatchItemStatus.completed,
      )
      .length;

  int get exhaustedCount => _items
      .where(
        (item) =>
            item.status == ClinicalLongFormBatchItemStatus.failed &&
            item.attempts >= maxAttempts,
      )
      .length;

  bool get isComplete => _items.isNotEmpty && completedCount == _items.length;

  double get progress => _items.isEmpty ? 0 : completedCount / _items.length;

  ClinicalLongFormBatchItem? claimNext() {
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];

      final candidate =
          item.status == ClinicalLongFormBatchItemStatus.pending ||
              (item.status == ClinicalLongFormBatchItemStatus.failed &&
                  item.attempts < maxAttempts);

      if (!candidate) {
        continue;
      }

      final claimed = item.copyWith(
        status: ClinicalLongFormBatchItemStatus.processing,
        attempts: item.attempts + 1,
        clearLastError: true,
      );

      _items[i] = claimed;
      return claimed;
    }

    return null;
  }

  void markCompleted({
    required int segmentIndex,
    required String resultRef,
  }) {
    final index = _positionOf(segmentIndex);
    final current = _items[index];

    if (current.status != ClinicalLongFormBatchItemStatus.processing) {
      throw StateError(
        'Only processing items can be completed.',
      );
    }

    final normalizedRef = resultRef.trim();
    if (normalizedRef.isEmpty || normalizedRef.length > 240) {
      throw ArgumentError.value(resultRef, 'resultRef');
    }

    _items[index] = current.copyWith(
      status: ClinicalLongFormBatchItemStatus.completed,
      resultRef: normalizedRef,
      clearLastError: true,
    );
  }

  void markFailed({
    required int segmentIndex,
    required String errorCode,
  }) {
    final index = _positionOf(segmentIndex);
    final current = _items[index];

    if (current.status != ClinicalLongFormBatchItemStatus.processing) {
      throw StateError(
        'Only processing items can fail.',
      );
    }

    final normalizedError = _validateOpaqueCode(
      errorCode,
      fieldName: 'errorCode',
    );

    _items[index] = current.copyWith(
      status: ClinicalLongFormBatchItemStatus.failed,
      lastErrorCode: normalizedError,
      clearResultRef: true,
    );
  }

  int recoverInterruptedProcessing() {
    var recovered = 0;

    for (var i = 0; i < _items.length; i++) {
      final current = _items[i];
      if (current.status != ClinicalLongFormBatchItemStatus.processing) {
        continue;
      }

      _items[i] = current.copyWith(
        status: ClinicalLongFormBatchItemStatus.pending,
        lastErrorCode: 'interrupted_requeued',
        clearResultRef: true,
      );
      recovered++;
    }

    return recovered;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'medcases.long_form_batch_queue.v1',
        'sessionId': sessionId,
        'maxAttempts': maxAttempts,
        'items': _items.map((item) => item.toJson()).toList(growable: false),
      };

  factory ClinicalLongFormBatchQueue.fromJson(
    Map<String, Object?> json,
  ) {
    if (json['schema'] != 'medcases.long_form_batch_queue.v1') {
      throw const FormatException('Unsupported batch queue schema.');
    }

    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Invalid batch queue items.');
    }

    return ClinicalLongFormBatchQueue(
      sessionId: json['sessionId']! as String,
      maxAttempts: json['maxAttempts']! as int,
      items: rawItems
          .cast<Map<String, Object?>>()
          .map(ClinicalLongFormBatchItem.fromJson),
    );
  }

  int _positionOf(int segmentIndex) {
    final index = _items.indexWhere(
      (item) => item.segmentIndex == segmentIndex,
    );
    if (index < 0) {
      throw StateError('Unknown segment index: $segmentIndex');
    }
    return index;
  }

  void _validate() {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    if (maxAttempts < 1 || maxAttempts > 10) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts');
    }

    var previousIndex = -1;
    final dedupeKeys = <String>{};

    for (final item in _items) {
      if (item.segmentIndex <= previousIndex) {
        throw StateError(
          'Batch items must be strictly ordered by segment index.',
        );
      }
      previousIndex = item.segmentIndex;

      if (item.attempts < 0 || item.attempts > maxAttempts) {
        throw StateError('Invalid batch attempt count.');
      }
      if (item.segmentPath.trim().isEmpty) {
        throw StateError('Empty segment path.');
      }
      if (!dedupeKeys.add(item.deduplicationKey)) {
        throw StateError('Duplicate batch deduplication key.');
      }

      _validateOpaqueCode(
        item.deduplicationKey,
        fieldName: 'deduplicationKey',
      );
    }
  }

  static String _validateOpaqueCode(
    String raw, {
    required String fieldName,
  }) {
    final value = raw.trim();
    if (value.isEmpty ||
        value.length > 240 ||
        value.contains('\n') ||
        value.contains('\r')) {
      throw ArgumentError.value(raw, fieldName);
    }
    return value;
  }
}
