/// Canonical Study CTA identity. Clinical decisions remain in the snapshot;
/// these app-owned pairs only localize the same educational follow-up.
class StudyCanonicalContinuation {
  static const prefix = 'STUDY_CANONICAL_CTA::';
  static const choices = <String, List<String>>{
    'pathophysiology': [
      'Aprofundar fisiopatologia',
      'Profundizar fisiopatología',
      'Explique em mais profundidade a fisiopatologia do tema atual.',
      'Explica con más profundidad la fisiopatología del tema actual.'
    ],
    'differential': [
      'Comparar diagnósticos diferenciais',
      'Comparar diagnósticos diferenciales',
      'Compare os principais diagnósticos diferenciais do tema atual.',
      'Compara los principales diagnósticos diferenciales del tema actual.'
    ],
    'monitoring': [
      'Revisar monitorização',
      'Revisar monitorización',
      'Explique a monitorização e a reavaliação no tema atual.',
      'Explica la monitorización y la reevaluación del tema actual.'
    ],
    'clinical_application': [
      'Aplicar em caso didático',
      'Aplicar a un caso didáctico',
      'Apresente um caso fictício do tema atual e explique o raciocínio clínico.',
      'Presenta un caso ficticio del tema actual y explica el razonamiento clínico.'
    ],
  };

  static String select(Set<String> sectionIds) =>
      choices.keys.firstWhere((id) => !sectionIds.contains(id),
          orElse: () => 'clinical_application');

  static String metadata(String id) => '[NEXT_ACTION_PROMPT: $prefix$id]';

  static String? parse(String prompt) {
    if (!prompt.startsWith(prefix)) return null;
    final id = prompt.substring(prefix.length).trim();
    return choices.containsKey(id) ? id : null;
  }

  static ({String id, String label, String question})? resolve(
      String prompt, String language, Iterable<String> earlierMessages) {
    final requested = parse(prompt);
    if (requested == null) return null;
    final used = <String>{};
    for (final message in earlierMessages) {
      for (final id in choices.keys) {
        if (message.contains(metadata(id))) used.add(id);
      }
    }
    final available = [
      requested,
      ...choices.keys.where((id) => id != requested)
    ].where((id) => !used.contains(id));
    if (available.isEmpty) return (id: '', label: '', question: '');
    final id = available.first;
    final pair = choices[id]!;
    final es = language.startsWith('es');
    return (id: id, label: pair[es ? 1 : 0], question: pair[es ? 3 : 2]);
  }
}
