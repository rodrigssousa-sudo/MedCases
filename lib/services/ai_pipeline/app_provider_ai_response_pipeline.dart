import '../../providers/app_provider.dart';
import 'ai_legacy_callback_pipeline.dart';
import 'ai_request_contract.dart';
import 'ai_response_event.dart';
import 'ai_response_pipeline.dart';

typedef AppProviderChunkCallback = void Function(
  String accumulatedText,
);

typedef AppProviderDoneCallback = void Function(
  String finalText,
);

typedef AppProviderStructuredDoneCallback = void Function(
  String finalText,
  Object? structuredOutput,
);

typedef AppProviderErrorCallback = void Function(
  String errorMessage,
);

/// Porta mínima usada pelo novo pipeline para conversar com o provider atual.
///
/// A porta evita que os testes da nova arquitetura dependam da implementação
/// interna de onze mil linhas do [AppProvider].
abstract class AppProviderAiPort {
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
  });

  void cancelAiStream();
}

/// Implementação produtiva da porta que delega ao [AppProvider] existente.
///
/// Nenhuma regra de prompt, streaming, sanitização, persistência ou UI é
/// reproduzida aqui.
class LiveAppProviderAiPort implements AppProviderAiPort {
  final AppProvider provider;

  const LiveAppProviderAiPort(this.provider);

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
  }) {
    return provider.sendAiMessageForPipeline(
      input,
      onChunk: onChunk,
      onDone: onDone,
      onStructuredDone: onStructuredDone == null
          ? null
          : (
              finalText,
              clinicalOutput,
            ) {
              onStructuredDone(
                finalText,
                clinicalOutput,
              );
            },
      onError: onError,
      longResponse: longResponse,
      fromButton: fromButton,
      pipelineRequestId: pipelineRequestId,
      pipelineSessionId: pipelineSessionId,
    );
  }

  @override
  void cancelAiStream() {
    provider.cancelAiStream(notifyBufferedPipeline: false);
  }
}

/// Adaptador oficial de transição entre [AiResponsePipeline] e [AppProvider].
///
/// Nesta etapa ele ainda não é utilizado por AiScreen, Home ou qualquer outro
/// consumidor produtivo.
class AppProviderAiResponsePipeline implements AiResponsePipeline {
  final AppProviderAiPort port;
  final String providerLabel;

  const AppProviderAiResponsePipeline({
    required this.port,
    this.providerLabel = 'app_provider_legacy',
  });

  factory AppProviderAiResponsePipeline.fromAppProvider(
    AppProvider provider, {
    String providerLabel = 'app_provider_legacy',
  }) {
    return AppProviderAiResponsePipeline(
      port: LiveAppProviderAiPort(provider),
      providerLabel: providerLabel,
    );
  }

  @override
  Stream<AiResponseEvent> execute(
    AiRequestContract request,
  ) {
    final bridge = LegacyCallbackAiResponsePipeline(
      provider: providerLabel,
      cancelLegacy: port.cancelAiStream,
      runner: (
        currentRequest, {
        required onChunk,
        required onDone,
        required onError,
      }) {
        final fromButton = currentRequest.metadata['fromButton'] == true;

        return port.sendAiMessage(
          currentRequest.input,
          longResponse: currentRequest.longResponse,
          fromButton: fromButton,
          pipelineRequestId: currentRequest.requestId,
          pipelineSessionId: currentRequest.sessionId,
          onChunk: onChunk,
          onDone: (finalText) {
            onDone(finalText);
          },
          onStructuredDone: (
            finalText,
            structuredOutput,
          ) {
            onDone(
              finalText,
              structuredOutput,
            );
          },
          onError: onError,
        );
      },
    );

    return bridge.execute(request);
  }
}
