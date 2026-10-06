import 'clinical_patient_quantity.dart';

/// Presentation scope is not authorization for a personalized prescription.
class ClinicalDoseScope {
  static bool referenceLabel(String text) => RegExp(
          r'\b(?:dose|dosis)\s+(?:(?:padr[aã]o|est[aá]ndar|standard)\s*(?:de\s+refer[eê]ncia|de\s+referencia)?|de\s+refer[eê]ncia|de\s+referencia)\b',
          caseSensitive: false)
      .hasMatch(text.replaceAll(RegExp(r'[*_`]'), ''));

  static bool individualized(String text) =>
      ClinicalPatientQuantity.hasWeight(text) ||
      RegExp(
              r'\b(?:ajust\w*|calcul\w*|calcule|prescri\w*|administr\w*|dilui\w*|diluya|infundir|titular)\b|'
              r'\b(?:meu|minha|mi|este|esta|esse|essa)\s+(?:paciente|dose|dosis)\b|'
              r'\b(?:paciente|peso|pesa|idade|edad|clcr|egfr|tfg)\s*[:=]?\s*\d',
              caseSensitive: false)
          .hasMatch(text);

  static bool referenceRequest(String text) =>
      !individualized(text) &&
      (referenceLabel(text) ||
          (RegExp(r'\b(?:explique|explica|mecanismo|indicaciones|indicações|visão geral|resumen)\b',
                      caseSensitive: false)
                  .hasMatch(text) &&
              RegExp(r'\b(?:dose|doses|dosis|posologia|posología)\b',
                      caseSensitive: false)
                  .hasMatch(text)));

  // A general reference regimen may describe administration or titration.
  // Those verbs alone do not make it a calculation for a particular patient.
  static bool patientSpecificFragment(String text,
      {bool generalEducational = false}) {
    if (RegExp(
            r'\b(?:meu|minha|mi|este|esta|esse|essa)\s+(?:paciente|dose|dosis)\b|'
            r'\b(?:el|o|un|um)\s+paciente\b|'
            r'\bpaciente\s+(?:de|con|com|tiene|tem|presenta|apresenta)\b|'
            r'\b(?:calculad[oa]|individualizad[oa])\b',
            caseSensitive: false)
        .hasMatch(text)) return true;
    var facts = text;
    if (generalEducational) {
      // Only a general request may treat a renal range as population guidance.
      // Explicit patients/calculations above, single values and age/weight
      // below remain patient-specific. Arithmetic and terminal gates are intact.
      facts = facts.replaceAll(
          RegExp(
              r'\b(?:TFG|eGFR|ClCr)\s*(?:de\s+|entre\s+)?'
              r'\d+(?:[.,]\d+)?\s*(?:[–—-]|a|y|e)\s*\d+(?:[.,]\d+)?',
              caseSensitive: false),
          'renal reference range');
    }
    return RegExp(
            r'\b(?:paciente|peso|pesa|idade|edad|clcr|egfr|tfg)\s*[:=]?\s*\d',
            caseSensitive: false)
        .hasMatch(facts);
  }

  /// A renal-function threshold in mL/min is not an administered mL dose.
  /// Mixed medication regimens and infusion instructions retain dose validation.
  static bool renalFunctionReference(String text) {
    if (patientSpecificFragment(text) ||
        RegExp(r'\b(?:infund\w*|infus\w*|administr\w*|calcul\w*)\b',
                caseSensitive: false)
            .hasMatch(text)) {
      return false;
    }
    final plain = text.replaceAll(RegExp(r'[*_`]'), '');
    final renalMeasurement = RegExp(
        r'\b(?:TFG|eGFR|ClCr|filtrado(?: glomerular)?|filtração glomerular)\s*'
        r'(?:[<>=≤≥]|inferior a|superior a|menor que|maior que|de|entre|:|\s)*'
        r'\d+(?:[.,]\d+)?(?:\s*[–—-]\s*\d+(?:[.,]\d+)?)?\s*ml/min'
        r'(?:/1[.,]73\s*m[²2])?',
        caseSensitive: false);
    if (!renalMeasurement.hasMatch(plain)) return false;
    final remainder = plain.replaceAll(renalMeasurement, 'renal threshold');
    return !RegExp(
            r'\d+(?:[.,]\d+)?\s*(?:mg|mcg|µg|μg|ug|g|ml|ui|iu|unidades)\b',
            caseSensitive: false)
        .hasMatch(remainder);
  }

  static bool referenceFragment(String text,
          {bool generalEducational = false}) =>
      (referenceLabel(text) || renalFunctionReference(text)) &&
      !patientSpecificFragment(text, generalEducational: generalEducational) &&
      !_invalidReferenceValue(text);

  static bool _invalidReferenceValue(String text) {
    if (RegExp(r'NaN|Infinity|fict[ií]ci|inventad', caseSensitive: false)
        .hasMatch(text)) return true;
    final invalid = RegExp(
        r'(?:\b0(?:[.,]0+)?|-\d+(?:[.,]\d+)?)\s*(?:mg|mcg|g|ml|ui)\b',
        caseSensitive: false);
    for (final match in invalid.allMatches(text)) {
      // An ASCII range separator after a positive number is not a minus sign.
      // No quantity is changed; zero/negative endpoints remain rejected.
      final prefix = text.substring(0, match.start).trimRight();
      final rangeStart = RegExp(r'(-?\d+(?:[.,]\d+)?)$').firstMatch(prefix);
      final lower =
          num.tryParse(rangeStart?.group(1)?.replaceAll(',', '.') ?? '');
      final rangeEnd =
          RegExp(r'^-(\d+(?:[.,]\d+)?)').firstMatch(match.group(0)!);
      final upper =
          num.tryParse(rangeEnd?.group(1)?.replaceAll(',', '.') ?? '');
      if (lower != null && lower > 0 && upper != null && upper > 0) {
        continue;
      }
      return true;
    }
    return false;
  }

