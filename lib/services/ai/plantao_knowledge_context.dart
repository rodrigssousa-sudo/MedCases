import '../../data/laboratory/lab_reference_catalog.dart';
import '../../models/lab_reference_model.dart';

/// Selects existing source records; never chooses a patient-specific interval,
/// converts units, computes a result or rewrites approved clinical source facts.
class PlantaoKnowledgeContext {
  static String _fold(String value) {
    var result = value.toLowerCase();
    const accents = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ü': 'u',
      'ç': 'c'
    };
    accents.forEach((a, b) {
      result = result.replaceAll(a, b);
    });
    return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static List<Map<String, Object?>> labs(String query) {
    final q = ' ${_fold(query)} ';
    final matches = LabReferenceCatalog.records.where((record) {
      final names = [
        record.canonicalNamePt,
        record.canonicalNameEs,
        ...record.aliases
      ];
      return names.any((name) {
        // The catalog uses an em dash between the full name and abbreviation.
        // Short symbols alone are ambiguous outside the structured lab screen.
        final term = _fold(name.split('—').first);
        return term.length >= 3 && q.contains(' $term ');
      });
    }).take(3);
    List<Map<String, String>> lines(List<LabValueLine> values) => values
        .map((v) => {
              'populationOrCondition': v.labelPt,
              'value': v.value,
            })
        .toList(growable: false);
    return matches
        .map((r) => <String, Object?>{
              'sourceId': 'lab_${r.testId}',
              'knowledgeVersion': LabReferenceCatalog.clinicalVersion,
              'sourceMode': LabReferenceCatalog.sourceMode,
              'sourceTitle': r.sourceTitle,
              'sourceDate': r.sourceDate,
              'lastClinicalReview': r.lastClinicalReview,
              'sourceLocale': 'pt',
              'testId': r.testId,
              'name': r.canonicalNamePt,
              'unit': r.unit,
              'specimen': r.specimenType,
              'method': r.method,
              'methodSpecific': r.methodSpecific,
              'referenceType': r.referenceType,
              'referenceIntervals': lines(r.referenceIntervals),
              'clinicalDecisionLimits': lines(r.clinicalDecisionLimits),
              'criticalValues': lines(r.criticalValues),
              'qualitativeValues': r.qualitativeValues,
              'clinicalNotes': r.clinicalNotesPt,
              'statuses': r.statuses.map((s) => s.name).toList()..sort(),
              'patientSpecificIntervalSelected': false,
            })
        .toList(growable: false);
  }
}
