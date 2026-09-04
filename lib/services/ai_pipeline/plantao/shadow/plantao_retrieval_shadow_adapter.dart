import '../contracts/plantao_evidence_bundle.dart';
import '../contracts/plantao_request.dart';

import 'dart:convert';
import '../../../../data/protocols_database.dart';
import '../adapters/plantao_protocol_matcher_evidence_adapter.dart';
String _plantaoRetrievalShadowSha256Hex(String input) {
  const roundConstants = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];

  int rotateRight(int value, int bits) {
    return ((value >>> bits) | (value << (32 - bits))) & 0xffffffff;
  }

  final bytes = <int>[...utf8.encode(input), 0x80];
  final bitLength = (bytes.length - 1) * 8;
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  for (var shift = 56; shift >= 0; shift -= 8) {
    bytes.add((bitLength >> shift) & 0xff);
  }

  var h0 = 0x6a09e667;
  var h1 = 0xbb67ae85;
  var h2 = 0x3c6ef372;
  var h3 = 0xa54ff53a;
  var h4 = 0x510e527f;
  var h5 = 0x9b05688c;
  var h6 = 0x1f83d9ab;
  var h7 = 0x5be0cd19;

  final words = List<int>.filled(64, 0);
  for (var offset = 0; offset < bytes.length; offset += 64) {
    for (var index = 0; index < 16; index++) {
      final base = offset + index * 4;
      words[index] = ((bytes[base] << 24) |
              (bytes[base + 1] << 16) |
              (bytes[base + 2] << 8) |
              bytes[base + 3]) &
          0xffffffff;
    }
    for (var index = 16; index < 64; index++) {
      final s0 = rotateRight(words[index - 15], 7) ^
          rotateRight(words[index - 15], 18) ^
          (words[index - 15] >>> 3);
      final s1 = rotateRight(words[index - 2], 17) ^
          rotateRight(words[index - 2], 19) ^
          (words[index - 2] >>> 10);
      words[index] =
          (words[index - 16] + s0 + words[index - 7] + s1) & 0xffffffff;
    }

    var a = h0;
    var b = h1;
    var c = h2;
    var d = h3;
    var e = h4;
    var f = h5;
    var g = h6;
    var h = h7;

    for (var index = 0; index < 64; index++) {
      final sum1 =
          rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25);
      final choose = (e & f) ^ ((~e) & g);
      final temp1 =
          (h + sum1 + choose + roundConstants[index] + words[index]) &
              0xffffffff;
      final sum0 =
          rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (sum0 + majority) & 0xffffffff;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }

    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + h) & 0xffffffff;
  }

  return <int>[h0, h1, h2, h3, h4, h5, h6, h7]
      .map((value) => value.toRadixString(16).padLeft(8, '0'))
      .join();
}

