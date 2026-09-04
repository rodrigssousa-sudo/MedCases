import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AppProvider evaluates buffered cutover before the legacy terminal machine',
    () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      final sendAiMessage = source.indexOf(
        'Future<bool> sendAiMessage(',
      );
      final gate = source.indexOf(
        'phase3kShouldAttemptBufferedCutover',
        sendAiMessage,
      );
      final execute = source.indexOf(
        'phase3kActiveCutoverController.execute(',
        gate,
      );
      final legacyTerminal = source.indexOf(
        'AiFinalizationTransaction',
        execute,
      );

      expect(sendAiMessage, greaterThanOrEqualTo(0));
      expect(gate, greaterThan(sendAiMessage));
      expect(execute, greaterThan(gate));
      expect(legacyTerminal, greaterThan(execute));
      expect(
        source,
        contains(
          'PlantaoBufferedCutoverDisposition.committed',
        ),
      );
      expect(
        source,
        contains(
          'PlantaoBufferedCutoverDisposition.fallbackAllowed',
        ),
      );
      expect(
        source,
        contains(
          'PlantaoBufferedCutoverDisposition.rejectedAfterStart',
        ),
      );
      expect(
        source,
        isNot(contains('PlantaoResponsePipeline()')),
      );
      expect(
        source,
        isNot(contains('.drain<void>()')),
      );
    },
  );
}
