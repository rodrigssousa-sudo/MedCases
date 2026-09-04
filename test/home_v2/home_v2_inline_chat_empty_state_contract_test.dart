import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home V2 — estado vazio oficial da IA', () {
    test(
      'centraliza saudação e move a conversa para o topo após o envio',
      () {
        final root = Directory.current;

        final chatFile = File(
          '${root.path}/lib/home_v2/components/chat/inline_chat_view.dart',
        );

        expect(
          chatFile.existsSync(),
          isTrue,
          reason: 'A view canônica da IA deve existir.',
        );

        final source = chatFile.readAsStringSync();

        expect(
          source,
          contains('class _InlineEmptyGreeting extends StatelessWidget'),
          reason: 'A saudação deve possuir widget visual próprio.',
        );

        expect(
          source,
          contains('if (hasConversation)'),
          reason: 'A conversa deve continuar governada por hasConversation.',
        );

        expect(
          source,
          contains('_InlineEmptyGreeting('),
          reason: 'O estado vazio deve montar a saudação oficial.',
        );

        expect(
          source,
          contains('child: Center('),
          reason: 'A saudação deve ficar centralizada na área vazia.',
        );

        for (final dynamicGreetingContract in const [
          'class _InlineGreetingLine extends StatelessWidget',
          'DateTime.now().hour',
          "return isEs ? 'Buena madrugada' : 'Boa madrugada'",
          "return isEs ? 'Buen día' : 'Bom dia'",
          "return isEs ? 'Buenas tardes' : 'Boa tarde'",
          "return isEs ? 'Buenas noches' : 'Boa noite'",
          'return RichText(',
          'text: greeting',
          r"text: ', $normalizedName'",
          'color: _homeAccent(palette)',
          'color: palette.textPrimary',
          'required this.userName',
          'final String userName',
        ]) {
          expect(
            source,
            contains(dynamicGreetingContract),
            reason: 'Contrato da saudação dinâmica ausente: '
                '$dynamicGreetingContract',
          );
        }

        expect(
          source,
          contains('fontSize: 22'),
          reason: 'A saudação inicial personalizada deve usar 22 px.',
        );

        expect(
          source,
          matches(
            RegExp(
              r"isEs\s*\?\s*'Describe el caso o la duda clínica\.'\s*"
              r":\s*'Descreva o caso ou a dúvida clínica\.'",
              dotAll: true,
            ),
          ),
          reason: 'O novo subtítulo clínico bilíngue deve existir.',
        );

        expect(
          source,
          contains('crossAxisAlignment: CrossAxisAlignment.center'),
          reason: 'O conteúdo da saudação deve ficar centralizado.',
        );

        expect(
          source,
          contains('textAlign: TextAlign.center'),
          reason: 'Os textos da saudação devem ficar centralizados.',
        );

        expect(
          source,
          contains('textAlign: TextAlign.left'),
          reason:
              'A saudação da conversa deve ficar alinhada à esquerda após o envio.',
        );

        for (final preservedContract in const [
          'final hasConversation =',
          'visibleMessages.isNotEmpty || streaming.trim().isNotEmpty || thinking',
          'for (var index = 0; index < visibleMessages.length; index++)',
          'MarkdownBody(',
          '_InlineConversationGreeting(',
          'if (thinking && streaming.trim().isNotEmpty)',
          'if (thinking && streaming.trim().isEmpty)',
          '_InlineComposer(',
          'controller: controller',
          'focusNode: focusNode',
          'thinking: thinking',
          'onSend: onSend',
          'onHistory: onHistory',
          'onNewChat: onNewChat',
          'onToggleExpanded: onToggleExpanded',
        ]) {
          expect(
            source,
            contains(preservedContract),
            reason: 'Contrato estrutural ausente: $preservedContract',
          );
        }
      },
    );
  });
}
