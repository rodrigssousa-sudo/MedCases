import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home V2 — composer oficial da IA', () {
    test(
      'usa altura 50, raio 24, borda 0.6 e botão 32 × 32',
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

        final composerStart = source.indexOf(
          'class _InlineComposer extends StatelessWidget',
        );

        expect(
          composerStart,
          greaterThanOrEqualTo(0),
          reason: 'O composer real deve continuar existindo.',
        );

        final composer = source.substring(composerStart);

        expect(
          composer,
          contains('return Material('),
          reason: 'O composer fiel deve possuir superfície Material própria.',
        );

        expect(
          composer,
          contains('color: palette.surfaceSoft'),
          reason: 'A superfície do composer deve usar a paleta compartilhada.',
        );

        expect(
          composer,
          contains('borderRadius: BorderRadius.circular(24)'),
          reason: 'O composer fiel deve usar raio 24.',
        );

        expect(
          composer,
          contains('minHeight: 50'),
          reason: 'O composer deve preservar altura mínima de 50 px.',
        );

        expect(
          composer,
          contains(
            'padding: const EdgeInsets.fromLTRB(11, 3, 3, 3)',
          ),
          reason: 'O composer deve usar o padding exato do preview.',
        );

        expect(
          composer,
          matches(
            RegExp(
              r'border:\s*Border\.all\(\s*'
              r'color:\s*palette\.border,\s*'
              r'width:\s*0\.6,\s*'
              r'\)',
              dotAll: true,
            ),
          ),
          reason: 'A borda do composer deve possuir largura 0.6.',
        );

        expect(
          composer,
          contains('width: 32'),
          reason: 'O botão de envio deve possuir largura 32.',
        );

        expect(
          composer,
          contains('height: 32'),
          reason: 'O botão de envio deve possuir altura 32.',
        );

        expect(
          composer,
          contains('size: 19'),
          reason: 'O ícone de envio deve possuir tamanho 19.',
        );

        expect(
          composer,
          contains('customBorder: const CircleBorder()'),
          reason: 'O botão de envio deve permanecer circular.',
        );

        for (final inputBorder in const [
          'border: InputBorder.none',
          'enabledBorder: InputBorder.none',
          'focusedBorder: InputBorder.none',
          'disabledBorder: InputBorder.none',
        ]) {
          expect(
            composer,
            contains(inputBorder),
            reason: 'Borda interna do TextField ausente: $inputBorder',
          );
        }

        for (final preservedContract in const [
          'controller: controller',
          'focusNode: focusNode',
          'enabled: !thinking',
          'minLines: 1',
          'maxLines: 6',
          'textCapitalization: TextCapitalization.sentences',
          'textInputAction: TextInputAction.send',
          'onSubmitted: (_)',
          'if (!thinking)',
          'onSend();',
          'onTap: thinking ? null : onSend',
          'Icons.arrow_upward_rounded',
          'final HomeV2Palette palette',
          'final TextEditingController controller',
          'final FocusNode focusNode',
          'final bool thinking',
          'final VoidCallback onSend',
        ]) {
          expect(
            composer,
            contains(preservedContract),
            reason: 'Contrato funcional ausente: $preservedContract',
          );
        }
      },
    );
  });
}