  /// Study checks whole quantities; the trailing zero of 1.0 mg is not 0 mg.
  /// Keep the existing Plantão validator unchanged.
  static bool hasInvalidReferenceValue(String text) {
    if (RegExp(r'\b(?:NaN|Infinity)\b|fict[ií]ci|inventad',
            caseSensitive: false)
        .hasMatch(text)) return true;
    for (final match in RegExp(
            r'(?<![\d.,])(-?\d+(?:[.,]\d+)?)\s*(?:mg|mcg|g|ml|ui)\b',
            caseSensitive: false)
        .allMatches(text)) {
      final value = num.parse(match[1]!.replaceAll(',', '.'));
      if (value > 0) continue;
      final prefix = text.substring(0, match.start).trimRight();
      final lower =
          RegExp(r'(?<![\d.,])(-?\d+(?:[.,]\d+)?)$').firstMatch(prefix);
      if (value < 0 &&
          lower != null &&
          num.parse(lower[1]!.replaceAll(',', '.')) > 0) continue;
      return true;
    }
    return false;
  }

  /// Carry an explicit reference heading onto its numeric list items. This
  /// supplies scope only; never creates or changes a numeric regimen.
  static String labelReferenceSections(String text, String language) {
    int? referenceDepth;
    final label = language.startsWith('es')
        ? 'Dosis estándar de referencia: '
        : 'Dose padrão de referência: ';
    return text.split('\n').map((line) {
      final heading = line.trim();
      final markdownHeading = RegExp(r'^#{1,6}\s').firstMatch(heading);
      final depth = markdownHeading?.group(0)!.trim().length;
      final boldHeading = heading.startsWith('**') && heading.endsWith('**');
      if (depth != null || boldHeading) {
        if (referenceLabel(heading) && !individualized(heading)) {
          referenceDepth = depth ?? 7;
        } else if (individualized(heading) ||
            (depth != null &&
                referenceDepth != null &&
                depth <= referenceDepth!)) {
          referenceDepth = null;
        }
      }
      if (referenceDepth != null &&
          !referenceLabel(line) &&
          !patientSpecificFragment(line) &&
          RegExp(r'\b\d+(?:[.,]\d+)?\s*(?:mg|mcg|g|ml|ui)\b',
                  caseSensitive: false)
              .hasMatch(line)) {
        return '$label$line';
      }
      return line;
    }).join('\n');
  }

  static String prompt(String language) => language.startsWith('es')
      ? '\nRESPUESTA: Usa exclusivamente el idioma español para la explicación. Por defecto entrega una síntesis práctica: conducta o indicación, dosis de referencia y puntos clave de seguridad. Evita capítulos extensos, repetición y párrafos de cierre genéricos. Amplía solo si se solicita detalle o si es esencial para el caso. No omitas manejo útil por ausencia de catálogo. El contexto interno relevante es apoyo, no autorización. No agregues información irrelevante. Cita solamente fuentes realmente disponibles; nunca inventes enlaces, DOI o PMID.\nDOSIS: Distingue referencia general de ajuste individual. En educación clínica incluye dosis estándar habituales cuando sean aplicables y conocidas; en consultas de fármacos presenta dosis inicial, vía, frecuencia, rango usual y máximo solo cuando estén sustentados, agrupando las pautas bajo un único título Markdown “## Dosis de referencia” y usando bullets breves sin repetir el rótulo en cada línea. Mantén indicación, vía y población de referencia. No inventes dosis ni finjas individualización. Para calcular o ajustar a un paciente pide las variables necesarias (peso, edad, función renal/hepática, gestación, superficie corporal, interacciones o concentración según corresponda). La ausencia de estos datos no impide explicar el manejo general. Conserva contraindicaciones y seguridad especializada.'
      : '\nRESPOSTA: Use português na explicação. Por padrão entregue uma síntese prática: conduta ou indicação, doses de referência e pontos essenciais de segurança. Evite capítulos extensos, repetição e parágrafos finais genéricos. Aprofunde apenas quando solicitado ou essencial ao caso. Não omita manejo útil pela ausência de catálogo. Contexto interno relevante é apoio, não autorização. Não acrescente informação irrelevante. Cite apenas fontes realmente disponíveis; nunca invente links, DOI ou PMID.\nDOSES: Diferencie referência geral de ajuste individual. Na educação clínica inclua doses padrão usuais quando aplicáveis e conhecidas; em consultas de fármacos apresente dose inicial, via, frequência, faixa usual e máximo somente quando sustentados, agrupando os esquemas sob um único título Markdown “## Dose de referência” e usando bullets curtos sem repetir o rótulo em cada linha. Mantenha indicação, via e população de referência. Não invente doses nem finja individualização. Para calcular ou ajustar ao paciente peça as variáveis necessárias (peso, idade, função renal/hepática, gestação, superfície corporal, interações ou concentração conforme aplicável). A ausência desses dados não impede explicar o manejo geral. Preserve contraindicações e segurança especializada.';
}
