enum PlantaoRemoteDrugEvidenceFailureKind {
  timeout,
  httpNotFound,
  httpStatus,
  payloadTooLarge,
  invalidContract,
  invalidPayload,
  unsafeRequest,
  unknown,
}

class PlantaoRemoteDrugEvidenceRuntimeObserver {
  PlantaoRemoteDrugEvidenceRuntimeObserver();

  static const bool shadowOnly = true;
  static const bool productiveConnectionEnabled = false;
  static const bool promptMutationEnabled = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;
  static const bool clinicalPayloadLoggingEnabled = false;
  static const bool medicationMaterializationEnabled = false;
  static const bool deterministicDosingEnabled = false;

  int _logicalRequestCount = 0;
  int _logicalSuccessCount = 0;
  int _logicalFailureCount = 0;
  int _httpRequestCount = 0;
  int _httpSuccessCount = 0;
  int _httpFailureCount = 0;
  int _currentPointerNetworkFetchCount = 0;
  int _currentPointerCacheHitCount = 0;
  int _currentPointerExpiredCount = 0;
  int _currentPointerCoalescedRequestCount = 0;
  int _currentPointerStaleFallbackCount = 0;
  int _currentPointerRefreshSuccessCount = 0;
  int _logicalLatencyMicrosTotal = 0;
  int _logicalLatencyMicrosMax = 0;
  int _httpLatencyMicrosTotal = 0;
  int _httpLatencyMicrosMax = 0;
  final Map<PlantaoRemoteDrugEvidenceFailureKind, int> _failureCounts =
      <PlantaoRemoteDrugEvidenceFailureKind, int>{};

  PlantaoRemoteDrugEvidenceRuntimeSnapshot get snapshot {
    return PlantaoRemoteDrugEvidenceRuntimeSnapshot(
      logicalRequestCount: _logicalRequestCount,
      logicalSuccessCount: _logicalSuccessCount,
      logicalFailureCount: _logicalFailureCount,
      httpRequestCount: _httpRequestCount,
      httpSuccessCount: _httpSuccessCount,
      httpFailureCount: _httpFailureCount,
      currentPointerNetworkFetchCount: _currentPointerNetworkFetchCount,
      currentPointerCacheHitCount: _currentPointerCacheHitCount,
      currentPointerExpiredCount: _currentPointerExpiredCount,
      currentPointerCoalescedRequestCount: _currentPointerCoalescedRequestCount,
      currentPointerStaleFallbackCount: _currentPointerStaleFallbackCount,
      currentPointerRefreshSuccessCount: _currentPointerRefreshSuccessCount,
      logicalLatencyMicrosTotal: _logicalLatencyMicrosTotal,
      logicalLatencyMicrosMax: _logicalLatencyMicrosMax,
      httpLatencyMicrosTotal: _httpLatencyMicrosTotal,
      httpLatencyMicrosMax: _httpLatencyMicrosMax,
      failureCounts: Map.unmodifiable(_failureCounts),
    );
  }

  void recordCurrentPointerNetworkFetch() {
    _currentPointerNetworkFetchCount += 1;
  }

  void recordCurrentPointerCacheHit() {
    _currentPointerCacheHitCount += 1;
  }

  void recordCurrentPointerExpired() {
    _currentPointerExpiredCount += 1;
  }

  void recordCurrentPointerCoalescedRequest() {
    _currentPointerCoalescedRequestCount += 1;
  }

  void recordCurrentPointerStaleFallback() {
    _currentPointerStaleFallbackCount += 1;
  }

  void recordCurrentPointerRefreshSuccess() {
    _currentPointerRefreshSuccessCount += 1;
  }

  void recordLogicalRequest() {
    _logicalRequestCount += 1;
  }

  void recordLogicalSuccess(Duration elapsed) {
    _logicalSuccessCount += 1;
    _logicalLatencyMicrosTotal += elapsed.inMicroseconds;
    if (elapsed.inMicroseconds > _logicalLatencyMicrosMax) {
      _logicalLatencyMicrosMax = elapsed.inMicroseconds;
    }
  }

  void recordLogicalFailure(
    Duration elapsed,
    PlantaoRemoteDrugEvidenceFailureKind kind,
  ) {
    _logicalFailureCount += 1;
    _logicalLatencyMicrosTotal += elapsed.inMicroseconds;
    if (elapsed.inMicroseconds > _logicalLatencyMicrosMax) {
      _logicalLatencyMicrosMax = elapsed.inMicroseconds;
    }
    _failureCounts[kind] = (_failureCounts[kind] ?? 0) + 1;
  }

  void recordHttpRequest() {
    _httpRequestCount += 1;
  }

  void recordHttpSuccess(Duration elapsed) {
    _httpSuccessCount += 1;
    _httpLatencyMicrosTotal += elapsed.inMicroseconds;
    if (elapsed.inMicroseconds > _httpLatencyMicrosMax) {
      _httpLatencyMicrosMax = elapsed.inMicroseconds;
    }
  }

  void recordHttpFailure(
    Duration elapsed,
    PlantaoRemoteDrugEvidenceFailureKind kind,
  ) {
    _httpFailureCount += 1;
    _httpLatencyMicrosTotal += elapsed.inMicroseconds;
    if (elapsed.inMicroseconds > _httpLatencyMicrosMax) {
      _httpLatencyMicrosMax = elapsed.inMicroseconds;
    }
    _failureCounts[kind] = (_failureCounts[kind] ?? 0) + 1;
  }

