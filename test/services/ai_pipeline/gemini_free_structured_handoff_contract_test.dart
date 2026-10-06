import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Gemini Free tipa só os dois fechamentos validados e preserva stream_onDone',
    () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      // Count the two Free-stream handoffs; shared post-safety adapters
      // elsewhere in AppProvider are outside this contract.
      expect(
        RegExp(
          r'PlantaoLocalClinicalOutputAdapter\s*'
          r'\.\s*fromValidatedText\s*\(\s*(?:finalText|retryFinalText)\s*,?\s*\)',
        ).allMatches(source),
        hasLength(2),
      );

      expect(
        RegExp(
          r'PlantaoLocalClinicalOutputAdapter\s*'
          r'\.\s*fromValidatedText\(\s*finalText,?\s*\)',
        ).hasMatch(source),
        isTrue,
      );

      expect(
        source,
        contains(
          'wrappedOnDone(freeUiText, freeClinicalOutput);',
        ),
      );

      expect(
        RegExp(
          r'PlantaoLocalClinicalOutputAdapter\s*'
          r'\.\s*fromValidatedText\(\s*retryFinalText,?\s*\)',
        ).hasMatch(source),
        isTrue,
      );

      expect(
        source,
        contains(
          'wrappedOnDone(retryFinalText, retryClinicalOutput);',
        ),
      );

      expect(
        RegExp(
          r'wrappedOnDone\(finalText\);',
        ).allMatches(source),
        hasLength(2),
        reason: 'texto normal e fallback de stream_onDone devem continuar '
            'fail-closed',
      );
    },
  );
}
