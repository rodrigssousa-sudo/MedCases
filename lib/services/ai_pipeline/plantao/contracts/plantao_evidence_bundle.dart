enum PlantaoEvidenceKind {
  clinical,
  drug,
  protocol,
  patientFact,
  caseEvidence,
  external,
}

enum PlantaoRetrievalStatus { complete, partial, empty, failed }

class PlantaoEvidenceDocument {
  PlantaoEvidenceDocument({
    required this.documentId,
    required this.version,
    required this.kind,
    required this.excerpt,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = Map<String, Object?>.unmodifiable(metadata);

  final String documentId;
  final String version;
  final PlantaoEvidenceKind kind;
  final String excerpt;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'documentId': documentId,
      'version': version,
      'kind': kind.name,
      'excerpt': excerpt,
      'metadata': metadata,
    };
  }

  factory PlantaoEvidenceDocument.fromJson(Map<String, Object?> json) {
    return PlantaoEvidenceDocument(
      documentId: json['documentId'] as String,
      version: json['version'] as String,
      kind: PlantaoEvidenceKind.values.firstWhere(
        (PlantaoEvidenceKind item) => item.name == json['kind'],
        orElse: () => throw FormatException(
          'Unknown PlantaoEvidenceKind: ${json['kind']}',
        ),
      ),
      excerpt: json['excerpt'] as String,
      metadata: _objectMap(json['metadata']),
    );
  }
}

class PlantaoDrugEvidenceDocument extends PlantaoEvidenceDocument {
  PlantaoDrugEvidenceDocument({
    required super.documentId,
    required super.version,
    required super.excerpt,
    required this.drugName,
    required this.dose,
    required this.unit,
    required this.route,
    required this.frequency,
    super.metadata,
  }) : super(kind: PlantaoEvidenceKind.drug);

  final String drugName;
  final num dose;
  final String unit;
  final String route;
  final String frequency;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      ...super.toJson(),
      'drugName': drugName,
      'dose': dose,
      'unit': unit,
      'route': route,
      'frequency': frequency,
    };
  }

  factory PlantaoDrugEvidenceDocument.fromJson(Map<String, Object?> json) {
    return PlantaoDrugEvidenceDocument(
      documentId: json['documentId'] as String,
      version: json['version'] as String,
      excerpt: json['excerpt'] as String,
      drugName: json['drugName'] as String,
      dose: json['dose'] as num,
      unit: json['unit'] as String,
      route: json['route'] as String,
      frequency: json['frequency'] as String,
      metadata: _objectMap(json['metadata']),
    );
  }
}

class PlantaoEvidenceCoverage {
  const PlantaoEvidenceCoverage({
    required this.hasClinical,
    required this.hasDrug,
    required this.hasProtocol,
    required this.hasPatientFacts,
  });

  final bool hasClinical;
  final bool hasDrug;
  final bool hasProtocol;
  final bool hasPatientFacts;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'hasClinical': hasClinical,
      'hasDrug': hasDrug,
      'hasProtocol': hasProtocol,
      'hasPatientFacts': hasPatientFacts,
    };
  }

  factory PlantaoEvidenceCoverage.fromJson(Map<String, Object?> json) {
    return PlantaoEvidenceCoverage(
      hasClinical: json['hasClinical'] as bool,
      hasDrug: json['hasDrug'] as bool,
      hasProtocol: json['hasProtocol'] as bool,
      hasPatientFacts: json['hasPatientFacts'] as bool,
    );
  }
}


/// Validation state for the request-scoped canonical evidence bundle.
enum PlantaoEvidenceValidationStatus {
  unavailable,
  validated,
  rejected,
}

/// One bounded and provenance-bearing clinical evidence item.
///
/// This contract contains no raw patient text and no renderer instructions.
class PlantaoEvidenceItem {
  const PlantaoEvidenceItem({
    required this.kind,
    required this.sourceId,
    required this.sourceVersion,
    required this.documentId,
    required this.contentHash,
    required this.boundedExcerpt,
    this.clinicalFacts = const <String>[],
    this.retrievalScore = 0,
    this.exactIdentity = false,
    this.validated = false,
  });

  final String kind;
  final String sourceId;
  final String sourceVersion;
  final String documentId;
  final String contentHash;
  final String boundedExcerpt;
  final List<String> clinicalFacts;
  final double retrievalScore;
  final bool exactIdentity;
  final bool validated;

  String canonicalKey() {
    final facts = clinicalFacts
        .map(PlantaoEvidenceBundle.normalizeCanonicalText)
        .where((value) => value.isNotEmpty)
        .toList(growable: false)
      ..sort();

    return <String>[
      PlantaoEvidenceBundle.normalizeCanonicalText(kind),
      PlantaoEvidenceBundle.normalizeCanonicalText(sourceId),
      PlantaoEvidenceBundle.normalizeCanonicalText(sourceVersion),
      PlantaoEvidenceBundle.normalizeCanonicalText(documentId),
      PlantaoEvidenceBundle.normalizeCanonicalText(contentHash),
      PlantaoEvidenceBundle.normalizeCanonicalText(boundedExcerpt),
      facts.join('\u001e'),
      retrievalScore.toStringAsFixed(6),
      exactIdentity ? '1' : '0',
      validated ? '1' : '0',
    ].join('\u001f');
  }
}

