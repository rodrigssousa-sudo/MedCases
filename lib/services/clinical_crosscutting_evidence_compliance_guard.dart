import '../data/clinical_crosscutting_evidence_compliance_profiles.dart';

class ClinicalCrosscuttingComplianceResult {
  final String text;
  final bool modified;
  final String? evidenceId;
  final List<String> violations;

  const ClinicalCrosscuttingComplianceResult({
    required this.text,
    required this.modified,
    required this.evidenceId,
    required this.violations,
  });
}

/// Generic data-driven post-provider clinical evidence compliance.
///
/// This code does not encode pathology decisions. The existing resolver
/// selects an evidence ID; this guard loads that ID's data profile and checks
/// whether the provider output contains a curated forbidden unsupported claim.
class ClinicalCrosscuttingEvidenceComplianceGuard {
  const ClinicalCrosscuttingEvidenceComplianceGuard._();

  static ClinicalCrosscuttingComplianceResult enforce({
    required String query,
    required String assistantOutput,
    required String lang,
    required String evidenceContext,
  }) {
    return enforceByEvidenceId(
      query: query,
      assistantOutput: assistantOutput,
      lang: lang,
      evidenceId: _extractEvidenceId(evidenceContext),
    );
  }

  static ClinicalCrosscuttingComplianceResult enforceByEvidenceId({
    required String query,
    required String assistantOutput,
    required String lang,
    required String? evidenceId,
  }) {
    if (evidenceId == null || evidenceId.trim().isEmpty) {
      return ClinicalCrosscuttingComplianceResult(
        text: assistantOutput,
        modified: false,
        evidenceId: null,
        violations: const <String>[],
      );
    }

    final profile = clinicalCrosscuttingComplianceProfileFor(evidenceId);
    if (profile == null || assistantOutput.trim().isEmpty) {
      return ClinicalCrosscuttingComplianceResult(
        text: assistantOutput,
        modified: false,
        evidenceId: evidenceId,
        violations: const <String>[],
      );
    }

    final normalizedOutput = _normalize(assistantOutput);
    final normalizedQuery = _normalize(query);
    final isClassificationQuery = profile.classificationNeedles.any(
      (needle) => normalizedQuery.contains(_normalize(needle)),
    );
    final isEs = lang.toLowerCase().startsWith('es');

    final violations = profile.forbiddenNeedles
        .where((needle) => normalizedOutput.contains(_normalize(needle)))
        .toList(growable: true);

    // MEDCASES_REQUIRED_ASSERTIONS_SEMANTIC_FAIL_CLOSED_V1
    _appendMissingRequiredAssertions(
      violations: violations,
      normalizedQuery: normalizedQuery,
      normalizedOutput: normalizedOutput,
      profile: profile,
    );

    // MEDCASES_RICH_EVIDENCE_SEMANTIC_FAIL_CLOSED_V1
    final dedicatedClassificationReplacement = isEs
        ? profile.esClassificationReplacement
        : profile.ptClassificationReplacement;
    if (isClassificationQuery &&
        dedicatedClassificationReplacement != null &&
        dedicatedClassificationReplacement.trim().isNotEmpty &&
        assistantOutput.trim() != dedicatedClassificationReplacement.trim()) {
      violations.add('classification_authoritative_replacement');
    }

    if (!isClassificationQuery &&
        _perKgDayRangeNeedsReplacement(
          query: query,
          assistantOutput: assistantOutput,
          profile: profile,
        )) {
      violations.add('per_kg_day_range_mismatch');
    }

    if (violations.isEmpty) {
      return ClinicalCrosscuttingComplianceResult(
        text: assistantOutput,
        modified: false,
        evidenceId: evidenceId,
        violations: const <String>[],
      );
    }

    var replacement = isClassificationQuery
        ? (isEs
              ? (profile.esClassificationReplacement ?? profile.esReplacement)
              : (profile.ptClassificationReplacement ?? profile.ptReplacement))
        : (isEs ? profile.esReplacement : profile.ptReplacement);

    replacement = _renderWeightCalculation(
      template: replacement,
      query: query,
      profile: profile,
      isEs: isEs,
    ).trim();

    if (replacement.isEmpty || replacement == assistantOutput.trim()) {
      return ClinicalCrosscuttingComplianceResult(
        text: assistantOutput,
        modified: false,
        evidenceId: evidenceId,
        violations: violations,
      );
    }

    return ClinicalCrosscuttingComplianceResult(
      text: replacement,
      modified: true,
      evidenceId: evidenceId,
      violations: violations,
    );
  }

