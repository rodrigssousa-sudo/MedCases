import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão traumatic cardiac tamponade runtime richness V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('requires tamponade term plus traumatic context', () {
      expect(source, contains('final hasTamponadeTerm ='));
      expect(source, contains('final hasTraumaticTamponadeContext ='));
      expect(source, contains('hasTamponadeTerm && hasTraumaticTamponadeContext'));
      expect(source, contains("folded.contains('tamponamento cardiaco')"));
      expect(source, contains("folded.contains('taponamiento cardiaco')"));
      expect(source, contains("folded.contains('cardiac tamponade')"));
    });

    test('does not capture nontraumatic tamponade by term alone', () {
      final traumaticExpression =
          source.indexOf('hasTamponadeTerm && hasTraumaticTamponadeContext');
      expect(traumaticExpression, greaterThanOrEqualTo(0));
      expect(source, isNot(contains('final isTraumaticCardiacTamponade = hasTamponadeTerm;')));
    });

    test('uses eFAST POCUS without CT delay in unstable high suspicion', () {
      expect(source, contains('Usar eFAST/POCUS a beira-leito'));
      expect(source, contains('NAO atrasar intervencao definitiva por TC'));
      expect(source, contains('Usar eFAST/POCUS a pie de cama'));
      expect(source, contains('NO retrasar intervencion definitiva por TC'));
    });

    test('surgical decompression and repair are definitive in traumatic tamponade', () {
      expect(source, contains('priorizar descompressao CIRURGICA do pericardio e reparo da lesao cardiaca/vascular como tratamento definitivo'));
      expect(source, contains('priorizar descompresion QUIRURGICA del pericardio y reparacion de la lesion cardiaca/vascular como tratamiento definitivo'));
    });

    test('needle pericardiocentesis is bridge not definitive treatment', () {
      expect(source, contains('pericardiocentese por agulha NAO e tratamento definitivo'));
      expect(source, contains('apenas como ponte temporaria'));
      expect(source, contains('pericardiocentesis con aguja NO es tratamiento definitivo'));
      expect(source, contains('solo como puente temporal'));
    });

    test('stable equivocal hemopericardium gets surgical involvement and pericardial window consideration', () {
      expect(source, contains('Paciente estavel com suspeita de hemopericardio'));
      expect(source, contains('considerar janela pericardica'));
      expect(source, contains('Paciente estable con sospecha de hemopericardio'));
      expect(source, contains('considerar ventana pericardica'));
    });

    test('penetrating traumatic arrest selected thoracotomy uses less than 15 minutes', () {
      expect(source, contains('trauma toracico penetrante com tamponamento'));
      expect(source, contains('toracotomia ressuscitativa'));
      expect(source, contains('tempo desde a parada <15 min'));
      expect(source, contains('trauma toracico penetrante con taponamiento'));
      expect(source, contains('toracotomia resucitativa'));
      expect(source, contains('tiempo desde el paro es <15 min'));
    });

    test('supports hemostatic resuscitation for concomitant hemorrhagic shock', () {
      expect(source, contains('choque hemorragico concomitante'));
      expect(source, contains('ressuscitacao hemostatica/hemocomponentes'));
      expect(source, contains('shock hemorrágico concomitante'));
      expect(source, contains('reanimacion hemostatica/hemocomponentes'));
    });

    test('REBOA is not used to treat pericardial tamponade', () {
      expect(source, contains('REBOA nao e indicada para tratar tamponamento pericardico'));
      expect(source, contains('REBOA no esta indicada para tratar taponamiento pericardico'));
    });

    test('preserves previous thoracic guards', () {
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_HIPERTENSIVO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ABERTO'));
      expect(source, contains('AUTORIDADE_FINAL_HEMOTORAX_MACICO'));
      expect(source, contains('AUTORIDADE_FINAL_TORAX_INSTAVEL'));
      expect(source, contains('AUTORIDADE_FINAL_CONTUSAO_PULMONAR'));
      expect(source, contains('AUTORIDADE_FINAL_FRATURAS_COSTAIS'));
      expect(source, contains('AUTORIDADE_FINAL_INFECCAO_PLEURAL_EMPIEMA'));
      expect(source, contains('AUTORIDADE_FINAL_DERRAME_PLEURAL'));
    });

    test('tamponade guard precedes flail chest and pulmonary contusion', () {
      final tamponade = source.indexOf('if (isTraumaticCardiacTamponade)');
      final flail = source.indexOf('if (isFlailChest)');
      final contusion = source.indexOf('if (isPulmonaryContusion)');
      expect(tamponade, greaterThanOrEqualTo(0));
      expect(flail, greaterThan(tamponade));
      expect(contusion, greaterThan(flail));
    });
  });
}
