import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';

class FakeAppProviderAiPort implements AppProviderAiPort {
  String? capturedInput;
  bool? capturedLongResponse;
  bool? capturedFromButton;
  String? capturedRequestId;
  String? capturedSessionId;

  bool accepted = true;
  bool emitSuccess = true;
  Object? structuredPayload;

  final Completer<bool>? pendingCompleter;

  int cancelCalls = 0;

  FakeAppProviderAiPort({
    this.pendingCompleter,
  });

  @override
  Future<bool> sendAiMessage(
    String input, {
    required AppProviderChunkCallback onChunk,
    required AppProviderDoneCallback onDone,
    AppProviderStructuredDoneCallback? onStructuredDone,
    required AppProviderErrorCallback onError,
    bool longResponse = false,
    bool fromButton = false,
    String? pipelineRequestId,
    String? pipelineSessionId,
  }) async {
    capturedInput = input;
    capturedLongResponse = longResponse;
    capturedFromButton = fromButton;
    capturedRequestId = pipelineRequestId;
    capturedSessionId = pipelineSessionId;

    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }

    if (emitSuccess) {
      onChunk('Con');
      onChunk('Conduta');

      onDone('Conduta final.');

      onStructuredDone?.call(
        'Conduta final.',
        structuredPayload,
      );
    }

    return accepted;
  }

  @override
  void cancelAiStream() {
    cancelCalls++;
  }
}

AiRequestContract buildRequest({
  AiRequestMode mode = AiRequestMode.plantao,
  Map<String, Object?> metadata = const <String, Object?>{},
}) {
  return AiRequestContract(
    requestId: 'request-adapter',
    sessionId: 'session-adapter',
    input: 'Avaliar paciente.',
    mode: mode,
    locale: AiRequestLocale.pt,
    sourceSurface: AiSourceSurface.aiScreen,
    metadata: metadata,
  );
}

void main() {
  group('AppProviderAiResponsePipeline', () {
    test(
      'encaminha input, modo, IDs e fromButton',
      () async {
        final port = FakeAppProviderAiPort()
          ..structuredPayload = <String, Object?>{
            'diagnostico': 'Pneumonia',
          };

        final pipeline = AppProviderAiResponsePipeline(
          port: port,
          providerLabel: 'provider-test',
        );

        final events = await pipeline
            .execute(
              buildRequest(
                mode: AiRequestMode.estudo,
                metadata: const <String, Object?>{
                  'fromButton': true,
                },
              ),
            )
            .toList();

        expect(
          port.capturedInput,
          'Avaliar paciente.',
        );
        expect(port.capturedLongResponse, isTrue);
        expect(port.capturedFromButton, isTrue);
        expect(
          port.capturedRequestId,
          'request-adapter',
        );
        expect(
          port.capturedSessionId,
          'session-adapter',
        );

        final deltas = events.whereType<AiResponseDelta>().toList();

        expect(deltas, hasLength(2));
        expect(deltas.first.delta, 'Con');
        expect(deltas.last.delta, 'duta');

        final terminals = events.whereType<AiResponseTerminal>().toList();

        expect(terminals, hasLength(1));
        expect(
          terminals.single.result.requestId,
          'request-adapter',
        );
        expect(
          terminals.single.result.sessionId,
          'session-adapter',
        );
        expect(
          terminals.single.result.provider,
          'provider-test',
        );
        expect(
          terminals.single.result.finalText,
          'Conduta final.',
        );
        expect(
          terminals.single.result.structuredOutput,
          same(port.structuredPayload),
        );
      },
    );

    test(
      'usa Plantão e fromButton false por padrão',
      () async {
        final port = FakeAppProviderAiPort();

        final pipeline = AppProviderAiResponsePipeline(
          port: port,
        );

        await pipeline.execute(buildRequest()).toList();

        expect(port.capturedLongResponse, isFalse);
        expect(port.capturedFromButton, isFalse);
      },
    );

    test(
      'materializa rejeição do provider',
      () async {
        final port = FakeAppProviderAiPort()
          ..accepted = false
          ..emitSuccess = false;

        final pipeline = AppProviderAiResponsePipeline(
          port: port,
        );

        final events = await pipeline.execute(buildRequest()).toList();

        final terminal = events.last as AiResponseTerminal;

        expect(
          terminal.result.terminalCause,
          AiTerminalCause.error,
        );
        expect(
          terminal.result.errorCode,
          'legacy_send_rejected',
        );
      },
    );

    test(
      'encaminha cancelamento ao provider uma vez',
      () async {
        final completer = Completer<bool>();

        final port = FakeAppProviderAiPort(
          pendingCompleter: completer,
        );

        final events = <AiResponseEvent>[];

        final pipeline = AppProviderAiResponsePipeline(
          port: port,
        );

        final subscription =
            pipeline.execute(buildRequest()).listen(events.add);

        await Future<void>.delayed(Duration.zero);

        expect(
          events.whereType<AiResponseStarted>(),
          hasLength(1),
        );

        await subscription.cancel();
        await subscription.cancel();

        expect(port.cancelCalls, 1);

        completer.complete(true);

        await Future<void>.delayed(Duration.zero);

        expect(
          events.whereType<AiResponseTerminal>(),
          isEmpty,
        );
      },
    );

    test(
      'factory produtiva permanece compilável',
      () {
        final AppProviderAiResponsePipeline Function(
          AppProvider provider,
        ) factory = (
          provider,
        ) {
          return AppProviderAiResponsePipeline.fromAppProvider(provider);
        };

        expect(factory, isNotNull);
      },
    );
  });
}
