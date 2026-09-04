final class ClinicalMedicalVocabulary {
  const ClinicalMedicalVocabulary._();

  static const List<String> _shared = <String>[
    'ceftriaxona',
    'piperacilina',
    'tazobactam',
    'vancomicina',
    'enoxaparina',
    'metformina',
    'insulina',
    'noradrenalina',
    'adrenalina',
    'furosemida',
    'creatinina',
    'troponina',
    'hemoglobina',
    'hematócrito',
    'plaquetas',
    'leucócitos',
    'sódio',
    'potássio',
    'lactato',
    'saturação',
    'Glasgow',
    'Murphy',
    'McBurney',
    'dispneia',
    'taquicardia',
    'bradicardia',
    'hipotensão',
    'hipertensão',
    'miligrama',
    'micrograma',
    'mililitro',
  ];

  static const List<String> _spanish = <String>[
    'disnea',
    'taquicardia',
    'bradicardia',
    'hipotensión',
    'hipertensión',
    'saturación',
    'hematocrito',
    'plaquetas',
    'leucocitos',
    'sodio',
    'potasio',
    'miligramos',
    'microgramos',
    'mililitros',
  ];

  static const List<String> _portuguese = <String>[
    'dispneia',
    'taquicardia',
    'bradicardia',
    'hipotensão',
    'hipertensão',
    'saturação',
    'hematócrito',
    'plaquetas',
    'leucócitos',
    'sódio',
    'potássio',
    'miligramas',
    'microgramas',
    'mililitros',
  ];

  static List<String> buildHints({
    required String locale,
    Iterable<String> extraHints = const <String>[],
    int maxHints = 64,
  }) {
    if (maxHints < 1 || maxHints > 128) {
      throw ArgumentError.value(maxHints, 'maxHints');
    }

    final lowerLocale = locale.toLowerCase();
    final languageHints = lowerLocale.startsWith('es')
        ? _spanish
        : lowerLocale.startsWith('pt')
            ? _portuguese
            : const <String>[];

    final ordered = <String>[];
    final seen = <String>{};

    void add(String raw) {
      final value = raw.trim();
      if (value.isEmpty || value.length > 80) {
        return;
      }
      final key = value.toLowerCase();
      if (seen.add(key)) {
        ordered.add(value);
      }
    }

    for (final hint in extraHints) {
      add(hint);
      if (ordered.length >= maxHints) {
        return List<String>.unmodifiable(ordered);
      }
    }

    for (final hint in languageHints) {
      add(hint);
      if (ordered.length >= maxHints) {
        return List<String>.unmodifiable(ordered);
      }
    }

    for (final hint in _shared) {
      add(hint);
      if (ordered.length >= maxHints) {
        break;
      }
    }

    return List<String>.unmodifiable(ordered);
  }
}
