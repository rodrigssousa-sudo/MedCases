import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão flail chest/pulmonary contusion runtime richness V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('recognizes flail chest and pulmonary contusion terminology', () {
      expect(source, contains("folded.contains('torax instavel')"));
      expect(source, contains("folded.contains('volet costal')"));
      expect(source, contains("folded.contains('flail chest')"));
      expect(source, contains("folded.contains('contusao pulmonar')"));
      expect(source, contains("folded.contains('contusion pulmonar')"));
      expect(source, contains("folded.contains('pulmonary contusion')"));
    });

    test('flail chest prioritizes analgesia and pulmonary hygiene', () {
      expect(source, contains('analgesia multimodal e tecnicas regionais'));
      expect(source, contains('fisioterapia respiratoria'));
      expect(source, contains('mobilizacao precoce'));
      expect(source, contains('limpeza de secrecoes'));
    });

    test('does not mandate intubation without respiratory failure', () {
      expect(source, contains('NAO intubar nem manter ventilacao mecanica apenas pelo diagnostico de torax instavel'));
      expect(source, contains('NAO indicar intubacao obrigatoria apenas pela imagem de contusao'));
      expect(source, contains('NO intubar ni mantener ventilacion mecanica solo por el diagnostico de torax inestable'));
      expect(source, contains('NO indicar intubacion obligatoria por la imagen de contusion'));
    });

    test('uses lung protective ventilation if respiratory failure requires support', () {
      expect(source, contains('estrategia protetora pulmonar'));
      expect(source, contains('baixo volume corrente e limitacao de pressoes'));
      expect(source, contains('volumen corriente bajo y limitacion de presiones'));
    });

    test('uses balanced resuscitation without fluid overload or under-resuscitation', () {
      expect(source, contains('evitando sobrecarga volêmica'));
      expect(source, contains('subressuscitar choque'));
      expect(source, contains('evitando sobrecarga de volumen'));
      expect(source, contains('infrarresucitar shock'));
    });

    test('considers SSRF in all flail chest and uses early timing', () {
      expect(source, contains('Considerar estabilizacao cirurgica das fraturas costais (SSRF) em todo paciente com flail chest'));
      expect(source, contains('objetivo precoce 48-72 h apos o trauma'));
      expect(source, contains('dentro de 3-7 dias'));
      expect(source, contains('Considerar estabilizacion quirurgica de fracturas costales (SSRF) en todo paciente con flail chest'));
    });

    test('pulmonary contusion is not an absolute contraindication to SSRF', () {
      expect(source, contains('Contusao pulmonar associada NAO e contraindicacao absoluta para SSRF'));
      expect(source, contains('La contusion pulmonar asociada NO es una contraindicacion absoluta para SSRF'));
    });

    test('active hemodynamic instability does not trigger routine SSRF', () {
      expect(source, contains('Instabilidade hemodinamica ativa'));
      expect(source, contains('nao realizar SSRF rotineira ate estabilizacao'));
      expect(source, contains('Inestabilidad hemodinamica activa'));
      expect(source, contains('no llevar a SSRF rutinaria hasta estabilizacion'));
    });

    test('pulmonary contusion remains primarily supportive', () {
      expect(source, contains('tratamento e principalmente suporte'));
      expect(source, contains('nao existe drenagem ou cirurgia rotineira para contusao isolada'));
      expect(source, contains('tratamiento es principalmente de soporte'));
      expect(source, contains('no existe drenaje o cirugia rutinaria para la contusion aislada'));
    });

    test('preserves previous thoracic and pleural guards', () {
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_HIPERTENSIVO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ABERTO'));
      expect(source, contains('AUTORIDADE_FINAL_HEMOTORAX_MACICO'));
      expect(source, contains('AUTORIDADE_FINAL_HEMOTORAX_PEQUENO_MODERADO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_SIMPLES_TRAUMATICO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ESPONTANEO'));
      expect(source, contains('AUTORIDADE_FINAL_INFECCAO_PLEURAL_EMPIEMA'));
      expect(source, contains('AUTORIDADE_FINAL_DERRAME_PLEURAL'));
    });

    test('flail chest has precedence over isolated pulmonary contusion', () {
      final flail = source.indexOf('if (isFlailChest)');
      final contusion = source.indexOf('if (isPulmonaryContusion)');
      expect(flail, greaterThanOrEqualTo(0));
      expect(contusion, greaterThan(flail));
    });
  });
}
