import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String screen;

  setUpAll(() {
    screen = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();
  });

  group(
    'R18.6AC-R1B-H1 — histórico e modo',
    () {
      test('Novo Chat comum volta ao seletor', () {
        expect(
          screen,
          contains(
            'void _startNewChat({'
            'bool preserveConfirmedMode = false'
            '})',
          ),
        );

        expect(
          screen,
          contains(
            'if (preserveConfirmedMode)',
          ),
        );

        expect(
          screen,
          contains(
            '_modeConfirmed = false;',
          ),
        );

        expect(
          screen,
          contains(
            '_longResponse = true;',
          ),
        );
      });

      test('troca manual preserva o modo escolhido', () {
        expect(
          screen,
          contains(
            '_startNewChat('
            'preserveConfirmedMode: true'
            ');',
          ),
        );
      });

      test('restore valida geração e sessionId', () {
        final start = screen.indexOf(
          'void _restoreFromSummary(',
        );

        final end = screen.indexOf(
          '/// Desce para o fundo do chat.',
          start,
        );

        final restore = screen.substring(
          start,
          end,
        );

        expect(
          screen,
          contains(
            'String? _selectedHistorySessionId;',
          ),
        );

        expect(
          restore,
          contains(
            '_selectedHistorySessionId = '
            'summary.sessionId;',
          ),
        );

        expect(
          RegExp(
            r'_selectedHistorySessionId\s*!='
            r'\s*summary\.sessionId',
          ).allMatches(restore).length,
          2,
        );
      });

      test('continuação e scroll não foram alterados', () {
        expect(
          screen,
          contains(
            'StudyContinuationResolver.resolve(',
          ),
        );

        expect(
          screen,
          isNot(
            contains(
              '_studyContinuationReadyGeneration',
            ),
          ),
        );

        expect(
          screen,
          isNot(
            contains(
              '_userScrolledUp = !nearBottom',
            ),
          ),
        );
      });
    },
  );
}
