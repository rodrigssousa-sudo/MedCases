import '../electrolytes/electrolytes_score_engine_2026.dart';
import '../hepato/hepato_score_engine_2026.dart';

/// Selection delegates arithmetic to existing engines. Only explicit current-turn
/// values with units are accepted: no stale calculator cache or inferred values.
class PlantaoToolContext {
  static Map<String, Object?> resolve(String query) {
    final q = query.toLowerCase();
    String? tool;
    if (RegExp(r's[oó]dio corrigido|sodio corregido|corrected sodium')
        .hasMatch(q)) tool = 'corrected_sodium';
    if (RegExp(r'\bfib[- ]?4\b').hasMatch(q)) tool = 'fib4';
    if (tool == null) return const {};
    double? number(String pattern) {
      final values = RegExp(pattern, caseSensitive: false)
          .allMatches(query)
          .map((m) => double.tryParse(m[1]!.replaceAll(',', '.')))
          .whereType<double>()
          .toSet();
      if (values.length != 1 || !values.single.isFinite || values.single <= 0)
        return null;
      return values.single;
    }

    final patterns = tool == 'corrected_sodium'
        ? {
            'sodiumMmolL':
                r'\b(?:na|sodio|s[oó]dio|sodium)\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*(?:mmol/l|meq/l)\b',
            'glucoseMgDl':
                r'\b(?:glicose|glucosa|glucose)\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*mg/dl\b',
          }
        : {
            'ageYears':
                r'\b(?:idade|edad|age)\s*[:=]?\s*(\d+)\s*(?:anos|años|years)\b',
            'astUL': r'\bast\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*u/l\b',
            'altUL': r'\balt\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*u/l\b',
            'platelets10e9L':
                r'\b(?:plaquetas|platelets)\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*(?:x|×)\s*10\^?9/l\b',
          };
    final inputs = {for (final e in patterns.entries) e.key: number(e.value)};
    final missing =
        inputs.entries.where((e) => e.value == null).map((e) => e.key).toList();
    if (missing.isNotEmpty)
      return {
        'toolId': tool,
        'state': 'UNKNOWN',
        'requiredInputs': missing,
        'manualLlmCalculationAllowed': false
      };
    try {
      final value = tool == 'corrected_sodium'
          ? ElectrolytesScoreEngine2026.correctedSodiumForHyperglycemia(
              measuredSodiumMmolL: inputs['sodiumMmolL']!,
              glucoseMgDl: inputs['glucoseMgDl']!)
          : HepatoScoreEngine2026.fib4(
              ageYears: inputs['ageYears']!.toInt(),
              astUL: inputs['astUL']!,
              altUL: inputs['altUL']!,
              platelets10e9L: inputs['platelets10e9L']!);
      return {
        'toolId': tool,
        'state': 'DERIVED_BY_DETERMINISTIC_TOOL',
        'inputs': inputs,
        'value': value,
        'unit': tool == 'corrected_sodium' ? 'mmol/L' : 'score',
        'engineVersion': '2026',
        'manualLlmCalculationAllowed': false
      };
    } on ArgumentError {
      return {
        'toolId': tool,
        'state': 'UNKNOWN',
        'reason': 'invalid_tool_input',
        'manualLlmCalculationAllowed': false
      };
    }
  }
}
