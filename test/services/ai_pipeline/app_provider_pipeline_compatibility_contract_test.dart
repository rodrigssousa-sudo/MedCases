import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';

AiLegacyCallbackRunner buildLegacyRunnerFromProvider(
  AppProvider provider,
) {
  return (
    request, {
    required onChunk,
    required onDone,
    required onError,
  }) {
    return provider.sendAiMessage(
      request.input,
      longResponse: request.longResponse,
      pipelineRequestId: request.requestId,
      pipelineSessionId: request.sessionId,
      onChunk: onChunk,
      onDone: (text) {
        onDone(text);
      },
      onStructuredDone: (
        text,
        clinicalOutput,
      ) {
        onDone(text, clinicalOutput);
      },
      onError: onError,
    );
  };
}

void main() {
  group('AppProvider pipeline compatibility seam', () {
    late String providerSource;

    setUpAll(() {
      providerSource = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();
    });

    test('adapter tipado compila', () {
      final AiLegacyCallbackRunner Function(
        AppProvider provider,
      ) builder = buildLegacyRunnerFromProvider;

      expect(builder, isNotNull);
    });

    test('aceita IDs externos opcionais', () {
      expect(
        providerSource,
        contains('String? pipelineRequestId'),
      );

      expect(
        providerSource,
        contains('String? pipelineSessionId'),
      );
    });

    test('preserva os fallbacks legados', () {
      expect(
        providerSource,
        contains(
          ': ProviderRouterService'
          '.generateRequestId();',
        ),
      );

      expect(
        providerSource,
        contains(
          'if (_currentConversationSessionId.isEmpty) {',
        ),
      );
    });

    test('aplica sessionId externo antes do fallback', () {
      final externalAssignment = providerSource.indexOf(
        '_currentConversationSessionId =\n'
        '          normalizedPipelineSessionId!;',
      );

      final fallback = providerSource.indexOf(
        'if (_currentConversationSessionId.isEmpty) {',
      );

      expect(externalAssignment, greaterThanOrEqualTo(0));
      expect(fallback, greaterThan(externalAssignment));
    });

    test('nenhum consumidor foi integrado nesta etapa', () {
      final files = <String>[
        'lib/screens/ai_screen.dart',
        'lib/screens/home_screen.dart',
        'lib/screens/ai/widgets/'
            'ambassador_panel.dart',
        'lib/home_v2/'
            'migration_home_screen_reference.dart',
      ];

      for (final file in files) {
        final source = File(file).readAsStringSync();

        expect(
          source,
          isNot(contains('pipelineRequestId:')),
          reason: '$file integrou requestId antecipadamente.',
        );

        expect(
          source,
          isNot(contains('pipelineSessionId:')),
          reason: '$file integrou sessionId antecipadamente.',
        );
      }
    });
  });
}
