import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String screen;
  late String provider;

  setUpAll(() {
    screen = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    provider = File(
      'lib/providers/app_provider.dart',
    ).readAsStringSync();
  });

  group(
    'R18.6AB-R1B-R3-R1 — retomada histórica atômica',
    () {
      test('Provider adota a identidade restaurada', () {
        expect(
          provider,
          contains(
            'void adoptRestoredAiConversation({',
          ),
        );

        expect(
          provider,
          contains(
            '_currentConversationSessionId = '
            'normalizedSessionId;',
          ),
        );

        expect(
          provider,
          contains(
            '_currentConversationTitle = '
            'normalizedTitle;',
          ),
        );

        expect(
          provider,
          contains(
            '_isFirstMessageOfSession = false;',
          ),
        );
      });

      test('modo salvo é aplicado diretamente', () {
        expect(
          screen,
          contains(
            '_decodeStoredHistoryMode(summary.mode)',
          ),
        );

        expect(
          screen,
          contains(
            '_longResponse = restoredMode;',
          ),
        );

        expect(
          screen,
          contains(
            '_modeConfirmed = restoredMode != null;',
          ),
        );
      });

      test('Estudo e Guardia são reconhecidos', () {
        expect(
          screen,
          contains("case 'estudo':"),
        );

        expect(
          screen,
          contains("case 'estudio':"),
        );

        expect(
          screen,
          contains("case 'guardia':"),
        );

        expect(
          screen,
          contains("case 'plantao':"),
        );
      });

      test('modo desconhecido não reinicia a sessão', () {
        expect(
          screen,
          contains(
            'final adoptingRestoredMode =',
          ),
        );

        expect(
          screen,
          contains(
            '!adoptingRestoredMode &&',
          ),
        );

        expect(
          screen,
          contains(
            '[AI_MODE_SELECTOR][RESTORED_ADOPTION]',
          ),
        );
      });

      test('duas reconstruções permanecem', () {
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
          RegExp(
            r'p\.rebuildAiHistoryFromMessages\(',
          ).allMatches(restore).length,
          2,
        );
      });

      test('restore possui geração e stale guard', () {
        expect(
          screen,
          contains(
            'int _historyRestoreGeneration = 0;',
          ),
        );

        expect(
          screen,
          contains(
            '++_historyRestoreGeneration;',
          ),
        );

        expect(
          screen,
          contains(
            'restoreGeneration != '
            '_historyRestoreGeneration',
          ),
        );

        expect(
          screen,
          contains(
            '[SESSION_RESTORE][STALE_DROP]',
          ),
        );
      });

      test(
        'limpar e Novo Chat invalidam restore pendente',
        () {
          final prefixInvalidators = RegExp(
            r'\+\+_historyRestoreGeneration;',
          ).allMatches(screen).length;

          final postfixInvalidators = RegExp(
            r'_historyRestoreGeneration\+\+;',
          ).allMatches(screen).length;

          expect(
            prefixInvalidators,
            greaterThanOrEqualTo(1),
          );

          expect(
            postfixInvalidators,
            greaterThanOrEqualTo(2),
          );
        },
      );

      test('restore nunca inicia Novo Chat', () {
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
          restore,
          isNot(
            contains('_startNewChat();'),
          ),
        );

        expect(
          restore,
          isNot(
            contains('clearAiHistory();'),
          ),
        );

        expect(
          restore,
          isNot(
            contains('resetAiSessionFull();'),
          ),
        );
      });

      test('continuação, streaming e scroll permanecem', () {
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
              '_userScrolledUp = !nearBottom',
            ),
          ),
        );

        final bubble = File(
          'lib/screens/ai/widgets/ai_bubble.dart',
        ).readAsStringSync();

        expect(
          bubble,
          contains(
            'AI-RECONSTRUCTION-R18.6Z-R2-R2-R1',
          ),
        );
      });
    },
  );
}
