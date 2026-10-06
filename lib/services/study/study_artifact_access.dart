import '../../models/study_workspace_model.dart';
import '../entitlement_service.dart';
import '../medcases_feature_authorization.dart';

/// Uses the existing Premium authority; source type never changes access.
class StudyArtifactAccess {
  static const target =
      FeatureTarget.capability(MedCasesCapability.extendedStudyAi);
  static bool requiresPremium(StudyArtifactType type) =>
      type != StudyArtifactType.fullSummary &&
      type != StudyArtifactType.keyPoints;
  static bool allows(
          StudyArtifactType type, MedCasesFeatureAuthorization owner) =>
      !requiresPremium(type) || owner.allows(target);
  static Future<void> require(StudyArtifactType type) async {
    if (!requiresPremium(type)) return;
    final owner = MedCasesFeatureAuthorization.instance;
    if (!await owner.authorize(target,
        entrypoint: FeatureEntryPoint.studyAction)) {
      throw StateError('study_premium_required');
    }
  }
}
