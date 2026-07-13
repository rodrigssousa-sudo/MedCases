// ══════════════════════════════════════════════════════════════════════════════
// test/ai_stream/ai_event_test.dart
// BUILD 462B-REDIRECIONADA — AiEvent Anti-Frankenstein contract tests
//
// Valida:
//   • Todos os eventos carregam requestId + attempt + timestamp
//   • AiTextDelta carrega delta + sequence
//   • AiProviderSwitched existe e tem fromProvider + toProvider + reason
//   • AiStreamReset existe e tem reason
//   • AiFailed existe e tem code + message + retryable + partialText
//   • hasSignificantPartial funciona corretamente (threshold = 80)
//   • sanitizeAndCheck continua sendo barreira (não testado aqui — em app_provider_test)
//   • factory .now() preenche timestamp automaticamente
//   • Sealed class — switch exaustivo compila
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_stream/ai_event.dart';

void main() {
  group('AiEvent — base contract', () {
    test('AiStarted carrega requestId + attempt + timestamp + model + provider', () {
      final event = AiStarted.now(
        requestId: 'req_123',
        attempt:   1,
        model:     'gemini-2.5-flash',
        provider:  'gemini_free',
      );
      expect(event.requestId, equals('req_123'));
      expect(event.attempt,   equals(1));
      expect(event.timestamp,  isNotEmpty);
      expect(event.model,      equals('gemini-2.5-flash'));
      expect(event.provider,   equals('gemini_free'));
      expect(event.startedAtMs, greaterThan(0));
    });

    test('AiTextDelta carrega delta bruto + sequence (não acumulado)', () {
      final e1 = AiTextDelta.now(
        requestId: 'req_123', attempt: 2, delta: 'Iniciar', sequence: 1,
      );
      final e2 = AiTextDelta.now(
        requestId: 'req_123', attempt: 2, delta: ' norepinefrina', sequence: 2,
      );
      expect(e1.delta, equals('Iniciar'));
      expect(e2.delta, equals(' norepinefrina'));
      // Delta não é acumulado — cada um traz apenas o fragmento novo
      expect(e1.delta + e2.delta, equals('Iniciar norepinefrina'));
      expect(e1.sequence, equals(1));
      expect(e2.sequence, equals(2));
    });

    test('AiTextDelta GPT attempt=2 sequence começa em 1', () {
      final delta = AiTextDelta.now(
        requestId: 'req_gpt_test', attempt: 2, delta: 'X', sequence: 1,
      );
      expect(delta.attempt,  equals(2));
      expect(delta.sequence, equals(1));
    });

    test('AiCompleted carrega fullText + usedProvider + durationMs', () {
      final event = AiCompleted.now(
        requestId:   'req_abc',
        attempt:     2,
        fullText:    'Texto médico completo aqui',
        usedProvider: 'gpt_4o_mini',
        durationMs:  1234,
        inputTokensApprox:  120,
        outputTokensApprox: 45,
      );
      expect(event.fullText,    equals('Texto médico completo aqui'));
      expect(event.usedProvider, equals('gpt_4o_mini'));
      expect(event.durationMs,  equals(1234));
      expect(event.attempt,     equals(2));
    });
  });

  group('AiProviderSwitched — Anti-Frankenstein', () {
    test('carrega fromProvider + toProvider + reason + requestId + attempt + timestamp', () {
      final event = AiProviderSwitched.now(
        requestId:    'req_456',
        attempt:      2,
        fromProvider: 'gemini_free',
        toProvider:   'gpt_4o_mini',
        reason:       'quota',
      );
      expect(event.requestId,    equals('req_456'));
      expect(event.attempt,      equals(2));
      expect(event.timestamp,    isNotEmpty);
      expect(event.fromProvider, equals('gemini_free'));
      expect(event.toProvider,   equals('gpt_4o_mini'));
      expect(event.reason,       equals('quota'));
    });

    test('é uma AiEvent (sealed class member)', () {
      final AiEvent event = AiProviderSwitched.now(
        requestId: 'r', attempt: 2,
        fromProvider: 'a', toProvider: 'b', reason: 'c',
      );
      expect(event, isA<AiProviderSwitched>());
    });
  });

  group('AiStreamReset — Anti-Frankenstein', () {
    test('carrega reason + requestId + attempt + timestamp', () {
      final event = AiStreamReset.now(
        requestId: 'req_789',
        attempt:   2,
        reason:    'provider_switch_no_partial',
      );
      expect(event.requestId, equals('req_789'));
      expect(event.attempt,   equals(2));
      expect(event.timestamp,  isNotEmpty);
      expect(event.reason,     equals('provider_switch_no_partial'));
    });

    test('é uma AiEvent (sealed class member)', () {
      final AiEvent event = AiStreamReset.now(
        requestId: 'r', attempt: 2, reason: 'test',
      );
      expect(event, isA<AiStreamReset>());
    });
  });

  group('AiFailed — falha clínica', () {
    test('carrega code + message + retryable + partialText', () {
      final event = AiFailed.now(
        requestId:   'req_fail',
        attempt:     2,
        code:        'eof_no_transport_done',
        message:     'Stream encerrou sem transport_done',
        retryable:   false,
        partialText: 'Texto parcial acumulado antes da falha...',
      );
      expect(event.code,       equals('eof_no_transport_done'));
      expect(event.message,    isNotEmpty);
      expect(event.retryable,  isFalse);
      expect(event.partialText, isNotNull);
    });

    test('sem partialText quando nenhum texto foi recebido', () {
      final event = AiFailed.now(
        requestId: 'req_fail2',
        attempt:   2,
        code:      'gpt_sse_connect_error',
        message:   'Connection refused',
        retryable: true,
      );
      expect(event.partialText, isNull);
      expect(event.hasSignificantPartial, isFalse);
    });

    test('hasSignificantPartial false quando parcial < 80 chars', () {
      const shortText = 'Curto'; // 5 chars
      final event = AiFailed.now(
        requestId: 'r', attempt: 2, code: 'x', message: 'm',
        retryable: false, partialText: shortText,
      );
      expect(event.hasSignificantPartial, isFalse);
    });

    test('hasSignificantPartial true quando parcial >= 80 chars', () {
      final longText = 'A' * 80; // exatamente 80 chars = threshold
      final event = AiFailed.now(
        requestId: 'r', attempt: 2, code: 'x', message: 'm',
        retryable: false, partialText: longText,
      );
      expect(event.hasSignificantPartial, isTrue);
    });

    test('kSignificantPartialThreshold = 80', () {
      expect(AiFailed.kSignificantPartialThreshold, equals(80));
    });

    test('retryable=true para erros de rede (timeout, network)', () {
      final event = AiFailed.now(
        requestId: 'r', attempt: 2,
        code: 'timeout', message: 'timeout', retryable: true,
      );
      expect(event.retryable, isTrue);
    });

    test('retryable=false para erros de autenticação', () {
      final event = AiFailed.now(
        requestId: 'r', attempt: 2,
        code: 'unauthenticated', message: 'auth', retryable: false,
      );
      expect(event.retryable, isFalse);
    });

    test('é uma AiEvent (sealed class member)', () {
      final AiEvent event = AiFailed.now(
        requestId: 'r', attempt: 2, code: 'x', message: 'm', retryable: false,
      );
      expect(event, isA<AiFailed>());
    });
  });

  group('Sealed class — switch exaustivo', () {
    test('switch cobre todos os cases sem default necessário', () {
      final events = <AiEvent>[
        AiStarted.now(requestId: 'r', attempt: 1, model: 'm', provider: 'p'),
        AiTextDelta.now(requestId: 'r', attempt: 1, delta: 'x', sequence: 0),
        AiToolResult(requestId: 'r', attempt: 1, timestamp: '', toolName: 't', data: const {}),
        AiSources(requestId: 'r', attempt: 1, timestamp: '', sources: const []),
        AiCompleted.now(requestId: 'r', attempt: 1, fullText: '', usedProvider: ''),
        AiFailed.now(requestId: 'r', attempt: 1, code: 'e', message: 'm', retryable: false),
        AiProviderSwitched.now(requestId: 'r', attempt: 2, fromProvider: 'a', toProvider: 'b', reason: 'c'),
        AiStreamReset.now(requestId: 'r', attempt: 2, reason: 'd'),
      ];

      // Verificar que o switch exaustivo compila (nenhum default necessário)
      int handled = 0;
      for (final event in events) {
        switch (event) {
          case AiStarted():          handled++;
          case AiTextDelta():        handled++;
          case AiToolResult():       handled++;
          case AiSources():          handled++;
          case AiCompleted():        handled++;
          case AiFailed():           handled++;
          case AiProviderSwitched(): handled++;
          case AiStreamReset():      handled++;
        }
      }
      expect(handled, equals(events.length));
    });
  });

  group('Identidade de fragmento', () {
    test('requestId + attempt + sequence identificam unicamente um fragmento', () {
      const reqId = 'req_unique';
      final fragments = [
        AiTextDelta.now(requestId: reqId, attempt: 2, delta: 'A', sequence: 1),
        AiTextDelta.now(requestId: reqId, attempt: 2, delta: 'B', sequence: 2),
        AiTextDelta.now(requestId: reqId, attempt: 2, delta: 'C', sequence: 3),
      ];

      // Todos têm o mesmo requestId e attempt
      for (final f in fragments) {
        expect(f.requestId, equals(reqId));
        expect(f.attempt,   equals(2));
      }

      // Sequences são únicas e crescentes
      expect(fragments[0].sequence, equals(1));
      expect(fragments[1].sequence, equals(2));
      expect(fragments[2].sequence, equals(3));

      // Identidade única por tripla
      final ids = fragments
          .map((f) => '${f.requestId}|${f.attempt}|${f.sequence}')
          .toSet();
      expect(ids.length, equals(3));
    });
  });

  group('Factory .now() timestamp', () {
    test('nowIso retorna string ISO-8601 UTC válida', () {
      final ts = AiEvent.nowIso();
      expect(ts, matches(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'));
      expect(DateTime.tryParse(ts), isNotNull);
    });
  });
}
