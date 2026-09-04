import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/'
    'plantao_qa_cutover_support.dart';

void main() {
  group('PlantaoQaCutoverSupport eligibility', () {
    test('production default allowlist is empty and closed', () {
      const support = PlantaoQaCutoverSupport();

      expect(support.hasConfiguredUidAllowlist, isFalse);
      expect(
        support.isEligible(
          isPlantao: true,
          authenticatedUid: 'qa-user-001',
        ),
        isFalse,
      );
    });

    test('requires Plantão mode and exact authenticated UID', () {
      const support = PlantaoQaCutoverSupport(
        rawUidAllowlist: ' qa-user-001,qa-user-002 ',
      );

      expect(support.hasConfiguredUidAllowlist, isTrue);
      expect(
        support.isEligible(
          isPlantao: true,
          authenticatedUid: 'qa-user-001',
        ),
        isTrue,
      );
      expect(
        support.isEligible(
          isPlantao: false,
          authenticatedUid: 'qa-user-001',
        ),
        isFalse,
      );
      expect(
        support.isEligible(
          isPlantao: true,
          authenticatedUid: 'qa-user',
        ),
        isFalse,
      );
      expect(
        support.isEligible(
          isPlantao: true,
          authenticatedUid: null,
        ),
        isFalse,
      );
    });

    test('does not use email or substring identity matching', () {
      const support = PlantaoQaCutoverSupport(
        rawUidAllowlist: 'uid-exact',
      );

      expect(
        support.isEligible(
          isPlantao: true,
          authenticatedUid: 'uid-exact@example.com',
        ),
        isFalse,
      );
      expect(
        support.isEligible(
          isPlantao: true,
          authenticatedUid: 'prefix-uid-exact-suffix',
        ),
        isFalse,
      );
    });
  });

  group('PlantaoQaCutoverSupport observability', () {
    test('event payload contains only approved non-clinical fields', () {
      const support = PlantaoQaCutoverSupport();
      final payload = support.buildEvent(
        event: PlantaoQaCutoverEvent.pipelineStarted,
        reason: PlantaoQaCutoverReason.uidAllowlisted,
        requestId: 'request-001',
        sessionId: 'session-001',
      );

      expect(
        payload.keys.toSet(),
        equals(
          <String>{
            'component',
            'event',
            'reason',
            'mode',
            'requestId',
            'sessionId',
          },
        ),
      );
      expect(payload['requestId'], 'request-001');
      expect(payload['sessionId'], 'session-001');
    });

    test('correlation identifiers are bounded', () {
      const support = PlantaoQaCutoverSupport();
      final payload = support.buildEvent(
        event: PlantaoQaCutoverEvent.terminalCompleted,
        reason: PlantaoQaCutoverReason.terminalCompleted,
        requestId: 'r' * 300,
        sessionId: 's' * 300,
      );

      expect(
        (payload['requestId']! as String).length,
        128,
      );
      expect(
        (payload['sessionId']! as String).length,
        128,
      );
    });

    test('production source embeds no UID and no clinical payload key', () {
      final source = File(
        'lib/services/ai_pipeline/plantao/'
        'plantao_qa_cutover_support.dart',
      ).readAsStringSync();

      expect(
        source,
        contains("defaultValue: ''"),
      );
      expect(
        RegExp(
          r"rawUidAllowlist\s*:\s*'[^']+'",
        ).hasMatch(source),
        isFalse,
      );

      const forbiddenQuotedKeys = <String>[
        "'prompt'",
        "'response'",
        "'patient'",
        "'medication'",
        "'drugEvidence'",
        "'clinicalText'",
        "'input'",
        "'output'",
      ];
      for (final key in forbiddenQuotedKeys) {
        expect(source, isNot(contains(key)));
      }
    });

    test('observability reasons are closed enums, not free text', () {
      final source = File(
        'lib/services/ai_pipeline/plantao/'
        'plantao_qa_cutover_support.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          'required PlantaoQaCutoverReason reason',
        ),
      );
      expect(
        source,
        isNot(contains('Map<String, dynamic> details')),
      );
      expect(
        source,
        isNot(contains('String message')),
      );
    });
  });
}
