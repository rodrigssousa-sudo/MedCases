import 'dart:convert';

import '../contracts/plantao_canonical_drug_evidence.dart';
import '../ports/plantao_drug_evidence_port.dart';

typedef PlantaoGeneratedDrugEvidenceJsonLoader = Future<String> Function(
    String relativePath);

class PlantaoGeneratedDrugEvidenceReadOnlyAdapter
    implements PlantaoDrugEvidencePort {
  PlantaoGeneratedDrugEvidenceReadOnlyAdapter({
    required this.loadJsonText,
    this.maximumManifestBytes = 256 * 1024,
    this.maximumIndexBytes = 4 * 1024 * 1024,
    this.maximumDocumentBytes = 2 * 1024 * 1024,
  });

  static const bool productiveConnectionEnabled = false;
  static const bool providerGroundingEnabled = false;
  static const bool promptMutationEnabled = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;
  static const bool medicationMaterializationEnabled = false;
  static const bool textToRegimenInferenceEnabled = false;

  static const String manifestPath = 'manifest.json';
  static const String indexPath = 'index.json';

  final PlantaoGeneratedDrugEvidenceJsonLoader loadJsonText;
  final int maximumManifestBytes;
  final int maximumIndexBytes;
  final int maximumDocumentBytes;

  PlantaoDrugEvidenceManifest? _cachedManifest;
  List<PlantaoDrugEvidenceIndexEntry>? _cachedIndex;
  String? _cachedIndexKey;
  final Map<String, PlantaoCanonicalDrugEvidenceDocument> _documentCache =
      <String, PlantaoCanonicalDrugEvidenceDocument>{};

  @override
  Future<PlantaoDrugEvidenceManifest> loadManifest() async {
    final cached = _cachedManifest;
    if (cached != null) return cached;

    final envelope = await _loadObject(
      manifestPath,
      maximumBytes: maximumManifestBytes,
    );
    final source = _objectMap(envelope['source']);
    final projection = _objectMap(envelope['projection']);

    if (projection['typedRegimenCount'] != 0 ||
        projection['deterministicDosingPublishableCount'] != 0 ||
        projection['textToRegimenInferenceUsed'] != false) {
      throw const FormatException(
        'Generated drug projection violates read-only safety contract',
      );
    }

    final manifest = PlantaoDrugEvidenceManifest(
      version: source['bundleVersion'] as String,
      contentSha256: source['bundleSha256'] as String,
      identitySchema: source['identitySchema'] as String,
      drugCount: (source['drugCount'] as num).toInt(),
      interactionCount: (source['interactionCount'] as num).toInt(),
      collisionCount: (source['collisionCount'] as num? ?? 0).toInt(),
      exportErrors: (source['exportErrors'] as num).toInt(),
      endpoints: const <String, String>{
        'manifest': '/generated/ai-drug-data/manifest.json',
        'drugsIndex': '/generated/ai-drug-data/index.json',
        'drugById': '/generated/ai-drug-data/drugs/{id}.json',
      },
    );
    manifest.ensureValid();
    _cachedManifest = manifest;
    return manifest;
  }

  @override
  Future<List<PlantaoDrugEvidenceIndexEntry>> loadIndex(
    PlantaoDrugEvidenceManifest manifest,
  ) async {
    manifest.ensureValid();
    final key = '${manifest.version}:${manifest.contentSha256}';
    if (_cachedIndex != null && _cachedIndexKey == key) {
      return _cachedIndex!;
    }

    final payload = await _loadJson(
      indexPath,
      maximumBytes: maximumIndexBytes,
    );
    if (payload is! List<Object?>) {
      throw const FormatException('Generated drug index must be a JSON list');
    }

    final entries = payload.map((Object? item) {
      final envelope = _objectMap(item);
      return PlantaoDrugEvidenceIndexEntry.fromJson(<String, Object?>{
        'id': envelope['drugId'],
        'name': envelope['name'],
        'category': envelope['category'] ?? '',
        'keywords': envelope['keywords'] ?? const <Object?>[],
        'schema': envelope['calculatorSchema'] ?? 'unknown',
        'sourceModule': envelope['sourceModule'] ?? 'generated',
        'hasContextVariants': envelope['hasContextVariants'] ?? false,
        'contextVariantCount': envelope['contextVariantCount'] ?? 0,
        'canonicalOwner': envelope['canonicalOwner'] ??
            envelope['sourceModule'] ??
            'generated',
      });
    }).toList(growable: false);

    if (entries.length != manifest.drugCount) {
      throw FormatException(
        'Generated drug index count mismatch: ${entries.length} '
        '!= ${manifest.drugCount}',
      );
    }
    if (entries.map((entry) => entry.documentId).toSet().length !=
        entries.length) {
      throw const FormatException(
          'Generated drug index contains duplicate IDs');
    }

    final immutable = List<PlantaoDrugEvidenceIndexEntry>.unmodifiable(entries);
    _cachedIndex = immutable;
    _cachedIndexKey = key;
    return immutable;
  }

  @override
  Future<PlantaoCanonicalDrugEvidenceDocument> loadDocument({
    required String documentId,
    required PlantaoDrugEvidenceManifest manifest,
  }) async {
    manifest.ensureValid();
    _ensureSafeDocumentId(documentId);
    final key = '${manifest.version}:${manifest.contentSha256}:$documentId';
    final cached = _documentCache[key];
    if (cached != null) return cached;

    final envelope = await _loadObject(
      'drugs/$documentId.json',
      maximumBytes: maximumDocumentBytes,
    );

    if (envelope['drugId'] != documentId) {
      throw FormatException('Generated drug ID mismatch: $documentId');
    }
    if (envelope['typedRegimens'] is! List<Object?> ||
        (envelope['typedRegimens'] as List<Object?>).isNotEmpty ||
        envelope['typedRegimenInferenceUsed'] != false ||
        envelope['publishableForDeterministicDosing'] != false) {
      throw const FormatException(
        'Generated drug document violates read-only safety contract',
      );
    }

    final sourceEvidence = _objectMap(envelope['sourceEvidence']);
    final calculatorDocument = _objectMap(
      sourceEvidence['calculatorDocument'],
    );
    final document = PlantaoCanonicalDrugEvidenceDocument.fromJson(
      calculatorDocument,
      manifest: manifest,
    );
    if (document.documentId != documentId) {
      throw FormatException(
        'Calculator document ID mismatch: ${document.documentId} '
        '!= $documentId',
      );
    }

    _documentCache[key] = document;
    return document;
  }

  void clearCache() {
    _cachedManifest = null;
    _cachedIndex = null;
    _cachedIndexKey = null;
    _documentCache.clear();
  }

  Future<Map<String, Object?>> _loadObject(
    String relativePath, {
    required int maximumBytes,
  }) async {
    return _objectMap(
      await _loadJson(relativePath, maximumBytes: maximumBytes),
    );
  }

  Future<Object?> _loadJson(
    String relativePath, {
    required int maximumBytes,
  }) async {
    final text = await loadJsonText(relativePath);
    if (utf8.encode(text).length > maximumBytes) {
      throw StateError(
        'Generated drug evidence payload exceeds limit: $relativePath',
      );
    }
    return jsonDecode(text);
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
