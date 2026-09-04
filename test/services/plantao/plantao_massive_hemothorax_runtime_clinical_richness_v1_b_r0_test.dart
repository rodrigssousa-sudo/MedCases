import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão massive hemothorax runtime clinical richness V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('recognizes massive hemothorax wording in ES PT and English', () {
      expect(source, contains("folded.contains('hemotorax macico')"));
      expect(source, contains("folded.contains('hemotorax masivo')"));
      expect(source, contains("folded.contains('massive hemothorax')"));
    });

    test('keeps questions first and preserves open pneumothorax guard', () {
      final questionsIndex = source.indexOf('if (isQuestionsTask)');
      final openIndex = source.indexOf('if (isOpenPneumothorax)');
      final massiveIndex = source.indexOf('if (isMassiveHemothorax)');
      expect(questionsIndex, greaterThanOrEqualTo(0));
      expect(openIndex, greaterThan(questionsIndex));
      expect(massiveIndex, greaterThan(openIndex));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ABERTO'));
      expect(source, contains('AUTORIDAD_FINAL_NEUMOTORAX_ABIERTO'));
    });

    test('requires tube thoracostomy and hemostatic resuscitation', () {
      expect(source, contains('toracostomia con tubo'));
      expect(source, contains('toracostomia com dreno'));
      expect(source, contains('reanimacion hemostatica con hemoderivados'));
      expect(source, contains('ressuscitacao hemostatica com hemocomponentes'));
    });

    test('uses current operative thresholds with physiologic context', () {
      expect(source, contains('>1500 mL iniciales'));
      expect(source, contains('>1500 mL iniciais'));
      expect(source, contains('>200 mL/h durante 3 horas consecutivas'));
      expect(source, contains('>200 mL/h por 3 horas consecutivas'));
      expect(source, contains('sin otra fuente de sangrado'));
      expect(source, contains('sem outra fonte de sangramento'));
    });

    test('forbids threshold-only decisions and CT delay in instability', () {
      expect(source, contains('El debito del tubo NO decide por si solo'));
      expect(source, contains('O debito do dreno NAO decide isoladamente'));
      expect(source, contains('NO retrasar control quirurgico por TC'));
      expect(source, contains('NAO atrasar controle cirurgico por TC'));
    });

    test('covers persistent shock transfusion and additional operative indications', () {
      expect(source, contains('persiste shock'));
      expect(source, contains('persistirem choque'));
      expect(source, contains('necesidad transfusional'));
      expect(source, contains('necessidade transfusional'));
      expect(source, contains('Hemotorax retenido grande'));
      expect(source, contains('Hemotorax retido volumoso'));
      expect(source, contains('lesion diafragmatica'));
      expect(source, contains('lesao diafragmatica'));
    });

    test('does not invent drug doses or transfusion ratios', () {
      expect(source, contains('NO inventar farmacos, dosis ni proporciones transfusionales'));
      expect(source, contains('NAO inventar farmacos, doses ou proporcoes transfusionais'));
    });
  });
}
