import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../shadow/plantao_remote_drug_evidence_runtime_observer.dart';

class PlantaoVersionedRemoteDrugEvidenceJsonLoader {
  PlantaoVersionedRemoteDrugEvidenceJsonLoader({
    http.Client? client,
    Uri? baseUri,
    this.requestTimeout = const Duration(seconds: 8),
    this.maximumCurrentBytes = 64 * 1024,
    this.maximumPayloadBytes = 4 * 1024 * 1024,
    this.currentPointerTtl = const Duration(minutes: 5),
    DateTime Function()? now,
    this.observer,
  })  : client = client ?? http.Client(),
        now = now ?? DateTime.now,
        baseUri = baseUri ??
            Uri.parse(
              'https://medcasescalcu.com/data/ai-drug-data/',
            ),
        _ownsClient = client == null;

  static const bool shadowOnly = true;
  static const bool productiveConnectionEnabled = false;
  static const bool promptMutationEnabled = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;
  static const bool medicationMaterializationEnabled = false;
  static const bool deterministicDosingEnabled = false;

  final http.Client client;
  final Uri baseUri;
  final Duration requestTimeout;
  final int maximumCurrentBytes;
  final int maximumPayloadBytes;
  final Duration currentPointerTtl;
  final DateTime Function() now;
  final PlantaoRemoteDrugEvidenceRuntimeObserver? observer;
  final bool _ownsClient;

  _PlantaoRemoteDrugEvidenceCurrent? _cachedCurrent;
  DateTime? _cachedCurrentAt;
  Future<_PlantaoRemoteDrugEvidenceCurrent>? _currentPointerInFlight;

  Future<String> loadJsonText(String relativePath) async {
    observer?.recordLogicalRequest();
    final stopwatch = Stopwatch()..start();

    try {
      final current = await _loadCurrent();

      final remotePath = switch (relativePath) {
        'manifest.json' => current.manifestPath,
        'index.json' => current.indexPath,
        _ when relativePath.startsWith('drugs/') =>
          _resolveDrugPath(relativePath, current),
        _ => throw FormatException(
            'Unsupported generated drug evidence path: $relativePath',
          ),
      };

      _ensureBundleScopedPath(
        remotePath,
        bundleId: current.bundleId,
      );

      final result = await _getText(
        baseUri.resolve(remotePath),
        maximumBytes: maximumPayloadBytes,
        noCache: false,
      );
      stopwatch.stop();
      observer?.recordLogicalSuccess(stopwatch.elapsed);
      return result;
    } catch (error) {
      stopwatch.stop();
      observer?.recordLogicalFailure(
        stopwatch.elapsed,
        _classifyLogicalFailure(error),
      );
      rethrow;
    }
  }

  void clearCache() {
    _cachedCurrent = null;
    _cachedCurrentAt = null;
  }

  Future<void> refreshCurrentPointer({
    bool allowStaleOnFailure = true,
  }) async {
    await _loadCurrent(
      forceRefresh: true,
      allowStaleOnFailure: allowStaleOnFailure,
    );
  }

  void invalidateCurrentPointerForLifecycle() {
    clearCache();
  }

  void close() {
    clearCache();
    if (_ownsClient) {
      client.close();
    }
  }

