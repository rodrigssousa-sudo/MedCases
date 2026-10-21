import 'dart:convert';

/// Lossless layout of an already authorized source, never a clinical summary.
/// Unknown sections, extra prose or a long source keep the integral fallback.
/// The caller must validate source identity, approval, locale and hashes first.
abstract final class PlantaoLosslessSourceLayout {
  static const sections = {
    'initial': ['Conduta imediata', 'Conducta inmediata'],
    'diagnosis': ['Avaliação e diferenciais', 'Evaluación y diferenciales'],
    'options': ['Tratamento e condições', 'Tratamiento y condiciones'],
    'followup': [
      'Monitorização e reavaliação',
      'Monitorización y reevaluación'
    ],
    'safety': ['Alertas críticos', 'Alertas críticos'],
    'concept': ['Reconhecimento', 'Reconocimiento'],
  };

  static Map<String, dynamic>? derive(
      String payloadJson, String projection, String locale) {
    if (!['pt', 'es'].contains(locale)) return null;
    try {
      final payload = jsonDecode(payloadJson);
      if (payload is! Map ||
          payload['facts'] is! List ||
          payload['title'] is! Map ||
          payload['title'][locale] is! String) {
        return null;
      }
      final facts = payload['facts'] as List;
      if (facts.length != sections.length) return null;
      final bySection = <String, String>{};
      final ids = <String>{};
      for (final fact in facts) {
        if (fact is! Map ||
            fact['id'] is! String ||
            !ids.add(fact['id']) ||
            !sections.containsKey(fact['section']) ||
            bySection.containsKey(fact['section']) ||
            fact[locale] is! String ||
            (fact[locale] as String).trim().isEmpty) {
          return null;
        }
        bySection[fact['section']] = fact[locale];
      }
      // Check every clinical paragraph in the approved projection. A payload
      // fact inventory alone cannot prove that the projection adds no warning.
      final sourceHeadings = locale == 'pt'
          ? {
              'Abordagem inicial': 'initial',
              'Diagnóstico e diferenciais': 'diagnosis',
              'Tratamento: opções e critérios de escolha': 'options',
              'Segurança e monitorização': 'safety',
              'Reavaliação e destino': 'followup',
              'Reconhecimento rápido': 'concept',
            }
          : {
              'Abordaje inicial': 'initial',
              'Diagnóstico y diferenciales': 'diagnosis',
              'Tratamiento: opciones y criterios de elección': 'options',
              'Seguridad y monitorización': 'safety',
              'Reevaluación y destino': 'followup',
              'Reconocimiento rápido': 'concept',
            };
      final body = <String>[];
      String? currentSection;
      final seen = <String>{};
      var references = false;
      for (final paragraph in projection.trim().split(RegExp(r'\n\s*\n'))) {
        final p = paragraph.trim();
        if (RegExp(r'^## Refer[eê]ncias?$', caseSensitive: false).hasMatch(p)) {
          references = true;
          continue;
        }
        if (references) {
          // Bibliographic entries only: do not silently omit clinical prose.
          if (!RegExp(r'^\d+\. \[[^\n]+\]\(https://[^\s]+\)$').hasMatch(p)) {
            return null;
          }
          continue;
        }
        if (p == '# ${payload['title'][locale]}') continue;
        if (p.startsWith('## ')) {
          currentSection = sourceHeadings[p.substring(3)];
          if (currentSection == null || !seen.add(currentSection)) return null;
          continue;
        }
        if (currentSection == null || bySection[currentSection] != p) {
          return null;
        }
        body.add(p);
      }
      if (!references ||
          body.length != facts.length ||
          seen.length != sections.length) {
        return null;
      }
      final remaining = List<String>.from(body);
      for (final text in bySection.values) {
        final i = remaining.indexOf(text);
        if (i < 0) return null;
        remaining.removeAt(i);
      }
      if (remaining.isNotEmpty) return null;
      final index = locale == 'pt' ? 0 : 1;
      final blocks = [
        for (final entry in sections.entries)
          {
            'section': entry.key,
            'title': entry.value[index],
            'text': bySection[entry.key]!
          }
      ];
      final visible = [
        payload['title'][locale],
        for (final b in blocks) '${b['title']} ${b['text']}'
      ].join(' ');
      final words = visible.trim().split(RegExp(r'\s+')).length;
      if (words > 150) return null; // Never truncate or choose a subset to fit.
      return {
        'method': 'LOSSLESS_AUTHORIZED_SOURCE_LAYOUT',
        'clinicalTitle': payload['title'][locale],
        'blocks': blocks,
        'wordCount': words,
        'omittedClinicalFacts': 0,
        'approvalScope': 'ORIGINAL_FULL_SOURCE_UNCHANGED'
      };
    } on FormatException {
      return null;
    }
  }
}
