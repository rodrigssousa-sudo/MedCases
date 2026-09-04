import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('H5C1-G1-V12-M14-R7 — GPT SSE produção', () {
    late String appProvider;
    late String providerRouter;

    setUpAll(() {
      appProvider = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();
      providerRouter = File(
        'lib/services/provider_router_service.dart',
      ).readAsStringSync();
    });

    test('Plantão critical entra no GPT SSE real', () {
      final gateIndex = appProvider.indexOf(
        'final bool shouldUseGptSse',
      );
      final streamIndex = appProvider.indexOf(
        'ProviderRouterService.callGptProxyStream(',
      );
      final lateCriticalIndex = appProvider.indexOf(
        "if (effectivePriority == 'critical')",
      );

      expect(gateIndex, greaterThanOrEqualTo(0));
      expect(streamIndex, greaterThan(gateIndex));
      expect(lateCriticalIndex, greaterThan(streamIndex));
      expect(
        appProvider,
        contains(
          "(!longResponse && aiPriority == 'critical')",
        ),
      );
      expect(
        appProvider,
        contains('if (shouldUseGptSse) {'),
      );
    });

    test('classificação de prioridade possui um único proprietário', () {
      expect(
        RegExp(
          r'AiSmartRouter\.classifyPriority\(',
        ).allMatches(appProvider).length,
        1,
      );
      expect(
        appProvider,
        contains(
          'contractName/aiPriority foram resolvidos uma única vez',
        ),
      );
    });

    test('ProviderRouter expõe ownership do cliente SSE', () {
      expect(
        providerRouter,
        contains(
          'void Function(GptSseClient client)? onClientCreated',
        ),
      );
      expect(
        providerRouter,
        contains('onClientCreated?.call(client);'),
      );
      expect(
        appProvider,
        contains('onClientCreated: (client) {'),
      );
      expect(
        appProvider,
        contains('_activeGptClient = client;'),
      );
    });

    test('falhas GPT SSE escalam somente para Gemini Paid', () {
      expect(
        appProvider,
        contains(
          'runGeminiPaidFallbackFromGptSse',
        ),
      );
      expect(
        appProvider,
        contains('ProviderRouterService.callPaidProxy('),
      );
      expect(
        appProvider,
        contains("provider: 'gemini_paid'"),
      );
      expect(
        appProvider,
        contains('attempt: 3'),
      );

      final helperStart = appProvider.indexOf(
        'Future<void> runGeminiPaidFallbackFromGptSse',
      );
      final helperEnd = appProvider.indexOf(
        '// Ativar estado de streaming',
        helperStart,
      );
      final helper = appProvider.substring(
        helperStart,
        helperEnd,
      );

      expect(
        helper,
        isNot(contains('callGptProxy(')),
      );
      expect(
        helper,
        isNot(contains('callGptProxyStream(')),
      );
    });

    test('parcial GPT não é persistido nem concatenado', () {
      expect(
        appProvider,
        contains(
          'O parcial permanece somente na superfície provisória.',
        ),
      );
      expect(
        appProvider,
        contains(
          'Nunca é persistido nem concatenado ao Gemini Paid.',
        ),
      );
      expect(
        appProvider,
        isNot(
          contains(
            r'${e.partialText}',
          ),
        ),
      );
    });

    test('auth e budget guard permanecem terminais', () {
      expect(
        appProvider,
        contains('finishGptSsePreflightError'),
      );
      expect(
        RegExp(
          r'finishGptSsePreflightError\(',
        ).allMatches(appProvider).length,
        6,
      );
      expect(
        appProvider,
        contains("e.code == 'auth_expired'"),
      );
      expect(
        appProvider,
        contains("e.code == 'gpt_sse_budget_guard'"),
      );
      expect(
        appProvider,
        contains('Limite de uso atingido'),
      );
    });

    test('eventos tardios não alteram a superfície após fallback', () {
      expect(
        appProvider,
        contains('if (qaFallbackStarted) {'),
      );
      expect(
        appProvider,
        contains('[AI_E2E][POST_FALLBACK_DROP]'),
      );
      expect(
        appProvider,
        contains('unawaited(activeSubscription.cancel());'),
      );
    });

    test('seam GPT SSE mantém formato canônico', () {
      expect(
        appProvider,
        contains(
          'clinicalOutput: finalizationOutcome.structure?.clinicalOutput,',
        ),
      );
      expect(
        appProvider,
        contains(
          ');\n                } on AiSafeOutputException',
        ),
      );
      expect(
        appProvider,
        isNot(
          contains(
            ');                } on AiSafeOutputException',
          ),
        ),
      );
    });

    test('Gemini Paid passa pelo finalizador canônico', () {
      expect(
        appProvider,
        contains(
          'AiResponseFinalizationProcessor.withExistingImplementations()',
        ),
      );
      expect(
        appProvider,
        contains(
          'await _finalizeGptSuccessfulRequest(',
        ),
      );
      expect(
        appProvider,
        contains(
          'finalizationOutcome.structure?.clinicalOutput',
        ),
      );
    });
  });
}
