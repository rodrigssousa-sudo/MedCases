import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_iamcest_killip_classification_guard.dart';

void main() {
  const physicalCase = '''
CASO FICTICIO DE HOMOLOGACIÓN:
Varón de 58 años con dolor retroesternal opresivo de 50 minutos, irradiado al brazo izquierdo, con náuseas. ECG con elevación persistente del ST en V2–V5. Troponina elevada. PA 128/78 mmHg, FC 86 lpm, SpO₂ 96% al aire ambiente. Está consciente, bien perfundido. Auscultación pulmonar sin estertores. Sin edema periférico ni ingurgitación yugular.
¿Cuál es el diagnóstico, cuál es la clasificación del IAM y cuál es la clase de Killip? Explica qué significa esa clase, por qué corresponde a este paciente y cuál es la conducta inicial.
''';

  group('M55E R8 visible provider numbering artifact final close', () {
    test(
        'exact physical provider artifacts 3 and 4 are removed from visible pharmacologic lanes',
        () {
      const providerRaw = '''
🟥 CONDUCTA CLÍNICA INMEDIATA
IAMCEST (Infarto Agudo de Miocardio con Elevación del Segmento ST)

Conducta inmediata:
- Activar estrategia de reperfusión inmediata.

Tratamiento farmacológico:
- Antiagregación: 3. AAS 300 mg VO masticar + Ticagrelor 180 mg VO (o Prasugrel 60 mg si ICP).
- 4. Anticoagulación: HNF 60–70 UI/kg IV bolo (máx. 5000 UI).

Clasificación:
Killip Clase I.
''';

      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: physicalCase,
        assistantOutput: providerRaw,
        languageCode: 'es',
      );

      expect(out, contains('Antiagregación: AAS 300 mg VO masticar'));
      expect(out, contains('Anticoagulación: HNF 60–70 UI/kg IV bolo'));
      expect(out, isNot(contains('Antiagregación: 3.')));
      expect(out, isNot(contains('Antiagregación: 3)')));
      expect(out, isNot(contains('- 4. Anticoagulación')));
      expect(out, isNot(contains('Anticoagulación: 4.')));
      expect(out, isNot(contains('Anticoagulación: 4)')));
      final numberedArtifacts = out
          .split('\n')
          .map((line) => line.trimLeft())
          .where(
            (line) =>
                line.startsWith('- 3.') ||
                line.startsWith('- 3)') ||
                line.startsWith('- 4.') ||
                line.startsWith('- 4)'),
          )
          .toList();
      expect(numberedArtifacts, isEmpty);
    });

    test('normal provider medication lines remain semantically unchanged', () {
      const providerRaw = '''
IAMCEST (Infarto Agudo de Miocardio con Elevación del Segmento ST)
Tratamiento farmacológico:
- Antiagregación: AAS 300 mg VO masticar + Ticagrelor 180 mg VO.
- Anticoagulación parenteral según la estrategia de reperfusión y contraindicaciones.
''';

      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: physicalCase,
        assistantOutput: providerRaw,
        languageCode: 'es',
      );

      expect(
          out,
          contains(
              'Antiagregación: AAS 300 mg VO masticar + Ticagrelor 180 mg VO.'));
      expect(
          out,
          contains(
              'Anticoagulación parenteral según la estrategia de reperfusión y contraindicaciones.'));
      expect(out, contains('AAS 300 mg'));
      expect(out, contains('Ticagrelor 180 mg'));
    });

    test(
        'stacked leading list plus ordinal marker is stripped without touching dose numbers',
        () {
      const providerRaw = '''
IAMCEST (Infarto Agudo de Miocardio con Elevación del Segmento ST)
Tratamiento farmacológico:
- 3. AAS 300 mg VO masticar + Ticagrelor 180 mg VO.
- 4. Anticoagulación: HNF 60–70 UI/kg IV bolo.
''';

      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: physicalCase,
        assistantOutput: providerRaw,
        languageCode: 'es',
      );

      expect(
          out,
          contains(
              'Antiagregación: AAS 300 mg VO masticar + Ticagrelor 180 mg VO.'));
      expect(out, contains('Anticoagulación: HNF 60–70 UI/kg IV bolo.'));
      expect(out, contains('300 mg'));
      expect(out, contains('180 mg'));
      expect(out, contains('60–70 UI/kg'));
      expect(out, isNot(contains('- 3.')));
      expect(out, isNot(contains('- 4.')));
    });
  });
}
