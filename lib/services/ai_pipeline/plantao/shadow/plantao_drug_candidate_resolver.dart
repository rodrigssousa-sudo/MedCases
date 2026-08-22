import '../contracts/plantao_canonical_drug_evidence.dart';

class PlantaoDrugCandidateResolver {
  const PlantaoDrugCandidateResolver();

  PlantaoDrugCandidateResolution resolve({
    required String term,
    required String languageCode,
    required Iterable<PlantaoDrugEvidenceIndexEntry> entries,
  }) {
    final normalizedTerm = normalize(term);
    if (normalizedTerm.isEmpty) {
      return PlantaoDrugCandidateResolution(
        status: PlantaoDrugCandidateResolutionStatus.invalidInput,
        normalizedTerm: normalizedTerm,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        reasons: const <String>['drug_identity_term_empty'],
      );
    }

    final entryList = List<PlantaoDrugEvidenceIndexEntry>.unmodifiable(entries);
    final stages = <_ResolutionStage>[
      _ResolutionStage(
        kind: PlantaoDrugIdentityMatchKind.exactId,
        values: (entry) => <String>[entry.documentId],
      ),
      _ResolutionStage(
        kind: PlantaoDrugIdentityMatchKind.exactPreferredLanguageName,
        values: (entry) => _nameVariants(entry.nameFor(languageCode)),
      ),
      _ResolutionStage(
        kind: PlantaoDrugIdentityMatchKind.exactSecondaryLanguageName,
        values: (entry) => _nameVariants(entry.secondaryNameFor(languageCode)),
      ),
      _ResolutionStage(
        kind: PlantaoDrugIdentityMatchKind.exactKeyword,
        values: (entry) => entry.keywords,
      ),
    ];

    for (final stage in stages) {
      final matches = <String, PlantaoCanonicalDrugCandidate>{};
      for (final entry in entryList) {
        final matchedValue = stage
            .values(entry)
            .firstWhere(
              (value) => normalize(value) == normalizedTerm,
              orElse: () => '',
            );
        if (matchedValue.isEmpty) continue;
        matches.putIfAbsent(
          entry.documentId,
          () => PlantaoCanonicalDrugCandidate(
            documentId: entry.documentId,
            canonicalName: entry.nameFor(languageCode),
            matchedValue: matchedValue,
            matchKind: stage.kind,
            schema: entry.schema,
            sourceModule: entry.sourceModule,
            hasContextVariants: entry.hasContextVariants,
          ),
        );
      }

      if (matches.length == 1) {
        return PlantaoDrugCandidateResolution(
          status: PlantaoDrugCandidateResolutionStatus.matched,
          normalizedTerm: normalizedTerm,
          candidates: matches.values,
          reasons: <String>['exact_${stage.kind.name}'],
        );
      }
      if (matches.length > 1) {
        return PlantaoDrugCandidateResolution(
          status: PlantaoDrugCandidateResolutionStatus.ambiguous,
          normalizedTerm: normalizedTerm,
          candidates: matches.values,
          reasons: <String>['ambiguous_${stage.kind.name}:${matches.length}'],
        );
      }
    }

    return PlantaoDrugCandidateResolution(
      status: PlantaoDrugCandidateResolutionStatus.notFound,
      normalizedTerm: normalizedTerm,
      candidates: const <PlantaoCanonicalDrugCandidate>[],
      reasons: const <String>['drug_identity_not_found'],
    );
  }

  static List<String> _nameVariants(String value) {
    final variants = <String>[value];
    for (final part in value.split('/')) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty && !variants.contains(trimmed)) {
        variants.add(trimmed);
      }
    }
    return variants;
  }

  static String normalize(String value) {
    var normalized = value.trim().toLowerCase();
    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
      '_': ' ',
      '-': ' ',
      '/': ' ',
    };
    for (final replacement in replacements.entries) {
      normalized = normalized.replaceAll(replacement.key, replacement.value);
    }
    return normalized
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
  }
}

class _ResolutionStage {
  const _ResolutionStage({required this.kind, required this.values});

  final PlantaoDrugIdentityMatchKind kind;
  final List<String> Function(PlantaoDrugEvidenceIndexEntry entry) values;
}
