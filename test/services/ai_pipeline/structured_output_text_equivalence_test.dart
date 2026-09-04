import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/structured_output_text_equivalence.dart';

void main() {
  group('StructuredOutputTextEquivalence', () {
    const backendText = '''
🟥 TRIGLICERIDEMIA SEVERA
📖 Resumo:
- Nivel >1000 mg/dL, riesgo pancreatitis aguda.
🔑 Pontos-clave:
- Dieta: restricción grasa, alcohol, carbohidratos.
- **Fenofibrato 145 mg VO** diario.
- **Ácidos grasos Omega-3 4 g VO** diario.
⚠️ Alerta clínico:
- Pancreatitis aguda: dolor epigástrico, vómitos.
📌 Próximo:
- Investigar causas secundarias, reevaluar lípidos.
''';

    const uiText = '''
🟥 TRIGLICERIDEMIA SEVERA
📖 Resumo:
- Nivel >1000 mg/dL, riesgo pancreatitis aguda.
🔑 Pontos-clave:
- Dieta: restricción grasa, alcohol, carbohidratos.
- Fenofibrato 145 mg VO diario.
- Ácidos grasos Omega-3 4 g VO diario.
⚠️ Alerta clínico:
- Pancreatitis aguda: dolor epigástrico, vómitos.
📌 Próximo:
- Investigar causas secundarias, reevaluar lípidos.
''';

    test('aceita exatamente o caso runtime 368 para 360 sem Markdown', () {
      expect(
        StructuredOutputTextEquivalence.matches(
          backendText: backendText,
          uiText: uiText,
        ),
        isTrue,
      );
      expect(backendText.length - uiText.length, 8);
    });

    test('aceita somente diferenças de caixa, espaço e Markdown', () {
      expect(
        StructuredOutputTextEquivalence.matches(
          backendText: '**LABETALOL 20 mg IV**',
          uiText: '  labetalol   20 mg IV  ',
        ),
        isTrue,
      );
    });

    test('rejeita alteração de dose', () {
      expect(
        StructuredOutputTextEquivalence.matches(
          backendText: backendText,
          uiText: uiText.replaceFirst('145 mg', '160 mg'),
        ),
        isFalse,
      );
    });

    test('rejeita alteração de fármaco', () {
      expect(
        StructuredOutputTextEquivalence.matches(
          backendText: backendText,
          uiText: uiText.replaceFirst('Fenofibrato', 'Gemfibrozilo'),
        ),
        isFalse,
      );
    });

    test('rejeita remoção de conteúdo clínico', () {
      expect(
        StructuredOutputTextEquivalence.matches(
          backendText: backendText,
          uiText: uiText.replaceFirst(
            '- Pancreatitis aguda: dolor epigástrico, vómitos.\n',
            '',
          ),
        ),
        isFalse,
      );
    });

    test('rejeita identidades vazias', () {
      expect(
        StructuredOutputTextEquivalence.matches(
          backendText: '',
          uiText: '',
        ),
        isFalse,
      );
    });
  });
}
