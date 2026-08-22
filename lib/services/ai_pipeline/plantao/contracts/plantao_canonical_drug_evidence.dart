enum PlantaoCanonicalDrugSchema { premiumV1, legacyV1, unknown }

enum PlantaoDrugEvidenceCompleteness {
  insufficientIdentity,
  identityOnly,
  partialClinical,
  richClinical,
}

enum PlantaoDrugIdentityMatchKind {
  exactId,
  exactPreferredLanguageName,
  exactSecondaryLanguageName,
  exactKeyword,
}

enum PlantaoDrugCandidateResolutionStatus {
  matched,
  notFound,
  ambiguous,
  invalidInput,
}

class PlantaoDrugEvidenceManifest {
  PlantaoDrugEvidenceManifest({
    required this.version,
    required this.contentSha256,
    required this.identitySchema,
    required this.drugCount,
    required this.interactionCount,
    required this.collisionCount,
    required this.exportErrors,
    required Map<String, String> endpoints,
  }) : endpoints = Map<String, String>.unmodifiable(endpoints);

  final String version;
  final String contentSha256;
  final String identitySchema;
  final int drugCount;
  final int interactionCount;
  final int collisionCount;
  final int exportErrors;
  final Map<String, String> endpoints;

  String get manifestEndpoint => endpoints['manifest'] ?? '';
  String get indexEndpoint => endpoints['drugsIndex'] ?? '';
  String get documentEndpointTemplate => endpoints['drugById'] ?? '';

  void ensureValid() {
    if (version.trim().isEmpty) {
      throw const FormatException('Drug manifest version cannot be empty');
    }
    if (!_isSha256(contentSha256)) {
      throw const FormatException('Drug manifest SHA-256 is invalid');
    }
    if (identitySchema.trim().isEmpty) {
      throw const FormatException('Drug identity schema cannot be empty');
    }
    if (drugCount <= 0) {
      throw const FormatException('Drug manifest count must be positive');
    }
    if (interactionCount < 0 || collisionCount < 0) {
      throw const FormatException('Drug manifest counts cannot be negative');
    }
    if (exportErrors != 0) {
      throw FormatException(
        'Drug manifest contains export errors: $exportErrors',
      );
    }
    for (final endpoint in <String>[
      manifestEndpoint,
      indexEndpoint,
      documentEndpointTemplate,
    ]) {
      if (!endpoint.startsWith('/')) {
        throw FormatException('Drug endpoint must be relative: $endpoint');
      }
    }
    if (!documentEndpointTemplate.contains('{id}')) {
      throw const FormatException(
        'Drug document endpoint must contain the {id} token',
      );
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      'contentSha256': contentSha256,
      'identitySchema': identitySchema,
      'drugCount': drugCount,
      'interactionCount': interactionCount,
      'collisionCount': collisionCount,
      'exportErrors': exportErrors,
      'endpoints': endpoints,
    };
  }

  factory PlantaoDrugEvidenceManifest.fromJson(Map<String, Object?> json) {
    final manifest = PlantaoDrugEvidenceManifest(
      version: json['version'] as String,
      contentSha256: json['contentSha256'] as String,
      identitySchema: json['identitySchema'] as String,
      drugCount: (json['drugCount'] as num).toInt(),
      interactionCount: (json['interactionCount'] as num).toInt(),
      collisionCount: (json['collisionCount'] as num).toInt(),
      exportErrors: (json['exportErrors'] as num).toInt(),
      endpoints: _stringMap(json['endpoints']),
    );
    manifest.ensureValid();
    return manifest;
  }
}

class PlantaoDrugEvidenceIndexEntry {
  PlantaoDrugEvidenceIndexEntry({
    required this.documentId,
    required Map<String, String> names,
    required this.category,
    required Iterable<String> keywords,
    required this.schema,
    required this.sourceModule,
    required this.hasContextVariants,
    required this.contextVariantCount,
    required this.canonicalOwner,
  }) : names = Map<String, String>.unmodifiable(names),
       keywords = List<String>.unmodifiable(keywords);

