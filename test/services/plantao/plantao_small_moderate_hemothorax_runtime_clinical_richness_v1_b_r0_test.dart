import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão small/moderate hemothorax runtime richness V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('recognizes small and moderate hemothorax wording', () {
      expect(source, contains("folded.contains('hemotorax pequeno')"));
      expect(source, contains("folded.contains('hemotorax moderado')"));
      expect(source, contains("folded.contains('small hemothorax')"));
      expect(source, contains("folded.contains('moderate hemothorax')"));
    });

    test('limits numeric thresholds to traumatic hemothorax', () {
      expect(source, contains('correspondem a hemotorax TRAUMATICO'));
      expect(source, contains('corresponden a hemotorax TRAUMATICO'));
      expect(source, contains('nao extrapola-los automaticamente'));
      expect(source, contains('no extrapolarlos automaticamente'));
    });

    test('supports conservative care below 300 ml only when stable', () {
      expect(source, contains('Traumatico <300 mL e paciente estavel'));
      expect(source, contains('Traumatico <300 mL y paciente estable'));
      expect(source, contains('observacao estreita'));
      expect(source, contains('observacion estrecha'));
    });

    test('requires drainage at 500 ml or more when stable', () {
      expect(source, contains('Traumatico >=500 mL e paciente estavel'));
      expect(source, contains('Traumatico >=500 mL y paciente estable'));
      expect(source, contains('toracostomia/dreno toracico'));
      expect(source, contains('toracostomia/tubo toracico'));
    });

    test('keeps 300 to 499 ml as individualized gray zone', () {
      expect(source, contains('Entre 300-499 mL: NAO inventar limiar rigido'));
      expect(source, contains('Entre 300-499 mL: NO inventar un umbral rigido'));
      expect(source, contains('capacidade de vigilancia'));
      expect(source, contains('capacidad de vigilancia'));
    });

    test('unstable patients drain regardless of estimated volume', () {
      expect(source, contains('independentemente do volume'));
      expect(source, contains('independientemente del volumen'));
      expect(source, contains('aplicar a rota de hemotorax macico'));
      expect(source, contains('aplicar la ruta de hemotorax masivo'));
    });

    test('retained hemothorax favors early VATS and not first-line thrombolysis', () {
      expect(source, contains('VATS precoce, idealmente <=4 dias'));
      expect(source, contains('VATS precoz, idealmente <=4 dias'));
      expect(source, contains('em vez de trombolise como primeira estrategia'));
      expect(source, contains('en vez de trombolisis como primera estrategia'));
    });

    test('antibiotic prophylaxis remains protocol based and dose safe', () {
      expect(source, contains('considerar profilaxia antibiotica no momento da insercao'));
      expect(source, contains('considerar profilaxis antibiotica al momento de insercion'));
      expect(source, contains('nao inventar farmaco, dose ou duracao'));
      expect(source, contains('no inventar farmaco, dosis ni duracion'));
    });

    test('preserves all prior thoracic runtime guards', () {
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_HIPERTENSIVO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ABERTO'));
      expect(source, contains('AUTORIDADE_FINAL_HEMOTORAX_MACICO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_SIMPLES_TRAUMATICO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ESPONTANEO'));
    });

    test('massive hemothorax remains higher precedence', () {
      final massive = source.indexOf('if (isMassiveHemothorax)');
      final smallModerate = source.indexOf('if (isSmallModerateHemothorax)');
      expect(massive, greaterThanOrEqualTo(0));
      expect(smallModerate, greaterThan(massive));
    });
  });
}
