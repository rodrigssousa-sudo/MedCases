import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String region(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start);

  expect(start, greaterThanOrEqualTo(0), reason: startMarker);
  expect(end, greaterThan(start), reason: endMarker);

  return source.substring(start, end);
}

void main() {
  late String ai;
  late String home;
  late String guardia;

  setUpAll(() {
    ai = File('lib/screens/ai_screen.dart').readAsStringSync();
    home = File(
      'lib/home_v2/components/chat/inline_chat_view.dart',
    ).readAsStringSync();
    guardia = File(
      'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
    ).readAsStringSync();
  });

  group('IA response identity + HARD STOP source freeze', () {
    test('identidade RESPOSTA pertence à aba IA', () {
      final thinking = region(
        ai,
        'if (_thinking && i == _messages.length)',
        'final msg = _messages[i];',
      );
      final response = region(
        ai,
        'Widget bubbleContent = RepaintBoundary(',
        '// ── Build 192 / BUILD 232:',
      );
      final header = region(
        ai,
        'class _AiResponseIdentityHeader extends StatelessWidget',
        'class _AiHomeGreeting extends StatelessWidget',
      );

      expect(thinking, isNot(contains('_AiResponseIdentityHeader(')));
      expect(response, contains('_AiResponseIdentityHeader('));
      expect(header, contains('Icons.psychology_alt_rounded'));
      for (final token in const [
        'final title = isStreaming',
        "isEs ? 'GENERANDO RESPUESTA' : 'GERANDO RESPOSTA'",
        "isEs ? 'RESPUESTA COMPLETADA' : 'RESPOSTA CONCLUÍDA'",
        'final accent = palette.accent;',
        'color: accent',
      ]) {
        expect(header, contains(token), reason: token);
      }
      expect(header, contains('color: accent'));
    });

    test('Home voltou ao contrato anterior', () {
      expect(home, isNot(contains('showResponseIdentity')));
      expect(home, isNot(contains('_InlineAiResponseIdentity')));
      expect(
        home,
        contains("isEs ? 'GENERANDO RESPUESTA' : 'GERANDO RESPOSTA'"),
      );
      expect(home, contains('LinearProgressIndicator('));
    });

    test('Plantão congela o notifier visual ao iniciar HARD STOP', () {
      for (final token in const [
        'String? guardiaFrozenVisibleText;',
        'GuardiaStreamingPresentation.stableBeforeHardStop(',
        'final previousVisibleText =',
        'final hardStopBoundaryDetected =',
        'cleanedChunk.startsWith(previousVisibleText)',
        'final monotonicFrozenText = canPreservePreviousVisible',
        'guardiaFrozenVisibleText = monotonicFrozenText;',
        'visibleStreamingChunk = monotonicFrozenText;',
        '_streamingTextNotifier?.value != visibleStreamingChunk',
        '_streamingTextNotifier?.value = visibleStreamingChunk;',
        '[GUARDIA_STREAM_FREEZE] hardStopTailHidden=true',
        "'monotonic=true '",
      ]) {
        expect(ai, contains(token), reason: token);
      }
    });

    test('buffer bruto continua acumulando texto clínico integral', () {
      expect(
        ai,
        contains("_messages.add(_ChatMsg(role: 'ai', text: cleanedChunk));"),
      );
      expect(ai, contains('text: cleanedChunk,'));
    });

    test(
      'renderer mantém seção de segurança final-only com label localizado',
      () {
        expect(
          guardia,
          contains('GuardiaStreamingPresentation.stableBeforeHardStop('),
        );
        expect(
          guardia,
          contains("'Red flags/escalamiento'"),
      );
      expect(
        guardia,
        contains("'Red flags/escalonamento'"),
        );
        expect(guardia, isNot(contains("title: 'HARD STOP'")));
        expect(guardia, contains('rawText: stablePresentationText'));
      },
    );
  });
}
