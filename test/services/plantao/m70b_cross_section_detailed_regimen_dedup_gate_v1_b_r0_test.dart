import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';

String sectionBody(String text, String heading, String nextHeading) {
  final start = text.indexOf(heading);
  expect(start, greaterThanOrEqualTo(0));
  final end = text.indexOf(nextHeading, start + heading.length);
  expect(end, greaterThan(start));
  return text.substring(start, end);
}

void main() {
  group('M70B deterministic cross-section detailed-regimen dedup', () {
    test(
      'ES removes duplicated detailed regimen only from immediate conduct',
      () {
        const raw = '''
Síndrome clínico

Conducta inmediata
- Administrar MedicamentoAlfa IV 10 mg/kg de la solución 20 mg/mL; máximo 1 g en el adulto.
- Evaluar vía aérea y circulación.

Tratamiento farmacológico
- MedicamentoAlfa IV 10 mg/kg de la solución 20 mg/mL; máximo 1 g en el adulto.

Monitorización y reevaluación
- Reevaluar respuesta.
''';

        final result =
            PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
              userText: 'caso clínico',
              rawText: raw,
              language: 'es',
            );
        final immediate = sectionBody(
          result.finalText,
          'Conducta inmediata',
          'Tratamiento farmacológico',
        );
        final treatment = sectionBody(
          result.finalText,
          'Tratamiento farmacológico',
          'Monitorización y reevaluación',
        );

        expect(immediate, contains('Administrar MedicamentoAlfa IV'));
        expect(immediate, isNot(contains('10 mg/kg')));
        expect(immediate, isNot(contains('20 mg/mL')));
        expect(immediate, isNot(contains('máximo 1 g')));
        expect(immediate, contains('Evaluar vía aérea y circulación'));
        expect(treatment, contains('10 mg/kg'));
        expect(treatment, contains('20 mg/mL'));
        expect(treatment, contains('máximo 1 g'));
        expect(result.hasCriticalIssue, isFalse);
      },
    );

    test('PT has the same deterministic single-owner behavior', () {
      const raw = '''
Síndrome clínico

Conduta imediata
- Administrar MedicamentoAlfa IV 10 mg/kg da solução 20 mg/mL; máximo 1 g no adulto.
- Avaliar via aérea e circulação.

Tratamento farmacológico
- MedicamentoAlfa IV 10 mg/kg da solução 20 mg/mL; máximo 1 g no adulto.

Monitorização e reavaliação
- Reavaliar resposta.
''';

      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'caso clínico',
        rawText: raw,
        language: 'pt',
      );
      final immediate = sectionBody(
        result.finalText,
        'Conduta imediata',
        'Tratamento farmacológico',
      );
      final treatment = sectionBody(
        result.finalText,
        'Tratamento farmacológico',
        'Monitorização e reavaliação',
      );

      expect(immediate, contains('Administrar MedicamentoAlfa IV'));
      expect(immediate, isNot(contains('10 mg/kg')));
      expect(immediate, isNot(contains('20 mg/mL')));
      expect(immediate, isNot(contains('máximo 1 g')));
      expect(treatment, contains('10 mg/kg'));
      expect(treatment, contains('20 mg/mL'));
      expect(treatment, contains('máximo 1 g'));
    });

    test('does not strip unmatched medication or unmatched regimen', () {
      const raw = '''
Síndrome clínico

Conducta inmediata
- Administrar MedicamentoBeta IV 5 mg si está indicado.

Tratamiento farmacológico
- MedicamentoAlfa IV 10 mg/kg.

Monitorización y reevaluación
- Reevaluar respuesta.
''';

      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'caso clínico',
        rawText: raw,
        language: 'es',
      );
      expect(result.finalText, contains('MedicamentoBeta IV 5 mg'));
      expect(result.finalText, contains('MedicamentoAlfa IV 10 mg/kg'));
    });

    test('dedup pass is idempotent', () {
      const raw = '''
Síndrome clínico

Conducta inmediata
- Administrar MedicamentoAlfa IV 10 mg/kg.

Tratamiento farmacológico
- MedicamentoAlfa IV 10 mg/kg.

Monitorización y reevaluación
- Reevaluar respuesta.
''';

      final first = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'caso clínico',
        rawText: raw,
        language: 'es',
      );
      final second = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'caso clínico',
        rawText: first.finalText,
        language: 'es',
      );
      expect(second.finalText, first.finalText);
    });
  });
}