class PlantaoLegacyProtocolMatch {
  PlantaoLegacyProtocolMatch({
    required this.documentId,
    required this.version,
    required this.title,
    required this.recognize,
    required this.definition,
    required Iterable<String> actions,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : actions = List<String>.unmodifiable(actions),
       metadata = Map<String, Object?>.unmodifiable(metadata);

  final String documentId;
  final String version;
  final String title;
  final String recognize;
  final String definition;
  final List<String> actions;
  final Map<String, Object?> metadata;

  void ensureValid() {
    if (documentId.trim().isEmpty) {
      throw const FormatException('Protocol documentId cannot be empty');
    }
    if (version.trim().isEmpty) {
      throw const FormatException('Protocol version cannot be empty');
    }
    if (title.trim().isEmpty) {
      throw const FormatException('Protocol title cannot be empty');
    }
  }
}

class PlantaoRetrievalShadowSnapshot {
  PlantaoRetrievalShadowSnapshot({
    required this.requestId,
    required this.evidenceBundle,
    required Iterable<String> matchedProtocolDocumentIds,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : matchedProtocolDocumentIds = List<String>.unmodifiable(
         matchedProtocolDocumentIds,
       ),
       reasons = List<String>.unmodifiable(reasons);

  static const bool productiveExecutionEnabled = false;
  static const bool providerConnected = false;
  static const bool firestoreConnected = false;
  static const bool renderingEnabled = false;
  static const bool persistenceWriteEnabled = false;
  static const bool externalGroundingConnected = false;
  static const bool drugRetrievalConnected = false;
  static const bool legacyProtocolRetrievalBound = true;

  final String requestId;
  final PlantaoEvidenceBundle evidenceBundle;
  final List<String> matchedProtocolDocumentIds;
  final List<String> reasons;
  final DateTime observedAt;
}

class PlantaoRetrievalShadowAdapter {
  const PlantaoRetrievalShadowAdapter();

  PlantaoRetrievalShadowSnapshot bindLegacyProtocolMatches({
    required PlantaoRequest request,
    required Iterable<PlantaoLegacyProtocolMatch> matches,
  }) {
    final boundProtocolMatches =
        matches.toList(growable: false);
    final locale = request.language == PlantaoLanguage.es ? 'es' : 'pt';
    final sessionIdHash = _plantaoRetrievalShadowSha256Hex(request.sessionId);
    final queryFingerprint = _plantaoRetrievalShadowSha256Hex('$locale:${request.question.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase()}');
    final protocolsById = {
      for (final protocol in protocolsDatabase) protocol.id: protocol,
    };
    final protocolEvidence = <PlantaoEvidenceItem>[];
    final protocolLimitations = <String>[];

    for (final match in boundProtocolMatches) {
      final metadataId = match.metadata['legacyProtocolId'];
      final documentId = match.documentId;
      final documentIdValue = documentId.startsWith('protocol:')
          ? documentId.substring('protocol:'.length)
          : '';

      if (metadataId is! String ||
          metadataId.isEmpty ||
          documentIdValue.isEmpty) {
        protocolLimitations.add('protocol_identity_missing');
        continue;
      }
      if (metadataId != documentIdValue) {
        protocolLimitations.add('protocol_identity_mismatch');
        continue;
      }

      final protocol = protocolsById[metadataId];
      if (protocol == null) {
        protocolLimitations.add('protocol_model_not_found');
        continue;
      }

      protocolEvidence.add(PlantaoProtocolMatcherEvidenceAdapter.toEvidenceItem(protocol: protocol, locale: locale));
    }

    final validationStatus = boundProtocolMatches.isEmpty
        ? PlantaoEvidenceValidationStatus.unavailable
        : protocolEvidence.length == boundProtocolMatches.length &&
                protocolLimitations.isEmpty
            ? PlantaoEvidenceValidationStatus.validated
            : PlantaoEvidenceValidationStatus.rejected;
    final limitations = List<String>.unmodifiable(protocolLimitations);
    const drugEvidence = <PlantaoEvidenceItem>[];
    final bundleHash = PlantaoEvidenceBundle.computeCanonicalBundleHash(
      locale: locale,
      queryFingerprint: queryFingerprint,
      protocolEvidence: protocolEvidence,
      drugEvidence: drugEvidence,
      validationStatus: validationStatus,
      limitations: limitations,
    );
    final createdAtEpochMs =
        DateTime.now().toUtc().millisecondsSinceEpoch;

    request.ensureValid();

    final uniqueMatches = <String, PlantaoLegacyProtocolMatch>{};
    for (final match in boundProtocolMatches) {
      match.ensureValid();
      uniqueMatches.putIfAbsent(match.documentId, () => match);
    }

    final protocolDocuments = uniqueMatches.values
        .map(
          (match) => PlantaoEvidenceDocument(
            documentId: match.documentId,
            version: match.version,
            kind: PlantaoEvidenceKind.protocol,
            excerpt: _excerpt(match),
            metadata: <String, Object?>{
              ...match.metadata,
              'title': match.title,
              'sourceMode': 'legacy_local_protocol_retrieval',
              'deduplicated': true,
            },
          ),
        )
        .toList(growable: false);

    final versions = <String, String>{
      for (final document in protocolDocuments)
        document.documentId: document.version,
    };

    final reasons = <String>[
      if (protocolDocuments.isEmpty) 'legacy_protocol_retrieval_empty',
      'dedicated_clinical_document_retrieval_not_connected',
      'drug_retrieval_not_connected',
      'external_grounding_not_bound',
    ];

    final bundle = PlantaoEvidenceBundle(
      requestId: request.requestId,
      sessionIdHash: sessionIdHash,
      locale: locale,
      queryFingerprint: queryFingerprint,
      protocolEvidence: List<PlantaoEvidenceItem>.unmodifiable(protocolEvidence),
      drugEvidence: drugEvidence,
      validationStatus: validationStatus,
      bundleHash: bundleHash,
      createdAtEpochMs: createdAtEpochMs,
      limitations: limitations,
      clinicalDocuments: const <PlantaoEvidenceDocument>[],
      drugDocuments: const <PlantaoDrugEvidenceDocument>[],
      protocolDocuments: protocolDocuments,
      patientFacts: const <PlantaoEvidenceDocument>[],
      caseEvidence: const <PlantaoEvidenceDocument>[],
      externalGrounding: const <PlantaoEvidenceDocument>[],
      documentVersions: versions,
      coverage: PlantaoEvidenceCoverage(
        hasClinical: false,
        hasDrug: false,
        hasProtocol: protocolDocuments.isNotEmpty,
        hasPatientFacts: false,
      ),
      missingRequirements: reasons,
      retrievalStatus: protocolDocuments.isEmpty
          ? PlantaoRetrievalStatus.empty
          : PlantaoRetrievalStatus.partial,
    );

    return PlantaoRetrievalShadowSnapshot(
      requestId: request.requestId,
      evidenceBundle: bundle,
      matchedProtocolDocumentIds: protocolDocuments.map(
        (document) => document.documentId,
      ),
      reasons: reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }

  static String _excerpt(PlantaoLegacyProtocolMatch match) {
    final parts = <String>[
      match.title.trim(),
      if (match.recognize.trim().isNotEmpty)
        'Reconhecer: ${match.recognize.trim()}',
      if (match.definition.trim().isNotEmpty)
        'Definição: ${match.definition.trim()}',
      if (match.actions.isNotEmpty)
        'Conduta: ${match.actions.where((item) => item.trim().isNotEmpty).join(' | ')}',
    ];
    final combined = parts.join('\n');
    if (combined.length <= 1200) return combined;
    return combined.substring(0, 1200);
  }
}
