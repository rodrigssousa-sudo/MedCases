import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

void main() {
  group('M67 global treatment response structure', () {
    test('ES full-management contract is canonical and owns detailed dose', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery:
            '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\nrequiredActions=fixture',
        isPlantaoMode: true,
      );

      // The M67 marker is a source comment and is intentionally not part of
      // the runtime system prompt. Validate the actual contract text instead.
      expect(prompt, contains('CONTRATO GLOBAL DE ESTRUCTURA'));
      expect(prompt, contains('FORMATO FARMACOLÓGICO CANÓNICO'));
      expect(prompt, contains('Conducta inmediata'));
      expect(prompt, contains('Tratamiento farmacológico'));
      expect(prompt, contains('Monitorización y reevaluación'));
      expect(prompt, contains('Puntos clave'));
      expect(prompt, contains('Red flags/escalamiento'));
      expect(prompt, contains('Limitaciones / datos faltantes'));
      expect(prompt, contains('DUEÑO DE DOSIS'));
      expect(prompt, contains('Tratamiento farmacológico es el dueño visual'));
      expect(prompt, contains('CONTINUACIÓN FOCALIZADA'));
      expect(prompt, contains('REGLA ATÓMICA DE requiredActions'));
    });

    test('PT has the same canonical treatment-response ownership', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery:
            '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\nrequiredActions=fixture',
        isPlantaoMode: true,
      );

      expect(prompt, contains('CONTRATO GLOBAL DE ESTRUTURA'));
      expect(prompt, contains('Conduta imediata'));
      expect(prompt, contains('Tratamento farmacológico'));
      expect(prompt, contains('Monitorização e reavaliação'));
      expect(prompt, contains('Pontos-chave'));
      expect(prompt, contains('Red flags/escalonamento'));
      expect(prompt, contains('Limitações / dados faltantes'));
      expect(prompt, contains('DONO DA DOSE'));
      expect(prompt, contains('Tratamento farmacológico é o dono visual'));
      expect(prompt, contains('CONTINUAÇÃO FOCALIZADA'));
      expect(prompt, contains('REGRA ATÔMICA DE requiredActions'));
    });

    test('Study path does not receive the M67 Plantao contract', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery:
            '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\nrequiredActions=fixture',
        isPlantaoMode: false,
      );

      expect(prompt, isNot(contains('CONTRATO GLOBAL DE ESTRUCTURA')));
      expect(prompt, isNot(contains('DUEÑO DE DOSIS')));
      expect(prompt, isNot(contains('FORMATO FARMACOLÓGICO CANÓNICO')));
    });

    test('productive M67 source window remains pathology-agnostic', () {
      final source = File('lib/services/ai_service.dart').readAsStringSync();
      final marker = source.indexOf(
        'M67_GLOBAL_TREATMENT_RESPONSE_STRUCTURE_V1',
      );
      expect(marker, greaterThan(0));

      final end = marker + 7200 < source.length ? marker + 7200 : source.length;
      final window = source.substring(marker, end).toLowerCase();

      for (final forbidden in <String>[
        'anafilax',
        'adrenalina',
        'cristaloide',
        'iamcest',
        'sepsis',
      ]) {
        expect(window, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}
