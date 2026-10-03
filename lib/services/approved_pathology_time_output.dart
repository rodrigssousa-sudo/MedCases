import '../data/new_pathology_approved_context.dart';
import '../models/protocol_model.dart';
import '../utils/clinical_time_unit_presentation.dart';

/// Never guess a month/week/day from an ambiguous provider abbreviation.
abstract final class ApprovedPathologyTimeOutput {
  static String enforce({required String query, required String text,
      required String language, required String Function(String) normalize}) {
    if (text.isEmpty) return text;
    final models = <ProtocolModel>[];
    approvedNewPathologyContext(query, language,
        normalize: normalize, matchedProtocols: models);
    if (models.length != 1) return text;
    final owner = models.single;
    if (!ClinicalTimeUnitPresentation.appliesTo(owner.id)) return text;
    if (ClinicalTimeUnitPresentation.hasAmbiguousTime(text)) {
      // Reuse only the exact approved facts; do not manufacture an oral regimen.
      return <String>[
        owner.getField(owner.title, language),
        ...owner.getActions(language),
        language == 'es' ? 'Referencias' : 'Referências',
        ...owner.getList(owner.references, language),
      ].join('\n\n');
    }
    return ClinicalTimeUnitPresentation.forOwner(owner.id, text, language);
  }
}
