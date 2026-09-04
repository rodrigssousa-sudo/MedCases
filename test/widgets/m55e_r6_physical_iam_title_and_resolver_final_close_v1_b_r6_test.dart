import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';

void main() {
  group('M55E R6 exact physical IAM final close', () {
    test(
        'generic clinical task title is rejected and IAMCEST becomes canonical disease title',
        () {
      const raw = '''
CONDUCTA CLÍNICA INMEDIATA
IAMCEST (Infarto Agudo de Miocardio con Elevación del Segmento ST)
Conducta inmediata:
- Activar estrategia de reperfusión inmediata.
''';
      final title = GuardiaM55ePresentationPolicy.canonicalDiseaseTitle(
        parsedDiagnosis: 'CONDUCTA CLÍNICA INMEDIATA',
        rawText: raw,
        isSpanish: true,
      );
      expect(
          title, 'INFARTO AGUDO DE MIOCARDIO CON ELEVACIÓN DEL ST (IAMCEST)');
      expect(title, isNot('CONDUCTA CLÍNICA INMEDIATA'));
    });

    test(
        'exact physical IAMCEST Killip I/no congestion cannot resolve iam_congestao',
        () {
      const user =
          '''Varón de 58 años con dolor retroesternal opresivo de 50 minutos, irradiado al brazo izquierdo, con náuseas. ECG con elevación persistente del ST en V2–V5. Troponina elevada. PA 128/78 mmHg, FC 86 lpm, SpO₂ 96% al aire ambiente. Está consciente, bien perfundido. Auscultación pulmonar sin estertores. Sin edema periférico ni ingurgitación yugular. ¿Cuál es el diagnóstico, cuál es la clasificación del IAM y cuál es la clase de Killip? Explica qué significa esa clase, por qué corresponde a este paciente y cuál es la conducta inicial.''';
      const ai = '''
INFARTO AGUDO DE MIOCARDIO CON ELEVACIÓN DEL ST (IAMCEST)
Conducta inmediata:
- Activar reperfusión / ICP primaria.
Tratamiento farmacológico:
- Antiagregación y anticoagulación.
Clasificación:
Killip Clase I. Sin signos clínicos de insuficiencia cardíaca.
''';
      final result = ClinicalReferenceResolver.resolve(
        userText: user,
        aiText: ai,
        lang: 'es',
      );
      expect(result.protocolId, 'iam_supra');
      expect(result.protocolId, isNot('iam_congestao'));
      expect(result.sourceType, 'clinical_protocol');
    });

    test('true positive congestion still resolves iam_congestao', () {
      final result = ClinicalReferenceResolver.resolve(
        userText:
            'IAMCEST confirmado con edema agudo de pulmón, estertores y Killip III.',
        aiText: 'INFARTO AGUDO DE MIOCARDIO CON ELEVACIÓN DEL ST (IAMCEST)',
        lang: 'es',
      );
      expect(result.protocolId, 'iam_congestao');
    });
  });
}
