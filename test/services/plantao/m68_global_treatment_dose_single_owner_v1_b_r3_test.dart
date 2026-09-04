import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

void main() {
  group('M68 single-owner detailed dose contract', () {
    String plantaoPrompt(String lang) => AiService.buildClinicalSystemPrompt(
      lang: lang,
      matchedProtocolSummaries: const <String>[],
      matchedDrugSummaries: const <String>[],
      userQuery:
          '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\nrequiredActions=fixture',
      isPlantaoMode: true,
    );

    test('ES makes pharmacologic section the unique detailed-regimen owner', () {
      final prompt = plantaoPrompt('es');

      expect(
        prompt,
        contains('Conducta inmediata NO puede contener valores de dosis'),
      );
      expect(prompt, contains('dueño visual ÚNICO'));
      expect(prompt, contains('UNA SOLA VEZ'));
      expect(
        prompt,
        contains(
          'reescribe Conducta inmediata dejando solo la acción clínica sin la dosis duplicada',
        ),
      );
      expect(
        prompt,
        contains(
          'completitud atómica de requiredActions se evalúa sobre la RESPUESTA COMPLETA',
        ),
      );
      expect(prompt, contains("SIN insertar signos '+'"));
    });

    test('PT has the same unique detailed-regimen ownership', () {
      final prompt = plantaoPrompt('pt');

      expect(
        prompt,
        contains('Conduta imediata NÃO pode conter valores de dose'),
      );
      expect(prompt, contains('dono visual ÚNICO'));
      expect(prompt, contains('UMA ÚNICA VEZ'));
      expect(
        prompt,
        contains(
          'reescreva Conduta imediata deixando somente a ação clínica sem a dose duplicada',
        ),
      );
      expect(
        prompt,
        contains(
          'completude atômica de requiredActions é avaliada sobre a RESPOSTA COMPLETA',
        ),
      );
      expect(prompt, contains("SEM inserir sinais '+'"));
    });

    test('Study does not receive M68 Plantao ownership contract', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery:
            '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\nrequiredActions=fixture',
        isPlantaoMode: false,
      );

      expect(
        prompt,
        isNot(
          contains('Conducta inmediata NO puede contener valores de dosis'),
        ),
      );
      expect(prompt, isNot(contains('dueño visual ÚNICO')));
    });

    test('productive M68 source window remains pathology-agnostic', () {
      final source = File('lib/services/ai_service.dart').readAsStringSync();
      final marker = source.indexOf(
        'M68_GLOBAL_TREATMENT_DOSE_SINGLE_OWNER_V1 ES',
      );
      expect(marker, greaterThan(0));

      final end = source.indexOf(
        'M68_GLOBAL_TREATMENT_DOSE_SINGLE_OWNER_V1 PT',
        marker + 1,
      );
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
        expect(window, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}