  final String documentId;
  final Map<String, String> names;
  final String category;
  final List<String> keywords;
  final PlantaoCanonicalDrugSchema schema;
  final String sourceModule;
  final bool hasContextVariants;
  final int contextVariantCount;
  final String canonicalOwner;

  String nameFor(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    if (normalized.startsWith('es')) {
      return names['es'] ?? names['pt'] ?? documentId;
    }
    return names['pt'] ?? names['es'] ?? documentId;
  }

  String secondaryNameFor(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    if (normalized.startsWith('es')) {
      return names['pt'] ?? names['es'] ?? documentId;
    }
    return names['es'] ?? names['pt'] ?? documentId;
  }

  void ensureValid() {
    if (!_isSafeDocumentId(documentId)) {
      throw FormatException('Invalid drug document ID: $documentId');
    }
    if ((names['pt'] ?? '').trim().isEmpty &&
        (names['es'] ?? '').trim().isEmpty) {
      throw FormatException('Drug index entry has no name: $documentId');
    }
    if (sourceModule.trim().isEmpty || canonicalOwner.trim().isEmpty) {
      throw FormatException('Drug index ownership is missing: $documentId');
    }
    if (contextVariantCount < 0) {
      throw FormatException('Invalid context variant count: $documentId');
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': documentId,
      'name': names,
      'category': category,
      'keywords': keywords,
      'schema': _schemaToWire(schema),
      'sourceModule': sourceModule,
      'hasContextVariants': hasContextVariants,
      'contextVariantCount': contextVariantCount,
      'canonicalOwner': canonicalOwner,
    };
  }

  factory PlantaoDrugEvidenceIndexEntry.fromJson(Map<String, Object?> json) {
    final entry = PlantaoDrugEvidenceIndexEntry(
      documentId: json['id'] as String,
      names: _stringMap(json['name']),
      category: json['category'] as String,
      keywords: _stringList(json['keywords']),
      schema: _schemaFromWire(json['schema'] as String?),
      sourceModule: json['sourceModule'] as String,
      hasContextVariants: json['hasContextVariants'] as bool? ?? false,
      contextVariantCount: (json['contextVariantCount'] as num? ?? 0).toInt(),
      canonicalOwner:
          json['canonicalOwner'] as String? ?? json['sourceModule'] as String,
    );
    entry.ensureValid();
    return entry;
  }
}

class PlantaoCanonicalDrugEvidenceDocument {
  PlantaoCanonicalDrugEvidenceDocument({
    required this.documentId,
    required this.category,
    required Map<String, String> names,
    required Iterable<String> keywords,
    required this.dataVersion,
    required this.clinicalContentSha256,
    required this.source,
    required this.schema,
    required this.sourceModule,
    required Map<String, Object?> pt,
    required Map<String, Object?> es,
    required Map<String, Object?> raw,
    Map<String, Object?> collision = const <String, Object?>{},
    Iterable<Object?> contextVariants = const <Object?>[],
  }) : names = Map<String, String>.unmodifiable(names),
       keywords = List<String>.unmodifiable(keywords),
       pt = Map<String, Object?>.unmodifiable(pt),
       es = Map<String, Object?>.unmodifiable(es),
       raw = Map<String, Object?>.unmodifiable(raw),
       collision = Map<String, Object?>.unmodifiable(collision),
       contextVariants = List<Object?>.unmodifiable(contextVariants);

  final String documentId;
  final String category;
  final Map<String, String> names;
  final List<String> keywords;
  final String dataVersion;
  final String clinicalContentSha256;
  final String source;
  final PlantaoCanonicalDrugSchema schema;
  final String sourceModule;
  final Map<String, Object?> pt;
  final Map<String, Object?> es;
  final Map<String, Object?> raw;
  final Map<String, Object?> collision;
  final List<Object?> contextVariants;

  bool get hasCollision => collision.isNotEmpty;
  bool get hasContextVariants => contextVariants.isNotEmpty;

  bool get hasTypedRegimens {
    final value = raw['aiRegimens'];
    if (value is! List<Object?> || value.isEmpty) return false;
    return value.every((Object? item) {
      if (item is! Map<Object?, Object?>) return false;
      return item['dose'] is num &&
          _hasValue(item['unit']) &&
          _hasValue(item['route']) &&
          _hasValue(item['frequency']);
    });
  }

