import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão vascular 10-pathology super bundle V1-B-R0-R1', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all ten vascular authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_SINDROME_COMPARTIMENTAL_AGUDA',
        'AUTORIDADE_FINAL_DISSECCAO_ARTERIAL_CERVICAL',
        'AUTORIDADE_FINAL_PSEUDOANEURISMA_POS_CATETER',
        'AUTORIDADE_FINAL_ANEURISMA_POPLITEO_COMPLICADO',
        'AUTORIDADE_FINAL_AAA_SINTOMATICO_ROTO',
        'AUTORIDADE_FINAL_TROMBOSE_VENOSA_SUPERFICIAL',
        'AUTORIDADE_FINAL_FLEGMASIA_TROMBOSE_VENOSA_MACICA',
        'AUTORIDADE_FINAL_TROMBOSE_VENOSA_PROFUNDA',
        'AUTORIDADE_FINAL_ISQUEMIA_CRONICA_AMEACADORA_MEMBRO',
        'AUTORIDADE_FINAL_ISQUEMIA_AGUDA_MEMBRO',
      ]) {
        expect(source, contains(token));
      }
    });

    test('acute limb ischemia uses Rutherford and immediate heparin', () {
      expect(source, contains('classificar viabilidade por Rutherford'));
      expect(source, contains('Iniciar heparina nao fracionada IV imediatamente salvo contraindicacao'));
      expect(source, contains('Rutherford IIb'));
      expect(source, contains('revascularizacao imediata'));
    });

    test('ALI distinguishes IIa viable and irreversible III', () {
      expect(source, contains('Rutherford IIa permite imagem anatomica urgente'));
      expect(source, contains('Rutherford I e viavel'));
      expect(source, contains('Rutherford III e irreversivel'));
      expect(source, contains('revascularizar pode ser danoso'));
    });

    test('ALI monitors reperfusion complications', () {
      expect(source, contains('sindrome compartimental, hipercalemia, acidose, rabdomiolise e LRA'));
      expect(source, contains('Nao atrasar membro imediatamente ameacado'));
    });

    test('CLTI uses objective perfusion WIfI and revascularization', () {
      expect(source, contains('pressao de pododactilo/TBI, TcPO2'));
      expect(source, contains('Usar WIfI'));
      expect(source, contains('Revascularizacao endovascular, cirurgica ou hibrida e recomendada'));
    });

    test('CLTI integrates wound infection prevention and selective amputation', () {
      expect(source, contains('cuidado da ferida, offloading, controle de infeccao'));
      expect(source, contains('Amputacao primaria fica para membro nao salvavel'));
      expect(source, contains('Nao tratar CLTI como claudicacao simples'));
    });

    test('DVT diagnostic route uses pretest D dimer and compression ultrasound', () {
      expect(source, contains('probabilidade pre-teste validada'));
      expect(source, contains('D-dimero negativo pode excluir TVP'));
      expect(source, contains('ultrassom venoso de compressao/duplex'));
      expect(source, contains('repetir imagem seriada'));
    });

    test('DVT anticoagulates proximal disease and avoids routine thrombolysis or filter', () {
      expect(source, contains('TVP proximal confirmada sem contraindicacao exige anticoagulacao terapeutica'));
      expect(source, contains('Tratamento inicial geralmente dura pelo menos 3 meses'));
      expect(source, contains('Trombolise/trombectomia NAO e rotina para toda TVP'));
      expect(source, contains('Filtro de VCI apenas se anticoagulacao estiver contraindicada'));
    });

    test('DVT guard yields to explicit pulmonary embolism route', () {
      expect(source, contains('final isDeepVeinThrombosis = hasDvtTerms && !hasPulmonaryEmbolismTerms'));
      expect(source, contains('se o caso mencionar TEP, usar a rota especifica de embolia pulmonar'));
    });

    test('phlegmasia is limb-threatening and uses urgent anticoagulation plus clot removal', () {
      expect(source, contains('risco de gangrena venosa, choque e amputacao'));
      expect(source, contains('Iniciar anticoagulacao terapeutica imediata salvo contraindicacao'));
      expect(source, contains('trombolise dirigida por cateter, trombectomia farmacomecanica/mecanica ou trombectomia cirurgica'));
    });

    test('SVT treatment depends on length and distance to deep junction', () {
      expect(source, contains('TVS de membro inferior >=5 cm e a >3 cm'));
      expect(source, contains('aproximadamente 45 dias'));
      expect(source, contains('TVS a <=3 cm da juncao safenofemoral/safenopoplitea'));
      expect(source, contains('Antibioticos NAO sao tratamento de TVS nao infecciosa'));
    });

    test('AAA rupture uses hemorrhage activation controlled resuscitation CTA when tolerated', () {
      expect(source, contains('protocolo hemorragico imediatamente'));
      expect(source, contains('evitar ressuscitacao cristaloide agressiva'));
      expect(source, contains('hipotensao permissiva'));
      expect(source, contains('angio-TC urgente define ruptura e anatomia para EVAR'));
    });

    test('AAA rupture requires emergent repair and no empiric anticoagulation', () {
      expect(source, contains('AAA roto exige reparo emergente'));
      expect(source, contains('EVAR e favorecido quando anatomia, equipe e tempo permitirem'));
      expect(source, contains('Nao anticoagular/trombolizar empiricamente'));
    });

    test('complicated popliteal aneurysm follows acute limb and selective repair route', () {
      expect(source, contains('Trombose aguda pode se apresentar como isquemia aguda de membro'));
      expect(source, contains('heparina nao fracionada salvo contraindicacao'));
      expect(source, contains('exclusao + bypass aberto ou tecnica endovascular'));
      expect(source, contains('aneurisma popliteo contralateral e aneurisma de aorta abdominal'));
    });

    test('postcatheter pseudoaneurysm uses duplex observation threshold and thrombin injection', () {
      expect(source, contains('Duplex vascular e o exame diagnostico de escolha'));
      expect(source, contains('Pseudoaneurisma pequeno (<2 cm)'));
      expect(source, contains('Injecao de trombina guiada por ultrassom'));
      expect(source, contains('Expansao rapida, infeccao, necrose cutanea, isquemia distal'));
    });

    test('cervical dissection permits standard acute stroke reperfusion when eligible', () {
      expect(source, contains('Angio-TC ou angio-RM de cabeca/pescoco'));
      expect(source, contains('NAO exclui trombolise IV nem trombectomia mecanica'));
      expect(source, contains('tratamento antitrombotico habitualmente 3-6 meses'));
      expect(source, contains('Stent/reparo endovascular NAO e primeira linha rotineira'));
    });

    test('acute compartment syndrome is clinical serial and fasciotomy is not delayed', () {
      expect(source, contains('dor ao estiramento passivo'));
      expect(source, contains('parestesia/paralisia e ausencia de pulso sao tardios'));
      expect(source, contains('exames seriados'));
      expect(source, contains('pressao diferencial (PA diastolica - pressao compartimental) <=30 mmHg'));
      expect(source, contains('fasciotomia urgente e completa'));
    });

    test('compartment syndrome does not let testing delay high clinical suspicion', () {
      expect(source, contains('nao atrasar por imagem, CK ou medida de pressao desnecessaria'));
      expect(source, contains('Nao inventar limiar isolado como substituto do exame clinico'));
    });

    test('vascular bundle precedes metabolic bundle', () {
      final vascular = source.indexOf('if (isAcuteCompartmentSyndrome)');
      final ali = source.indexOf('if (isAcuteLimbIschemia)');
      final metabolic = source.indexOf('if (isAdrenalCrisis)');
      expect(vascular, greaterThanOrEqualTo(0));
      expect(ali, greaterThan(vascular));
      expect(metabolic, greaterThan(ali));
    });

    test('previous major bundles remain present', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_CETOACIDOSE_DIABETICA',
        'AUTORIDADE_FINAL_PANCREATITE_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_LESAO_RENAL_AGUDA',
        'AUTORIDADE_FINAL_SINDROME_AORTICA_AGUDA',
        'AUTORIDADE_FINAL_TEP_AGUDO',
        'AUTORIDADE_FINAL_ISQUEMIA_MESENTERICA_AGUDA',
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
