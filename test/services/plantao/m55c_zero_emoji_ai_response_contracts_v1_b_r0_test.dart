import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/tep_2026_plantao_response_guard.dart';

bool hasPictographicEmoji(String text) {
  for (final cp in text.runes) {
    if ((cp >= 0x1F000 && cp <= 0x1FAFF) || (cp >= 0x2600 && cp <= 0x27BF)) {
      return true;
    }
  }
  return false;
}

void main() {
  group('M55C zero emoji AI response contracts', () {
    test('AI-facing initial structure contract ES/PT contains zero emoji', () {
      final es = AiService.buildM54PhysicalHomologationContractForTesting(
        'Paciente con IAMCEST. Clasifica y define conducta inicial.',
        isEs: true,
      );
      final pt = AiService.buildM54PhysicalHomologationContractForTesting(
        'Paciente com IAMCEST. Classifique e defina conduta inicial.',
        isEs: false,
      );

      expect(hasPictographicEmoji(es), isFalse);
      expect(hasPictographicEmoji(pt), isFalse);
      expect(es, contains('1) PATOLOGÍA/TEMA CLÍNICO'));
      expect(es, contains('2) Conducta inmediata'));
      expect(es, contains('4) Clasificación'));
      expect(es, contains('PROHIBIDO usar emojis'));
      expect(pt, contains('1) PATOLOGIA/TEMA CLÍNICO'));
      expect(pt, contains('2) Conduta imediata'));
      expect(pt, contains('4) Classificação'));
      expect(pt, contains('PROIBIDO usar emojis'));
    });

    test('M55B bronchiolitis and anaphylaxis contracts remain zero emoji', () {
      final bron = AiService.buildM54PhysicalHomologationContractForTesting(
        'Lactante de 4 meses con bronquiolitis aguda, primer episodio de sibilancias.',
        isEs: true,
      );
      final ana = AiService.buildM54PhysicalHomologationContractForTesting(
        'Mujer con anafilaxia y choque tras maní. Conducta inmediata.',
        isEs: true,
      );
      expect(hasPictographicEmoji(bron), isFalse);
      expect(hasPictographicEmoji(ana), isFalse);
      expect(bron, contains('M55B_BRONQUIOLITIS_SUPPORTIVE_CARE'));
      expect(ana, contains('M55B_ANAFILAXIS_FIRST_ACTION_PRIORITY'));
    });

    test('TEP deterministic C3R output contains zero emoji and preserves table', () {
      const input =
          'Paciente de 68 años con embolia pulmonar aguda confirmada por angio-TC. '
          'PA 118/72 mmHg, FC 118 lpm, FR 32 rpm, SpO2 88% al aire ambiente. '
          'No presentó hipotensión ni paro. La angio-TC muestra relación VD/VI de 1,2 '
          'y la troponina está elevada. Según AHA/ACC 2026 clasifique e indique conducta.';
      final out = Tep2026PlantaoResponseGuard.materialize(
        userInput: input,
        assistantOutput: 'RAW_LEGACY',
        languageCode: 'es',
      );
      expect(hasPictographicEmoji(out), isFalse);
      expect(out, contains('TEP AGUDO CONFIRMADO'));
      expect(out, contains('Clasificación AHA/ACC 2026:'));
      expect(
        out,
        contains('| Criterio / clasificación | Resultado en este paciente |'),
      );
      expect(out, contains('| Categoría / resultado final | **C3R** |'));
      expect(out, contains('| Relación VD/VI | **1,2** |'));
    });
  });
}