class PlantaoEvidenceBundle {
  /// Request identity shared across retrieval, generation and validation.
  final String requestId;

  /// Hashed session identity; never raw patient or conversation text.
  final String sessionIdHash;

  /// Evidence-language contract (`pt` or `es`).
  final String locale;

  /// Fingerprint of the normalized retrieval query.
  final String queryFingerprint;

  /// Bounded validated protocol evidence.
  final List<PlantaoEvidenceItem> protocolEvidence;

  /// Exact-identity bounded pharmacological evidence.
  final List<PlantaoEvidenceItem> drugEvidence;

  /// Validation state for this exact request-scoped bundle.
  final PlantaoEvidenceValidationStatus validationStatus;

  /// Deterministic identity of normalized evidence content.
  final String bundleHash;

  /// Request-scoped creation timestamp.
  final int createdAtEpochMs;

  /// Explicit evidence gaps, timeouts and unavailable criteria.
  final List<String> limitations;


  PlantaoEvidenceBundle({
    required Iterable<PlantaoEvidenceDocument> clinicalDocuments,
    required Iterable<PlantaoDrugEvidenceDocument> drugDocuments,
    required Iterable<PlantaoEvidenceDocument> protocolDocuments,
    required Iterable<PlantaoEvidenceDocument> patientFacts,
    required Iterable<PlantaoEvidenceDocument> caseEvidence,
    required Iterable<PlantaoEvidenceDocument> externalGrounding,
    required Map<String, String> documentVersions,
    required this.coverage,
    required Iterable<String> missingRequirements,
    required this.retrievalStatus,
  
    this.requestId = '',
    this.sessionIdHash = '',
    this.locale = 'pt',
    this.queryFingerprint = '',
    this.protocolEvidence = const <PlantaoEvidenceItem>[],
    this.drugEvidence = const <PlantaoEvidenceItem>[],
    this.validationStatus = PlantaoEvidenceValidationStatus.unavailable,
    this.bundleHash = '',
    this.createdAtEpochMs = 0,
    this.limitations = const <String>[],
}) : clinicalDocuments = List<PlantaoEvidenceDocument>.unmodifiable(
         clinicalDocuments,
       ),
       drugDocuments = List<PlantaoDrugEvidenceDocument>.unmodifiable(
         drugDocuments,
       ),
       protocolDocuments = List<PlantaoEvidenceDocument>.unmodifiable(
         protocolDocuments,
       ),
       patientFacts = List<PlantaoEvidenceDocument>.unmodifiable(patientFacts),
       caseEvidence = List<PlantaoEvidenceDocument>.unmodifiable(caseEvidence),
       externalGrounding = List<PlantaoEvidenceDocument>.unmodifiable(
         externalGrounding,
       ),
       documentVersions = Map<String, String>.unmodifiable(documentVersions),
       missingRequirements = List<String>.unmodifiable(missingRequirements);

  final List<PlantaoEvidenceDocument> clinicalDocuments;
  final List<PlantaoDrugEvidenceDocument> drugDocuments;
  final List<PlantaoEvidenceDocument> protocolDocuments;
  final List<PlantaoEvidenceDocument> patientFacts;
  final List<PlantaoEvidenceDocument> caseEvidence;
  final List<PlantaoEvidenceDocument> externalGrounding;
  final Map<String, String> documentVersions;
  final PlantaoEvidenceCoverage coverage;
  final List<String> missingRequirements;
  final PlantaoRetrievalStatus retrievalStatus;

  factory PlantaoEvidenceBundle.empty({
    Iterable<String> missingRequirements = const <String>[],
  }) {
    return PlantaoEvidenceBundle(
      clinicalDocuments: const <PlantaoEvidenceDocument>[],
      drugDocuments: const <PlantaoDrugEvidenceDocument>[],
      protocolDocuments: const <PlantaoEvidenceDocument>[],
      patientFacts: const <PlantaoEvidenceDocument>[],
      caseEvidence: const <PlantaoEvidenceDocument>[],
      externalGrounding: const <PlantaoEvidenceDocument>[],
      documentVersions: const <String, String>{},
      coverage: const PlantaoEvidenceCoverage(
        hasClinical: false,
        hasDrug: false,
        hasProtocol: false,
        hasPatientFacts: false,
      ),
      missingRequirements: missingRequirements,
      retrievalStatus: PlantaoRetrievalStatus.empty,
    );
  }