  void reset() {
    _logicalRequestCount = 0;
    _logicalSuccessCount = 0;
    _logicalFailureCount = 0;
    _httpRequestCount = 0;
    _httpSuccessCount = 0;
    _httpFailureCount = 0;
    _currentPointerNetworkFetchCount = 0;
    _currentPointerCacheHitCount = 0;
    _currentPointerExpiredCount = 0;
    _currentPointerCoalescedRequestCount = 0;
    _currentPointerStaleFallbackCount = 0;
    _currentPointerRefreshSuccessCount = 0;
    _logicalLatencyMicrosTotal = 0;
    _logicalLatencyMicrosMax = 0;
    _httpLatencyMicrosTotal = 0;
    _httpLatencyMicrosMax = 0;
    _failureCounts.clear();
  }
}

class PlantaoRemoteDrugEvidenceRuntimeSnapshot {
  const PlantaoRemoteDrugEvidenceRuntimeSnapshot({
    required this.logicalRequestCount,
    required this.logicalSuccessCount,
    required this.logicalFailureCount,
    required this.httpRequestCount,
    required this.httpSuccessCount,
    required this.httpFailureCount,
    required this.currentPointerNetworkFetchCount,
    required this.currentPointerCacheHitCount,
    required this.currentPointerExpiredCount,
    required this.currentPointerCoalescedRequestCount,
    required this.currentPointerStaleFallbackCount,
    required this.currentPointerRefreshSuccessCount,
    required this.logicalLatencyMicrosTotal,
    required this.logicalLatencyMicrosMax,
    required this.httpLatencyMicrosTotal,
    required this.httpLatencyMicrosMax,
    required this.failureCounts,
  });

  final int logicalRequestCount;
  final int logicalSuccessCount;
  final int logicalFailureCount;
  final int httpRequestCount;
  final int httpSuccessCount;
  final int httpFailureCount;
  final int currentPointerNetworkFetchCount;
  final int currentPointerCacheHitCount;
  final int currentPointerExpiredCount;
  final int currentPointerCoalescedRequestCount;
  final int currentPointerStaleFallbackCount;
  final int currentPointerRefreshSuccessCount;
  final int logicalLatencyMicrosTotal;
  final int logicalLatencyMicrosMax;
  final int httpLatencyMicrosTotal;
  final int httpLatencyMicrosMax;
  final Map<PlantaoRemoteDrugEvidenceFailureKind, int> failureCounts;

  double get logicalSuccessRate {
    if (logicalRequestCount == 0) return 1;
    return logicalSuccessCount / logicalRequestCount;
  }

  double get httpSuccessRate {
    if (httpRequestCount == 0) return 1;
    return httpSuccessCount / httpRequestCount;
  }

  double get currentPointerCacheHitRate {
    final total = currentPointerNetworkFetchCount + currentPointerCacheHitCount;
    if (total == 0) return 0;
    return currentPointerCacheHitCount / total;
  }

  Duration get logicalAverageLatency {
    if (logicalRequestCount == 0) return Duration.zero;
    return Duration(
      microseconds: logicalLatencyMicrosTotal ~/ logicalRequestCount,
    );
  }

  Duration get httpAverageLatency {
    if (httpRequestCount == 0) return Duration.zero;
    return Duration(
      microseconds: httpLatencyMicrosTotal ~/ httpRequestCount,
    );
  }

  int failuresOf(PlantaoRemoteDrugEvidenceFailureKind kind) {
    return failureCounts[kind] ?? 0;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'shadowOnly': true,
        'productiveConnectionEnabled': false,
        'persistenceEnabled': false,
        'clinicalPayloadLoggingEnabled': false,
        'logicalRequestCount': logicalRequestCount,
        'logicalSuccessCount': logicalSuccessCount,
        'logicalFailureCount': logicalFailureCount,
        'logicalSuccessRate': logicalSuccessRate,
        'logicalAverageLatencyMicros': logicalAverageLatency.inMicroseconds,
        'logicalLatencyMicrosMax': logicalLatencyMicrosMax,
        'httpRequestCount': httpRequestCount,
        'httpSuccessCount': httpSuccessCount,
        'httpFailureCount': httpFailureCount,
        'httpSuccessRate': httpSuccessRate,
        'httpAverageLatencyMicros': httpAverageLatency.inMicroseconds,
        'httpLatencyMicrosMax': httpLatencyMicrosMax,
        'currentPointerNetworkFetchCount': currentPointerNetworkFetchCount,
        'currentPointerCacheHitCount': currentPointerCacheHitCount,
        'currentPointerCacheHitRate': currentPointerCacheHitRate,
        'currentPointerExpiredCount': currentPointerExpiredCount,
        'currentPointerCoalescedRequestCount':
            currentPointerCoalescedRequestCount,
        'currentPointerStaleFallbackCount': currentPointerStaleFallbackCount,
        'currentPointerRefreshSuccessCount': currentPointerRefreshSuccessCount,
        'failureCounts': <String, int>{
          for (final entry in failureCounts.entries)
            entry.key.name: entry.value,
        },
      };
}
