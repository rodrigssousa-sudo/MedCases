import 'dart:convert';

import 'package:http/http.dart' as http;

import '../contracts/plantao_canonical_drug_evidence.dart';
import '../ports/plantao_drug_evidence_port.dart';

class PlantaoHttpDrugEvidenceAdapter implements PlantaoDrugEvidencePort {
  PlantaoHttpDrugEvidenceAdapter({
    http.Client? client,
    Uri? baseUri,
    this.requestTimeout = const Duration(seconds: 8),
    this.maximumManifestBytes = 256 * 1024,
    this.maximumIndexBytes = 4 * 1024 * 1024,
    this.maximumDocumentBytes = 1024 * 1024,
  }) : client = client ?? http.Client(),
       baseUri = baseUri ?? Uri.parse('https://medcasescalcu.com/'),
       _ownsClient = client == null;

  static const bool productiveConnectionEnabled = false;
  static const bool providerGroundingEnabled = false;
  static const bool promptMutationEnabled = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;
  static const bool authenticationEnabled = false;
  static const bool cookiesEnabled = false;

  final http.Client client;
  final Uri baseUri;
  final Duration requestTimeout;
  final int maximumManifestBytes;
  final int maximumIndexBytes;
  final int maximumDocumentBytes;
  final bool _ownsClient;
  PlantaoDrugEvidenceManifest? _cachedManifest;
  List<PlantaoDrugEvidenceIndexEntry>? _cachedIndex;
  String? _cachedIndexKey;
  final Map<String, PlantaoCanonicalDrugEvidenceDocument> _documentCache =
      <String, PlantaoCanonicalDrugEvidenceDocument>{};

  @override
  Future<PlantaoDrugEvidenceManifest> loadManifest() async {
    final cached = _cachedManifest;
    if (cached != null) return cached;

    final payload = await _getObject(
      baseUri.resolve('/data/manifest.json'),
      maximumBytes: maximumManifestBytes,
    );
    final manifest = PlantaoDrugEvidenceManifest.fromJson(payload);
    _cachedManifest = manifest;
    return manifest;
  }

  @override
  Future<List<PlantaoDrugEvidenceIndexEntry>> loadIndex(
    PlantaoDrugEvidenceManifest manifest,
  ) async {
    manifest.ensureValid();
    final cacheKey = '${manifest.version}:${manifest.contentSha256}';
    final cached = _cachedIndex;
    if (cached != null && _cachedIndexKey == cacheKey) return cached;

    final payload = await _getJson(
      baseUri.resolve(manifest.indexEndpoint),
      maximumBytes: maximumIndexBytes,
    );
    if (payload is! List<Object?>) {
      throw const FormatException('Drug index must be a JSON list');
    }
    final entries = payload
        .map(
          (Object? item) =>
              PlantaoDrugEvidenceIndexEntry.fromJson(_objectMap(item)),
        )
        .toList(growable: false);
    if (entries.length != manifest.drugCount) {
      throw FormatException(
        'Drug index count mismatch: ${entries.length} '
        '!= ${manifest.drugCount}',
      );
    }
    final uniqueIds = entries.map((entry) => entry.documentId).toSet();
    if (uniqueIds.length != entries.length) {
      throw const FormatException('Drug index contains duplicated IDs');
    }
    final immutable = List<PlantaoDrugEvidenceIndexEntry>.unmodifiable(entries);
    _cachedIndex = immutable;
    _cachedIndexKey = cacheKey;
    return immutable;
  }

  @override
  Future<PlantaoCanonicalDrugEvidenceDocument> loadDocument({
    required String documentId,
    required PlantaoDrugEvidenceManifest manifest,
  }) async {
    manifest.ensureValid();
    _ensureSafeDocumentId(documentId);
    final cacheKey =
        '${manifest.version}:${manifest.contentSha256}:$documentId';
    final cached = _documentCache[cacheKey];
    if (cached != null) return cached;

    final encodedId = Uri.encodeComponent(documentId);
    final endpoint = manifest.documentEndpointTemplate.replaceFirst(
      '{id}',
      encodedId,
    );
    final payload = await _getObject(
      baseUri.resolve(endpoint),
      maximumBytes: maximumDocumentBytes,
    );
    final document = PlantaoCanonicalDrugEvidenceDocument.fromJson(
      payload,
      manifest: manifest,
    );
    if (document.documentId != documentId) {
      throw FormatException(
        'Drug document ID mismatch: ${document.documentId} != $documentId',
      );
    }
    _documentCache[cacheKey] = document;
    return document;
  }

  void clearCache() {
    _cachedManifest = null;
    _cachedIndex = null;
    _cachedIndexKey = null;
    _documentCache.clear();
  }

  void close() {
    clearCache();
    if (_ownsClient) client.close();
  }

  Future<Map<String, Object?>> _getObject(
    Uri uri, {
    required int maximumBytes,
  }) async {
    final payload = await _getJson(uri, maximumBytes: maximumBytes);
    return _objectMap(payload);
  }

  Future<Object?> _getJson(Uri uri, {required int maximumBytes}) async {
    final response = await client
        .get(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw StateError(
        'Drug evidence HTTP ${response.statusCode}: ${uri.path}',
      );
    }
    if (response.bodyBytes.length > maximumBytes) {
      throw StateError('Drug evidence payload exceeds limit: ${uri.path}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static void _ensureSafeDocumentId(String value) {
    if (value.isEmpty) {
      throw const FormatException('Drug document ID cannot be empty');
    }
    for (final codeUnit in value.codeUnits) {
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isLowercase = codeUnit >= 97 && codeUnit <= 122;
      final isSeparator = codeUnit == 45 || codeUnit == 95;
      if (!isDigit && !isLowercase && !isSeparator) {
        throw FormatException('Unsafe drug document ID: $value');
      }
    }
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected a JSON object');
  }
  return value.map(
    (Object? key, Object? item) =>
        MapEntry<String, Object?>(key as String, item),
  );
}
