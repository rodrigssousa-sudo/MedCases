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

  fail(
    'Classe sem fechamento: $declaration',
  );
}

void main() {
  late String ai;
  late String composer;
  late String home;
  late String palette;
  late String greeting;
  late String composerState;

  setUpAll(() {
    ai = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    composer = File(
      'lib/screens/ai/widgets/'
      'prompt_composer.dart',
    ).readAsStringSync();

    home = File(
      'lib/home_v2/components/chat/'
      'inline_chat_view.dart',
    ).readAsStringSync();

    palette = File(
      'lib/home_v2/theme/'
      'home_v2_palette.dart',
    ).readAsStringSync();

    greeting = classBlock(
      ai,
      'class _AiHomeGreeting '
      'extends StatelessWidget',
    );

    composerState = classBlock(
      composer,
      'class _PromptComposerState '
      'extends State<PromptComposer>',
    );
  });

  group(
    'AI-VIS-B.2.1-R3 — saudação e composer',
    () {
      test(
        'colore período e vírgula sem colorir o nome',
        () {
          for (final token in const [
            "greeting.indexOf(',')",
            'greeting.substring(0, commaIndex + 1)',
            'greeting.substring(commaIndex + 1)',
            'text: greetingLead',
            'color: palette.accent',
            'text: greetingName',
            'color: palette.textPrimary',
            'Text.rich(',
          ]) {
            expect(
              greeting,
              contains(token),
              reason: token,
            );
          }

          expect(
            RegExp(
              r'TextSpan\(\s*'
              r'text:\s*greetingName,\s*'
              r'style:\s*TextStyle\(\s*'
              r'color:\s*palette\.textPrimary',
              multiLine: true,
            ).hasMatch(greeting),
            isTrue,
          );
        },
      );

      test(
        'composer utiliza a paleta compartilhada',
        () {
          expect(
            composer,
            contains(
              "import '../../../home_v2/theme/"
              "home_v2_palette.dart';",
            ),
          );

          for (final token in const [
            'HomeV2Palette.resolve(dark)',
            'palette.surfaceSoft',
            'palette.border',
            'palette.borderActive',
            'palette.textPrimary',
            'palette.textSecondary',
            'palette.accent',
          ]) {
            expect(
              composerState,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'composer replica a geometria da Home',
        () {
          for (final token in const [
            'BorderRadius.circular(24)',
            'minHeight: 50',
            'width: 0.6',
            'minLines: 1',
            'maxLines: 6',
            'width: 34',
            'height: 34',
            'width: 32',
            'height: 32',
            'fontSize: 14',
            'fontSize: 13.5',
          ]) {
            expect(
              composerState,
              contains(token),
              reason: token,
            );
          }

          expect(
            composerState,
            contains(
              'EdgeInsets.fromLTRB(\n'
              '              11,\n'
              '              3,\n'
              '              3,\n'
              '              3,',
            ),
          );

          for (final token in const [
            'color: palette.surfaceSoft',
            'BorderRadius.circular(24)',
            'minHeight: 50',
            'padding: const EdgeInsets.fromLTRB(11, 3, 3, 3)',
            'color: palette.border',
            'width: 0.6',
            'minLines: 1',
            'maxLines: 6',
          ]) {
            expect(
              home,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'remove vidro raio 30 e cores antigas',
        () {
          for (final forbidden in const [
            'BackdropFilter',
            'ImageFilter.blur',
            "import 'dart:ui' show ImageFilter;",
            'Color(0xFF16181D)',
            'Color(0xFFF9FAFB)',
            'Color(0xFF00E5FF)',
            'Color(0xFF008CA4)',
            'Radius.circular(30)',
            'BorderRadius.circular(30)',
            'maxLines: null',
            'maxHeight: 140',
          ]) {
            expect(
              composer,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );

      test(
        'preserva conexão e bloqueio duplo',
        () {
          for (final token in const [
            'widget.isConnected',
            'widget.onConnectTap',
            'final locked = !widget.isConnected',
            'onTap: locked ? widget.onConnectTap : null',
            'enabled: !locked',
            'readOnly: locked',
            'FocusScope.of(context).unfocus()',
          ]) {
            expect(
              composerState,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'preserva envio cancelamento e teclado real',
        () {
          for (final token in const [
            'widget.onSend',
            'widget.onCancel',
            'widget.thinking',
            'LogicalKeyboardKey.enter',
            'HardwareKeyboard.instance.isShiftPressed',
            'HardwareKeyboard.instance.isControlPressed',
            'KeyEventResult.handled',
            'KeyEventResult.ignored',
            'TextInputAction.newline',
            'TextInputType.multiline',
            'onSubmitted:',
          ]) {
            expect(
              composerState,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'preserva ditado e feedback de áudio',
        () {
          for (final token in const [
            'widget.onVoice',
            'widget.sttListening',
            'widget.sttSoundLevel',
            '_PromptAudioWave(',
            "'Detener dictado'",
            "'Parar ditado'",
            "'Escuchando…'",
            "'Ouvindo…'",
            'Icons.mic_none_rounded',
            'Icons.mic_rounded',
            'Icons.mic_off_outlined',
          ]) {
            expect(
              composerState,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'envio usa verde e cancelamento usa vermelho',
        () {
          expect(
            RegExp(
              r'widget\.thinking\s*'
              r'\?\s*const Color\(0xFFEF4444\)\s*'
              r':\s*palette\.accent',
            ).hasMatch(composerState),
            isTrue,
          );

          expect(
            composerState,
            contains('Icons.stop_rounded'),
          );

          expect(
            composerState,
            contains('Icons.arrow_upward_rounded'),
          );
        },
      );

      test(
        'paleta oficial permanece fonte única',
        () {
          expect(
            palette,
            contains('class HomeV2Palette'),
          );

          expect(
            palette,
            contains(
              'static HomeV2Palette '
              'resolve(bool dark)',
            ),
          );

          expect(
            palette,
            contains(
              'accent: Color(0xFF00C781)',
            ),
          );
        },
      );

      test(
        'não cria infraestrutura funcional paralela',
        () {
          for (final forbidden in const [
            'ChangeNotifier',
            'StreamController',
            'Provider<',
            'FirebaseFirestore',
            'SharedPreferences',
            'SpeechToText',
            'TextEditingController()',
          ]) {
            expect(
              composerState,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );
    },
  );
}