  PlantaoDrugEvidenceCompleteness get completeness {
    final hasNames =
        (names['pt'] ?? '').trim().isNotEmpty &&
        (names['es'] ?? '').trim().isNotEmpty;
    final hasSearchIdentity = keywords.isNotEmpty;
    final hasDose = _localizedHasAny(<String>['dose', 'doseKg']);
    final hasAdministration = _localizedHasAny(<String>[
      'presentation',
      'dilution',
      'speed',
    ]);
    final hasRenal = _localizedHasAny(<String>['renalDose']);
    final hasSafety = _localizedHasAny(<String>[
      'commonAdverseEffects',
      'dangerousAdverseEffects',
      'alerts',
      'safetyFlags',
    ]);

    if (hasNames &&
        hasSearchIdentity &&
        hasDose &&
        hasAdministration &&
        hasSafety) {
      return PlantaoDrugEvidenceCompleteness.richClinical;
    }
    if (hasNames && hasSearchIdentity && (hasDose || hasRenal || hasSafety)) {
      return PlantaoDrugEvidenceCompleteness.partialClinical;
    }
    if (hasNames && hasSearchIdentity) {
      return PlantaoDrugEvidenceCompleteness.identityOnly;
    }
    return PlantaoDrugEvidenceCompleteness.insufficientIdentity;
  }

  bool get supportsMedicationMaterialization => hasTypedRegimens;

  String nameFor(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    if (normalized.startsWith('es')) {
      return names['es'] ?? names['pt'] ?? documentId;
    }
    return names['pt'] ?? names['es'] ?? documentId;
  }

  Map<String, Object?> localizedPayload(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    return normalized.startsWith('es') ? es : pt;
  }

  void ensureValid(PlantaoDrugEvidenceManifest manifest) {
    if (!_isSafeDocumentId(documentId)) {
      throw FormatException('Invalid drug document ID: $documentId');
    }
    if (dataVersion != manifest.version) {
      throw FormatException(
        'Drug document version mismatch: $documentId '
        '$dataVersion != ${manifest.version}',
      );
    }
    if (clinicalContentSha256 != manifest.contentSha256) {
      throw FormatException('Drug bundle SHA mismatch: $documentId');
    }
    if (source.trim().isEmpty || sourceModule.trim().isEmpty) {
      throw FormatException('Drug source is missing: $documentId');
    }
    if (completeness == PlantaoDrugEvidenceCompleteness.insufficientIdentity) {
      throw FormatException('Drug identity is insufficient: $documentId');
    }
  }

  bool _localizedHasAny(List<String> fields) {
    for (final payload in <Map<String, Object?>>[pt, es]) {
      for (final field in fields) {
        if (_hasValue(payload[field])) return true;
      }
    }
    return false;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': documentId,
      'category': category,
      'name': names,
      'keywords': keywords,
      'dataVersion': dataVersion,
      'clinicalContentSha256': clinicalContentSha256,
      'source': source,
      'schema': _schemaToWire(schema),
      'sourceModule': sourceModule,
      'pt': pt,
      'es': es,
      if (collision.isNotEmpty) 'clinicalCollision': collision,
      if (contextVariants.isNotEmpty)
        'clinicalContextVariants': contextVariants,
    };
  }

  factory PlantaoCanonicalDrugEvidenceDocument.fromJson(
    Map<String, Object?> json, {
    required PlantaoDrugEvidenceManifest manifest,
  }) {
    final document = PlantaoCanonicalDrugEvidenceDocument(
      documentId: json['id'] as String,
      category: json['category'] as String,
      names: _stringMap(json['name']),
      keywords: _stringList(json['keywords']),
      dataVersion: json['dataVersion'] as String,
      clinicalContentSha256: json['clinicalContentSha256'] as String,
      source: json['source'] as String,
      schema: _schemaFromWire(json['schema'] as String?),
      sourceModule: json['sourceModule'] as String,
      pt: _objectMap(json['pt']),
      es: _objectMap(json['es']),
      raw: json,
      collision: _objectMap(json['clinicalCollision']),
      contextVariants: _objectList(json['clinicalContextVariants']),
    );
    document.ensureValid(manifest);
    return document;
  }
}

