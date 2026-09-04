import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão tension pneumothorax runtime clinical richness V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('recognizes PT ES and English tension pneumothorax wording', () {
      expect(source, contains("folded.contains('pneumotorax hipertensivo')"));
      expect(source, contains("folded.contains('neumotorax hipertensivo')"));
      expect(source, contains("folded.contains('pneumotorax a tension')"));
      expect(source, contains("folded.contains('neumotorax a tension')"));
      expect(source, contains("folded.contains('tension pneumothorax')"));
    });

    test('questions remains highest precedence and tension outranks open PNX', () {
      final questions = source.indexOf('if (isQuestionsTask)');
      final tension = source.indexOf('if (isTensionPneumothorax)');
      final open = source.indexOf('if (isOpenPneumothorax)');
      final massive = source.indexOf('if (isMassiveHemothorax)');
      expect(questions, greaterThanOrEqualTo(0));
      expect(tension, greaterThan(questions));
      expect(open, greaterThan(tension));
      expect(massive, greaterThan(open));
    });

    test('requires immediate decompression without waiting imaging', () {
      expect(source, contains('NO esperar radiografia, ecografia ni TC'));
      expect(source, contains('NAO esperar radiografia, ultrassom ou TC'));
      expect(source, contains('Descomprimir inmediatamente'));
      expect(source, contains('Descomprimir imediatamente'));
    });

    test('supports finger or needle decompression and definitive chest tube', () {
      expect(source, contains('toracostomia digital/simple'));
      expect(source, contains('toracostomia digital/simples'));
      expect(source, contains('aguja/cateter de gran calibre'));
      expect(source, contains('agulha/cateter de grosso calibre'));
      expect(source, contains('toracostomia con tubo cuanto antes como tratamiento pleural definitivo'));
      expect(source, contains('toracostomia com dreno o quanto antes como tratamento pleural definitivo'));
    });

    test('keeps WSES-AAST emergency needle landmarks conditional to protocol anatomy', () {
      expect(source, contains('2.o espacio intercostal linea medioclavicular'));
      expect(source, contains('5.o espacio intercostal linea medioaxilar'));
      expect(source, contains('2.o espaco intercostal linha hemiclavicular'));
      expect(source, contains('5.o espaco intercostal linha axilar media'));
      expect(source, contains('segun protocolo y anatomia'));
      expect(source, contains('conforme protocolo e anatomia'));
    });

    test('failed decompression triggers immediate reassessment and escalation', () {
      expect(source, contains('Si no mejora, reevaluar posicion/permeabilidad'));
      expect(source, contains('Se nao houver melhora, reavaliar posicao/permeabilidade'));
      expect(source, contains('sin demorar por imagen'));
      expect(source, contains('sem atrasar por imagem'));
    });

    test('preserves prior thoracic guards', () {
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ABERTO'));
      expect(source, contains('AUTORIDADE_FINAL_HEMOTORAX_MACICO'));
    });
  });
}
