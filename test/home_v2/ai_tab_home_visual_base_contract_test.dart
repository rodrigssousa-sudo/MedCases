import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String aiRowBlock(
  String source,
) {
  const declaration = 'Widget _buildAiRow() => Row(';

  final start = source.indexOf(
    declaration,
  );

  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: '_buildAiRow ausente',
  );

  final rowStart = source.indexOf(
    'Row(',
    start,
  );

  final opening = source.indexOf(
    '(',
    rowStart,
  );

  var depth = 0;
  String? quote;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;

  for (var index = opening; index < source.length; index++) {
    final character = source[index];

    final pair = index + 1 < source.length
        ? source.substring(
            index,
            index + 2,
          )
        : character;

    if (lineComment) {
      if (character == '\n') {
        lineComment = false;
      }
      continue;
    }

    if (blockComment) {
      if (pair == '*/') {
        blockComment = false;
        index++;
      }
      continue;
    }

    if (quote != null) {
      if (escaped) {
        escaped = false;
        continue;
      }

      if (character == '\\') {
        escaped = true;
        continue;
      }

      if (character == quote) {
        quote = null;
      }

      continue;
    }

    if (pair == '//') {
      lineComment = true;
      index++;
      continue;
    }

    if (pair == '/*') {
      blockComment = true;
      index++;
      continue;
    }

    if (character == "'" || character == '"') {
      quote = character;
      continue;
    }

    if (character == '(') {
      depth++;
    } else if (character == ')') {
      depth--;

      if (depth == 0) {
        final semicolon = source.indexOf(
          ';',
          index,
        );

        expect(
          semicolon,
          greaterThan(index),
        );

        return source.substring(
          start,
          semicolon + 1,
        );
      }
    }
  }

  fail(
    '_buildAiRow sem fechamento',
  );
}

void main() {
  late String ai;
  late String main;
  late String palette;
  late String mobileBar;
  late String modeToggle;
  late String promptComposer;
  late String aiBubble;
  late String aiRow;

  setUpAll(() {
    ai = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    main = File(
      'lib/main.dart',
    ).readAsStringSync();

    palette = File(
      'lib/home_v2/theme/'
      'home_v2_palette.dart',
    ).readAsStringSync();

    mobileBar = File(
      'lib/screens/ai/widgets/'
      'mobile_ai_action_bar.dart',
    ).readAsStringSync();

    modeToggle = File(
      'lib/screens/ai/widgets/'
      'response_mode_toggle.dart',
    ).readAsStringSync();

    promptComposer = File(
      'lib/screens/ai/widgets/'
      'prompt_composer.dart',
    ).readAsStringSync();

    aiBubble = File(
      'lib/screens/ai/widgets/'
      'ai_bubble.dart',
    ).readAsStringSync();

    aiRow = aiRowBlock(main);
  });

  group(
    'AI-VIS-B.1-R1 — base visual da aba IA',
    () {
      test(
        'AiScreen consome HomeV2Palette',
        () {
          expect(
            ai,
            contains(
              "import '../home_v2/theme/"
              "home_v2_palette.dart';",
            ),
          );

          expect(
            ai,
            contains(
              'HomeV2Palette.dark',
            ),
          );

          expect(
            ai,
            contains(
              'HomeV2Palette.light',
            ),
          );

          expect(
            ai,
            contains(
              'final chatBg = '
              'palette.background;',
            ),
          );
        },
      );

      test(
        'canvas cromático antigo foi removido',
        () {
          expect(
            RegExp(
              r'final\s+chatBg\s*=\s*dark\s*'
              r'\?\s*const\s+Color'
              r'\(0xFF121418\)',
            ).hasMatch(ai),
            isFalse,
          );

          expect(
            palette,
            contains(
              'final Color background',
            ),
          );
        },
      );

      test(
        'barra contextual usa branco no dark',
        () {
          expect(
            aiRow,
            contains('Colors.white'),
          );

          expect(
            aiRow,
            isNot(
              contains(
                'const Color(0xFF6B7280)',
              ),
            ),
          );

          expect(
            RegExp(
              r'fontWeight\s*:\s*'
              r'FontWeight\.w500\s*,\s*'
              r'color\s*:\s*widget\.dark\s*'
              r'\?\s*Colors\.white\s*'
              r':\s*const\s+Color'
              r'\(0xFF4B5563\)\s*,',
              multiLine: true,
            ).hasMatch(aiRow),
            isTrue,
          );
        },
      );

      test(
        'callbacks reais da barra permanecem',
        () {
          for (final token in const [
            'AiScreen.openHistoryCallback',
            'AiScreen.historyCountNotifier',
            'widget.onFabDoubleTap',
            'widget.onTabChange(0)',
            '_buildMenuButton()',
          ]) {
            expect(
              aiRow,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'Novo Chat mantém cadeia canônica',
        () {
          expect(
            main,
            contains(
              'onFabDoubleTap: () => '
              '_resetAndStartNewChat()',
            ),
          );

          expect(
            main,
            contains(
              'AiScreen.clearChatCallback.value',
            ),
          );
        },
      );

      test(
        'M+ superior permanece proprietário',
        () {
          expect(
            mobileBar,
            contains(
              'class MobileAiActionBar',
            ),
          );

          expect(
            mobileBar,
            contains(
              'class MplusPulse',
            ),
          );

          expect(
            mobileBar,
            contains("'M+'"),
          );

          expect(
            ai,
            contains(
              'MobileAiActionBar(',
            ),
          );
        },
      );

      test(
        'Estudo e Guardia permanecem intactos',
        () {
          expect(
            modeToggle,
            contains(
              'class ResponseModeToggle',
            ),
          );

          expect(
            modeToggle,
            contains(
              'required this.value',
            ),
          );

          expect(
            modeToggle,
            contains(
              'required this.onChanged',
            ),
          );

          expect(
            ai,
            contains(
              'ResponseModeToggle(',
            ),
          );
        },
      );

      test(
        'composer e renderer permanecem',
        () {
          expect(
            promptComposer,
            contains(
              'class PromptComposer',
            ),
          );

          expect(
            aiBubble,
            contains(
              'class AiBubble',
            ),
          );

          expect(
            ai,
            contains(
              'PromptComposer(',
            ),
          );

          expect(
            ai,
            contains(
              'AiBubble(',
            ),
          );
        },
      );

      test(
        'motores funcionais foram preservados',
        () {
          for (final token in const [
            'SttHelper.start(',
            'SttHelper.stop()',
            '_streamingTextNotifier',
            'pendingQuery',
            'pendingHistory',
            '_chatHistory',
            '_saveCurrentSessionToHistory(',
            '_sendDebounced(',
          ]) {
            expect(
              ai,
              contains(token),
              reason: token,
            );
          }
        },
      );
    },
  );
}
