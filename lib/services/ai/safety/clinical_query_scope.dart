import 'clinical_patient_quantity.dart';

/// Intent and patient-context relations; disease/drug names are not signals.
/// Deterministic local classification, not an authorization to prescribe.
enum ClinicalQueryScope {
  generalEducational,
  patientSpecific,
  calculationOrIndividualization,
}

class ClinicalQueryScopePolicy {
  static ClinicalQueryScope classify(String query) {
    final q = ClinicalPatientQuantity.normalize(query)
        .toLowerCase()
        .replaceFirst(RegExp(r'^\s*[¿¡]\s*'), '');
    bool matches(String pattern) =>
        RegExp(pattern, caseSensitive: false).hasMatch(q);
    final patient = matches(
        r'\b(?:meu|minha|mi|este|esta|esse|essa|this|my)\s+(?:paciente|patient)\b|'
        r'\b(?:paciente|patient)\s+(?:de\s+)?\d|'
        r'\b(?:peso|pesa|idade|edad|age|weight|clcr|egfr|tfg)\s*[:=]?\s*\d|'
        r'\b\d+(?:[.,]\d+)?\s*(?:kg|anos|años|years)\b|'
        r'\bchild[ -]?pugh\s*[abc]\b|'
        r'\b(?:gestante|embarazada)\s+(?:com|con)\b|'
        r'\b(?:paciente|patient)\s+(?:com|con|with)\b');
    // Explaining principles/formulas is distinct from executing an adjustment.
    final explanation = matches(
        r'\b(?:explique|explica|explique-me|descreva|describa|princípios|principios|fórmula|formula|como funciona|cómo funciona)\b');
    final requestedOperation = (patient &&
            matches(r'\b(?:dose|doses|dosis|posologia|posología)\b')) ||
        matches(r'^\s*(?:dose|dosis)\s+pedi[aá]trica\s*[?.]?\s*$') ||
        matches(
            r'(?:^|[;.!?]\s*|\be\s+|\by\s+)(?:por favor\s+)?(?:calcule|calcula|calcular|ajuste|ajusta|ajustar|individualize|individualizar|prescreva|prescribe|dilua|diluya)\b|'
            r'^\s*(?:ajuste|ajusta|ajustar)\s+por\s+(?:função|función)\s+(?:renal|hep[aá]tica)|'
            r'^\s*(?:cálculo|calculo|c[aá]lcular|ajuste)\s+(?:de\s+|da\s+|do\s+)?(?:dose|dosis|infus|renal|hep[aá]tic)|'
            r'\b(?:dose|dosis)\s+(?:pedi[aá]trica\s+)?(?:por peso|individualizad[ao])\b|'
            r'\b(?:ajustar|calcular|titular|infundir)\b.{0,60}\b(?:para|por|segundo|según|conforme|função|función)\b');
    if (requestedOperation && (!explanation || patient)) {
      return ClinicalQueryScope.calculationOrIndividualization;
    }
    if (patient) return ClinicalQueryScope.patientSpecific;
    return ClinicalQueryScope.generalEducational;
  }
}
