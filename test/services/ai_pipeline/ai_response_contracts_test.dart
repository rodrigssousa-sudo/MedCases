import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';

void main() {
  group('AiRequestContract', () {
    test('preserva um snapshot imutável do histórico e dos metadados', () {
      final history = <AiHistoryEntry>[
        const AiHistoryEntry(
          role: 'user',
          text: 'Paciente com dispneia.',
        ),
      ];

      final metadata = <String, Object?>{
        'source': 'contract_test',
      };

      final request = AiRequestContract(
        requestId: 'request-1',
        sessionId: 'session-1',
        input: 'Avaliar dispneia.',
        mode: AiRequestMode.plantao,
        locale: AiRequestLocale.pt,
        sourceSurface: AiSourceSurface.aiScreen,
        history: history,
        metadata: metadata,
      );

      history.add(
        const AiHistoryEntry(
          role: 'ai',
          text: 'Mutação externa.',
        ),
      );
      metadata['source'] = 'mutated';

      expect(request.history, hasLength(1));
      expect(request.metadata['source'], 'contract_test');
      expect(
        () => request.history.add(
          const AiHistoryEntry(role: 'user', text: 'bloqueado'),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => request.metadata['new'] = true,
        throwsUnsupportedError,
      );
    });

    test('deriva longResponse exclusivamente do modo', () {
      final plantao = AiRequestContract(
        requestId: 'request-plantao',
        sessionId: 'session-plantao',
        input: 'Conduta imediata.',
        mode: AiRequestMode.plantao,
        locale: AiRequestLocale.pt,
        sourceSurface: AiSourceSurface.aiScreen,
      );

      final estudo = AiRequestContract(
        requestId: 'request-estudo',
        sessionId: 'session-estudo',
        input: 'Explique a fisiopatologia.',
        mode: AiRequestMode.estudo,
        locale: AiRequestLocale.es,
        sourceSurface: AiSourceSurface.home,
      );

      expect(plantao.longResponse, isFalse);
      expect(estudo.longResponse, isTrue);
    });
  });

  group('AiResponseResult', () {
    test('preserva referências em coleção imutável', () {
      final references = <Object?>[
        'referencia-1',
      ];

      final result = AiResponseResult(
        requestId: 'request-1',
        sessionId: 'session-1',
        finalText: 'Resposta final.',
        displayText: 'Resposta final.',
        terminalCause: AiTerminalCause.completed,
        persistenceStatus: AiPersistenceStatus.persisted,
        references: references,
      );

      references.add('referencia-2');

      expect(result.references, <Object?>['referencia-1']);
      expect(
        () => result.references.add('bloqueado'),
        throwsUnsupportedError,
      );
    });
  });

  group('AiResponsePipeline', () {
    test('emite sequência tipada sem conhecer widgets ou providers', () async {
      final request = AiRequestContract(
        requestId: 'request-typed',
        sessionId: 'session-typed',
        input: 'Avaliar paciente.',
        mode: AiRequestMode.plantao,
        locale: AiRequestLocale.pt,
        sourceSurface: AiSourceSurface.aiScreen,
      );

      final result = AiResponseResult(
        requestId: request.requestId,
        sessionId: request.sessionId,
        finalText: 'Conduta final.',
        displayText: 'Conduta final.',
        provider: 'legacy',
        terminalCause: AiTerminalCause.completed,
        persistenceStatus: AiPersistenceStatus.notAttempted,
      );

      final pipeline = DelegatingAiResponsePipeline(
        (currentRequest) async* {
          yield AiResponseStarted(
            requestId: currentRequest.requestId,
            sessionId: currentRequest.sessionId,
            provider: 'legacy',
          );

          yield AiResponseDelta(
            requestId: currentRequest.requestId,
            sessionId: currentRequest.sessionId,
            delta: 'Conduta',
            accumulatedText: 'Conduta',
            provider: 'legacy',
          );

          yield AiResponseTerminal(
            requestId: currentRequest.requestId,
            sessionId: currentRequest.sessionId,
            result: result,
          );
        },
      );

      final events = await pipeline.execute(request).toList();

      expect(events, hasLength(3));
      expect(events[0], isA<AiResponseStarted>());
      expect(events[1], isA<AiResponseDelta>());
      expect(events[2], isA<AiResponseTerminal>());

      for (final event in events) {
        expect(event.requestId, request.requestId);
        expect(event.sessionId, request.sessionId);
      }

      final terminal = events.last as AiResponseTerminal;
      expect(terminal.result.finalText, 'Conduta final.');
      expect(
        terminal.result.persistenceStatus,
        AiPersistenceStatus.notAttempted,
      );
    });
  });
}
