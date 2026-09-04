class PlantaoMachineNativeRichPhaseCompletionResult {
  const PlantaoMachineNativeRichPhaseCompletionResult({
    required this.text,
    required this.applied,
    required this.addedMonitoring,
    required this.addedReassessment,
    required this.addedEscalation,
  });

  final String text;
  final bool applied;
  final int addedMonitoring;
  final int addedReassessment;
  final int addedEscalation;
}

/// M73B_TYPED_RICH_PHASES_FINAL_COMPLETENESS_BRIDGE_V1
///
/// Deterministic, provider-free completion from exact authored machine phases.
class PlantaoMachineNativeRichPhaseCompletion {
  const PlantaoMachineNativeRichPhaseCompletion._();

  static PlantaoMachineNativeRichPhaseCompletionResult complete({
    required String text,
    required String userText,
    required String language,
    required bool enabled,
    required List<String> monitoring,
    required List<String> reassessment,
    required List<String> escalationCriteria,
  }) {
    if (!enabled ||
        text.trim().isEmpty ||
        !_hasManagementIntentOrSurface(userText, text)) {
      return PlantaoMachineNativeRichPhaseCompletionResult(
        text: text,
        applied: false,
        addedMonitoring: 0,
        addedReassessment: 0,
        addedEscalation: 0,
      );
    }

    final missingMonitoring = _missing(text, monitoring);
    final missingReassessment = _missing(text, reassessment);
    final missingEscalation = _missing(text, escalationCriteria);

    if (missingMonitoring.isEmpty &&
        missingReassessment.isEmpty &&
        missingEscalation.isEmpty) {
      return PlantaoMachineNativeRichPhaseCompletionResult(
        text: text,
        applied: false,
        addedMonitoring: 0,
        addedReassessment: 0,
        addedEscalation: 0,
      );
    }

    final isEs = language.toLowerCase().startsWith('es');
    final out = StringBuffer(text.trimRight());

    final monitorAndReassess = <String>[
      ...missingMonitoring,
      ...missingReassessment,
    ];

    if (monitorAndReassess.isNotEmpty) {
      out
        ..writeln()
        ..writeln()
        ..writeln(
          isEs
              ? 'Monitorización y reevaluación'
              : 'Monitorização e reavaliação',
        );
      for (final item in _unique(monitorAndReassess)) {
        out.writeln('- $item');
      }
    }

    if (missingEscalation.isNotEmpty) {
      out
        ..writeln()
        ..writeln(
          isEs ? 'Red flags/escalamiento' : 'Sinais de alerta/escalonamento',
        );
      for (final item in _unique(missingEscalation)) {
        out.writeln('- $item');
      }
    }

    return PlantaoMachineNativeRichPhaseCompletionResult(
      text: out.toString().trimRight(),
      applied: true,
      addedMonitoring: missingMonitoring.length,
      addedReassessment: missingReassessment.length,
      addedEscalation: missingEscalation.length,
    );
  }

  static bool _hasManagementIntentOrSurface(String userText, String text) {
    final folded = _fold('$userText\n$text');
    const markers = <String>[
      'conducta',
      'conducta inmediata',
      'manejo',
      'tratamiento',
      'que hacer',
      'conduta',
      'conduta imediata',
      'tratamento',
      'o que fazer',
      'intervencao',
    ];
    return markers.any(folded.contains);
  }

  static List<String> _missing(String text, List<String> authored) {
    final out = <String>[];
    for (final raw in authored) {
      final item = raw.trim();
      if (item.isEmpty) continue;
      if (!_containsEvidence(text, item)) out.add(item);
    }
    return _unique(out);
  }

  static bool _containsEvidence(String text, String authored) {
    final hay = _fold(text);
    final needle = _fold(authored);
    if (needle.isEmpty || hay.contains(needle)) return true;

    final authoredTokens = _tokens(needle);
    if (authoredTokens.isEmpty) return true;
    final hayTokens = _tokens(hay).toSet();

    var matched = 0;
    for (final token in authoredTokens) {
      if (hayTokens.contains(token)) matched++;
    }
    return matched / authoredTokens.length >= 0.65;
  }

  static List<String> _tokens(String value) {
    const stop = <String>{
      'para',
      'por',
      'con',
      'sin',
      'ante',
      'cada',
      'hasta',
      'quando',
      'com',
      'sem',
      'apos',
      'depois',
      'pela',
      'pelo',
      'uma',
      'uno',
      'una',
      'del',
      'las',
      'los',
      'que',
      'and',
    };
    return value
        .split(' ')
        .where((t) => t.length >= 4 && !stop.contains(t))
        .toSet()
        .toList(growable: false);
  }

  static List<String> _unique(List<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in values) {
      final key = _fold(item);
      if (key.isEmpty || !seen.add(key)) continue;
      out.add(item);
    }
    return out;
  }

  static String _fold(String value) {
    var s = value.toLowerCase();
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
    replacements.forEach((from, to) => s = s.replaceAll(from, to));
    return s
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
