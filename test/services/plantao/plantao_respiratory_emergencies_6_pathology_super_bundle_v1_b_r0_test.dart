import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão respiratory emergencies 6-pathology super bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all six respiratory authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_HEMOPTISE_AMEACADORA_VIDA',
        'AUTORIDADE_FINAL_SDRA_ARDS',
        'AUTORIDADE_FINAL_TEP_AGUDO',
        'AUTORIDADE_FINAL_ASMA_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_EXACERBACAO_DPOC',
        'AUTORIDADE_FINAL_PNEUMONIA_ADQUIRIDA_COMUNIDADE_GRAVE',
      ]) {
        expect(source, contains(token));
      }
    });

    test('life-threatening hemoptysis is physiology not volume defined', () {
      expect(source, contains('Definir gravidade pelo comprometimento de via aerea, troca gasosa e hemodinamica'));
      expect(source, contains('NAO apenas pelo volume estimado de sangue'));
      expect(source, contains('pulmao sangrante para baixo'));
    });

    test('hemoptysis airway bronchoscopy CTA and embolization route exists', () {
      expect(source, contains('broncoscopia precoce'));
      expect(source, contains('angio-TC de torax'));
      expect(source, contains('Embolizacao de arterias bronquicas/sistemicas nao bronquicas e tratamento de primeira linha'));
      expect(source, contains('Cirurgia fica para falha/recorrencia nao controlavel por embolizacao'));
    });

    test('ARDS uses low tidal volume and plateau limit', () {
      expect(source, contains('4-8 mL/kg de peso corporal predito'));
      expect(source, contains('pressao de plato <30 cmH2O'));
    });

    test('ARDS severe uses prolonged prone and avoids prolonged recruitment maneuvers', () {
      expect(source, contains('posicao prona prolongada >12 h/dia'));
      expect(source, contains('NAO usar manobras de recrutamento prolongadas rotineiramente'));
    });

    test('ARDS includes conditional steroids NMB and VV ECMO without rigid universal dosing', () {
      expect(source, contains('Corticoides sistemicos podem ser considerados na ARDS'));
      expect(source, contains('Bloqueio neuromuscular pode ser considerado'));
      expect(source, contains('considerar VV-ECMO em centro experiente'));
    });

    test('PE 2026 keeps Wells only in diagnostic pretest phase', () {
      expect(source, contains('AUTORIDADE_FINAL_TEP_AGUDO_AHA_ACC_2026'));
      expect(source, contains('Depois de confirmar TEP, NÃO usar Wells'));
      expect(source, contains('Wells/Geneva/PERC/YEARS'));
    });

    test('PE 2026 uses A-E subcategories and respiratory modifier R', () {
      for (final token in <String>[
        'B1 subsegmentar',
        'C1 VD e biomarcadores normais',
        'C2 VD anormal OU',
        'C3 VD anormal E',
        'D1 hipotensão transitória',
        'D2 choque normotensivo',
        'E1 hipotensão recorrente/persistente',
        'E2 choque cardiogênico refratário',
        'MODIFICADOR R',
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test('PE 2026 advanced therapy follows category-specific matrix', () {
      expect(source, contains('A-C1 não devem receber reperfusão avançada rotineiramente'));
      expect(source, contains('Em C2, trombólise sistêmica sobre anticoagulação isolada causa dano'));
      expect(source, contains('Em D1-D2 pode-se considerar trombólise sistêmica, CDL ou trombectomia mecânica'));
      expect(source, contains('Em E2 com choque refratário/parada'));
      expect(source, contains('VA-ECMO é razoável'));
    });

    test('acute severe asthma uses SABA ipratropium steroids and controlled oxygen', () {
      expect(source, contains('SABA inalatorio repetido'));
      expect(source, contains('acrescentar ipratropio'));
      expect(source, contains('corticoide sistemico precoce'));
      expect(source, contains('SpO2 aproximadamente 93-95%'));
    });

    test('acute severe asthma uses magnesium and avoids routine antibiotics sedatives', () {
      expect(source, contains('considerar sulfato de magnesio IV'));
      expect(source, contains('Nao usar antibioticos rotineiramente'));
      expect(source, contains('nao usar sedativos'));
    });

    test('acute severe asthma escalates on exhaustion neurologic decline or rising CO2', () {
      expect(source, contains('exaustao'));
      expect(source, contains('elevacao de CO2'));
      expect(source, contains('UTI e preparo para via aerea avancada'));
      expect(source, contains('Nao atrasar intubacao'));
    });

    test('AECOPD uses short acting bronchodilators and five-day steroid course', () {
      expect(source, contains('broncodilatador inalatorio de curta acao'));
      expect(source, contains('com ou sem anticolinergico de curta acao'));
      expect(source, contains('geralmente ate 5 dias conforme GOLD 2026'));
    });

    test('AECOPD antibiotics are indication based and generally five days', () {
      expect(source, contains('escarro purulento com aumento de dispneia/volume'));
      expect(source, contains('necessidade de ventilacao mecanica'));
      expect(source, contains('GOLD 2026 recomenda em geral 5 dias'));
    });

    test('AECOPD uses controlled oxygen and NIV first line for hypercapnic acidosis', () {
      expect(source, contains('SpO2 88-92%'));
      expect(source, contains('VNI e suporte ventilatorio de primeira linha'));
      expect(source, contains('falha da VNI exige avaliar intubacao invasiva'));
      expect(source, contains('Nao usar metilxantinas rotineiramente'));
    });

    test('severe CAP uses ATS IDSA severity rather than CURB alone', () {
      expect(source, contains('criterios ATS/IDSA de CAP grave'));
      expect(source, contains('ventilacao mecanica invasiva ou choque com vasopressores'));
      expect(source, contains('Nao usar CURB-65 como unica decisao de UTI'));
    });

    test('severe CAP starts empiric antibiotics without procalcitonin veto', () {
      expect(source, contains('Iniciar antibioticos empiricos precocemente'));
      expect(source, contains('MRSA/Pseudomonas'));
      expect(source, contains('Nao usar procalcitonina baixa como unica razao para negar antibioticos iniciais'));
    });

    test('ATS 2025 steroid distinction for CAP is present', () {
      expect(source, contains('ATS 2025: NAO usar corticoides sistemicos rotineiramente na CAP nao grave'));
      expect(source, contains('na CAP grave hospitalizada podem ser considerados corticoides sistemicos'));
    });

    test('respiratory bundle precedes abdominal bundle', () {
      final hemoptysis = source.indexOf('if (isLifeThreateningHemoptysis)');
      final ards = source.indexOf('if (isArds)');
      final pe = source.indexOf('if (isAcutePulmonaryEmbolism)');
      final asthma = source.indexOf('if (isAcuteSevereAsthma)');
      final copd = source.indexOf('if (isAecopd)');
      final cap = source.indexOf('if (isSevereCap)');
      final abdomen = source.indexOf('if (isAbdominalSolidOrganTrauma)');
      expect(hemoptysis, greaterThanOrEqualTo(0));
      expect(ards, greaterThan(hemoptysis));
      expect(pe, greaterThan(ards));
      expect(asthma, greaterThan(pe));
      expect(copd, greaterThan(asthma));
      expect(cap, greaterThan(copd));
      expect(abdomen, greaterThan(cap));
    });

    test('abdominal and thoracic retained authorities remain present', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_TRAUMA_ABDOMINAL_ORGAOS_SOLIDOS',
        'AUTORIDADE_FINAL_COLANGITE_AGUDA',
        'AUTORIDADE_FINAL_VISCERA_OCA_PERFURADA',
        'AUTORIDADE_FINAL_ISQUEMIA_MESENTERICA_AGUDA',
        'AUTORIDADE_FINAL_RIM_OBSTRUIDO_INFECTADO',
        'AUTORIDADE_FINAL_HEMORRAGIA_DIGESTIVA_AGUDA',
        'AUTORIDADE_FINAL_OBSTRUCAO_INTESTINAL',
        'AUTORIDADE_FINAL_PANCREATITE_AGUDA',
        'AUTORIDADE_FINAL_COLECISTITE_AGUDA',
        'AUTORIDADE_FINAL_APENDICITE_AGUDA',
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
        'AUTORIDADE_FINAL_LESAO_AORTICA_TRAUMATICA_BTAI',
        'AUTORIDADE_FINAL_TORAX_INSTAVEL',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
