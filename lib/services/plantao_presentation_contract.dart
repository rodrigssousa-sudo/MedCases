import 'ai/safety/clinical_query_scope.dart';

/// Shared presentation contract; clinical safety remains in specialized guards.
class PlantaoPresentationContract {
  static const anchor = '[PLANTAO_PRESENTATION_CONTRACT_V2]';
  static const contract = 'Bedside clinical answer, not a textbook. Answer the requested aspect first. '
          'Use the selected language, Markdown headings, concise paragraphs and bullets. '
          'No decorative emojis. ' +
      universalStructure +
      'Internal context/grounding enrich, never authorize. '
          'Preserve useful safe content. Specialized guards limit unsafe fragments; '
          'final quality review is presentation-only. Never invent patient facts, '
          'regimens, URLs, DOI or PMID. Standard reference doses are allowed when '
          'supported; individual calculations require the necessary patient context. ';

  static const universalStructure =
      '[PLANTAO_PRESENTATION_CONTRACT_V2] For treatment questions prefer three '
      'main sections: Conduta imediata / Conducta inmediata, Tratamento farmacológico / '
      'Tratamiento farmacológico, Monitorização / Monitorización. Adapt headings '
      'to diagnostic, drug-only, calculation and procedure intent; never invent treatment. '
      'One or two immediate-action sentences and one or two monitoring sentences when sufficient. '
      'Keep each medicine, dose, route and interval together; attach applicable duration, '
      'repeat criteria, titration, maximum and critical contraindication immediately below. '
      'Prefer two options only when the source supports relevant alternatives. '
      'Explicitly preserve ALTERNATIVE, COMBINATION, SEQUENTIAL, LOADING, MAINTENANCE, '
      'INFUSION, PRN and SINGLE_DOSE relationships. Never infer an alternative from a list, '
      'never turn infusion duration into repetition interval or loading into maintenance. '
      'No separate reference-dose section, generic next step, duplicated indications, '
      'warnings or academic introduction. Integrate critical warnings in the relevant action. '
      'Nonurgent detail only on demand; do not repeat earlier content. '
      'This is a flexible presentation target: one, two or additional sections are valid. Critical information takes precedence. '
      'Preserve P2Y12, SpO2, SpO₂, H1N1, IL-6, HbA1c, CD4, K⁺, Na⁺, µg/kg/min, mg/dL, ≥, ≤, °C, ClCr and ECG exactly. '
      'Never invent unsupported medicine, dose, route, duration or patient facts. ';

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
        'Keep each supported medicine and its dose, route, frequency, duration '
        'and limits together in treatment. Never create a separate dose section. '
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
                    ? 'PRIORITIZED: 120-180 words, 2-3 short sections; immediate actions and supported medication orders first'
                    : 'BEDSIDE: 100-160 words, 2-3 short sections';
    return '\nRESPONSE_DENSITY=$density. These are flexible writing targets, '
        'never truncate essential treatment, supported doses, monitoring or critical alerts. '
        'LESS BUT BETTER: one clinical idea per bullet, usually one sentence. '
        'Use one # sentence-case title, ## sections and ### drug/subsection titles only '
        'when useful. No empty sections or automatic comprehensive monograph. '
        'Essential layer: immediate action, supported treatment/reference doses and critical safety. '
        'Initial answer is a concise bedside action sheet: merge monitoring and critical restrictions into the relevant action, without repeating sections. Reserve pathophysiology, extended differential diagnosis and secondary explanation for explicit More requests. '
        'Relevant detail: only details that change management or answer the question. '
        'References: supplied sources only, under a final localized reference heading. '
        'Keep primary treatment/doses in the answer, never behind a follow-up CTA. '
        'Bold selectively: drug name, dose, route, frequency or decisive warning; '
        'never whole paragraphs. No ALL CAPS headings except true acronyms. '
        'No decorative emojis. No generic concluding counseling or repeated disclaimers. '
        'Write each Markdown block in final form, separated by a newline; do not '
        'repeat/rewrite previous blocks during streaming.\n';
  }

  static String forLanguage(String language) => '$contract\nAnswer entirely in '
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
