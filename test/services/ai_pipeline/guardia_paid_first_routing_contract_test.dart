import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart';

void main() {
  group('H5C1-G1-V12-M13-R2 — Guardia paid-first routing', () {
    test('Guardia critical permanece critical com Gemini conectado', () {
      expect(
        AppProvider.resolveEffectiveAiPriorityForRouting(
          isPlantaoMode: true,
          geminiConnected: true,
          aiPriority: 'critical',
          forcePaidCanary: false,
        ),
        'critical',
      );
    });

    test('Estudo critical com Gemini permanece academic/free-first', () {
      expect(
        AppProvider.resolveEffectiveAiPriorityForRouting(
          isPlantaoMode: false,
          geminiConnected: true,
          aiPriority: 'critical',
          forcePaidCanary: false,
        ),
        'academic',
      );
    });

    test('canário debug continua forçando critical', () {
      expect(
        AppProvider.resolveEffectiveAiPriorityForRouting(
          isPlantaoMode: false,
          geminiConnected: true,
          aiPriority: 'critical',
          forcePaidCanary: true,
        ),
        'critical',
      );
    });

    test('sem Gemini preserva a prioridade original', () {
      expect(
        AppProvider.resolveEffectiveAiPriorityForRouting(
          isPlantaoMode: false,
          geminiConnected: false,
          aiPriority: 'academic',
          forcePaidCanary: false,
        ),
        'academic',
      );
    });

    test('produção resolve modo por !longResponse e loga só override real', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('isPlantaoMode: !longResponse'),
      );
      expect(
        source,
        contains("effectivePriority == 'academic'"),
      );
      expect(
        source,
        isNot(
          contains(
            ": (_geminiConnected ? 'academic' : aiPriority)",
          ),
        ),
      );
    });
  });
}
