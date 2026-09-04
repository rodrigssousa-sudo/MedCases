final class ClinicalTranscriptionEvalCase {
  const ClinicalTranscriptionEvalCase({
    required this.id,
    required this.locale,
    required this.reference,
    required this.hypothesis,
    this.medicalTerms = const <String>[],
    this.units = const <String>[],
    this.criticalPhrases = const <String>[],
  });

  final String id;
  final String locale;
  final String reference;
  final String hypothesis;
  final List<String> medicalTerms;
  final List<String> units;
  final List<String> criticalPhrases;
}

final class ClinicalTranscriptionAccuracyResult {
  const ClinicalTranscriptionAccuracyResult({
    required this.id,
    required this.wordErrorRate,
    required this.wordAccuracy,
    required this.medicalTermRecall,
    required this.numberRecall,
    required this.unitRecall,
    required this.criticalPhraseRecall,
    required this.weightedClinicalScore,
    required this.referenceWordCount,
    required this.editDistance,
  });

  final String id;
  final double wordErrorRate;
  final double wordAccuracy;
  final double medicalTermRecall;
  final double numberRecall;
  final double unitRecall;
  final double criticalPhraseRecall;
  final double weightedClinicalScore;
  final int referenceWordCount;
  final int editDistance;

  bool get passesStrictClinicalGate =>
      weightedClinicalScore >= 0.95 &&
      medicalTermRecall == 1.0 &&
      numberRecall == 1.0 &&
      unitRecall == 1.0 &&
      criticalPhraseRecall == 1.0;
}

final class ClinicalTranscriptionSuiteResult {
  const ClinicalTranscriptionSuiteResult({
    required this.results,
    required this.averageWordErrorRate,
    required this.averageClinicalScore,
    required this.strictPassCount,
  });

  final List<ClinicalTranscriptionAccuracyResult> results;
  final double averageWordErrorRate;
  final double averageClinicalScore;
  final int strictPassCount;
}

final class ClinicalTranscriptionAccuracyEvaluator {
  const ClinicalTranscriptionAccuracyEvaluator();

  ClinicalTranscriptionAccuracyResult evaluate(
    ClinicalTranscriptionEvalCase testCase,
  ) {
    final referenceWords = _words(testCase.reference);
    final hypothesisWords = _words(testCase.hypothesis);

    final distance = _levenshtein(referenceWords, hypothesisWords);
    final wer = referenceWords.isEmpty
        ? (hypothesisWords.isEmpty ? 0.0 : 1.0)
        : distance / referenceWords.length;

    final wordAccuracy = (1.0 - wer).clamp(0.0, 1.0).toDouble();

    final medicalRecall = _phraseRecall(
      testCase.medicalTerms,
      testCase.hypothesis,
    );

    final unitRecall = _phraseRecall(
      testCase.units,
      testCase.hypothesis,
    );

    final criticalRecall = _phraseRecall(
      testCase.criticalPhrases,
      testCase.hypothesis,
    );

    final referenceNumbers = _numbers(testCase.reference);
    final hypothesisNumbers = _numbers(testCase.hypothesis);
    final numberRecall = _multisetRecall(
      referenceNumbers,
      hypothesisNumbers,
    );

    final weighted = (wordAccuracy * 0.35 +
            medicalRecall * 0.25 +
            numberRecall * 0.20 +
            unitRecall * 0.10 +
            criticalRecall * 0.10)
        .clamp(0.0, 1.0)
        .toDouble();

    return ClinicalTranscriptionAccuracyResult(
      id: testCase.id,
      wordErrorRate: wer,
      wordAccuracy: wordAccuracy,
      medicalTermRecall: medicalRecall,
      numberRecall: numberRecall,
      unitRecall: unitRecall,
      criticalPhraseRecall: criticalRecall,
      weightedClinicalScore: weighted,
      referenceWordCount: referenceWords.length,
      editDistance: distance,
    );
  }