  bool get isEmpty =>
      clinicalDocuments.isEmpty &&
      drugDocuments.isEmpty &&
      protocolDocuments.isEmpty &&
      patientFacts.isEmpty &&
      caseEvidence.isEmpty &&
      externalGrounding.isEmpty;

  bool get hasDeterministicDrugEvidence =>
      drugDocuments.isNotEmpty && coverage.hasDrug;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'clinicalDocuments': clinicalDocuments
          .map((PlantaoEvidenceDocument item) => item.toJson())
          .toList(growable: false),
      'drugDocuments': drugDocuments
          .map((PlantaoDrugEvidenceDocument item) => item.toJson())
          .toList(growable: false),
      'protocolDocuments': protocolDocuments
          .map((PlantaoEvidenceDocument item) => item.toJson())
          .toList(growable: false),
      'patientFacts': patientFacts
          .map((PlantaoEvidenceDocument item) => item.toJson())
          .toList(growable: false),
      'caseEvidence': caseEvidence
          .map((PlantaoEvidenceDocument item) => item.toJson())
          .toList(growable: false),
      'externalGrounding': externalGrounding
          .map((PlantaoEvidenceDocument item) => item.toJson())
          .toList(growable: false),
      'documentVersions': documentVersions,
      'coverage': coverage.toJson(),
      'missingRequirements': missingRequirements,
      'retrievalStatus': retrievalStatus.name,
    };
  }

  factory PlantaoEvidenceBundle.fromJson(Map<String, Object?> json) {
    return PlantaoEvidenceBundle(
      clinicalDocuments: _documentList(json['clinicalDocuments']),
      drugDocuments: _drugDocumentList(json['drugDocuments']),
      protocolDocuments: _documentList(json['protocolDocuments']),
      patientFacts: _documentList(json['patientFacts']),
      caseEvidence: _documentList(json['caseEvidence']),
      externalGrounding: _documentList(json['externalGrounding']),
      documentVersions: _stringMap(json['documentVersions']),
      coverage: PlantaoEvidenceCoverage.fromJson(_objectMap(json['coverage'])),
      missingRequirements: _stringList(json['missingRequirements']),
      retrievalStatus: PlantaoRetrievalStatus.values.firstWhere(
        (PlantaoRetrievalStatus item) => item.name == json['retrievalStatus'],
        orElse: () => throw FormatException(
          'Unknown PlantaoRetrievalStatus: ${json['retrievalStatus']}',
        ),
      ),
    );
  }


  /// Produces the same hash for the same normalized evidence regardless of
  /// list order or irrelevant whitespace.
  static String computeCanonicalBundleHash({
    required String locale,
    required String queryFingerprint,
    List<PlantaoEvidenceItem> protocolEvidence =
        const <PlantaoEvidenceItem>[],
    List<PlantaoEvidenceItem> drugEvidence =
        const <PlantaoEvidenceItem>[],
    PlantaoEvidenceValidationStatus validationStatus =
        PlantaoEvidenceValidationStatus.unavailable,
    List<String> limitations = const <String>[],
  }) {
    final protocols = protocolEvidence
        .map((item) => item.canonicalKey())
        .toList(growable: false)
      ..sort();
    final drugs = drugEvidence
        .map((item) => item.canonicalKey())
        .toList(growable: false)
      ..sort();
    final normalizedLimitations = limitations
        .map(normalizeCanonicalText)
        .where((value) => value.isNotEmpty)
        .toList(growable: false)
      ..sort();

    final payload = <String>[
      normalizeCanonicalText(locale),
      normalizeCanonicalText(queryFingerprint),
      validationStatus.name,
      protocols.join('\u001d'),
      drugs.join('\u001d'),
      normalizedLimitations.join('\u001d'),
    ].join('\u001c');

    return stableHash32(payload);
  }

  static String normalizeCanonicalText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String stableHash32(String value) {
    var hash = 0x811c9dc5;

    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash.toRadixString(16).padLeft(8, '0');
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value == null) {
    return const <String, Object?>{};
  }
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected an object map');
  }
  return value.map(
    (Object? key, Object? item) =>
        MapEntry<String, Object?>(key as String, item),
  );
}

Map<String, String> _stringMap(Object? value) {
  final Map<String, Object?> raw = _objectMap(value);
  return raw.map(
    (String key, Object? item) => MapEntry<String, String>(key, item as String),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('Expected a string list');
  }
  return value.map((Object? item) => item as String).toList();
}

List<PlantaoEvidenceDocument> _documentList(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('Expected a document list');
  }
  return value
      .map((Object? item) => PlantaoEvidenceDocument.fromJson(_objectMap(item)))
      .toList();
}

List<PlantaoDrugEvidenceDocument> _drugDocumentList(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('Expected a drug document list');
  }
  return value
      .map(
        (Object? item) =>
            PlantaoDrugEvidenceDocument.fromJson(_objectMap(item)),
      )
      .toList();
}
