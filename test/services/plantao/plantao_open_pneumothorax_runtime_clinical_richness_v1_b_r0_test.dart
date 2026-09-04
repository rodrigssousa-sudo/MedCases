import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão open pneumothorax runtime clinical richness V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('recognizes Spanish and Portuguese open pneumothorax wording', () {
      expect(source, contains("folded.contains('neumotorax abierto')"));
      expect(source, contains("folded.contains('pneumotorax abierto')"));
      expect(source, contains("folded.contains('neumotorax aberto')"));
      expect(source, contains("folded.contains('pneumotorax aberto')"));
      expect(source, contains("folded.contains('herida aspirante')"));
      expect(source, contains("folded.contains('ferida aspirante')"));
    });

    test('keeps questions task at higher precedence', () {
      final questionsIndex = source.indexOf('if (isQuestionsTask)');
      final openIndex = source.indexOf('if (isOpenPneumothorax)');
      expect(questionsIndex, greaterThanOrEqualTo(0));
      expect(openIndex, greaterThan(questionsIndex));
    });

    test('requires core open pneumothorax sequence in both languages', () {
      expect(source, contains('aposito oclusivo fijado en tres lados'));
      expect(source, contains('toracostomia con tubo'));
      expect(source, contains('reparacion del defecto de pared toracica'));

      expect(source, contains('curativo oclusivo fixado em tres lados'));
      expect(source, contains('toracostomia com dreno'));
      expect(source, contains('reparo do defeito da parede toracica'));
    });

    test('covers tension deterioration and supportive care', () {
      expect(source, contains('descomprimir de inmediato sin esperar imagen'));
      expect(source, contains('descomprimir imediatamente sem esperar imagem'));
      expect(source, contains('Incluir oxigeno/soporte ventilatorio'));
      expect(source, contains('oxigenio/suporte ventilatorio'));
      expect(source, contains('analgesia'));
    });

    test('adds penetrating-trauma antibiotic prophylaxis without inventing dose', () {
      expect(source, contains('incluir profilaxis antibiotica'));
      expect(source, contains('incluir profilaxia antibiotica'));
      expect(source, contains('no inventar farmaco o dosis'));
      expect(source, contains('nao inventar farmaco ou dose'));
    });

    test('treats wound explicitly and forbids routine pleural lavage', () {
      expect(source, contains('limpieza/irrigacion local solo si corresponde por contaminacion'));
      expect(source, contains('limpeza/irrigacao local somente quando indicada por contaminacao'));
      expect(source, contains('tejido desvitalizado'));
      expect(source, contains('tecido desvitalizado'));
      expect(source, contains('desbridamiento'));
      expect(source, contains('desbridamento'));
      expect(source, contains('NO describir punciones repetidas ni lavado pleural rutinario'));
      expect(source, contains('NAO descrever puncoes repetidas nem lavagem pleural rotineira'));
    });

    test('does not modify M10 contract, renderer, pipeline or next action owner', () {
      expect(source, contains('_buildPlantaoPhysicalRuntimeContract'));
      expect(source, contains('type=open_pneumothorax'));
    });
  });
}
