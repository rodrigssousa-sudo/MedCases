import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_truncation_repair_coordinator.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/ai_stream/truncation_inspector.dart';

void main() {
  group('AiService.repairTruncated contract', () {
    test(
      'assinatura é compatível com o runner canônico',
      () {
        final AiTruncationRepairRunner runner = ({
          required String originalText,
          required String requestId,
          required bool isPlantaoMode,
          required String appLanguage,
        }) {
          return AiService.repairTruncated(
            originalText: originalText,
            requestId: requestId,
            isPlantaoMode: isPlantaoMode,
            appLanguage: appLanguage,
          );
        };

        expect(runner, isNotNull);
      },
    );

    test(
      'porta delegada preserva todos os argumentos',
      () async {
        String? capturedText;
        String? capturedRequestId;
        bool? capturedPlantao;
        String? capturedLanguage;

        final port = DelegatingAiTruncationRepairPort(
          runner: ({
            required originalText,
            required requestId,
            required isPlantaoMode,
            required appLanguage,
          }) async {
            capturedText = originalText;
            capturedRequestId = requestId;
            capturedPlantao = isPlantaoMode;
            capturedLanguage = appLanguage;

            return TruncationRepairResult.repaired(
              'Texto final.',
            );
          },
        );

        final result = await port.repair(
          originalText: 'Texto parcial',
          requestId: 'request-contract',
          isPlantaoMode: true,
          appLanguage: 'es',
        );

        expect(capturedText, 'Texto parcial');
        expect(
          capturedRequestId,
          'request-contract',
        );
        expect(capturedPlantao, isTrue);
        expect(capturedLanguage, 'es');
        expect(result.isValid, isTrue);
        expect(result.wasRepaired, isTrue);
        expect(result.text, 'Texto final.');
      },
    );

    test(
      'implementação existente mantém contrato sem persistência direta',
      () {
        final source = File(
          'lib/services/ai_service.dart',
        ).readAsStringSync();

        expect(
          source,
          contains(
            'static Future<TruncationRepairResult> '
            'repairTruncated({',
          ),
        );

        expect(
          source,
          contains(
            'required String originalText',
          ),
        );

        expect(
          source,
          contains(
            'required String requestId',
          ),
        );

        expect(
          source,
          contains(
            'required bool isPlantaoMode',
          ),
        );

        expect(
          source,
          contains(
            "String appLanguage = 'pt'",
          ),
        );
      },
    );
  });
}
