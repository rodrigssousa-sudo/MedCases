final class PlantaoCanonicalPhenotypeResolution {
  const PlantaoCanonicalPhenotypeResolution({
    required this.canonicalPathologyKey,
    required this.ruleId,
    required this.confidence,
  });

  final String canonicalPathologyKey;
  final String ruleId;
  final double confidence;
}

/// High-specificity phenotype bridge.
///
/// It does not load a protocol, authorize treatment, call a provider, write
/// Firestore, or render UI. It only proposes a canonical pathology key.
/// The machine-native prefetch must still prove that the key exists uniquely
/// in the enabled identity registry before any clinical authority is loaded.
abstract final class PlantaoCanonicalPhenotypeResolver {
  static const String anaphylaxisRule =
      'M58_ANAPHYLAXIS_HIGH_SPECIFICITY_PHENOTYPE_V1';

  static PlantaoCanonicalPhenotypeResolution? resolve(String clinicalText) {
    final q = _fold(clinicalText);
    if (q.isEmpty) return null;

    if (_containsAny(q, const <String>[
      'anafilaxia',
      'anafilax',
      'anaphylaxis',
      'choque anafilactico',
      'choque anafilatico',
    ])) {
      return const PlantaoCanonicalPhenotypeResolution(
        canonicalPathologyKey: 'anafilaxia',
        ruleId: anaphylaxisRule,
        confidence: 1,
      );
    }

    final skinMucosa = _hasPositiveSignal(
      q,
      const <String>[
        'urticaria',
        'angioedema',
        'edema labial',
        'edema de labios',
        'edema de labio',
        'edema de lingua',
        'edema de lengua',
        'edema de uvula',
      ],
      const <String>[
        'sin urticaria',
        'sem urticaria',
        'sin angioedema',
        'sem angioedema',
        'sin edema labial',
        'sem edema labial',
        'sin edema de labios',
        'sem edema de labios',
        'sin edema de lengua',
        'sem edema de lingua',
      ],
    );

    final breathing = _hasPositiveSignal(
      q,
      const <String>[
        'disnea',
        'dispneia',
        'sibilancia',
        'sibilancias',
        'sibilos',
        'broncoespasmo',
        'estridor',
        'rouquidao',
        'ronquera',
      ],
      const <String>[
        'sin disnea',
        'sem dispneia',
        'sin sibilancia',
        'sin sibilancias',
        'sem sibilancia',
        'sem sibilancias',
        'sem sibilos',
        'sin broncoespasmo',
        'sem broncoespasmo',
        'sin estridor',
        'sem estridor',
        'sin ronquera',
        'sem rouquidao',
      ],
    );

    final circulation =
        _hasPositiveSignal(
          q,
          const <String>[
            'hipotension',
            'hipotensao',
            'choque',
            'shock',
            'mareo',
            'tontura',
            'sincope',
          ],
          const <String>[
            'sin hipotension',
            'sem hipotensao',
            'sin shock',
            'sem shock',
            'sin choque',
            'sem choque',
            'sin mareo',
            'sem tontura',
            'sin sincope',
            'sem sincope',
          ],
        ) ||
        _hasAdultHypotensiveBloodPressure(q);

    final trigger = _containsAny(q, const <String>[
      'mani',
      'cacahuete',
      'amendoim',
      'penicilina',
      'amoxicilina',
      'picadura',
      'medicamento',
      'alimento',
      'ingerir',
      'ingesta',
      'tras ingerir',
      'despues de ingerir',
    ]);

    final highSpecificity =
        skinMucosa &&
        (breathing || circulation) &&
        (trigger || (breathing && circulation));

    if (!highSpecificity) return null;

    return const PlantaoCanonicalPhenotypeResolution(
      canonicalPathologyKey: 'anafilaxia',
      ruleId: anaphylaxisRule,
      confidence: 0.98,
    );
  }

  static bool _hasAdultHypotensiveBloodPressure(String q) {
    final match = RegExp(
      r'\b(?:pa|presion|pressao)\s*[:=]?\s*(\d{2,3})\s*/\s*(\d{2,3})\b',
    ).firstMatch(q);
    if (match == null) return false;
    final systolic = int.tryParse(match.group(1) ?? '');
    return systolic != null && systolic < 90;
  }

  static bool _hasPositiveSignal(
    String q,
    Iterable<String> positiveTerms,
    Iterable<String> explicitNegations,
  ) {
    if (!_containsAny(q, positiveTerms)) return false;
    return !_containsAny(q, explicitNegations);
  }

  static bool _containsAny(String q, Iterable<String> terms) =>
      terms.any(q.contains);

  static String _fold(String value) {
    var out = value.toLowerCase();
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
    for (final entry in replacements.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return out
        .replaceAll(RegExp(r'[^a-z0-9/_ ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
