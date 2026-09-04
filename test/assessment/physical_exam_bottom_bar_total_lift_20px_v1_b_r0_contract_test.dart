import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/avaliacao_screen.dart').readAsStringSync();

  group('Physical exam bottom bar total lift 20px V1-B-R0', () {
    test('sube 10px adicionales para un total de 20px', () {
      expect(
        source,
        contains(
          'MEDCASES_PHYSICAL_EXAM_BOTTOM_BAR_TOTAL_LIFT_20PX_V1_B_R0',
        ),
      );
      expect(
        source,
        contains('padding: const EdgeInsets.fromLTRB(8, 5, 8, 28),'),
      );
      expect(
        source,
        isNot(
          contains('padding: const EdgeInsets.fromLTRB(8, 5, 8, 18),'),
        ),
      );
    });

    test('preserva toda a densidade homologada', () {
      for (final contract in const <String>[
        'MEDCASES_PHYSICAL_EXAM_VISUAL_DENSITY_REBALANCE_V1_B_R0_R3',
        'static const double screenTitle = 16.0;',
        'static const double tabLabel = 11.0;',
        'static const double sectionLabel = 10.0;',
        'static const double clinicalOption = 12.5;',
        'static const double inputComplement = 11.5;',
        '_AssessmentVisualScale.inputComplement',
        'minimumSize: const Size(40, 40),',
      ]) {
        expect(source, contains(contract), reason: contract);
      }
    });

    test('preserva PT ES e navegação', () {
      for (final contract in const <String>[
        "'EVALUACIÓN FÍSICA'",
        "'AVALIAÇÃO FÍSICA'",
        "isEs ? 'Anterior' : 'Anterior'",
        "isEs ? 'Siguiente' : 'Próximo'",
      ]) {
        expect(source, contains(contract), reason: contract);
      }
      expect(source, contains(r"'${sectionIdx + 1} / $total'"));
    });
  });
}
