import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão pleural effusion/empyema runtime richness V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('recognizes pleural infection before general effusion', () {
      final infection = source.indexOf('if (isPleuralInfection)');
      final effusion = source.indexOf('if (isPleuralEffusion)');
      expect(infection, greaterThanOrEqualTo(0));
      expect(effusion, greaterThan(infection));
      expect(source, contains("folded.contains('empiema')"));
      expect(source, contains("folded.contains('derrame pleural complicado')"));
    });

    test('frank pus drains without waiting for pH', () {
      expect(source, contains('francamente purulento (empiema)'));
      expect(source, contains('NAO esperar pH para decidir a drenagem'));
      expect(source, contains('NO esperar pH para decidir el drenaje'));
    });

    test('uses BTS 2023 pH risk thresholds', () {
      expect(source, contains('pH <=7,20'));
      expect(source, contains('pH >7,20 e <7,40'));
      expect(source, contains('pH >=7,40'));
      expect(source, contains('pH <=7.20'));
      expect(source, contains('pH >7.20 y <7.40'));
      expect(source, contains('pH >=7.40'));
    });

    test('intermediate pH uses LDH 900 and clinical context', () {
      expect(source, contains('LDH >900 UI/L'));
      expect(source, contains('febre persistente'));
      expect(source, contains('septacoes ao ultrassom'));
      expect(source, contains('fiebre persistente'));
      expect(source, contains('septaciones en ecografia'));
    });

    test('pH unavailable can use glucose below 3.3 mmol/L', () {
      expect(source, contains('glicose pleural <3,3 mmol/L (~60 mg/dL)'));
      expect(source, contains('glucosa pleural <3.3 mmol/L (~60 mg/dL)'));
    });

    test('initial pleural infection drainage is small bore', () {
      expect(source, contains('dreno de pequeno calibre <=14F'));
      expect(source, contains('tubo de pequeno calibre <=14F'));
    });

    test('residual collection can receive combined tPA DNase only', () {
      expect(source, contains('tPA 10 mg + DNase 5 mg'));
      expect(source, contains('duas vezes ao dia por 3 dias'));
      expect(source, contains('dos veces al dia durante 3 dias'));
      expect(source, contains('NAO usar tPA isolada nem DNase isolada'));
      expect(source, contains('NO usar tPA sola ni DNase sola'));
    });

    test('general effusion uses Light criteria without automatic drain', () {
      expect(source, contains('proteina pleura/soro >0,5'));
      expect(source, contains('LDH pleura/soro >0,6'));
      expect(source, contains('LDH pleural >2/3'));
      expect(source, contains('criterios de Light NAO significa por si so indicacao de dreno'));
      expect(source, contains('criterios de Light NO significa por si mismo que haya que colocar drenaje'));
    });

    test('diagnostic thoracentesis is ultrasound guided', () {
      expect(source, contains('toracocentese diagnostica deve ser guiada por ultrassom'));
      expect(source, contains('toracocentesis diagnostica debe ser guiada por ecografia'));
    });

    test('preserves previous thoracic guards', () {
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_HIPERTENSIVO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ABERTO'));
      expect(source, contains('AUTORIDADE_FINAL_HEMOTORAX_MACICO'));
      expect(source, contains('AUTORIDADE_FINAL_HEMOTORAX_PEQUENO_MODERADO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_SIMPLES_TRAUMATICO'));
      expect(source, contains('AUTORIDADE_FINAL_PNEUMOTORAX_ESPONTANEO'));
    });
  });
}
