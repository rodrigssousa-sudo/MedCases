import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/response_mode_toggle.dart';

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
  late String ai;
  late String mode;
  late String topbar;
  late String desktop;
  late String modeWidget;
  late String mplus;

  setUpAll(() {
    ai = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    mode = File(
      'lib/screens/ai/widgets/'
      'response_mode_toggle.dart',
    ).readAsStringSync();

    topbar = File(
      'lib/screens/ai/widgets/'
      'mobile_ai_action_bar.dart',
    ).readAsStringSync();

    desktop = File(
      'lib/screens/ai/widgets/'
      'wa_header.dart',
    ).readAsStringSync();

    modeWidget = classBlock(
      mode,
      'class ResponseModeToggle '
      'extends StatelessWidget',
    );

    mplus = classBlock(
      topbar,
      'class MplusPulse '
      'extends StatefulWidget',
    );
  });

  group(
    'AI UI Refinement — seletor preservado sem modo confirmado na topbar',
    () {
      test(
        'Estudo continua sendo o padrão funcional',
        () {
          expect(
            ai,
            contains(
              'bool _longResponse = true;',
            ),
          );

          expect(
            ai,
            contains(
              'longResponse: _longResponse',
            ),
          );
        },
      );

      test(
        'separa estado funcional de confirmação visual',
        () {
          for (final token in const [
            'bool _modeConfirmed = false;',
            'bool _modeReselectionPending = false;',
            'void _openResponseModeSelector()',
            'void _commitResponseMode(bool newValue)',
          ]) {
            expect(
              ai,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'seletor desaparece depois da escolha',
        () {
          expect(
            ai,
            contains(
              '!forceDisconnectedLabel && '
              '!_modeConfirmed',
            ),
          );

          expect(
            ai,
            contains(
              'onChanged: _commitResponseMode',
            ),
          );

          expect(
            ai,
            isNot(
              contains(
                'if (newValue == '
                '_longResponse) return;',
              ),
            ),
          );
        },
      );

      test(
        'troca posterior usa o reset canônico',
        () {
          for (final token in const [
            'final shouldRestart =',
            '_modeReselectionPending ||',
            '_messages.any(',
            "(message) => message.role == 'user',",
            'if (shouldRestart)',
            '_startNewChat(preserveConfirmedMode: true);',
            '_saveCurrentSessionToHistory(p);',
            'p.cancelAiStream();',
            '_aiUiRequestGeneration++;',
            '_streamingTextNotifier?.dispose();',
          ]) {
            expect(
              ai,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'seletor é texto puro sem ciano',
        () {
          for (final token in const [
            "'ESTUDIO'",
            "'ESTUDOS'",
            "'GUARDIA'",
            "'PLANTÃO'",
            '? Colors.white',
            ': const Color(0xFF4B5563)',
            'width: 1',
            'height: 18',
            'width: isCurrent ? 44 : 0',
            'height: 2',
          ]) {
            expect(
              modeWidget,
              contains(token),
              reason: token,
            );
          }

          for (final forbidden in const [
            '0xFF00E5FF',
            '0xFF008CA4',
            '0xFF00C781',
            'LinearGradient',
            'boxShadow',
            'inactiveBg',
            'Border.all',
            'BorderRadius.circular(24)',
          ]) {
            expect(
              modeWidget,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );

      test(
        'modo confirmado chega às duas topbars',
        () {
          for (final token in const [
            'modeConfirmed: _modeConfirmed',
            'studyMode: _longResponse',
            'onModeTap: '
                '_openResponseModeSelector',
          ]) {
            expect(
              ai,
              contains(token),
              reason: token,
            );
          }

          expect(
            ai
                    .split(
                      'modeConfirmed: _modeConfirmed',
                    )
                    .length -
                1,
            2,
          );
        },
      );

      test(
        'modo confirmado deixa de ser projetado nas topbars',
        () {
          for (final source in [
            topbar,
            desktop,
          ]) {
            expect(
              source,
              isNot(contains('AiModePulseLabel')),
            );
            expect(
              source,
              isNot(contains('onTap: onModeTap')),
            );
          }

          for (final label in const [
            "'ESTUDIO'",
            "'ESTUDOS'",
            "'GUARDIA'",
            "'PLANTÃO'",
          ]) {
            expect(
              topbar,
              isNot(contains(label)),
              reason: label,
            );
            expect(
              desktop,
              isNot(contains(label)),
              reason: label,
            );
          }
        },
      );

      test(
        'M+ conserva sua animação original',
        () {
          for (final token in const [
            'class MplusPulse '
                'extends StatefulWidget',
            'class MplusPulseState '
                'extends State<MplusPulse>',
            'AnimationController',
            'milliseconds: 1500',
            'begin: 0.35',
            'end: 1.0',
          ]) {
            expect(
              topbar,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'reseleção permanece funcional fora da projeção da topbar',
        () {
          for (final token in const [
            'void _openResponseModeSelector()',
            '_modeReselectionPending = true',
            'onChanged: _commitResponseMode',
          ]) {
            expect(
              ai,
              contains(token),
              reason: token,
            );
          }

          for (final source in [
            topbar,
            desktop,
          ]) {
            expect(
              source,
              isNot(contains('onTap: onModeTap')),
            );
            expect(
              source,
              isNot(contains('AiModePulseLabel')),
            );
          }
        },
      );

      test(
        'M+ permanece proprietário',
        () {
          for (final token in const [
            'class MplusPulse '
                'extends StatefulWidget',
            'class MplusPulseState '
                'extends State<MplusPulse>',
            'duration: const Duration'
                '(milliseconds: 1500)',
            "child: const Text(\n"
                "          'M+'",
            'onTap: onSettings',
          ]) {
            expect(
              topbar,
              contains(token),
              reason: token,
            );
          }

          expect(
            mplus,
            isNot(
              contains('AiModePulseLabel'),
            ),
          );
        },
      );

      test(
        'widgets visuais não criam infraestrutura paralela',
        () {
          for (final source in [
            mode,
          ]) {
            for (final forbidden in const [
              'ChangeNotifier',
              'StreamController',
              'Provider<',
              'FirebaseFirestore',
              'SharedPreferences',
              'SpeechToText',
              'TextEditingController',
              'Navigator.',
              'Scaffold(',
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

      testWidgets(
        'ambas as escolhas preservam o callback booleano',
        (tester) async {
          bool? selected;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ResponseModeToggle(
                  value: true,
                  dark: true,
                  lang: 'es',
                  onChanged: (value) {
                    selected = value;
                  },
                ),
              ),
            ),
          );

          await tester.tap(
            find.text('ESTUDIO'),
          );

          expect(selected, isTrue);

          await tester.tap(
            find.text('GUARDIA'),
          );

          expect(selected, isFalse);
        },
      );
    },
  );
}
