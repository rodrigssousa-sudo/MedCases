import 'clinical_query_scope.dart';

/// Study classifies what the user asks us to do, not numeric examples in a
/// lesson. This policy is deliberately not used by the Plantão contract.
class StudyQueryScope {
  static bool hasEducationalRequest(String query) => RegExp(
      r'^\s*(?:[¿¡]\s*)?(?:explique|explica|descreva|describa|compare|ensine|resuma|resume|aprofunde|profundiza)\b',
      caseSensitive: false).hasMatch(query);

  static ClinicalQueryScope classify(String query) {
    final q = query.trim().toLowerCase();
    bool has(String expression) => RegExp(expression, caseSensitive: false).hasMatch(q);
    final directOperation = has(
      r'(?:^|[;.!?]\s*|\b(?:e|y)\s+)(?:[¿¡]\s*)?(?:por favor\s+)?'
      r'(?:calcule|calcula|calcular|ajuste|ajusta|ajustar|prescreva|prescribe|dilua|diluya|individualize)\b');
    final targetedDose = has(
      r'\b(?:dose|dosis|doses)\s+(?:exat[ao]|exact[ao]|individualizad[ao])\b|'
      r'\b(?:dose|dosis|doses)\b.{0,55}\b(?:para|d[oa]|del)\s+'
      r'(?:(?:este|esse|meu|mi|esta)\s+)?(?:paciente|caso|crian[çc]a|niñ[oa])\b');
    if (directOperation || targetedDose) {
      return ClinicalQueryScope.calculationOrIndividualization;
    }
    final teaching = has(
      r'^(?:[¿¡]\s*)?(?:explique|explica|descreva|describa|compare|comparar|ensine|ensina|'
      r'aprofunde|profundiza|resuma|resume|revis[aã]o|revisi[oó]n|princ[ií]pios|principios)\b|'
      r'\b(?:doses|dosis|dose)\s+(?:padr[aã]o|est[aá]ndar|de refer[eê]ncia|de referencia)\b');
    return teaching ? ClinicalQueryScope.generalEducational : ClinicalQueryScopePolicy.classify(query);
  }
}
