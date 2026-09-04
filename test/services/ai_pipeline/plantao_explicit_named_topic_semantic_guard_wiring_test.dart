import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('named-topic guard runs after IAM core and before regimen guard', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import '../services/ai_pipeline/plantao/"
        "plantao_explicit_named_topic_semantic_guard.dart';",
      ),
    );

    final helper = source.indexOf(
      'String _applyPlantaoClinicalRegimenOutputGuard({',
    );
    final iamCore = source.indexOf(
      'PlantaoGenericAcsWholeResponseSemanticCore.materialize(',
      helper,
    );
    final namedGuard = source.indexOf(
      'PlantaoExplicitNamedTopicSemanticGuard.materialize(',
      helper,
    );
    final regimen = source.indexOf(
      'PlantaoClinicalRegimenOutputGuard.enforce(',
      helper,
    );

    expect(helper, greaterThanOrEqualTo(0));
    expect(iamCore, greaterThan(helper));
    expect(namedGuard, greaterThan(iamCore));
    expect(regimen, greaterThan(namedGuard));

    expect(
      RegExp(r'PlantaoExplicitNamedTopicSemanticGuard\.materialize\(')
          .allMatches(source),
      hasLength(1),
    );
  });
}
