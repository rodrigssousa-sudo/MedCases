import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(
  String source,
  String declaration,
) {
  final start = source.indexOf(declaration);

  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: 'Classe ausente: $declaration',
  );

  final opening = source.indexOf('{', start);

  var depth = 0;
  String? quote;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;

  for (var index = opening; index < source.length; index++) {
    final character = source[index];

    final pair = index + 1 < source.length
        ? source.substring(index, index + 2)
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

    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;

      if (depth == 0) {
        return source.substring(
          start,
          index + 1,
        );
      }
    }
  }

  fail('Classe sem fechamento: $declaration');
}

void main() {
  late String user;
  late String block;
  late String aiBubble;
  late String home;
  late String userState;
  late String blockClass;

  setUpAll(() {
    user = File(
      'lib/screens/ai/widgets/user_bubble.dart',
    ).readAsStringSync();

    block = File(
      'lib/screens/ai/widgets/'
      'ai_block_bubble.dart',
    ).readAsStringSync();

    aiBubble = File(
      'lib/screens/ai/widgets/ai_bubble.dart',
    ).readAsStringSync();

    home = File(
      'lib/home_v2/components/chat/'
      'inline_chat_view.dart',
    ).readAsStringSync();

    userState = classBlock(
      user,
      'class _UserBubbleState '
      'extends State<UserBubble>',
    );

    blockClass = classBlock(
      block,
      'class AiBlockBubble '
      'extends StatelessWidget',
    );
  });

  group(
    'AI-VIS-B.3-R1 — pergunta e resposta',
    () {
      test(
        'pergunta usa hierarquia visual da Home',
        () {
          for (final token in const [
            'HomeV2Palette.resolve(widget.dark)',
            'width: 3',
            'color: palette.accent',
            'BorderRadius.circular(3)',
            "isEs ? 'PREGUNTA' : 'PERGUNTA'",
            'fontSize: 10.2',
            'letterSpacing: 1.25',
            'SelectableText(',
            'widget.text',
            'fontSize: 13.6',
            'height: 1.45',
            'fontWeight: FontWeight.w600',
          ]) {
            expect(
              userState,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'pergunta preserva edição cópia e reenvio',
        () {
          for (final token in const [
            '_editCtrl',
            '_editFocus',
            '_startEdit',
            '_saveEdit',
            '_cancelEdit',
            '_showActions(context)',
            'widget.onEdit?.call(newText)',
            'widget.onCopy?.call()',
            'widget.isAiStreaming',
            'onLongPress:',
            'Icons.edit_outlined',
          ]) {
            expect(
              user,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'estado de edição usa a paleta compartilhada',
        () {
          for (final token in const [
            "isEs\n"
                "                    ? 'EDITAR PREGUNTA'\n"
                "                    : 'EDITAR PERGUNTA'",
            'color: palette.surfaceStrong',
            'color: palette.border',
            'color: palette.accent',
            'controller: _editCtrl',
            'focusNode: _editFocus',
            'maxLines: null',
          ]) {
            expect(
              userState,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'resposta usa HomeV2Palette e identidade final',
        () {
          expect(
            block,
            contains(
              "import '../../../home_v2/theme/"
              "home_v2_palette.dart';",
            ),
          );

          for (final token in const [
            'HomeV2Palette.resolve(dark)',
            'final kGreen = palette.accent',
            "'RESPUESTA COMPLETADA'",
            "'RESPOSTA CONCLUÍDA'",
            'fontSize: 10.2',
            'letterSpacing: 1.25',
            'palette.textPrimary',
          ]) {
            expect(
              blockClass,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'Markdown espelha a hierarquia da Home',
        () {
          for (final token in const [
            'p: TextStyle(',
            'fontSize: 13.5',
            'fontWeight: FontWeight.w400',
            'h1: TextStyle(',
            'fontSize: 14.2',
            'h2: TextStyle(',
            'fontSize: 13.9',
            'h3: TextStyle(',
            'fontSize: 13.6',
            'blockSpacing: 12',
            'listIndent: 20',
            'color: palette.accent',
            'color: palette.divider',
            'color: palette.border',
            'color: palette.surfaceStrong',
          ]) {
            expect(
              blockClass,
              contains(token),
              reason: token,
            );
          }

          expect(
            home,
            contains('blockSpacing: 12'),
          );

          expect(
            home,
            contains('listIndent: 20'),
          );
        },
      );

      test(
        'remove ciano e vermelho Ferrari do Markdown',
        () {
          for (final forbidden in const [
            'Color(0xFF00E5FF)',
            'Color(0xFFFF2400)',
            'Color(0xFF008CA4)',
            'blockSpacing: 6',
            'listIndent: 18',
          ]) {
            expect(
              blockClass,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );

      test(
        'resposta mantém único MarkdownBody e links internos',
        () {
          expect(
            'MarkdownBody('.allMatches(blockClass).length,
            1,
          );

          for (final token in const [
            'selectable: false',
            'softLineBreak: true',
            'styleSheet: sheet',
            'onTapLink:',
            "href.contains('http')",
            'CalculadoraScreen(initialUrl: href)',
          ]) {
            expect(
              blockClass,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'preserva referências TTS cópia e chips',
        () {
          for (final token in const [
            '_splitRefLines',
            'CollapsibleReferencesBlock(',
            'lines: refLines',
            'dark: dark',
            'lang: lang',
            'onTap: onTts',
            'onTap: onCopy',
            'onChipTap',
            'ttsPlaying',
            'ttsReady',
          ]) {
            expect(
              blockClass,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'AiBubble continua proprietário do streaming',
        () {
          for (final token in const [
            'class AiBubbleState '
                'extends State<AiBubble>',
            '_networkBuffer',
            '_renderTimer',
            'StreamingTextDrain',
            'streamingTextNotifier',
            '_displayText',
            '_cachedBlocks',
            'AiBlockBubble(',
          ]) {
            expect(
              aiBubble,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'não cria infraestrutura funcional paralela',
        () {
          for (final source in [
            userState,
            blockClass,
          ]) {
            for (final forbidden in const [
              'ChangeNotifier',
              'StreamController',
              'Provider<',
              'FirebaseFirestore',
              'SharedPreferences',
              'SpeechToText',
              'Timer.periodic',
            ]) {
              expect(
                source,
                isNot(contains(forbidden)),
                reason: forbidden,
              );
            }
          }
        },
      );
    },
  );
}
