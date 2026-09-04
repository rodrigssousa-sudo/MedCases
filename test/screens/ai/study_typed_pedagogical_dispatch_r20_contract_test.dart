import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R20 typed pedagogical dispatch source contract', () {
    late String screen;

    setUpAll(() {
      screen = File('lib/screens/ai_screen.dart').readAsStringSync();
    });

    test('Study typed explanation has dedicated contextual dispatch', () {
      expect(screen, contains('_buildStudyTypedPedagogicalDispatchPrompt('));
      expect(screen, contains('[R20][STUDY_TYPED_PEDAGOGICAL][DISPATCH]'));
      expect(screen, contains('provider.activeThreadTopic'));
      expect(
        screen,
        contains(
          'providerInputOverride == null && _longResponse && !fromButton',
        ),
      );
    });

    test('visible raw user input remains separate from transport', () {
      expect(screen, contains('visibleUserInput: trimmed'));
      expect(
        screen,
        contains('final transportOverride = providerInputOverride?.trim();'),
      );
      expect(screen, contains('final effectiveTransportOverride ='));
      expect(screen, contains('typedStudyOverride?.trim()'));
    });

    test('Plantao and R15 continuation contracts stay present', () {
      expect(screen, contains('_bindPlantaoCaseAnchorForButton(trimmed)'));
      expect(screen, contains('[STUDY_CONTINUATION][DISPATCH]'));
      expect(screen, contains('guard=generic_no_choice_terms'));
    });
  });
}
