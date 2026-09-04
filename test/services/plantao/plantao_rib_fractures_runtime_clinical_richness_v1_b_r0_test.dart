import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão rib fractures runtime richness V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('recognizes PT ES and English rib fracture terminology', () {
      expect(source, contains("folded.contains('fratura costal')"));
      expect(source, contains("folded.contains('fraturas costais')"));
      expect(source, contains("folded.contains('fractura costal')"));
      expect(source, contains("folded.contains('fracturas costales')"));
      expect(source, contains("folded.contains('rib fracture')"));
    });

    test('uses nonoperative multimodal analgesia and pulmonary hygiene', () {
      expect(source, contains('tratamento nao operatorio com analgesia multimodal eficaz'));
      expect(source, contains('higiene pulmonar/fisioterapia respiratoria'));
      expect(source, contains('espirometria de incentivo'));
      expect(source, contains('tratamiento no operatorio con analgesia multimodal eficaz'));
      expect(source, contains('higiene pulmonar/fisioterapia respiratoria'));
    });

    test('does not mandate intubation for isolated rib fracture', () {
      expect(source, contains('NAO intubar pela fratura costal isolada'));
      expect(source, contains('NO intubar por la fractura costal aislada'));
    });

    test('allows regional analgesia without imposing one universal technique', () {
      expect(source, contains('paravertebral, epidural, erector spinae ou serratus anterior'));
      expect(source, contains('nao impor uma tecnica como universal'));
      expect(source, contains('paravertebral, epidural, erector spinae o serrato anterior'));
      expect(source, contains('no imponer una tecnica como universal'));
    });

    test('considers SSRF for three or more severely displaced ipsilateral ribs', () {
      expect(source, contains('>=3 fraturas ipsilaterais severamente deslocadas das costelas 3-10'));
      expect(source, contains('>=3 fracturas ipsilaterales severamente desplazadas de costillas 3-10'));
    });

    test('uses persistent respiratory derangements in nonventilated patients', () {
      expect(source, contains('FR >20/min'));
      expect(source, contains('espirometria de incentivo <50% prevista'));
      expect(source, contains('dolor >5/10'));
      expect(source, contains('tos pobre'));
    });

    test('allows severe refractory pain as individualized SSRF reason', () {
      expect(source, contains('Dor intensa persistente nao responsiva a outras medidas'));
      expect(source, contains('Dolor severo persistente no respondedor a otras medidas'));
    });

    test('uses early SSRF timing and delayed fallback window', () {
      expect(source, contains('objetivo precoce 48-72 h apos o trauma'));
      expect(source, contains('dentro de 3-7 dias'));
      expect(source, contains('objetivo temprano 48-72 h desde el trauma'));
    });

    test('active hemodynamic instability blocks routine SSRF', () {
      expect(source, contains('Instabilidade hemodinamica ativa'));
      expect(source, contains('NAO realizar SSRF rotineira ate estabilizacao'));
      expect(source, contains('Inestabilidad hemodinamica activa'));
      expect(source, contains('NO realizar SSRF rutinaria hasta estabilizacion'));
    });

    test('does not automatically fix single or minimally displaced fracture', () {
      expect(source, contains('Fratura unica ou pouco deslocada sem deterioracao respiratoria NAO implica SSRF automatica'));
      expect(source, contains('Fractura unica o poco desplazada sin deterioro respiratorio NO implica SSRF automatica'));
    });

    test('preserves flail chest and pulmonary contusion precedence', () {
      final flail = source.indexOf('if (isFlailChest)');
      final contusion = source.indexOf('if (isPulmonaryContusion)');
      final rib = source.indexOf('if (isRibFracture)');
      expect(flail, greaterThanOrEqualTo(0));
      expect(contusion, greaterThan(flail));
      expect(rib, greaterThan(contusion));
    });

    test('preserves prior thoracic and pleural guards', () {
      expect(source, contains('AUTORIDADE_FINAL_TORAX_INSTAVEL'));
      expect(source, contains('AUTORIDADE_FINAL_CONTUSAO_PULMONAR'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_HIPERTENSIVO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ABERTO'));
      expect(source, contains('AUTORIDADE_FINAL_HEMOTORAX_MACICO'));
      expect(source, contains('AUTORIDADE_FINAL_HEMOTORAX_PEQUENO_MODERADO'));
      expect(source, contains('AUTORIDADE_FINAL_INFECCAO_PLEURAL_EMPIEMA'));
      expect(source, contains('AUTORIDADE_FINAL_DERRAME_PLEURAL'));
    });
  });
}
