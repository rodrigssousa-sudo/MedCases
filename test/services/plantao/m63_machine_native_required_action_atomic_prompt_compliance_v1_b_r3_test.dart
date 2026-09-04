import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

void main() {
  group('M63 machine-native requiredAction atomic prompt contract', () {
    test(
      'ES machine-native prompt makes each requiredAction atomic and complete',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'es',
          matchedProtocolSummaries: const <String>[],
          matchedDrugSummaries: const <String>[],
          userQuery:
              '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\nrequiredActions=fixture',
          isPlantaoMode: true,
        );
        expect(prompt, contains('REGLA ATÓMICA DE requiredActions'));
        expect(
          prompt,
          contains('cada elemento es obligatorio como unidad clínica completa'),
        );
        expect(
          prompt,
          contains('Una mención parcial NO satisface el elemento'),
        );
        expect(prompt, contains('misma polaridad clínica'));
        expect(prompt, contains('prohibitedActions'));
        expect(prompt, contains('monitoring'));
        expect(prompt, contains('reassessment'));
        expect(prompt, contains('escalationCriteria'));
      },
    );

    test('PT machine-native prompt has equivalent atomic contract', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery:
            '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\nrequiredActions=fixture',
        isPlantaoMode: true,
      );
      expect(prompt, contains('REGRA ATÔMICA DE requiredActions'));
      expect(
        prompt,
        contains(
          'cada elemento é obrigatório como uma unidade clínica completa',
        ),
      );
      expect(prompt, contains('Uma menção parcial NÃO satisfaz o elemento'));
      expect(prompt, contains('mesma polaridade clínica'));
    });

    test('Study path does not enter machine-native Plantao prompt', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery:
            '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\nrequiredActions=fixture',
        isPlantaoMode: false,
      );
      expect(prompt, isNot(contains('REGLA ATÓMICA DE requiredActions')));
    });

    test('source patch is generic and single-owner', () {
      final source = File('lib/services/ai_service.dart').readAsStringSync();
      expect(
        RegExp(
          'M63_MACHINE_NATIVE_REQUIRED_ACTION_ATOMIC_PROMPT_COMPLIANCE_V1',
        ).allMatches(source),
        hasLength(1),
      );
      final marker = source.indexOf(
        'M63_MACHINE_NATIVE_REQUIRED_ACTION_ATOMIC_PROMPT_COMPLIANCE_V1',
      );
      expect(marker, greaterThan(0));
      final start = marker > 700 ? marker - 700 : 0;
      final end = (marker + 2800) < source.length
          ? marker + 2800
          : source.length;
      final window = source.substring(start, end).toLowerCase();
      for (final forbidden in <String>[
        'anafilax',
        'adrenalina',
        'cristaloide',
      ]) {
        expect(window, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}