  static void _appendMissingRequiredAssertions({
    required List<String> violations,
    required String normalizedQuery,
    required String normalizedOutput,
    required ClinicalCrosscuttingComplianceProfile profile,
  }) {
    for (final rule in profile.requiredAssertionRules) {
      final queryMatches = rule.queryAllOfGroups.every(
        (group) =>
            group.isNotEmpty &&
            group.any((needle) => normalizedQuery.contains(_normalize(needle))),
      );
      if (!queryMatches) continue;

      for (var index = 0; index < rule.requiredOutputGroups.length; index++) {
        final group = rule.requiredOutputGroups[index];
        final satisfied =
            group.isNotEmpty &&
            group.any(
              (needle) => normalizedOutput.contains(_normalize(needle)),
            );
        if (!satisfied) {
          violations.add('required_assertion_missing:${rule.id}:$index');
        }
      }
    }
  }

  static bool _perKgDayRangeNeedsReplacement({
    required String query,
    required String assistantOutput,
    required ClinicalCrosscuttingComplianceProfile profile,
  }) {
    final min = profile.perKgDayMin;
    final max = profile.perKgDayMax;
    if (min == null || max == null) return false;

    final hasWeight = RegExp(
      r'\b\d{1,3}(?:[.,]\d+)?\s*kg\b',
      caseSensitive: false,
    ).hasMatch(query);
    if (!hasWeight) return false;

    final range = RegExp(
      r'(\d{1,3}(?:[.,]\d+)?)\s*'
      r'(?:-|–|—|a|à|to)\s*'
      r'(\d{1,3}(?:[.,]\d+)?)\s*'
      r'ml\s*/\s*kg\s*/\s*(?:dia|día|day)\b',
      caseSensitive: false,
    ).firstMatch(assistantOutput);

    if (range == null) return true;

    final low = double.tryParse(range.group(1)!.replaceAll(',', '.'));
    final high = double.tryParse(range.group(2)!.replaceAll(',', '.'));
    if (low == null || high == null) return true;

    const epsilon = 0.01;
    return (low - min).abs() > epsilon || (high - max).abs() > epsilon;
  }

  static String? _extractEvidenceId(String evidenceContext) {
    if (evidenceContext.trim().isEmpty) return null;
    return RegExp(
      r'^id=([^\r\n]+)',
      multiLine: true,
    ).firstMatch(evidenceContext)?.group(1)?.trim();
  }

  static String _renderWeightCalculation({
    required String template,
    required String query,
    required ClinicalCrosscuttingComplianceProfile profile,
    required bool isEs,
  }) {
    final min = profile.perKgDayMin;
    final max = profile.perKgDayMax;
    if (min == null || max == null) {
      return template
          .replaceAll('{WEIGHT_CALC_PT}', '')
          .replaceAll('{WEIGHT_CALC_ES}', '');
    }

    final match = RegExp(
      r'(\d{1,3}(?:[.,]\d+)?)\s*kg\b',
      caseSensitive: false,
    ).firstMatch(query);
    final weight = match == null
        ? null
        : double.tryParse(match.group(1)!.replaceAll(',', '.'));

    if (weight == null || weight <= 0 || weight > 400) {
      return template
          .replaceAll('{WEIGHT_CALC_PT}', '')
          .replaceAll('{WEIGHT_CALC_ES}', '');
    }

    final lowDay = weight * min;
    final highDay = weight * max;
    final lowHour = (lowDay / 24).roundToDouble();
    final highHour = (highDay / 24).roundToDouble();

    final pt =
        '• Para ${_format(weight)} kg: ${_format(lowDay)}–${_format(highDay)} '
        'mL/dia (aprox. ${_format(lowHour)}–${_format(highHour)} mL/h se '
        'administrado continuamente).';
    final es =
        '• Para ${_format(weight)} kg: ${_format(lowDay)}–${_format(highDay)} '
        'mL/día (aprox. ${_format(lowHour)}–${_format(highHour)} mL/h si se '
        'administra de forma continua).';

    return template
        .replaceAll('{WEIGHT_CALC_PT}', isEs ? '' : pt)
        .replaceAll('{WEIGHT_CALC_ES}', isEs ? es : '');
  }

  static String _format(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) {
      return rounded.toInt().toString();
    }
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String _normalize(String value) {
    var text = value.toLowerCase();
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
    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });
    return text
        .replaceAll(RegExp(r'[^a-z0-9%/.,:+\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
