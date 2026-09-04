import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Plantão effective gap action can render with empty canonical action',
    () {
      final row = File(
        'lib/screens/ai/widgets/action_buttons_row.dart',
      ).readAsStringSync();

      expect(row, contains('final bool canonicalActionAvailable'));
      expect(row, contains('hasStudyNext || action.label.isNotEmpty'));
      expect(row, contains('final bool effectivePlantaoAvailable'));
      expect(
        row,
        contains('isPlantaoMode && effectivePlantaoAction.label.isNotEmpty'),
      );
      expect(
        row,
        contains('(canonicalActionAvailable || effectivePlantaoAvailable)'),
      );

      expect(row, contains('PlantaoContinuationButton('));
      expect(row, contains('effectivePlantaoAction.promptToSend'));

      expect(
        row,
        contains('hasStudyNext ? effectiveStudyPrompt : action.promptToSend'),
      );
      expect(row, contains(': action.continuationType'));
      expect(row, contains(': action.requestedSections'));
      expect(row, contains('visibleLabel: aiLabel'));
      expect(row, contains('final calcBtn = link != null'));
    },
  );
}
