import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

void main() {
  group('M70B machine-native rapid-response reconciliation', () {
    String plantaoPrompt(String lang) => AiService.buildClinicalSystemPrompt(
      lang: lang,
      matchedProtocolSummaries: const <String>[],
      matchedDrugSummaries: const <String>[],
      userQuery:
          '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\nrequiredActions=fixture',
      isPlantaoMode: true,
    );

    test('ES reconciles M63 completeness with M68 single owner and density', () {
      final prompt = plantaoPrompt('es');
      expect(
        prompt,
        contains(
          'completitud atómica de cada requiredAction se exige sobre la respuesta completa y UNA SOLA VEZ',
        ),
      );
      expect(prompt, contains('preferentemente 2–3 bullets accionables'));
      expect(
        prompt,
        contains('Monitorización y reevaluación: máximo 2 bullets'),
      );
      expect(prompt, contains('Puntos clave: 0–1 bullet'));
      expect(prompt, contains('OMITE la sección si solo repite algo ya dicho'));
      expect(
        prompt,
        contains(
          'NUNCA autorizan omitir requiredActions, prohibitedActions, datos de seguridad ni criterios obligatorios',
        ),
      );
      expect(
        prompt,
        contains('Conducta inmediata NO puede contener valores de dosis'),
      );
    });

    test('PT has the same rapid-response and safety exception contract', () {
      final prompt = plantaoPrompt('pt');
      expect(
        prompt,
        contains(
          'completude atômica de cada requiredAction é exigida sobre a resposta completa e UMA ÚNICA VEZ',
        ),
      );
      expect(prompt, contains('preferencialmente 2–3 bullets acionáveis'));
      expect(prompt, contains('Monitorização e reavaliação: máximo 2 bullets'));
      expect(prompt, contains('Pontos-chave: 0–1 bullet'));
      expect(prompt, contains('OMITA a seção se apenas repetir algo já dito'));
      expect(
        prompt,
        contains(
          'NUNCA autorizam omitir requiredActions, prohibitedActions, dados de segurança ou critérios obrigatórios',
        ),
      );
      expect(
        prompt,
        contains('Conduta imediata NÃO pode conter valores de dose'),
      );
    });

    test('Study does not receive M70B Plantao contract', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery:
            '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\nrequiredActions=fixture',
        isPlantaoMode: false,
      );
      expect(prompt, isNot(contains('CONTRATO RÁPIDO DE PLANTÃO')));
    });

    test('productive M70B prompt blocks remain pathology-agnostic', () {
      final source = File('lib/services/ai_service.dart').readAsStringSync();
      for (final label in <String>['ES', 'PT']) {
        final marker = source.indexOf(
          'M70B_MACHINE_NATIVE_RAPID_RESPONSE_RECONCILIATION_V1 $label',
        );
        expect(marker, greaterThan(0));
        final endToken = label == 'ES'
            ? 'FORMATO FARMACOLÓGICO CANÓNICO:'
            : 'FORMATO FARMACOLÓGICO CANÔNICO:';
        final end = source.indexOf(endToken, marker);
        expect(end, greaterThan(marker));
        final window = source.substring(marker, end).toLowerCase();
        for (final forbidden in <String>[
          'anafilax',
          'adrenalina',
          'cristaloide',
          'iamcest',
          'sepsis',
          'asma',
          'hipogluc',
        ]) {
          expect(
            window,
            isNot(contains(forbidden)),
            reason: '$label:$forbidden',
          );
        }
      }
    });
  });
}