class PlantaoCanonicalDrugCandidate {
  const PlantaoCanonicalDrugCandidate({
    required this.documentId,
    required this.canonicalName,
    required this.matchedValue,
    required this.matchKind,
    required this.schema,
    required this.sourceModule,
    required this.hasContextVariants,
  });

  final String documentId;
  final String canonicalName;
  final String matchedValue;
  final PlantaoDrugIdentityMatchKind matchKind;
  final PlantaoCanonicalDrugSchema schema;
  final String sourceModule;
  final bool hasContextVariants;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'documentId': documentId,
      'canonicalName': canonicalName,
      'matchedValue': matchedValue,
      'matchKind': matchKind.name,
      'schema': _schemaToWire(schema),
      'sourceModule': sourceModule,
      'hasContextVariants': hasContextVariants,
    };
  }
}

class PlantaoDrugCandidateResolution {
  PlantaoDrugCandidateResolution({
    required this.status,
    required this.normalizedTerm,
    required Iterable<PlantaoCanonicalDrugCandidate> candidates,
    required Iterable<String> reasons,
  }) : candidates = List<PlantaoCanonicalDrugCandidate>.unmodifiable(
         candidates,
       ),
       reasons = List<String>.unmodifiable(reasons);

  final PlantaoDrugCandidateResolutionStatus status;
  final String normalizedTerm;
  final List<PlantaoCanonicalDrugCandidate> candidates;
  final List<String> reasons;

  bool get hasSingleMatch =>
      status == PlantaoDrugCandidateResolutionStatus.matched &&
      candidates.length == 1;
}

PlantaoCanonicalDrugSchema _schemaFromWire(String? value) {
  switch (value) {
    case 'premium-v1':
      return PlantaoCanonicalDrugSchema.premiumV1;
    case 'legacy-v1':
      return PlantaoCanonicalDrugSchema.legacyV1;
    default:
      return PlantaoCanonicalDrugSchema.unknown;
  }
}

String _schemaToWire(PlantaoCanonicalDrugSchema value) {
  switch (value) {
    case PlantaoCanonicalDrugSchema.premiumV1:
      return 'premium-v1';
    case PlantaoCanonicalDrugSchema.legacyV1:
      return 'legacy-v1';
    case PlantaoCanonicalDrugSchema.unknown:
      return 'unknown';
  }
}

bool _isSha256(String value) {
  if (value.length != 64) return false;
  for (final codeUnit in value.toLowerCase().codeUnits) {
    final isDigit = codeUnit >= 48 && codeUnit <= 57;
    final isHexLetter = codeUnit >= 97 && codeUnit <= 102;
    if (!isDigit && !isHexLetter) return false;
  }
  return true;
}

bool _isSafeDocumentId(String value) {
  if (value.isEmpty) return false;
  for (final codeUnit in value.codeUnits) {
    final isDigit = codeUnit >= 48 && codeUnit <= 57;
    final isLowercase = codeUnit >= 97 && codeUnit <= 122;
    final isSeparator = codeUnit == 45 || codeUnit == 95;
    if (!isDigit && !isLowercase && !isSeparator) return false;
  }
  return true;
}

bool _hasValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Iterable<Object?>) return value.isNotEmpty;
  if (value is Map<Object?, Object?>) return value.isNotEmpty;
  return true;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value == null) return const <String, Object?>{};
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected an object map');
  }
  return value.map(
    (Object? key, Object? item) =>
        MapEntry<String, Object?>(key as String, item),
  );
}

List<Object?> _objectList(Object? value) {
  if (value == null) return const <Object?>[];
  if (value is! List<Object?>) {
    throw const FormatException('Expected an object list');
  }
  return List<Object?>.unmodifiable(value);
}

Map<String, String> _stringMap(Object? value) {
  final raw = _objectMap(value);
  return raw.map(
    (String key, Object? item) => MapEntry<String, String>(key, item as String),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('Expected a string list');
  }
  return value.map((Object? item) => item as String).toList(growable: false);
}
