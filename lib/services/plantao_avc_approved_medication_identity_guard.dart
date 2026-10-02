/// Restores only the explicitly approved alteplase identity for the AVC owner.
/// It never infers a medication from a dose alone or changes regimen values.
class PlantaoAvcApprovedMedicationIdentityGuard {
  const PlantaoAvcApprovedMedicationIdentityGuard._();

  static String preserveName({
    required String text,
    required String language,
    required bool authoritative,
    required String? pathologyKey,
    required String? guidelineVersion,
    required List<String> approvedActions,
  }) {
    if (!authoritative || pathologyKey != 'avc_isquemico' ||
        guidelineVersion != 'AHA_ASA_AIS_2026_CORRECTED_JULY_2026') {
      return text;
    }
    final name = language == 'es' ? 'Alteplasa' : 'Alteplase';
    final approvedName = '$name: 0,9 mg/kg IV, máximo 90 mg;';
    if (!approvedActions.any((action) => action.contains(approvedName))) {
      return text;
    }
    final anonymousDose = RegExp(
      r'^(\s*(?:[-•]\s*)?(?:\*\*)?)0[.,]9\s*mg\s*/\s*kg\b',
      caseSensitive: false,
    );
    return text.split('\n').map((line) {
      final match = anonymousDose.firstMatch(line);
      if (match == null ||
          !RegExp(r'\b90\s*mg\b', caseSensitive: false).hasMatch(line) ||
          !RegExp(r'\b(?:IV|EV)\b', caseSensitive: false).hasMatch(line) ||
          !RegExp(r'\b60\s*min', caseSensitive: false).hasMatch(line) ||
          !RegExp(r'\b(?:10|diez|dez)\b', caseSensitive: false).hasMatch(line)) {
        return line;
      }
      final prefix = match.group(1)!;
      return '$prefix$name: ${line.substring(prefix.length)}';
    }).join('\n');
  }
}
