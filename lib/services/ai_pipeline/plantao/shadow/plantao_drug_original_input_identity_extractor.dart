import '../contracts/plantao_canonical_drug_evidence.dart';

enum PlantaoDrugOriginalInputIntent {
  none,
  drugInformation,
  dosage,
  dilution,
  infusion,
  interaction,
}

enum PlantaoDrugOriginalInputExtractionStatus {
  notEvaluated,
  matched,
  empty,
  ambiguous,
  invalidInput,
}

class PlantaoDrugOriginalInputExtraction {
  PlantaoDrugOriginalInputExtraction({
    required this.status,
    required this.intent,
    required Iterable<PlantaoCanonicalDrugCandidate> candidates,
    required Iterable<String> reasons,
  }) : candidates = List<PlantaoCanonicalDrugCandidate>.unmodifiable(
         candidates,
       ),
       reasons = List<String>.unmodifiable(reasons);

  final PlantaoDrugOriginalInputExtractionStatus status;
  final PlantaoDrugOriginalInputIntent intent;
  final List<PlantaoCanonicalDrugCandidate> candidates;
  final List<String> reasons;

  bool get isMatched =>
      status == PlantaoDrugOriginalInputExtractionStatus.matched &&
      candidates.isNotEmpty;
}

class PlantaoDrugOriginalInputIdentityExtractor {
  const PlantaoDrugOriginalInputIdentityExtractor();

  PlantaoDrugOriginalInputExtraction extract({
    required String originalUserInput,
    required String languageCode,
    required PlantaoDrugOriginalInputIntent intent,
    required Iterable<PlantaoDrugEvidenceIndexEntry> entries,
    int maximumCandidates = 8,
  }) {
    if (intent == PlantaoDrugOriginalInputIntent.none) {
      return PlantaoDrugOriginalInputExtraction(
        status: PlantaoDrugOriginalInputExtractionStatus.notEvaluated,
        intent: intent,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        reasons: const <String>['explicit_pharmacology_intent_absent'],
      );
    }

    final normalizedInput = normalizeForBoundary(originalUserInput);
    if (normalizedInput.isEmpty) {
      return PlantaoDrugOriginalInputExtraction(
        status: PlantaoDrugOriginalInputExtractionStatus.invalidInput,
        intent: intent,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        reasons: const <String>['original_user_input_empty'],
      );
    }
    if (maximumCandidates <= 0) {
      return PlantaoDrugOriginalInputExtraction(
        status: PlantaoDrugOriginalInputExtractionStatus.invalidInput,
        intent: intent,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        reasons: const <String>['maximum_candidates_invalid'],
      );
    }

    final paddedInput = ' $normalizedInput ';
    final aliasOwners = <String, Set<String>>{};
    final matches = <_EntryMatch>[];

    for (final entry in entries) {
      entry.ensureValid();
      _EntryMatch? best;
      for (final alias in _aliases(entry, languageCode)) {
        final normalizedAlias = normalizeForBoundary(alias.value);
        if (!_isSafeAlias(normalizedAlias, source: alias.source)) continue;
        final needle = ' $normalizedAlias ';
        final position = paddedInput.indexOf(needle);
        if (position < 0) continue;

        aliasOwners
            .putIfAbsent(normalizedAlias, () => <String>{})
            .add(entry.documentId);
        final candidate = _EntryMatch(
          entry: entry,
          alias: alias.value,
          normalizedAlias: normalizedAlias,
          matchKind: alias.matchKind,
          position: position,
        );
        if (best == null ||
            candidate.normalizedAlias.length > best.normalizedAlias.length) {
          best = candidate;
        }
      }
      if (best != null) matches.add(best);
    }

    matches.sort((left, right) {
      final position = left.position.compareTo(right.position);
      if (position != 0) return position;
      return right.normalizedAlias.length.compareTo(
        left.normalizedAlias.length,
      );
    });

    final deduplicated = <String, _EntryMatch>{};
    for (final match in matches) {
      deduplicated.putIfAbsent(match.entry.documentId, () => match);
    }
    final selected = deduplicated.values.toList(growable: false);

    if (selected.isEmpty) {
      return PlantaoDrugOriginalInputExtraction(
        status: PlantaoDrugOriginalInputExtractionStatus.empty,
        intent: intent,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        reasons: const <String>[
          'canonical_drug_identity_not_found_in_original_input',
        ],
      );
    }

    final hasAliasCollision = selected.any(
      (match) => (aliasOwners[match.normalizedAlias]?.length ?? 0) > 1,
    );
    final exceedsLimit = selected.length > maximumCandidates;
    final invalidInteractionCardinality =
        intent == PlantaoDrugOriginalInputIntent.interaction &&
        selected.length != 2;

    final candidates = selected
        .take(maximumCandidates)
        .map(
          (match) => PlantaoCanonicalDrugCandidate(
            documentId: match.entry.documentId,
            canonicalName: match.entry.nameFor(languageCode),
            matchedValue: match.alias,
            matchKind: match.matchKind,
            schema: match.entry.schema,
            sourceModule: match.entry.sourceModule,
            hasContextVariants: match.entry.hasContextVariants,
          ),
        )
        .toList(growable: false);

    if (hasAliasCollision || exceedsLimit || invalidInteractionCardinality) {
      return PlantaoDrugOriginalInputExtraction(
        status: PlantaoDrugOriginalInputExtractionStatus.ambiguous,
        intent: intent,
        candidates: candidates,
        reasons: <String>[
          if (hasAliasCollision) 'canonical_alias_collision',
          if (exceedsLimit)
            'canonical_candidate_limit_exceeded:${selected.length}',
          if (invalidInteractionCardinality)
            'interaction_requires_exactly_two_drugs:${selected.length}',
        ],
      );
    }

    return PlantaoDrugOriginalInputExtraction(
      status: PlantaoDrugOriginalInputExtractionStatus.matched,
      intent: intent,
      candidates: candidates,
      reasons: <String>[
        'canonical_identity_resolved_from_original_user_input',
        if (candidates.any((candidate) => candidate.hasContextVariants))
          'canonical_context_variants_present',
      ],
    );
  }

