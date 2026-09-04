import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/avaliacao_screen.dart').readAsStringSync();

  group('Physical exam visual density V1-B-R0-R3', () {
    test('usa escala local compacta sem alterar foundations globais', () {
      expect(
        source,
        contains(
          'MEDCASES_PHYSICAL_EXAM_VISUAL_DENSITY_REBALANCE_V1_B_R0_R3',
        ),
      );
      for (final contract in const <String>[
        'static const double screenTitle = 16.0;',
        'static const double tabLabel = 11.0;',
        'static const double fieldHint = 11.0;',
        'static const double sectionLabel = 10.0;',
        'static const double clinicalOption = 12.5;',
        'static const double inputFree = 12.5;',
        'static const double inputComplement = 11.5;',
        'static const double navPrimary = 11.0;',
        'static const double navSecondary = 10.0;',
        'static const double progress = 8.5;',
      ]) {
        expect(source, contains(contract), reason: contract);
      }
    });

    test('topbar e navegação de seções ficam menores', () {
      expect(source, contains('height: 48'));
      expect(source, contains('iconSize: 21'));
      expect(source, contains('fontSize: _AssessmentVisualScale.screenTitle'));
      expect(
        RegExp(r'height:\s*44').allMatches(source).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        source,
        contains('fontSize: _AssessmentVisualScale.tabLabel'),
      );
      expect(
        source,
        contains('padding: const EdgeInsets.symmetric(horizontal: 12)'),
      );
    });

    test('questões e Complementar usam densidade clínica compacta', () {
      for (final contract in const <String>[
        'padding: const EdgeInsets.fromLTRB(16, 10, 16, 10)',
        'fontSize: _AssessmentVisualScale.fieldHint',
        'fontSize: _AssessmentVisualScale.sectionLabel',
        'padding: const EdgeInsets.fromLTRB(7, 5, 7, 5)',
        'fontSize: _AssessmentVisualScale.clinicalOption',
        'const SizedBox(height: 6)',
        'horizontal: options.isEmpty ? 10 : 9',
        'vertical: options.isEmpty ? 8 : 7',
      ]) {
        expect(source, contains(contract), reason: contract);
      }
    });

    test('rodapé reduz volume sem remover ações', () {
      for (final contract in const <String>[
        'minimumSize: const Size(40, 40)',
        'padding: const EdgeInsets.fromLTRB(8, 5, 8, 28)',
        'width: active ? 14 : 5',
        'height: 4',
        'fontSize: _AssessmentVisualScale.navPrimary',
        'fontSize: _AssessmentVisualScale.navSecondary',
        'fontSize: _AssessmentVisualScale.progress',
        "isEs ? 'Anterior' : 'Anterior'",
        "isEs ? 'Siguiente' : 'Próximo'",
        "isEs ? 'Eliminar' : 'Apagar'",
        "'Copiar'",
        "isEs ? 'Guardar en HC' : 'Salvar na HC'",
      ]) {
        expect(source, contains(contract), reason: contract);
      }
      expect(
        'minimumSize: const Size(40, 40)'.allMatches(source).length,
        3,
      );
    });

    test('PT ES e conteúdo clínico central permanecem', () {
      for (final contract in const <String>[
        "'EVALUACIÓN FÍSICA'",
        "'AVALIAÇÃO FÍSICA'",
        "'Signos Vitales'",
        "'Sinais Vitais'",
        "'Cabeza y Cuello'",
        "'Cabeça e Pescoço'",
        'PageView.builder',
        'String _compileResult(bool isEs)',
        '_compileResult(isEs)',
        'saveHistory',
      ]) {
        expect(source, contains(contract), reason: contract);
      }
    });

    test('não altera tokens globais por esta implementação', () {
      expect(source, isNot(contains('MedTypography.')));
      expect(source, isNot(contains('MedSpacing.')));
    });
  });
}
