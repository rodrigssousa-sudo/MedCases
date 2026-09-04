import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_response_result.dart';
import 'package:medcases/services/ai_pipeline/ai_terminal_coordinator.dart';

AiResponseResult buildResult({
  String requestId = 'request-terminal',
  String sessionId = 'session-terminal',
  AiTerminalCause cause = AiTerminalCause.completed,
  bool isPartial = false,
  bool isFallback = false,
  String text = 'Resposta final.',
}) {
  return AiResponseResult(
    requestId: requestId,
    sessionId: sessionId,
    finalText: text,
    displayText: text,
    terminalCause: cause,
    isPartial: isPartial,
    isFallback: isFallback,
    persistenceStatus: AiPersistenceStatus.notAttempted,
  );
}

void main() {
  group('AiTerminalCoordinator', () {
    test(
      'aceita o primeiro terminal e rejeita concorrentes',
      () {
        final coordinator = AiTerminalCoordinator(
          requestId: 'request-terminal',
          sessionId: 'session-terminal',
        );

        final completedOutcome = coordinator.tryCommit(
          result: buildResult(
            cause: AiTerminalCause.completed,
          ),
          source: 'stream_done',
        );

        final errorOutcome = coordinator.tryCommit(
          result: buildResult(
            cause: AiTerminalCause.error,
            text: 'Erro tardio.',
          ),
          source: 'stream_error',
        );

        final timeoutOutcome = coordinator.tryCommit(
          result: buildResult(
            cause: AiTerminalCause.timeout,
            text: 'Timeout tardio.',
          ),
          source: 'global_timeout',
        );

        expect(
          completedOutcome,
          AiTerminalCommitOutcome.accepted,
        );

        expect(
          errorOutcome,
          AiTerminalCommitOutcome.alreadyCompleted,
        );

        expect(
          timeoutOutcome,
          AiTerminalCommitOutcome.alreadyCompleted,
        );

        expect(
          coordinator.result?.terminalCause,
          AiTerminalCause.completed,
        );

        expect(
          coordinator.acceptedSource,
          'stream_done',
        );
      },
    );

    test(
      'rejeita identidade divergente sem selar execução',
      () {
        final coordinator = AiTerminalCoordinator(
          requestId: 'request-terminal',
          sessionId: 'session-terminal',
        );

        final wrongRequest = coordinator.tryCommit(
          result: buildResult(
            requestId: 'request-other',
          ),
          source: 'wrong_request',
        );

        final wrongSession = coordinator.tryCommit(
          result: buildResult(
            sessionId: 'session-other',
          ),
          source: 'wrong_session',
        );

        expect(
          wrongRequest,
          AiTerminalCommitOutcome.identityMismatch,
        );

        expect(
          wrongSession,
          AiTerminalCommitOutcome.identityMismatch,
        );

        expect(coordinator.isCompleted, isFalse);

        final validOutcome = coordinator.tryCommit(
          result: buildResult(),
          source: 'valid_terminal',
        );

        expect(
          validOutcome,
          AiTerminalCommitOutcome.accepted,
        );

        expect(coordinator.isCompleted, isTrue);
      },
    );

    test(
      'terminalFuture resolve com resultado vencedor',
      () async {
        final fixedTime = DateTime.utc(
          2026,
          7,
          22,
          12,
        );

        final coordinator = AiTerminalCoordinator(
          requestId: 'request-terminal',
          sessionId: 'session-terminal',
          clock: () => fixedTime,
        );

        final future = coordinator.terminalFuture;

        coordinator.tryCommit(
          result: buildResult(
            cause: AiTerminalCause.partial,
            isPartial: true,
            text: 'Resposta parcial.',
          ),
          source: 'partial_error',
        );

        final commit = await future;

        expect(
          commit.result.terminalCause,
          AiTerminalCause.partial,
        );

        expect(commit.result.isPartial, isTrue);
        expect(commit.source, 'partial_error');
        expect(commit.committedAt, fixedTime);
      },
    );

    test(
      'executa limpezas pendentes exatamente uma vez',
      () {
        final coordinator = AiTerminalCoordinator(
          requestId: 'request-terminal',
          sessionId: 'session-terminal',
        );

        var timerCancelCalls = 0;
        var subscriptionCancelCalls = 0;

        coordinator.registerCleanup(() {
          timerCancelCalls++;
        });

        coordinator.registerCleanup(() {
          subscriptionCancelCalls++;
        });

        coordinator.tryCommit(
          result: buildResult(),
          source: 'completed',
        );

        coordinator.tryCommit(
          result: buildResult(
            cause: AiTerminalCause.error,
          ),
          source: 'late_error',
        );

        expect(timerCancelCalls, 1);
        expect(subscriptionCancelCalls, 1);
      },
    );

    test(
      'falha de uma limpeza não bloqueia as demais',
      () {
        final coordinator = AiTerminalCoordinator(
          requestId: 'request-terminal',
          sessionId: 'session-terminal',
        );

        var successfulCleanupCalls = 0;

        coordinator.registerCleanup(() {
          throw StateError('falha simulada');
        });

        coordinator.registerCleanup(() {
          successfulCleanupCalls++;
        });

        final outcome = coordinator.tryCommit(
          result: buildResult(),
          source: 'completed',
        );

        expect(
          outcome,
          AiTerminalCommitOutcome.accepted,
        );

        expect(successfulCleanupCalls, 1);
        expect(coordinator.isCompleted, isTrue);
      },
    );

    test(
      'limpeza registrada após terminal executa imediatamente',
      () {
        final coordinator = AiTerminalCoordinator(
          requestId: 'request-terminal',
          sessionId: 'session-terminal',
        );

        coordinator.tryCommit(
          result: buildResult(),
          source: 'completed',
        );

        var lateCleanupCalls = 0;

        coordinator.registerCleanup(() {
          lateCleanupCalls++;
        });

        expect(lateCleanupCalls, 1);
      },
    );

    test(
      'cancelamento pode vencer e bloquear sucesso tardio',
      () {
        final coordinator = AiTerminalCoordinator(
          requestId: 'request-terminal',
          sessionId: 'session-terminal',
        );

        final cancelOutcome = coordinator.tryCommit(
          result: buildResult(
            cause: AiTerminalCause.cancelled,
            text: '',
          ),
          source: 'user_cancel',
        );

        final lateSuccessOutcome = coordinator.tryCommit(
          result: buildResult(
            cause: AiTerminalCause.completed,
          ),
          source: 'stream_done',
        );

        expect(
          cancelOutcome,
          AiTerminalCommitOutcome.accepted,
        );

        expect(
          lateSuccessOutcome,
          AiTerminalCommitOutcome.alreadyCompleted,
        );

        expect(
          coordinator.result?.terminalCause,
          AiTerminalCause.cancelled,
        );
      },
    );

    test(
      'preserva flags de partial e fallback',
      () {
        final partialCoordinator = AiTerminalCoordinator(
          requestId: 'request-terminal',
          sessionId: 'session-terminal',
        );

        partialCoordinator.tryCommit(
          result: buildResult(
            cause: AiTerminalCause.partial,
            isPartial: true,
          ),
          source: 'partial',
        );

        expect(
          partialCoordinator.result?.isPartial,
          isTrue,
        );

        final fallbackCoordinator = AiTerminalCoordinator(
          requestId: 'request-fallback',
          sessionId: 'session-fallback',
        );

        fallbackCoordinator.tryCommit(
          result: buildResult(
            requestId: 'request-fallback',
            sessionId: 'session-fallback',
            cause: AiTerminalCause.fallback,
            isFallback: true,
          ),
          source: 'safe_fallback',
        );

        expect(
          fallbackCoordinator.result?.isFallback,
          isTrue,
        );

        expect(
          fallbackCoordinator.result?.terminalCause,
          AiTerminalCause.fallback,
        );
      },
    );

    test(
      'normaliza source vazio para unknown',
      () {
        final coordinator = AiTerminalCoordinator(
          requestId: 'request-terminal',
          sessionId: 'session-terminal',
        );

        coordinator.tryCommit(
          result: buildResult(),
          source: '   ',
        );

        expect(
          coordinator.acceptedSource,
          'unknown',
        );
      },
    );
  });
}