  Future<_PlantaoRemoteDrugEvidenceCurrent> _loadCurrent({
    bool forceRefresh = false,
    bool allowStaleOnFailure = true,
  }) async {
    final cached = _cachedCurrent;
    final cachedAt = _cachedCurrentAt;
    final cacheIsFresh = cached != null &&
        cachedAt != null &&
        now().difference(cachedAt) < currentPointerTtl;

    if (!forceRefresh && cacheIsFresh) {
      observer?.recordCurrentPointerCacheHit();
      return cached;
    }
    if (!forceRefresh && cached != null && !cacheIsFresh) {
      observer?.recordCurrentPointerExpired();
    }
    final inFlight = _currentPointerInFlight;
    if (inFlight != null) {
      observer?.recordCurrentPointerCoalescedRequest();
      return inFlight;
    }

    final stale = cached;
    final future = _refreshCurrentPointer(
      stale: stale,
      allowStaleOnFailure: allowStaleOnFailure,
    );

    _currentPointerInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_currentPointerInFlight, future)) {
        _currentPointerInFlight = null;
      }
    }
  }

  Future<_PlantaoRemoteDrugEvidenceCurrent> _refreshCurrentPointer({
    required _PlantaoRemoteDrugEvidenceCurrent? stale,
    required bool allowStaleOnFailure,
  }) async {
    try {
      final current = await _fetchCurrentPointer();
      _cachedCurrent = current;
      _cachedCurrentAt = now();
      observer?.recordCurrentPointerRefreshSuccess();
      return current;
    } catch (error, stackTrace) {
      if (allowStaleOnFailure && stale != null) {
        observer?.recordCurrentPointerStaleFallback();
        return stale;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<_PlantaoRemoteDrugEvidenceCurrent> _fetchCurrentPointer() async {
    observer?.recordCurrentPointerNetworkFetch();
    final text = await _getText(
      baseUri.resolve('current.json'),
      maximumBytes: maximumCurrentBytes,
      noCache: true,
    );
    final payload = jsonDecode(text);
    if (payload is! Map<Object?, Object?>) {
      throw const FormatException(
        'Remote drug evidence current pointer must be an object',
      );
    }
    final current = _PlantaoRemoteDrugEvidenceCurrent.fromJson(
      payload.map(
        (Object? key, Object? value) =>
            MapEntry<String, Object?>(key as String, value),
      ),
    );
    current.ensureValid();
    return current;
  }

  String _resolveDrugPath(
    String relativePath,
    _PlantaoRemoteDrugEvidenceCurrent current,
  ) {
    final documentId = relativePath
        .substring('drugs/'.length)
        .replaceFirst(RegExp(r'\.json$'), '');
    _ensureSafeDocumentId(documentId);
    return current.drugPathTemplate.replaceFirst('{id}', documentId);
  }

  Future<String> _getText(
    Uri uri, {
    required int maximumBytes,
    required bool noCache,
  }) async {
    observer?.recordHttpRequest();
    final stopwatch = Stopwatch()..start();

    try {
      final response = await client.get(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          if (noCache) 'Cache-Control': 'no-cache',
        },
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        final kind = response.statusCode == 404
            ? PlantaoRemoteDrugEvidenceFailureKind.httpNotFound
            : PlantaoRemoteDrugEvidenceFailureKind.httpStatus;
        stopwatch.stop();
        observer?.recordHttpFailure(stopwatch.elapsed, kind);
        throw StateError(
          'Remote drug evidence HTTP ${response.statusCode}: ${uri.path}',
        );
      }
      if (response.bodyBytes.length > maximumBytes) {
        stopwatch.stop();
        observer?.recordHttpFailure(
          stopwatch.elapsed,
          PlantaoRemoteDrugEvidenceFailureKind.payloadTooLarge,
        );
        throw StateError(
          'Remote drug evidence payload exceeds limit: ${uri.path}',
        );
      }

      final result = utf8.decode(response.bodyBytes);
      stopwatch.stop();
      observer?.recordHttpSuccess(stopwatch.elapsed);
      return result;
    } on TimeoutException {
      stopwatch.stop();
      observer?.recordHttpFailure(
        stopwatch.elapsed,
        PlantaoRemoteDrugEvidenceFailureKind.timeout,
      );
      rethrow;
    } on FormatException {
      stopwatch.stop();
      observer?.recordHttpFailure(
        stopwatch.elapsed,
        PlantaoRemoteDrugEvidenceFailureKind.invalidPayload,
      );
      rethrow;
    }
  }

  static PlantaoRemoteDrugEvidenceFailureKind _classifyLogicalFailure(
    Object error,
  ) {
    if (error is TimeoutException) {
      return PlantaoRemoteDrugEvidenceFailureKind.timeout;
    }
    if (error is FormatException) {
      final message = error.message.toString().toLowerCase();
      if (message.contains('unsafe') ||
          message.contains('unsupported generated drug evidence path')) {
        return PlantaoRemoteDrugEvidenceFailureKind.unsafeRequest;
      }
      return PlantaoRemoteDrugEvidenceFailureKind.invalidContract;
    }
    if (error is StateError) {
      final message = error.message.toString().toLowerCase();
      if (message.contains('http 404')) {
        return PlantaoRemoteDrugEvidenceFailureKind.httpNotFound;
      }
      if (message.contains('http ')) {
        return PlantaoRemoteDrugEvidenceFailureKind.httpStatus;
      }
      if (message.contains('exceeds limit')) {
        return PlantaoRemoteDrugEvidenceFailureKind.payloadTooLarge;
      }
    }
    return PlantaoRemoteDrugEvidenceFailureKind.unknown;
  }

  static void _ensureBundleScopedPath(
    String value, {
    required String bundleId,
  }) {
    final uri = Uri.parse(value);
    if (uri.isAbsolute ||
        uri.hasQuery ||
        uri.hasFragment ||
        value.startsWith('/') ||
        value.contains('\\') ||
        value.split('/').contains('..')) {
      throw FormatException(
        'Unsafe remote drug evidence path: $value',
      );
    }

    final expectedPrefix = 'bundles/$bundleId/';
    if (!value.startsWith(expectedPrefix)) {
      throw FormatException(
        'Remote drug evidence path escapes current bundle: $value',
      );
    }
  }

  static void _ensureSafeDocumentId(String value) {
    if (value.isEmpty || !RegExp(r'^[a-z0-9_-]+$').hasMatch(value)) {
      throw FormatException(
        'Unsafe remote drug evidence document ID: $value',
      );
    }
  }
}

class _PlantaoRemoteDrugEvidenceCurrent {
  const _PlantaoRemoteDrugEvidenceCurrent({
    required this.schemaVersion,
    required this.bundleId,
    required this.bundleVersion,
    required this.bundleSha256,
    required this.manifestPath,
    required this.indexPath,
    required this.drugPathTemplate,
    required this.drugCount,
    required this.typedRegimenCount,
    required this.deterministicDosingPublishableCount,
    required this.textToRegimenInferenceUsed,
  });

  factory _PlantaoRemoteDrugEvidenceCurrent.fromJson(
    Map<String, Object?> json,
  ) {
    return _PlantaoRemoteDrugEvidenceCurrent(
      schemaVersion: json['schemaVersion'] as String,
      bundleId: json['bundleId'] as String,
      bundleVersion: json['bundleVersion'] as String,
      bundleSha256: json['bundleSha256'] as String,
      manifestPath: json['manifestPath'] as String,
      indexPath: json['indexPath'] as String,
      drugPathTemplate: json['drugPathTemplate'] as String,
      drugCount: (json['drugCount'] as num).toInt(),
      typedRegimenCount: (json['typedRegimenCount'] as num).toInt(),
      deterministicDosingPublishableCount:
          (json['deterministicDosingPublishableCount'] as num).toInt(),
      textToRegimenInferenceUsed: json['textToRegimenInferenceUsed'] as bool,
    );
  }

  final String schemaVersion;
  final String bundleId;
  final String bundleVersion;
  final String bundleSha256;
  final String manifestPath;
  final String indexPath;
  final String drugPathTemplate;
  final int drugCount;
  final int typedRegimenCount;
  final int deterministicDosingPublishableCount;
  final bool textToRegimenInferenceUsed;

  void ensureValid() {
    if (schemaVersion != 'medcases-ai-drug-data-current-v1') {
      throw FormatException(
        'Unsupported remote drug evidence current schema: $schemaVersion',
      );
    }
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(bundleId)) {
      throw FormatException(
        'Unsafe remote drug evidence bundle ID: $bundleId',
      );
    }
    if (bundleVersion != bundleId) {
      throw const FormatException(
        'Remote drug evidence bundle version mismatch',
      );
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(bundleSha256)) {
      throw const FormatException(
        'Invalid remote drug evidence bundle SHA-256',
      );
    }
    if (drugCount <= 0 ||
        typedRegimenCount != 0 ||
        deterministicDosingPublishableCount != 0 ||
        textToRegimenInferenceUsed) {
      throw const FormatException(
        'Remote drug evidence current pointer violates safety contract',
      );
    }

    PlantaoVersionedRemoteDrugEvidenceJsonLoader._ensureBundleScopedPath(
      manifestPath,
      bundleId: bundleId,
    );
    PlantaoVersionedRemoteDrugEvidenceJsonLoader._ensureBundleScopedPath(
      indexPath,
      bundleId: bundleId,
    );
    PlantaoVersionedRemoteDrugEvidenceJsonLoader._ensureBundleScopedPath(
      drugPathTemplate.replaceFirst('{id}', 'probe'),
      bundleId: bundleId,
    );
    if (!drugPathTemplate.contains('{id}')) {
      throw const FormatException(
        'Remote drug evidence document template has no ID placeholder',
      );
    }
  }
}
