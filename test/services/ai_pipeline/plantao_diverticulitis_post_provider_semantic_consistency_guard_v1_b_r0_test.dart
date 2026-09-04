import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao_clinical_response_consistency_guard.dart';

void main() {
  group('Acute diverticulitis post-provider semantic consistency guard V1-B-R0', () {
    test('repairs exact Spanish physical drift without inventing regimen', () {
      const raw = """
🟥 DIVERTICULITIS AGUDA
🚨 Conducta inmediata:
* Solicitar TC abdomen/pelvis para confirmar y valorar gravedad.
* Evaluar clínica del paciente: fiebre, leucocitosis, y dolor abdominal.
🔑 Puntos clave:
* Manejo ambulatorio si no complicada y sin signos de alarma.
* Antibióticos solo si hay inmunocompromiso o empeoramiento de síntomas.
🚩 RED FLAGS:
* Peritonitis, perforación libre o obstrucción completa.
""";

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulitis aguda',
        assistantOutput: raw,
      );

      expect(out, contains('TC de abdomen/pelvis: indicada en la primera presentación'));
      expect(out, contains('En recurrencia típica ya documentada, no es automática'));
      expect(out, isNot(contains('Solicitar TC abdomen/pelvis para confirmar')));
      expect(out, contains('Antibióticos selectivos, no automáticos'));
      expect(out, contains('inmunocompromiso'));
      expect(out, contains('fragilidad/complejidad médica'));
      expect(out, contains('intolerancia oral'));
      expect(out, contains('empeoramiento clínico'));
      expect(out, contains('marcadores inflamatorios muy elevados'));
      expect(out, contains('imagen de mayor riesgo'));
      expect(out, contains('seguimiento/apoyo no fiable'));
      expect(out, isNot(contains('Antibióticos solo si')));
      expect(out, isNot(contains('ciprofloxacino')));
      expect(out, isNot(contains('metronidazol')));
      expect(out, isNot(RegExp(r'\b\d+\s*mg\b')));
    });

    test('repairs equivalent Portuguese drift', () {
      const raw = """
🟥 DIVERTICULITE AGUDA
🚨 Conduta imediata:
• Solicitar TC abdome/pelve para confirmar e avaliar gravidade.
🔑 Pontos chave:
• Antibióticos somente se imunocomprometido ou com piora clínica.
""";

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulite aguda',
        assistantOutput: raw,
      );

      expect(out, contains('TC de abdome/pelve: indicada na primeira apresentação'));
      expect(out, contains('Em recorrência típica já documentada, não é automática'));
      expect(out, contains('Antibióticos seletivos, não automáticos'));
      expect(out, contains('imunocomprometimento'));
      expect(out, contains('fragilidade/complexidade clínica'));
      expect(out, contains('intolerância oral'));
      expect(out, contains('marcadores inflamatórios muito elevados'));
      expect(out, contains('imagem de maior risco'));
      expect(out, contains('seguimento/apoio não confiável'));
    });

    test('does not rewrite explicit complicated diverticulitis', () {
      const raw = """
🚨 Conducta inmediata:
* Solicitar TC abdomen/pelvis para confirmar extensión del absceso.
* Antibióticos IV según foco y gravedad.
""";

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulitis aguda complicada con absceso',
        assistantOutput: raw,
      );
      expect(out, raw);
    });

    test('preserves already conditional CT and complete antibiotic wording', () {
      const raw = """
* Solicitar TC abdomen/pelvis en la primera presentación o si el diagnóstico es incierto.
* Antibióticos selectivos si hay inmunocompromiso, fragilidad, intolerancia oral, empeoramiento, marcadores inflamatorios altos, imagen de mayor riesgo o seguimiento no fiable.
""";

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulitis aguda',
        assistantOutput: raw,
      );
      expect(out, raw);
    });

    test('does not touch unrelated pathology output', () {
      const raw = """
🚨 Conducta inmediata:
* Solicitar TC abdomen/pelvis para confirmar y valorar gravedad.
* Antibióticos solo si hay inmunocompromiso o empeoramiento.
""";

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'apendicitis aguda',
        assistantOutput: raw,
      );
      expect(out, raw);
    });

    test('is idempotent after diverticulitis correction', () {
      const raw = """
* Solicitar TC abdomen/pelvis para confirmar y valorar gravedad.
* Antibióticos solo si hay inmunocompromiso o empeoramiento de síntomas.
""";

      final once = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulitis aguda',
        assistantOutput: raw,
      );
      final twice = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulitis aguda',
        assistantOutput: once,
      );
      expect(twice, once);
    });

    test('common post-provider seam binds consistency guard before return', () {
      final provider = File('lib/providers/app_provider.dart').readAsStringSync();
      final seamStart =
          provider.indexOf('String _applyPlantaoClinicalRegimenOutputGuard({');
      final seamEnd = provider.indexOf(
        '// ── MICRO-BUILD 462E-A.5.3.7.3.2.3',
        seamStart,
      );
      expect(seamStart, greaterThanOrEqualTo(0));
      expect(seamEnd, greaterThan(seamStart));
      final seam = provider.substring(seamStart, seamEnd);
      expect(seam, contains('final consistencyGuardedText ='));
      expect(seam, contains('PlantaoClinicalResponseConsistencyGuard.enforce('));
      expect(seam, contains('assistantOutput: result.text,'));
      expect(seam, contains('final tep2026GuardedText ='));
      expect(seam, contains('Tep2026PlantaoResponseGuard.materialize('));
      expect(seam, contains('final iamcestKillipGuardedText ='));
      expect(
        seam,
        contains('PlantaoIamcestKillipClassificationGuard.materialize('),
      );
      expect(seam, contains('return iamcestKillipGuardedText;'));
      final regimenIndex =
          seam.indexOf('PlantaoClinicalRegimenOutputGuard.enforce(');
      final consistencyIndex =
          seam.indexOf('PlantaoClinicalResponseConsistencyGuard.enforce(');
      final tepIndex = seam.indexOf('Tep2026PlantaoResponseGuard.materialize(');
      final iamIndex =
          seam.indexOf('PlantaoIamcestKillipClassificationGuard.materialize(');
      final returnIndex = seam.indexOf('return iamcestKillipGuardedText;');
      expect(regimenIndex, lessThan(consistencyIndex));
      expect(consistencyIndex, lessThan(tepIndex));
      expect(tepIndex, lessThan(iamIndex));
      expect(iamIndex, lessThan(returnIndex));
    });

    test('all existing common seam call sites remain wired', () {
      final provider = File('lib/providers/app_provider.dart').readAsStringSync();
      expect(
        RegExp(r'_applyPlantaoClinicalRegimenOutputGuard\(')
            .allMatches(provider)
            .length,
        greaterThanOrEqualTo(12),
      );
      expect(
        RegExp(r'PlantaoClinicalResponseConsistencyGuard\.enforce\(')
            .allMatches(provider)
            .length,
        greaterThanOrEqualTo(3),
      );
    });
  });
}
