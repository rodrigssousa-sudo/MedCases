import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

void main() {
  group('Guardia clinical criteria prompt contract', () {
    test('injects the Portuguese criteria contract in Plantão', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery: 'dor torácica',
        isPlantaoMode: true,
      );

      expect(
        prompt,
        contains('CONTRATO DE CRITÉRIOS E EVIDÊNCIA'),
      );
      expect(prompt, contains('de forma condicional'));
      expect(prompt, contains('informe qual dado falta'));
      expect(prompt, contains('preserve a incerteza clínica'));
    });

    test('injects the Spanish criteria contract in Guardia', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery: 'dolor torácico',
        isPlantaoMode: true,
      );

      expect(
        prompt,
        contains('CONTRATO DE CRITERIOS Y EVIDENCIA'),
      );
      expect(prompt, contains('de manera condicional'));
      expect(prompt, contains('indica qué dato falta'));
      expect(prompt, contains('conserva la incertidumbre clínica'));
    });

    test('does not inject the Plantão contract in Estudo', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery: 'dor torácica',
        isPlantaoMode: false,
      );

      expect(
        prompt,
        isNot(contains('CONTRATO DE CRITÉRIOS E EVIDÊNCIA')),
      );
      expect(
        prompt,
        isNot(contains('CONTRATO DE CRITERIOS Y EVIDENCIA')),
      );
    });

    test('preserves the existing protocol RAG assembly path', () {
      final source = File('lib/services/ai_service.dart').readAsStringSync();

      expect(source, contains(r'$ptRagAnchor'));
      expect(
        source,
        contains(r'$ptProtocol$ptDrugs$ptContext'),
      );
      expect(
        source,
        contains(r'$ptClinicalCriteriaContract'),
      );
    });
  });
}
