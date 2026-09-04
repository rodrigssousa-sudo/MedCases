import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AiScreen anexa structured output por identidade clínica conservadora',
    () {
      final source = File(
        'lib/screens/ai_screen.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          "import '../services/ai_pipeline/"
          "structured_output_text_equivalence.dart';",
        ),
      );
      expect(
        source,
        contains('StructuredOutputTextEquivalence.matches('),
      );
      expect(source, contains('backendText: finalText,'));
      expect(source, contains('uiText: committedText,'));
      expect(source, isNot(contains('committedText != finalText')));
      expect(source, contains('currentMessage.text != committedText'));
      expect(source, isNot(contains('currentMessage.text != finalText')));
      expect(source, contains('reason=final_text_not_equivalent'));
      expect(source, contains('[STRUCTURED_UI][ATTACHED]'));
    },
  );
}
