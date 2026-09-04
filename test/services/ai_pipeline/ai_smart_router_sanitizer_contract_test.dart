import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_response_sanitizer.dart';
import 'package:medcases/services/ai_smart_router.dart';

void main() {
  group('AiSmartRouter sanitizer contract', () {
    test(
      'assinatura é compatível com o runner canônico',
      () {
        final AiSmartRouterSanitizeRunner runner =
            AiSmartRouter.sanitizeAndCheck;

        final result = runner(
          'Conduta concluída.',
          isPlantaoMode: true,
          appLanguage: 'pt',
        );

        expect(result.text, 'Conduta concluída.');
        expect(result.hadMetaLeak, isFalse);
        expect(result.hadSevereLeak, isFalse);
        expect(result.isRecoverable, isTrue);
      },
    );

    test(
      'SanitizeResult preserva os quatro campos observados',
      () {
        const result = SanitizeResult(
          text: 'Texto limpo.',
          hadMetaLeak: true,
          hadSevereLeak: true,
          isRecoverable: false,
        );

        expect(result.text, 'Texto limpo.');
        expect(result.hadMetaLeak, isTrue);
        expect(result.hadSevereLeak, isTrue);
        expect(result.isRecoverable, isFalse);
      },
    );

    test(
      'implementação existente mantém assinatura pública observada',
      () {
        final source = File(
          'lib/services/ai_smart_router.dart',
        ).readAsStringSync();

        expect(
          source,
          contains(
            'static SanitizeResult sanitizeAndCheck(',
          ),
        );

        expect(
          source,
          contains(
            'bool isPlantaoMode = false',
          ),
        );

        expect(
          source,
          contains(
            "String appLanguage = 'pt'",
          ),
        );

        expect(
          source,
          contains('final String text;'),
        );

        expect(
          source,
          contains('final bool hadMetaLeak;'),
        );

        expect(
          source,
          contains('final bool hadSevereLeak;'),
        );

        expect(
          source,
          contains('final bool isRecoverable;'),
        );
      },
    );

    test(
      'remove marcador técnico reconhecido sem perder conteúdo clínico',
      () {
        final result = AiSmartRouter.sanitizeAndCheck(
          '[PROMPT] instrução interna\n'
          'Paciente estável. Manter monitorização.',
          isPlantaoMode: true,
          appLanguage: 'pt',
        );

        expect(result.hadMetaLeak, isTrue);
        expect(result.isRecoverable, isTrue);

        expect(
          result.text,
          'Paciente estável. Manter monitorização.',
        );

        expect(
          result.text,
          isNot(contains('[PROMPT]')),
        );
      },
    );

    test(
      'tag não reconhecida permanece fora do contrato atual',
      () {
        const text = '<thinking>interno</thinking>\n'
            'Paciente estável.';

        final result = AiSmartRouter.sanitizeAndCheck(
          text,
          isPlantaoMode: true,
          appLanguage: 'pt',
        );

        expect(result.hadMetaLeak, isFalse);
        expect(result.text, text);
      },
    );
  });
}
