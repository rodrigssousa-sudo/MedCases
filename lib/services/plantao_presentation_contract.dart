import 'ai/safety/clinical_query_scope.dart';

/// Shared presentation contract; clinical safety remains in specialized guards.
class PlantaoPresentationContract {
  static const anchor = '[PLANTAO_CANONICAL_PRESENTATION_V1]';
  static const contract =
      'Bedside clinical answer, not a textbook. Answer the requested aspect first. '
      'Use the selected language, Markdown headings, concise paragraphs and bullets. '
      'No decorative emojis. Internal context/grounding enrich, never authorize. '
      'Preserve useful safe content. Specialized guards limit unsafe fragments; '
      'final quality review is presentation-only. Never invent patient facts, '
      'regimens, URLs, DOI or PMID. Standard reference doses are allowed when '
      'supported; individual calculations require the necessary patient context. ';

  /// Response scope only: never authorizes a dose or changes a safety gate.
  static String queryType(String query) =>
      switch (ClinicalQueryScopePolicy.classify(query)) {
        ClinicalQueryScope.generalEducational => 'GENERAL_EDUCATIONAL_QUERY',
        ClinicalQueryScope.patientSpecific => 'PATIENT_SPECIFIC_QUERY',
        ClinicalQueryScope.calculationOrIndividualization =>
          'CALCULATION_QUERY',
      };

  static String responseScope(String query, String language) {
    final type = queryType(query);
    return '\n[PLANTAO_FINAL_RESPONSE_SCOPE_V1]\nQUERY_TYPE=$type\n'
        'Presentation contract only; specialized safety remains authoritative. '
        'For general education, answer first. Do not request patient age, weight, '
        'ECG or organ function as a prerequisite. Do not invent a patient or '
        'missing-data tables. A disease name is a topic, not an individual diagnosis. '
        'For patient-specific/calculation tasks, preserve actual thread context; '
        'ask only for missing variables affecting the requested decision. '
        'Show supported general reference information separately from adjustments. '
        'Keep reference regimens under ## Dosis de referencia (ES) or '
        '## Dose de referência (PT); optional ### drug subheadings. One scope '
        'label suffices. Include relevant drug, dose, route, frequency, duration '
        'and supported limits without repeating regimens/disclaimers. '
        'Preserve essential contraindications, interactions, pregnancy/allergy, '
        'pediatric and organ-function restrictions with their conditions. '
        'Use only relevant sections; no automatic monograph or closing essay. '
        'Localize alerts: Signos de alarma (ES), Sinais de alarme (PT). '
        'Do not invent references. Do not truncate essential regimens to meet a word target. '
        '${densityInstruction(query)}'
        'Answer in ${language.startsWith('es') ? 'Spanish' : 'Portuguese'}.\n';
  }

  /// A writing budget, never a content filter or clinical authorization.
  static String densityInstruction(String query) {
    final simple = RegExp(
            r'mecanismo|mechanism|(?:o que [ée]|qu[eé] es)|defin[ií]|contraindica',
            caseSensitive: false)
        .hasMatch(query);
    final emergency = RegExp(
            r'infarto|\bIAM\b|coronari|hiper[ck]alemia|sepsis|sepse|queimadura|quemadura|via a[eé]rea|v[ií]a a[eé]rea|choque',
            caseSensitive: false)
        .hasMatch(query);
    final detailed =
        RegExp(r'detalhad|detallad|complet[oa]|exhaustiv', caseSensitive: false)
            .hasMatch(query);
    final density = detailed
        ? 'DETAILED_ON_REQUEST'
        : simple
            ? 'FOCUSED: 60-120 words, 1-2 sections; answer only the requested aspect'
            : queryType(query) != 'GENERAL_EDUCATIONAL_QUERY'
                ? 'CASE_FOCUSED: focus on supplied facts and decision-changing missing variables'
                : emergency
                    ? 'PRIORITIZED: 250-400 words, 4-5 short sections; urgent actions first'
                    : 'BEDSIDE: 140-240 words, 3-4 short sections';
    return '\nRESPONSE_DENSITY=$density. These are flexible writing targets, '
        'never truncate essential treatment, supported doses, monitoring or critical alerts. '
        'LESS BUT BETTER: one clinical idea per bullet, usually one sentence. '
        'Use one # sentence-case title, ## sections and ### drug/subsection titles only '
        'when useful. No empty sections or automatic comprehensive monograph. '
        'Essential layer: immediate action, supported treatment/reference doses and critical safety. '
        'Relevant detail: only details that change management or answer the question. '
        'References: supplied sources only, under a final localized reference heading. '
        'Keep primary treatment/doses in the answer, never behind a follow-up CTA. '
        'Bold selectively: drug name, dose, route, frequency or decisive warning; '
        'never whole paragraphs. No ALL CAPS headings except true acronyms. '
        'No decorative emojis. No generic concluding counseling or repeated disclaimers. '
        'Write each Markdown block in final form, separated by a newline; do not '
        'repeat/rewrite previous blocks during streaming.\n';
  }

  static String forLanguage(String language) =>
      '$anchor\n$contract\nAnswer entirely in '
      '${language.startsWith('es') ? 'Spanish' : 'Portuguese'}.\n';
  static String normalize(String text) =>
      String.fromCharCodes(_compactReferenceLabels(text).runes.where((cp) =>
          !((cp >= 0x1F000 && cp <= 0x1FAFF) ||
              (cp >= 0x2600 && cp <= 0x27BF) ||
              cp == 0xFE0F ||
              cp == 0x200D)));
  static String _compactReferenceLabels(String text) {
    var referenceSection = false;
    final label = RegExp(
        r'^(?:Dosis estándar de referencia|Dose padrão de referência):\s*',
        caseSensitive: false);
    return text.split('\n').map((line) {
      final plain = line.replaceAll(RegExp(r'[#*_]'), '').trim();
      if (RegExp(
              r'^(?:dosis|dose|doses) (?:estándar |padrão )?(?:de referencia|de referência)\s*:?$',
              caseSensitive: false)
          .hasMatch(plain)) {
        referenceSection = true;
        return line;
      }
      if (line.trimLeft().startsWith('#')) referenceSection = false;
      if (referenceSection && label.hasMatch(line.trimLeft())) {
        return line.trimLeft().replaceFirst(label, '');
      }
      return line;
    }).join('\n');
  }
}
