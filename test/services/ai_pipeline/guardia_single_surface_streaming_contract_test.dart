import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String screen;
  late String view;

  setUpAll(() {
    screen = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    view = File(
      'lib/screens/ai/widgets/'
      'guardia_clinical_response_view.dart',
    ).readAsStringSync();
  });

  group(
    'Guardia single surface streaming contract',
    () {
      test('Guardia não depende de DTO nem fim do streaming', () {
        expect(
          RegExp(
            r'final\s+bool\s+useGuardiaPresentation\s*=\s*'
            r'!_longResponse\s*&&\s*!isSafeCard\s*;',
          ).hasMatch(screen),
          isTrue,
        );

        expect(
          screen,
          isNot(
            contains(
              'useStructuredGuardiaPresentation',
            ),
          ),
        );

        expect(
          screen,
          contains('output: msg.clinicalOutput,'),
        );
      });

      test('usa a mesma key durante parcial e final', () {
        expect(
          screen,
          contains(
            "key: ValueKey('guardia_\${msg.id}')",
          ),
        );

        expect(
          RegExp(
            r"ValueKey\('guardia_\$\{msg\.id\}'\)",
          ).allMatches(screen).length,
          1,
        );
      });

      test('Guardia recebe notifier ultralocal e estado streaming', () {
        expect(
          screen,
          contains(
            'isStreaming: isActiveStreamingBubble,',
          ),
        );
        expect(
          screen,
          contains(
            'streamingTextNotifier:',
          ),
        );
        expect(
          screen,
          contains(
            'onTextRevealed: _onBlockRevealed,',
          ),
        );
        expect(
          view,
          contains(
            'final ValueNotifier<String>? '
            'streamingTextNotifier;',
          ),
        );
      });

      test('renderer aceita output opcional e raw parcial', () {
        expect(
          view,
          contains(
            'final ClinicalStructuredOutput? output;',
          ),
        );
        expect(
          view,
          contains(
            '_RawGuardiaSections.parse(',
          ),
        );
        expect(
          view,
          contains(
            'final List<String> fallbackLines;',
          ),
        );
      });

      test('Guardia não sofre fade ao concluir streaming', () {
        expect(
          screen,
          contains(
            '(_longResponse || isSafeCard) &&',
          ),
        );
        expect(
          screen,
          contains(
            '_fadingInMsgId != null &&',
          ),
        );
      });

      test('Estudo e safe-card continuam no AiBubble', () {
        expect(
          screen,
          contains(
            'if (useGuardiaPresentation)',
          ),
        );
        expect(
          RegExp(
            r'else\s+AiBubble\s*\(',
          ).hasMatch(screen),
          isTrue,
        );
        expect(
          RegExp(
            r'_longResponse\s*&&\s*'
            r'msg\.clinicalOutput\s*!=\s*null',
          ).hasMatch(screen),
          isTrue,
        );
      });

      test('botão azul permanece fora do renderer', () {
        expect(
          view,
          isNot(
            contains('StudyContinuationResolver'),
          ),
        );
        expect(
          view,
          isNot(contains('_sendDebounced')),
        );
        expect(
          screen,
          contains('ActionButtonsRow('),
        );
      });
    },
  );
}
