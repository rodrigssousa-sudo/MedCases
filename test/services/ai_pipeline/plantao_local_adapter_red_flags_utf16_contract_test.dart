import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

bool isWellFormedUtf16(String value) {
  final units = value.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 >= units.length) return false;
      final low = units[++i];
      if (low < 0xDC00 || low > 0xDFFF) return false;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return false;
    }
  }
  return true;
}

void main() {
  test('RED FLAGS is typed as hard stop without broken surrogate', () {
    const text = '''
🟥 IAMCSST CONFIRMADO NO ECG
🚨 Conduta imediata:
• Alertar hemodinâmica imediatamente
💊 Tratamento farmacológico:
• **Aspirina 300 mg VO**
• **Ticagrelor 180 mg VO**
🔑 Pontos-chave:
• Meta: ICP em <90 min do 1º contato médico
• Monitorização contínua de ECG e parâmetros vitais
🚩 RED FLAGS:
• Hipotensão ou sinais de choque cardiogênico
📌 Preparar para cateterismo imediato.
''';

    final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);
    expect(output, isNotNull);
    expect(output!.pontosChave, hasLength(2));
    expect(output.hardStops, ['Hipotensão ou sinais de choque cardiogênico']);

    final transported = <String>[
      ...output.pontosChave,
      ...output.hardStops,
    ].join(' || ');
    expect(transported, isNot(contains('\uFFFD')));
    expect(isWellFormedUtf16(transported), isTrue);
    expect(output.pontosChave.join(' '), isNot(contains('RED FLAGS')));
  });
}
