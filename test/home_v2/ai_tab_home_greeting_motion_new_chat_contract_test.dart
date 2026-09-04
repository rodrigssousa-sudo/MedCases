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

  fail('Classe sem fechamento.');
}

String region(
  String source,
  String startMarker,
  String endMarker,
) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start);

  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));

  return source.substring(start, end);
}

void main() {
  late String ai;
  late String mainSource;
  late String greeting;
  late String newChat;

  setUpAll(() {
    ai = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    mainSource = File(
      'lib/main.dart',
    ).readAsStringSync();

    greeting = classBlock(
      ai,
      'class _AiHomeGreeting '
      'extends StatelessWidget',
    );

    newChat = region(
      mainSource,
      '// 3. NOVO CHAT',
      '// 4. MENU M+',
    );
  });

  group(
    'AI-VIS-B.2.5-R1 — saudação animada e Novo branco',
    () {
      test(
        'conversa é derivada apenas de mensagem real do usuário',
        () {
          expect(
            ai,
            contains(
              'final bool hasConversation =',
            ),
          );

          expect(
            ai,
            contains(
              "_messages.any((m) => "
              "m.role == 'user')",
            ),
          );
        },
      );

      test(
        'estado visual chega à saudação',
        () {
          for (final token in const [
            'compact: hasConversation',
            'hasConversation && '
                '_hasNewMessageAfterRestore',
            'required this.compact',
            'required this.animate',
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
        'possui transição suave para o topo esquerdo',
        () {
          for (final token in const [
            'AnimatedAlign(',
            'AnimatedSize(',
            'AnimatedSwitcher(',
            'Duration(milliseconds: 320)',
            'Curves.easeOutCubic',
            'Alignment.topLeft',
            'Alignment.center',
            "'ai-greeting-opening'",
            "'ai-greeting-compact'",
          ]) {
            expect(
              greeting,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'histórico recebe estado final sem animação artificial',
        () {
          expect(
            greeting,
            contains(
              'final motionDuration = animate',
            ),
          );

          expect(
            greeting,
            contains(': Duration.zero'),
          );

          expect(
            ai,
            contains(
              'animate:\n'
              '                          '
              'hasConversation && '
              '_hasNewMessageAfterRestore',
            ),
          );
        },
      );

      test(
        'estado vazio preserva saudação homologada',
        () {
          for (final token in const [
            'fontSize: 22',
            'fontWeight: FontWeight.w700',
            'textAlign: TextAlign.center',
            'CrossAxisAlignment.center',
            'maxWidth: 560',
            "'Describe el caso o la duda clínica.'",
            "'Descreva o caso ou a dúvida clínica.'",
          ]) {
            expect(
              greeting,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'conversa ativa espelha a Home',
        () {
          for (final token in const [
            'fontSize: 14',
            'fontWeight: FontWeight.w800',
            'textAlign: TextAlign.left',
            'CrossAxisAlignment.start',
            'EdgeInsets.fromLTRB(',
            '12,',
            '8,',
            '16,',
            '18,',
          ]) {
            expect(
              greeting,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'novo chat continua retornando à saudação central',
        () {
          for (final token in const [
            'void _clearChat()',
            'void _startNewChat()',
            '..clear()',
            "..add(_ChatMsg(role: 'ai', "
                "text: _buildGreeting"
                "(p.userName, p.lang)))",
            '_hasNewMessageAfterRestore = false',
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
        'Novo usa branco e cinza oficial',
        () {
          for (final token in const [
            'onTap: widget.onFabDoubleTap',
            'Icons.add_rounded',
            'size: 20',
            '? Colors.white',
            ': const Color(0xFF4B5563)',
            "widget.lang == 'es' "
                "? 'Nuevo' : 'Novo'",
          ]) {
            expect(
              newChat,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'Novo não conserva qualquer ciano',
        () {
          for (final forbidden in const [
            'LinearGradient(',
            '0xFF008CA4',
            '0xFF005566',
            '0xFF00E5FF',
            '_medcasesGreen',
            'boxShadow:',
            'Border.all(',
          ]) {
            expect(
              newChat,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );

      test(
        'não cria motor funcional paralelo',
        () {
          for (final forbidden in const [
            'ChangeNotifier',
            'StreamController',
            'FirebaseFirestore',
            'SharedPreferences',
            'SpeechToText',
            'TextEditingController()',
            'Navigator.',
            'Scaffold(',
          ]) {
            expect(
              greeting,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );
    },
  );
}
