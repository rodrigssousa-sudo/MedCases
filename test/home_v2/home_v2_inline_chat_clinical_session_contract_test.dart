import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home V2 — hierarquia clínica e sessão efêmera', () {
    test('renderiza pergunta, resposta formatada e ações finais bilíngues', () {
      final source = File(
        'lib/home_v2/components/chat/inline_chat_view.dart',
      ).readAsStringSync();

      for (final contract in const [
        "isEs ? 'PREGUNTA' : 'PERGUNTA'",
        "isEs ? 'GENERANDO RESPUESTA' : 'GERANDO RESPOSTA'",
        "isEs ? 'RESPUESTA COMPLETADA' : 'RESPOSTA CONCLUÍDA'",
        'class _InlineQuestion extends StatelessWidget',
        'class _InlineAnswer extends StatelessWidget',
        'width: 3',
        'color: _homeAccent(palette)',
        'MarkdownBody(',
        'selectable: false',
        'blockSpacing: 12',
        'listIndent: 20',
        "label: 'Copiar'",
        "'Continuar en IA'",
        "'Continuar na IA'",
        'onCopyAnswer(text)',
        'onTap: onContinueInAi',
      ]) {
        expect(
          source,
          contains(contract),
          reason: 'Contrato visual ausente: $contract',
        );
      }

      expect(
        source,
        isNot(contains('height: expanded ? 430 : 220')),
        reason: 'A conversa não pode continuar presa a uma altura fixa.',
      );

      expect(
        source,
        isNot(contains('physics: const BouncingScrollPhysics()')),
        reason: 'A IA da Home deve crescer no scroll externo da Home.',
      );
    });

    test('reduz a cápsula da identidade visual', () {
      final source = File(
        'lib/home_v2/components/chat/inline_chat_view.dart',
      ).readAsStringSync();

      for (final contract in const [
        'padding: const EdgeInsets.fromLTRB(10, 6, 11, 6)',
        'size: 16',
        'fontSize: 11.8',
        'letterSpacing: 0.65',
        'width: 32',
        'height: 32',
      ]) {
        expect(source, contains(contract));
      }

      expect(
        source,
        isNot(contains('fontSize: 14,\n'
            '                      fontWeight: FontWeight.w800,\n'
            '                      letterSpacing: 0.8')),
      );
    });

    test('Home não restaura automaticamente a última consulta', () {
      final source = File(
        'lib/screens/home_screen.dart',
      ).readAsStringSync();

      final stateStart = source.indexOf(
        'class _HomeInlineChatState extends State<_HomeInlineChat>',
      );

      final stateEnd = source.indexOf(
        '// STREAM SANITIZER',
        stateStart,
      );

      expect(stateStart, greaterThanOrEqualTo(0));
      expect(stateEnd, greaterThan(stateStart));

      final state = source.substring(stateStart, stateEnd);

      final initStart = state.indexOf('void initState()');
      final didUpdateStart = state.indexOf('void didUpdateWidget(');

      expect(initStart, greaterThanOrEqualTo(0));
      expect(didUpdateStart, greaterThan(initStart));

      final initBlock = state.substring(initStart, didUpdateStart);

      expect(
        initBlock,
        isNot(contains('_loadChatHistory();')),
        reason: 'A Home deve nascer vazia.',
      );

      final didUpdateEnd = state.indexOf(
        '@override\n  void dispose()',
        didUpdateStart,
      );

      expect(didUpdateEnd, greaterThan(didUpdateStart));

      final didUpdateBlock = state.substring(
        didUpdateStart,
        didUpdateEnd,
      );

      expect(
        didUpdateBlock,
        isNot(contains('_loadChatHistory();')),
        reason: 'Rebuilds não podem restaurar a última sessão.',
      );

      for (final preservedContract in const [
        'Future<void> _homePersistTurn()',
        'await prefs.setString(histKey, jsonEncode(histList))',
        'await prefs.setString(histKey, jsonEncode(histList))',
        'AiScreen.openHistoryCallback.value?.call();',
        'void _copyInlineAnswer(String text)',
        'Clipboard.setData(',
        'void _continueInlineInAi()',
        '_goToAiTab(null, true);',
        'onCopyAnswer: _copyInlineAnswer',
        'onContinueInAi: _continueInlineInAi',
      ]) {
        expect(
          source,
          contains(preservedContract),
          reason: 'Contrato funcional preservado ausente: $preservedContract',
        );
      }
    });

    test('revela apenas a resposta final pelo dreno de grafemas', () {
      final source = File(
        'lib/screens/home_screen.dart',
      ).readAsStringSync();

      for (final contract in const [
        'StreamingTextDrain.take(_streamingPending)',
        'const Duration(milliseconds: 24)',
        'onChunk: (_) {',
        '_queueInlineStreamingFinal(cleanFin);',
        "String _streamingRaw = '';",
        '_streamingRaw += drained.visible;',
        ': _homeCleanPartialMd(_streamingRaw);',
      ]) {
        expect(
          source,
          contains(contract),
          reason: 'Contrato final-only ausente: $contract',
        );
      }

      expect(
        source,
        isNot(
          contains('_queueInlineStreamingSnapshot('),
        ),
      );
    });
  });
}