  static String normalizeForBoundary(String value) {
    var source = value.trim().toLowerCase();
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
    };
    for (final replacement in replacements.entries) {
      source = source.replaceAll(replacement.key, replacement.value);
    }

    final output = StringBuffer();
    var lastWasSpace = true;
    for (final codeUnit in source.codeUnits) {
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isLetter = codeUnit >= 97 && codeUnit <= 122;
      if (isDigit || isLetter) {
        output.writeCharCode(codeUnit);
        lastWasSpace = false;
      } else if (!lastWasSpace) {
        output.write(' ');
        lastWasSpace = true;
      }
    }
    return output.toString().trim();
  }

  static Iterable<_Alias> _aliases(
    PlantaoDrugEvidenceIndexEntry entry,
    String languageCode,
  ) sync* {
    yield _Alias(
      value: entry.documentId,
      matchKind: PlantaoDrugIdentityMatchKind.exactId,
      source: _AliasSource.identifier,
    );

    for (final value in <String>[
      entry.nameFor(languageCode),
      entry.secondaryNameFor(languageCode),
    ]) {
      for (final variant in _nameVariants(value)) {
        yield _Alias(
          value: variant,
          matchKind: variant == value
              ? PlantaoDrugIdentityMatchKind.exactPreferredLanguageName
              : PlantaoDrugIdentityMatchKind.exactSecondaryLanguageName,
          source: _AliasSource.name,
        );
      }
    }

    for (final keyword in entry.keywords) {
      yield _Alias(
        value: keyword,
        matchKind: PlantaoDrugIdentityMatchKind.exactKeyword,
        source: _AliasSource.keyword,
      );
    }
  }

  static Iterable<String> _nameVariants(String value) sync* {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    yield trimmed;

    final opening = trimmed.indexOf('(');
    final closing = opening < 0 ? -1 : trimmed.indexOf(')', opening + 1);
    if (opening > 0) {
      final base = trimmed.substring(0, opening).trim();
      if (base.isNotEmpty && base != trimmed) yield base;
    }
    if (opening >= 0 && closing > opening + 1) {
      final parenthetical = trimmed.substring(opening + 1, closing).trim();
      final normalized = normalizeForBoundary(parenthetical);
      if (normalized.isNotEmpty && !normalized.contains(' ')) {
        yield parenthetical;
      }
    }
  }

  static bool _isSafeAlias(String normalized, {required _AliasSource source}) {
    if (normalized.length < 3 || normalized.length > 64) return false;
    final tokenCount = normalized.split(' ').length;
    if (source == _AliasSource.keyword) {
      return normalized.length >= 4 && tokenCount <= 3;
    }
    return tokenCount <= 6;
  }
}

enum _AliasSource { identifier, name, keyword }

class _Alias {
  const _Alias({
    required this.value,
    required this.matchKind,
    required this.source,
  });

  final String value;
  final PlantaoDrugIdentityMatchKind matchKind;
  final _AliasSource source;
}

class _EntryMatch {
  const _EntryMatch({
    required this.entry,
    required this.alias,
    required this.normalizedAlias,
    required this.matchKind,
    required this.position,
  });

  final PlantaoDrugEvidenceIndexEntry entry;
  final String alias;
  final String normalizedAlias;
  final PlantaoDrugIdentityMatchKind matchKind;
  final int position;
}
