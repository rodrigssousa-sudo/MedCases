import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão next-action formal outline contract', () {
    late String actionRow;
    late String actionCard;

    setUpAll(() {
      actionRow = File(
        'lib/screens/ai/widgets/action_buttons_row.dart',
      ).readAsStringSync();

      actionCard = File(
        'lib/screens/ai/widgets/action_card_button.dart',
      ).readAsStringSync();
    });

    test('uses canonical clinical green and removes legacy blue', () {
      expect(actionRow, contains('Color(0xFF0E8000)'));
      expect(actionRow, isNot(contains('0xFF1E88E5')));
      expect(actionRow, isNot(contains('_kBlueAI')));
      expect(
        RegExp(r'accentColor:\s*_kToolBtn,').allMatches(actionRow).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('keeps the card background fully transparent', () {
      expect(actionCard, contains('color: Colors.transparent,'));
      expect(actionCard, isNot(contains('color: effectiveBg,')));
      expect(actionCard, isNot(contains('effectiveBg')));
      expect(
        RegExp(
          r'^[ \t]*(?:final|const|var)\b[^;\n]*\b'
          r'(?:bg|bgHover|bgTap)\s*=',
          multiLine: true,
        ).hasMatch(actionCard),
        isFalse,
      );
    });

    test('forbids shadow glow and gradient', () {
      expect(actionCard, isNot(contains('boxShadow:')));
      expect(actionCard, isNot(contains('BoxShadow(')));
      expect(actionCard, isNot(contains('gradient:')));
    });

    test('retains one solid discreet outline', () {
      expect(
        RegExp(r'border:\s*Border\.all\(').allMatches(actionCard).length,
        1,
      );
      expect(actionCard, contains('color: effectiveBorder,'));
      expect(actionCard, contains('width: 1.0,'));
    });

    test('retains restrained pressed-state feedback', () {
      expect(actionCard, contains('AnimatedContainer('));
      expect(actionCard, contains('onTapDown'));
      expect(actionCard, contains('onTapUp'));
      expect(actionCard, contains('onTapCancel'));
      expect(
        actionCard,
        contains('Duration(milliseconds: 150)'),
      );
    });

    test('does not introduce AnimatedSize into either owner', () {
      expect(actionRow, isNot(contains('AnimatedSize')));
      expect(actionCard, isNot(contains('AnimatedSize')));
    });
  });
}
