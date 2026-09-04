import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourcePath = 'lib/home_v2/components/chat/inline_chat.dart';

  late String source;

  setUpAll(() {
    final file = File(sourcePath);

    expect(
      file.existsSync(),
      isTrue,
      reason: 'O adaptador oficial do chat da Home V2 deve existir.',
    );

    source = file.readAsStringSync();
  });

  group('InlineChat da Home V2', () {
    test('permanece um adaptador público e sem estado próprio', () {
      expect(
        source,
        contains('class InlineChat extends StatelessWidget'),
      );

      expect(
        source,
        isNot(contains('class InlineChat extends StatefulWidget')),
      );
    });

    test('delega exclusivamente para o HomeInlineChat real', () {
      expect(
        source,
        contains(
          "import '../../../screens/home_screen.dart' show HomeInlineChat;",
        ),
      );

      expect(
        source,
        contains('return HomeInlineChat('),
      );

      expect(
        source,
        contains('onNavigateToAi: onNavigateToAi'),
      );
    });

    test('preserva o contrato de tema, idioma e navegação', () {
      expect(source, contains('required this.dark'));
      expect(source, contains('required this.isEs'));
      expect(source, contains('required this.onNavigateToAi'));

      expect(source, contains('final bool dark;'));
      expect(source, contains('final bool isEs;'));
      expect(
        source,
        contains('final ValueChanged<int> onNavigateToAi;'),
      );
    });

    test('não contém motor, streaming ou persistência paralelos', () {
      const forbiddenTokens = <String>[
        'ChatController',
        'ChatStream',
        'ChatStorage',
        'fakeStream',
        'streamEngine',
        'SharedPreferences',
        'sendAiMessage',
        'Resposta temporária da Home V2',
      ];

      for (final token in forbiddenTokens) {
        expect(
          source,
          isNot(contains(token)),
          reason: 'O adaptador não pode conter ou importar "$token".',
        );
      }
    });

    test('não importa os antigos componentes visuais provisórios', () {
      const forbiddenImports = <String>[
        "import 'chat_controller.dart';",
        "import 'chat_header.dart';",
        "import 'chat_input.dart';",
        "import 'chat_messages.dart';",
        "import 'chat_storage.dart';",
        "import 'chat_stream.dart';",
      ];

      for (final import in forbiddenImports) {
        expect(
          source,
          isNot(contains(import)),
          reason: 'Import provisório não permitido: $import',
        );
      }
    });
  });
}
