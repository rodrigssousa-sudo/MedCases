import 'package:flutter/widgets.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/services/ai_pipeline/clinical_treatment_visual_readiness.dart';

/// PHASE3I-J2F8: disabled controlled visual integration harness.
///
/// Test-only harness. It is intentionally located under test/ and must never
/// be imported by productive code.
final class ClinicalTreatmentVisualIntegrationHarness extends StatelessWidget {
  const ClinicalTreatmentVisualIntegrationHarness({
    super.key,
    required this.output,
    required this.readiness,
    required this.legacyBuilder,
    required this.typedBuilder,
    this.enabled = false,
  });

  final ClinicalStructuredOutput output;
  final ClinicalTreatmentVisualReadinessReport readiness;
  final WidgetBuilder legacyBuilder;
  final WidgetBuilder typedBuilder;
  final bool enabled;

  bool get _canUseTyped =>
      enabled &&
      readiness.isReadyForControlledVisualIntegrationTest &&
      output.treatmentPresentation.items.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_canUseTyped) {
      return KeyedSubtree(
        key: const ValueKey('controlled_visual_harness_legacy'),
        child: legacyBuilder(context),
      );
    }

    try {
      return KeyedSubtree(
        key: const ValueKey('controlled_visual_harness_typed'),
        child: typedBuilder(context),
      );
    } catch (_) {
      return KeyedSubtree(
        key: const ValueKey('controlled_visual_harness_legacy_fallback'),
        child: legacyBuilder(context),
      );
    }
  }
}
