import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/prompt_composer.dart';

String classBlock(
  String source,
  String declaration,
) {
  final start = source.indexOf(declaration);

  expect(
    start,
    greaterThanOrEqualTo(0),
  );

  final opening = source.indexOf('{', start);
  var depth = 0;
  String? quote;
  var escaped = false;

  for (var index = opening; index < source.length; index++) {
    final character = source[index];

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

  fail('Classe sem fechamento.');
}

Widget buildComposer({
  required TextEditingController controller,
  required FocusNode focusNode,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: PromptComposer(
            ctrl: controller,
            focusNode: focusNode,
            dark: true,
            hasFocus: false,
            thinking: false,
            onSend: () {},
            onCancel: () {},
            onVoice: () {},
            sttListening: false,
            sttSoundLevel: 0,
            hint: 'Digite uma dúvida clínica...',
            lang: 'pt',
            isConnected: true,
          ),
        ),
      ),
    ),
  );
}

void main() {
  late String composer;
  late String home;
  late String state;

  setUpAll(() {
    composer = File(
      'lib/screens/ai/widgets/'
      'prompt_composer.dart',
    ).readAsStringSync();

    home = File(
      'lib/home_v2/components/chat/'
      'inline_chat_view.dart',
    ).readAsStringSync();

    state = classBlock(
      composer,
      'class _PromptComposerState '
      'extends State<PromptComposer>',
    );
  });

  group(
    'AI-VIS-B.2.2-R1 — alinhamento do composer',
    () {
      test(
        'mantém a geometria oficial da Home',
        () {
          for (final token in const [
            'color: palette.surfaceSoft',
            'BorderRadius.circular(24)',
            'minHeight: 50',
            'width: 0.6',
            'minLines: 1',
            'maxLines: 6',
            'crossAxisAlignment: '
                'CrossAxisAlignment.end',
          ]) {
            expect(
              state,
              contains(token),
              reason: token,
            );
          }

          expect(
            home,
            contains(
              'crossAxisAlignment: '
              'CrossAxisAlignment.end',
            ),
          );
        },
      );

      test(
        'microfone e envio usam slot externo comum',
        () {
          final microphoneStart = state.indexOf(
            'Widget microphoneButton({',
          );

          final sendStart = state.indexOf(
            'Widget sendButton()',
          );

          final normalStart = state.indexOf(
            'Widget normalComposer()',
          );

          final microphone = state.substring(
            microphoneStart,
            sendStart,
          );

          final send = state.substring(
            sendStart,
            normalStart,
          );

          expect(
            microphone,
            contains('width: 34'),
          );

          expect(
            microphone,
            contains('height: 34'),
          );

          expect(
            send,
            contains('width: 34'),
          );

          expect(
            send,
            contains('height: 34'),
          );

          expect(
            send,
            contains('width: 32'),
          );

          expect(
            send,
            contains('height: 32'),
          );

          expect(
            send,
            contains('child: Center('),
          );
        },
      );

      test(
        'controles usam estrutura Material e InkWell da Home',
        () {
          for (final token in const [
            'Material(',
            'InkWell(',
            'overlayColor: palette.pressedOverlay',
            'splashFactory: NoSplash.splashFactory',
          ]) {
            expect(
              state,
              contains(token),
              reason: token,
            );
          }
        },
      );

      testWidgets(
        'seta fica 1.4 px acima do microfone',
        (tester) async {
          final controller = TextEditingController();
          final focusNode = FocusNode();

          addTearDown(controller.dispose);
          addTearDown(focusNode.dispose);

          await tester.pumpWidget(
            buildComposer(
              controller: controller,
              focusNode: focusNode,
            ),
          );

          await tester.pump();

          final micCenter = tester.getCenter(
            find.byIcon(
              Icons.mic_none_rounded,
            ),
          );

          final sendCenter = tester.getCenter(
            find.byIcon(
              Icons.arrow_upward_rounded,
            ),
          );

          expect(
            micCenter.dy - sendCenter.dy,
            closeTo(1.4, 0.25),
          );
        },
      );

      test(
        'preserva callbacks e estados funcionais',
        () {
          for (final token in const [
            'widget.onVoice',
            'widget.onSend',
            'widget.onCancel',
            'widget.onConnectTap',
            'widget.sttListening',
            'widget.sttSoundLevel',
            'enabled: !locked',
            'readOnly: locked',
            'isShiftPressed',
            'isControlPressed',
            '_PromptAudioWave(',
            'Icons.stop_rounded',
            'Icons.mic_off_outlined',
          ]) {
            expect(
              state,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'aumenta somente a seta de envio',
        () {
          expect(
            state,
            contains(
              'size: stopMode ? 17 : 20',
            ),
          );

          expect(
            state,
            contains(
              'size: widget.thinking ? 17 : 21',
            ),
          );
        },
      );

      test(
        'não cria infraestrutura paralela',
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
              state,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );
    },
  );
}
