import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão simple/spontaneous pneumothorax runtime richness V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('keeps simple traumatic and spontaneous as separate routes', () {
      expect(source, contains('isSimpleTraumaticPneumothorax'));
      expect(source, contains('isSpontaneousPneumothorax'));
      expect(source.contains('SIMPLE_EQUALS_SPONTANEOUS'), isFalse);
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_SIMPLES_TRAUMATICO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ESPONTANEO'));
    });

    test('simple traumatic route requires trauma context', () {
      expect(source, contains('final hasTraumaContext'));
      expect(source, contains("folded.contains('trauma')"));
      expect(source, contains("folded.contains('traumatico')"));
      expect(source, contains('isSimplePneumothorax && hasTraumaContext'));
    });

    test('small stable traumatic PNX supports 24h observation', () {
      expect(source, contains('pequeno (ate 2 cm)'));
      expect(source, contains('por pelo menos 24 h'));
      expect(source, contains('pequeno (hasta 2 cm)'));
      expect(source, contains('durante al menos 24 h'));
    });

    test('traumatic route escalates based on physiology progression or failed observation', () {
      expect(source, contains('comprometimento respiratorio/hemodinamico'));
      expect(source, contains('compromiso respiratorio/hemodinamico'));
      expect(source, contains('falhar observacao'));
      expect(source, contains('falla observacion'));
      expect(source, contains('drenagem pleural com toracostomia'));
      expect(source, contains('drenaje pleural con toracostomia'));
    });

    test('spontaneous route distinguishes PSP and SSP', () {
      expect(source, contains('distinguir primario (PSP) de secundario (SSP)'));
      expect(source, contains('distinguir primario (PSP) de secundario (SSP)'));
      expect(source, contains('SSP: NAO aplicar automaticamente'));
      expect(source, contains('SSP: NO aplicar automaticamente'));
    });

    test('PSP pathway is symptom physiology based and supports conservative ambulatory care', () {
      expect(source, contains('nao apenas do tamanho radiologico'));
      expect(source, contains('no solo del tamano radiologico'));
      expect(source, contains('considerar manejo conservador'));
      expect(source, contains('considerar manejo ambulatorial'));
      expect(source, contains('considerar manejo ambulatorio'));
    });

    test('PSP intervention prioritizes needle aspiration and escalates if failure', () {
      expect(source, contains('priorizar aspiracao por agulha antes de drenagem toracica'));
      expect(source, contains('priorizar aspiracion con aguja antes que drenaje toracico'));
      expect(source, contains('Se aspiracao falhar'));
      expect(source, contains('Si aspiracion falla'));
    });

    test('preserves prior thoracic runtime guards', () {
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_HIPERTENSIVO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ABERTO'));
      expect(source, contains('AUTORIDADE_FINAL_HEMOTORAX_MACICO'));
    });

    test('runtime precedence keeps questions and life threats before simple/spontaneous', () {
      final q = source.indexOf('if (isQuestionsTask)');
      final tension = source.indexOf('if (isTensionPneumothorax)');
      final open = source.indexOf('if (isOpenPneumothorax)');
      final massive = source.indexOf('if (isMassiveHemothorax)');
      final simple = source.indexOf('if (isSimpleTraumaticPneumothorax)');
      final spont = source.indexOf('if (isSpontaneousPneumothorax)');
      expect(q, greaterThanOrEqualTo(0));
      expect(tension, greaterThan(q));
      expect(open, greaterThan(tension));
      expect(massive, greaterThan(open));
      expect(simple, greaterThan(massive));
      expect(spont, greaterThan(simple));
    });
  });
}
