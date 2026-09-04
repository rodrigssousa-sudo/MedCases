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
            hint: 'Describe el caso: síntomas, '
                'signos vitales, exámenes...',
            lang: 'es',
            isConnected: true,
          ),
        ),
      ),
    ),
  );
}

Finder slotForIcon(
  IconData icon,
) {
  return find
      .ancestor(
        of: find.byIcon(icon),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 34 && widget.height == 34,
        ),
      )
      .first;
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
    'AI-VIS-B.2.3-R5 — paridade final com a Home',
    () {
      test(
        'mantém o chassis oficial da Home',
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

          final paddingPattern = RegExp(
            r'padding\s*:\s*const\s+'
            r'EdgeInsets\.fromLTRB\(\s*'
            r'11\s*,\s*3\s*,\s*'
            r'3\s*,\s*3\s*,?\s*\)',
          );

          expect(
            paddingPattern.hasMatch(state),
            isTrue,
          );

          expect(
            paddingPattern.hasMatch(home),
            isTrue,
          );
        },
      );

      test(
        'usa placeholder compacto sem depender do formatter',
        () {
          expect(
            state,
            contains('final visualHint'),
          );

          expect(
            state,
            contains(
              "'Escribe una duda clínica...'",
            ),
          );

          expect(
            state,
            contains(
              "'Escreva uma dúvida clínica...'",
            ),
          );

          expect(
            RegExp(
              r'hintText\s*:\s*locked[\s\S]*'
              r':\s*visualHint',
            ).hasMatch(state),
            isTrue,
          );

          expect(
            state,
            isNot(
              contains(': widget.hint,'),
            ),
          );
        },
      );

      test(
        'seta possui 21 px e correção óptica',
        () {
          expect(
            state,
            contains('Transform.translate('),
          );

          expect(
            state,
            contains('Offset(0, -1.4)'),
          );

          expect(
            state,
            contains(
              'Icons.arrow_upward_rounded',
            ),
          );

          expect(
            RegExp(
              r'size\s*:\s*widget\.thinking\s*'
              r'\?\s*17\s*:\s*21',
            ).hasMatch(state),
            isTrue,
          );
        },
      );

      testWidgets(
        'placeholder externo longo não aparece',
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

          expect(
            find.text(
              'Escribe una duda clínica...',
            ),
            findsOneWidget,
          );

          expect(
            find.textContaining(
              'Describe el caso:',
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'alvos de toque permanecem em 34 por 34',
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

          final micSlot = tester.getRect(
            slotForIcon(
              Icons.mic_none_rounded,
            ),
          );

          final sendSlot = tester.getRect(
            slotForIcon(
              Icons.arrow_upward_rounded,
            ),
          );

          expect(
            micSlot.width,
            closeTo(34, 0.01),
          );

          expect(
            micSlot.height,
            closeTo(34, 0.01),
          );

          expect(
            sendSlot.width,
            closeTo(34, 0.01),
          );

          expect(
            sendSlot.height,
            closeTo(34, 0.01),
          );

          expect(
            (micSlot.center.dy - sendSlot.center.dy).abs(),
            lessThan(0.01),
          );
        },
      );

      testWidgets(
        'desenho da seta fica 1.4 px acima',
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

          final arrowCenter = tester.getCenter(
            find.byIcon(
              Icons.arrow_upward_rounded,
            ),
          );

          expect(
            micCenter.dy - arrowCenter.dy,
            closeTo(1.4, 0.25),
          );
        },
      );

      test(
        'preserva callbacks e motores',
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
        'não cria infraestrutura paralela',
        () {
          for (final forbidden in const [
            'ChangeNotifier',
            'StreamController',
            'Provider<',
            'FirebaseFirestore',
            'SharedPreferences',
            'SpeechToText(',
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