  ClinicalTranscriptionSuiteResult evaluateSuite(
    Iterable<ClinicalTranscriptionEvalCase> cases,
  ) {
    final results = cases.map(evaluate).toList(growable: false);

    if (results.isEmpty) {
      return const ClinicalTranscriptionSuiteResult(
        results: <ClinicalTranscriptionAccuracyResult>[],
        averageWordErrorRate: 0,
        averageClinicalScore: 0,
        strictPassCount: 0,
      );
    }

    final averageWer =
        results.map((result) => result.wordErrorRate).reduce((a, b) => a + b) /
            results.length;

    final averageClinical = results
            .map((result) => result.weightedClinicalScore)
            .reduce((a, b) => a + b) /
        results.length;

    final strictPasses =
        results.where((result) => result.passesStrictClinicalGate).length;

    return ClinicalTranscriptionSuiteResult(
      results: List<ClinicalTranscriptionAccuracyResult>.unmodifiable(
        results,
      ),
      averageWordErrorRate: averageWer,
      averageClinicalScore: averageClinical,
      strictPassCount: strictPasses,
    );
  }

  static List<String> _words(String value) {
    return _lexicalTokens(value);
  }

  static List<String> _numbers(String value) {
    return _lexicalTokens(value)
        .where((token) => RegExp(r'^\d').hasMatch(token))
        .toList(growable: false);
  }

  /// Tokenização clínica:
  /// - ignora pontuação terminal e separadores de frase;
  /// - preserva unidades compostas com slash (mg/dl);
  /// - preserva números decimais como um token;
  /// - canonicaliza somente separador decimal ',' -> '.';
  /// - NÃO transforma g em mg nem altera valores numéricos.
  static List<String> _lexicalTokens(String value) {
    final matches = RegExp(
      r'\d+(?:[.,]\d+)?|\p{L}+(?:/\p{L}+)*|%+',
      unicode: true,
    ).allMatches(value.toLowerCase());

    return matches
        .map((match) => match.group(0)!.replaceAll(',', '.'))
        .toList(growable: false);
  }

  static double _phraseRecall(
    Iterable<String> expected,
    String hypothesis,
  ) {
    final expectedItems = expected
        .map(_normalizeText)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    if (expectedItems.isEmpty) {
      return 1.0;
    }

    final normalizedHypothesis = _normalizeText(hypothesis);
    var hits = 0;

    for (final item in expectedItems) {
      if (_containsWholePhrase(normalizedHypothesis, item)) {
        hits++;
      }
    }

    return hits / expectedItems.length;
  }

  static double _multisetRecall(
    List<String> expected,
    List<String> observed,
  ) {
    if (expected.isEmpty) {
      return 1.0;
    }

    final available = <String, int>{};
    for (final item in observed) {
      available[item] = (available[item] ?? 0) + 1;
    }

    var hits = 0;
    for (final item in expected) {
      final count = available[item] ?? 0;
      if (count > 0) {
        hits++;
        available[item] = count - 1;
      }
    }

    return hits / expected.length;
  }

  static bool _containsWholePhrase(
    String normalizedHaystack,
    String normalizedNeedle,
  ) {
    final paddedHaystack = ' $normalizedHaystack ';
    final paddedNeedle = ' $normalizedNeedle ';
    return paddedHaystack.contains(paddedNeedle);
  }

  static String _normalizeText(String value) {
    return _lexicalTokens(value).join(' ');
  }

  static int _levenshtein(
    List<String> reference,
    List<String> hypothesis,
  ) {
    if (reference.isEmpty) {
      return hypothesis.length;
    }
    if (hypothesis.isEmpty) {
      return reference.length;
    }

    var previous = List<int>.generate(
      hypothesis.length + 1,
      (index) => index,
    );

    for (var i = 1; i <= reference.length; i++) {
      final current = List<int>.filled(hypothesis.length + 1, 0);
      current[0] = i;

      for (var j = 1; j <= hypothesis.length; j++) {
        final substitutionCost = reference[i - 1] == hypothesis[j - 1] ? 0 : 1;

        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + substitutionCost;

        var best = deletion;
        if (insertion < best) {
          best = insertion;
        }
        if (substitution < best) {
          best = substitution;
        }
        current[j] = best;
      }

      previous = current;
    }

    return previous.last;
  }
}
