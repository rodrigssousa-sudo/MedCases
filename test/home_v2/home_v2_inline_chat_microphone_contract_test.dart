import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(
  String source,
  String className,
) {
  final declaration = RegExp(
    'class\\s+$className\\b[^\\{]*\\{',
  ).firstMatch(source);

  expect(
    declaration,
    isNotNull,
    reason: 'Classe ausente: $className',
  );

  final opening = source.indexOf(
    '{',
    declaration!.start,
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

    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;

      if (depth == 0) {
        return source.substring(
          declaration.start,
          index + 1,
        );
      }
    }
  }

  fail(
    'Fechamento ausente: $className',
  );
}

void main() {
  late String home;
  late String view;
  late String helper;
  late String mobile;
  late String web;
  late String plist;
  late String manifest;

  late String owner;
  late String publicView;
  late String composer;

  setUpAll(() {
    home = File(
      'lib/screens/home_screen.dart',
    ).readAsStringSync();

    view = File(
      'lib/home_v2/components/chat/'
      'inline_chat_view.dart',
    ).readAsStringSync();

    helper = File(
      'lib/services/stt_helper.dart',
    ).readAsStringSync();

    mobile = File(
      'lib/services/stt_helper_mobile.dart',
    ).readAsStringSync();

    web = File(
      'lib/services/stt_helper_web.dart',
    ).readAsStringSync();

    plist = File(
      'ios/Runner/Info.plist',
    ).readAsStringSync();

    manifest = File(
      'android/app/src/main/'
      'AndroidManifest.xml',
    ).readAsStringSync();

    owner = classBlock(
      home,
      '_HomeInlineChatState',
    );

    publicView = classBlock(
      view,
      'HomeInlineChatV2View',
    );

    composer = classBlock(
      view,
      '_InlineComposer',
    );
  });

  group(
    'MB-I.5.15-C-R2 — microfone da Home',
    () {
      test(
        'usa exclusivamente SttHelper',
        () {
          expect(
            home,
            contains(
              "import '../services/"
              "stt_helper.dart';",
            ),
          );

          expect(
            home,
            isNot(
              contains(
                'package:speech_to_text/',
              ),
            ),
          );

          expect(
            home,
            isNot(
              contains('SpeechToText('),
            ),
          );

          expect(
            owner,
            contains('SttHelper.start('),
          );

          expect(
            owner,
            contains('SttHelper.stop()'),
          );
        },
      );

      test(
        'owner permanece na Home',
        () {
          expect(
            owner,
            contains(
              'bool _sttListening = false',
            ),
          );

          expect(
            owner,
            contains(
              'int _sttSessionEpoch = 0',
            ),
          );

          expect(
            owner,
            contains(
              'void _toggleInlineStt()',
            ),
          );

          expect(
            owner,
            contains(
              'Future<void> '
              '_startInlineStt() async',
            ),
          );

          expect(
            owner,
            contains(
              'Future<void> '
              '_stopInlineStt() async',
            ),
          );

          expect(
            owner,
            contains("'es-ES'"),
          );

          expect(
            owner,
            contains("'pt-BR'"),
          );
        },
      );

      test(
        'resultado entra no controller real',
        () {
          expect(
            owner,
            contains(
              'final spoken =',
            ),
          );

          expect(
            owner,
            contains(
              'recognizedText.trim()',
            ),
          );

          expect(
            owner,
            contains(
              'final existing =',
            ),
          );

          expect(
            owner,
            contains(
              '_ctrl.text.trim()',
            ),
          );

          expect(
            owner,
            contains(
              'final combined =',
            ),
          );

          expect(
            owner,
            contains(
              r": '$existing $spoken'",
            ),
          );

          expect(
            owner,
            contains(
              '_ctrl.value = '
              'TextEditingValue(',
            ),
          );

          expect(
            owner,
            contains(
              'TextSelection.collapsed(',
            ),
          );

          expect(
            owner,
            contains(
              '_focus.requestFocus()',
            ),
          );
        },
      );

      test(
        'não envia automaticamente',
        () {
          final resultStart = owner.indexOf(
            'onResult: (recognizedText)',
          );

          final errorStart = owner.indexOf(
            'onError: (code)',
            resultStart,
          );

          expect(
            resultStart,
            greaterThanOrEqualTo(0),
          );

          expect(
            errorStart,
            greaterThan(resultStart),
          );

          final resultBlock = owner.substring(
            resultStart,
            errorStart,
          );

          expect(
            resultBlock,
            isNot(
              contains('_onSendPressed()'),
            ),
          );

          expect(
            resultBlock,
            isNot(
              contains('_send('),
            ),
          );
        },
      );

      test(
        'segundo toque interrompe',
        () {
          expect(
            owner,
            contains(
              'if (_sttListening)',
            ),
          );

          expect(
            owner,
            contains(
              '_stopInlineStt();',
            ),
          );

          expect(
            owner,
            contains(
              '++_sttSessionEpoch',
            ),
          );
        },
      );

      test(
        'dispose fecha a sessão',
        () {
          final disposeStart = owner.indexOf(
            'void dispose()',
          );

          expect(
            disposeStart,
            greaterThanOrEqualTo(0),
          );

          final disposeBlock = owner.substring(
            disposeStart,
          );

          expect(
            disposeBlock,
            contains(
              'if (_sttListening)',
            ),
          );

          expect(
            disposeBlock,
            contains(
              'SttHelper.stop()',
            ),
          );
        },
      );

      test(
        'view recebe somente projeção',
        () {
          expect(
            publicView,
            contains(
              'required this.onVoice',
            ),
          );

          expect(
            publicView,
            contains(
              'required this.sttListening',
            ),
          );

          expect(
            publicView,
            contains(
              'final VoidCallback onVoice',
            ),
          );

          expect(
            publicView,
            contains(
              'final bool sttListening',
            ),
          );

          expect(
            publicView,
            isNot(
              contains('SttHelper.'),
            ),
          );

          expect(
            publicView,
            isNot(
              contains('SpeechToText('),
            ),
          );
        },
      );

      test(
        'composer possui botão funcional',
        () {
          expect(
            composer,
            contains(
              'required this.onVoice',
            ),
          );

          expect(
            composer,
            contains(
              'required this.sttListening',
            ),
          );

          expect(
            composer,
            contains(
              'onTap: thinking '
              '? null : onVoice',
            ),
          );

          expect(
            composer,
            contains(
              'Icons.mic_none_rounded',
            ),
          );

          expect(
            composer,
            contains(
              'Icons.stop_rounded',
            ),
          );

          expect(
            composer,
            contains(
              "'Detener dictado'",
            ),
          );

          expect(
            composer,
            contains(
              "'Parar ditado'",
            ),
          );

          expect(
            composer,
            isNot(
              contains('SttHelper.'),
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
        'feedback de erro permanece bilíngue',
        () {
          for (final token in const [
            'permission_denied',
            'not_available',
            'no_speech',
            'network',
            'audio_session',
            'Permissão de microfone negada',
            'Permiso de micrófono denegado',
          ]) {
            expect(
              owner,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'infraestrutura não foi duplicada',
        () {
          expect(
            helper,
            contains(
              'class SttHelper',
            ),
          );

          expect(
            mobile,
            contains(
              'SpeechToText _stt = '
              'SpeechToText()',
            ),
          );

          expect(
            web,
            contains(
              'html.SpeechRecognition',
            ),
          );

          expect(
            RegExp(
              r'class\s+SttHelper\b',
            ).allMatches(home).length,
            0,
          );

          expect(
            RegExp(
              r'SpeechToText\s*\(',
            ).allMatches(home).length,
            0,
          );
        },
      );

      test(
        'permissões permanecem presentes',
        () {
          expect(
            plist,
            contains(
              'NSMicrophoneUsageDescription',
            ),
          );

          expect(
            plist,
            contains(
              'NSSpeechRecognition'
              'UsageDescription',
            ),
          );

          expect(
            manifest,
            contains(
              'android.permission.'
              'RECORD_AUDIO',
            ),
          );
        },
      );
    },
  );
}
