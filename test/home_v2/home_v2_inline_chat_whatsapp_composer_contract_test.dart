import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String blockBetween(
  String source,
  String startMarker,
  String endMarker,
) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(
    endMarker,
    start,
  );

  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: 'Marcador inicial ausente: $startMarker',
  );

  expect(
    end,
    greaterThan(start),
    reason: 'Marcador final ausente: $endMarker',
  );

  return source.substring(start, end);
}

void main() {
  late String visual;
  late String canonical;
  late String view;
  late String header;
  late String composer;

  setUpAll(() {
    visual = File(
      'lib/home_v2/components/chat/'
      'inline_chat_view.dart',
    ).readAsStringSync();

    canonical = File(
      'lib/screens/home_screen.dart',
    ).readAsStringSync();

    view = blockBetween(
      visual,
      'class HomeInlineChatV2View '
          'extends StatelessWidget',
      'class _InlineChatHeader '
          'extends StatelessWidget',
    );

    header = blockBetween(
      visual,
      'class _InlineChatHeader '
          'extends StatelessWidget',
      'class _HeaderAction '
          'extends StatelessWidget',
    );

    final composerStart = visual.indexOf(
      'class _InlineComposer '
      'extends StatelessWidget',
    );

    expect(
      composerStart,
      greaterThanOrEqualTo(0),
    );

    composer = visual.substring(
      composerStart,
    );
  });

  group(
    'MB-I.5.15-B-R1 — composer estilo WhatsApp',
    () {
      test(
        'usa trinta pixels totais por lado',
        () {
          expect(
            view,
            contains(
              'padding: const '
              'EdgeInsets.fromLTRB'
              '(14, 8, 14, 12)',
            ),
          );

          expect(
            view,
            matches(
              RegExp(
                r'padding:\s*const '
                r'EdgeInsets\.symmetric\('
                r'\s*horizontal:\s*16,\s*\)',
              ),
            ),
          );

          expect(
            RegExp(
              r'\b_InlineComposer\s*\(',
            ).allMatches(view).length,
            1,
          );
        },
      );

      test(
        'cresce de uma até seis linhas',
        () {
          expect(
            composer,
            contains(
              'constraints: const '
              'BoxConstraints(',
            ),
          );

          expect(
            composer,
            contains('minHeight: 50'),
          );

          expect(
            composer,
            isNot(
              matches(
                RegExp(
                  r'\bheight\s*:\s*50\b',
                ),
              ),
            ),
          );

          expect(
            composer,
            contains('minLines: 1'),
          );

          expect(
            composer,
            contains('maxLines: 6'),
          );

          expect(
            composer,
            isNot(
              contains('maxLines: 5'),
            ),
          );

          expect(
            composer,
            contains(
              'keyboardType: '
              'TextInputType.multiline',
            ),
          );
        },
      );

      test(
        'mantém rolagem interna do TextField',
        () {
          expect(
            composer,
            contains('maxLines: 6'),
          );

          expect(
            composer,
            isNot(
              contains(
                'SingleChildScrollView(',
              ),
            ),
          );

          expect(
            composer,
            contains(
              'crossAxisAlignment: '
              'CrossAxisAlignment.center',
            ),
          );
        },
      );

      test(
        'envio permanece canônico',
        () {
          for (final token in const [
            'final _ctrl = '
                'TextEditingController();',
            'final text = '
                '(preset ?? _ctrl.text).trim();',
            '_ctrl.clear();',
            'controller: _ctrl',
            'onSend: _onSendPressed',
          ]) {
            expect(
              canonical,
              contains(token),
              reason: token,
            );
          }

          expect(
            composer,
            contains(
              'final TextEditingController '
              'controller',
            ),
          );

          expect(
            composer,
            isNot(
              contains(
                'TextEditingController()',
              ),
            ),
          );

          expect(
            composer,
            contains(
              'onTap: thinking '
              '? null : onSend',
            ),
          );
        },
      );

      test(
        'microfone permanece visual nesta MB',
        () {
          expect(
            composer,
            contains(
              'Icons.mic_none_rounded',
            ),
          );

          expect(
            composer,
            contains(
              'Icons.arrow_upward_rounded',
            ),
          );

          expect(
            composer,
            isNot(
              contains('SpeechToText('),
            ),
          );
        },
      );

      test(
        'título usa MedCases e IA verde',
        () {
          expect(
            header,
            contains('RichText('),
          );

          expect(
            header,
            contains(
              "text: 'MedCases '",
            ),
          );

          expect(
            header,
            contains(
              "text: 'IA'",
            ),
          );

          expect(
            header,
            contains(
              'color: palette.textPrimary',
            ),
          );

          expect(
            header,
            contains(
              'color: _homeAccent(palette)',
            ),
          );

          expect(
            header,
            isNot(
              contains("'MEDCASES IA'"),
            ),
          );
        },
      );

      test(
        'ações do header são preservadas',
        () {
          for (final token in const [
            'onDoubleTap: '
                'hasExpandableContent',
            'onTap: onNewChat',
          ]) {
            expect(
              header,
              contains(token),
              reason: token,
            );
          }
        },
      );
    },
  );
}
