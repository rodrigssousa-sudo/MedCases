import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão abdomen/renal/hepatic/GI/trauma 10-pathology super bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all ten final authority guards exist', () {
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
      ]) {
        expect(source, contains(token));
      }
    });

    test('solid organ trauma is physiology-first and CT-based when stable', () {
      expect(source, contains('A fisiologia manda sobre o grau anatomico'));
      expect(source, contains('eFAST e ferramenta rapida para hemoperitonio'));
      expect(source, contains('TC contrastada e o exame principal'));
      expect(source, contains('fase excretora/tardia'));
    });

    test('solid organ trauma preserves NOM and angioembolization routes', () {
      expect(source, contains('favorecer manejo nao operatorio'));
      expect(source, contains('embolizacao da arteria esplenica e estrategia de primeira linha'));
      expect(source, contains('embolizacao seletiva e util para extravasamento ativo'));
      expect(source, contains('Nao indicar laparotomia, esplenectomia, hepatectomia ou nefrectomia apenas pelo grau AAST isolado'));
    });

    test('acute cholangitis uses Tokyo severity and urgent source control', () {
      expect(source, contains('Classificar gravidade pelos Tokyo Guidelines'));
      expect(source, contains('Grau III/disfuncao organica'));
      expect(source, contains('Grau II: drenagem biliar precoce'));
      expect(source, contains('CPRE/ERCP e a via preferida'));
    });

    test('perforated viscus gets CT antibiotics and urgent surgical source control', () {
      expect(source, contains('TC de abdomen/pelve com contraste e o exame principal'));
      expect(source, contains('antibioticos IV de amplo espectro'));
      expect(source, contains('controle de foco cirurgico urgente'));
      expect(source, contains('Manejo nao operatorio NAO e rotina na ulcera perfurada'));
    });

    test('mesenteric ischemia does not wait for lactate and gets CTA', () {
      expect(source, contains('lactato normal NAO exclui isquemia precoce'));
      expect(source, contains('angio-TC arterial/venosa SEM DEMORA'));
      expect(source, contains('Nao esperar lactato confirmar o quadro'));
    });

    test('mesenteric ischemia distinguishes arterial MVT and NOMI routes', () {
      expect(source, contains('priorizar revascularizacao endovascular ou aberta'));
      expect(source, contains('Trombose venosa mesenterica sem peritonite: anticoagulacao sistemica'));
      expect(source, contains('NOMI: corrigir causa de baixo fluxo'));
      expect(source, contains('second-look em 24-48 h'));
    });

    test('infected obstructed kidney requires urgent drainage plus antibiotics', () {
      expect(source, contains('urgencia urologica'));
      expect(source, contains('antibioticos IV imediatamente'));
      expect(source, contains('cateter ureteral duplo J ou nefrostomia percutanea'));
      expect(source, contains('Adiar ureteroscopia/litotripsia'));
    });

    test('GI bleeding uses restrictive transfusion and correct low-risk GBS', () {
      expect(source, contains('limiar de Hb em torno de 7 g/dL'));
      expect(source, contains('Glasgow-Blatchford 0-1'));
      expect(source, contains('endoscopia alta em ate 24 h'));
    });

    test('variceal GI bleed starts vasoactive antibiotics and 12h endoscopy', () {
      expect(source, contains('iniciar farmaco vasoativo e profilaxia antibiotica'));
      expect(source, contains('endoscopia em ate 12 h'));
      expect(source, contains('ligadura e tratamento endoscopico preferido'));
    });

    test('lower GI significant bleeding gets CTA and IR route', () {
      expect(source, contains('HDB com hematoquezia hemodinamicamente significativa'));
      expect(source, contains('angio-TC e estrategia inicial util'));
      expect(source, contains('radiologia intervencionista/embolizacao'));
      expect(source, contains('Nao usar acido tranexamico rotineiramente'));
    });

    test('bowel obstruction identifies red flags for immediate surgery', () {
      expect(source, contains('Peritonite, estrangulamento/isquemia, perfuracao'));
      expect(source, contains('cirurgia urgente'));
      expect(source, contains('NAO prolongar manejo conservador'));
    });

    test('adhesive SBO permits monitored NOM and water soluble contrast', () {
      expect(source, contains('Obstrucao adesiva sem sinais de isquemia/peritonite'));
      expect(source, contains('contraste hidrossoluvel'));
      expect(source, contains('tentativa nao operatoria de ate ~72 h'));
    });

    test('acute pancreatitis uses revised diagnosis and severity logic', () {
      expect(source, contains('Confirmar com pelo menos 2 de 3'));
      expect(source, contains('BISAP ajuda a estratificar risco'));
      expect(source, contains('falencia organica persistente >48 h'));
    });

    test('acute pancreatitis rejects fixed aggressive hydration and prophylactic antibiotics', () {
      expect(source, contains('MODERADAMENTE agressiva e individualizada'));
      expect(source, contains('NAO usar hidratacao agressiva fixa para todos'));
      expect(source, contains('NAO usar antibioticos profilaticos na pancreatite necrosante esteril'));
      expect(source, contains('24-48 h conforme tolerancia'));
    });

    test('acute pancreatitis limits CT and urgent ERCP appropriately', () {
      expect(source, contains('Nao realizar TC contrastada rotineiramente na admissao'));
      expect(source, contains('apos 48-72 h'));
      expect(source, contains('Pancreatite biliar com colangite concomitante: CPRE precoce'));
      expect(source, contains('NAO realizar CPRE urgente de rotina'));
    });

    test('acute cholecystitis uses ultrasound and index admission surgery', () {
      expect(source, contains('ultrassom de hipocondrio direito e o exame inicial preferido'));
      expect(source, contains('colecistectomia laparoscopica precoce durante a internacao indice'));
      expect(source, contains('colecistectomia subtotal'));
      expect(source, contains('colecistite isolada NAO indica CPRE rotineira'));
    });

    test('acute appendicitis uses scores as stratification not diagnosis', () {
      expect(source, contains('NAO confirmar nem excluir apenas por Alvarado/AIR'));
      expect(source, contains('TC tem alta acuracia em adultos'));
    });

    test('acute appendicitis allows selected antibiotic NOM without appendicolith', () {
      expect(source, contains('apendicite NAO complicada e sem apendicolito'));
      expect(source, contains('tratamento antibiotico nao operatorio pode ser discutido'));
      expect(source, contains('apendicolito aumenta risco de falha'));
    });

    test('appendicitis surgery and antibiotic stewardship are preserved', () {
      expect(source, contains('Apendicectomia laparoscopica e o tratamento padrao'));
      expect(source, contains('demora intra-hospitalar de ate 24 h'));
      expect(source, contains('NAO requer antibioticos pos-operatorios prolongados'));
    });

    test('thoracic critical bundle remains fully present', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
        'AUTORIDADE_FINAL_LESAO_AORTICA_TRAUMATICA_BTAI',
        'AUTORIDADE_FINAL_LESAO_TRAQUEOBRONQUICA_TRAUMATICA',
        'AUTORIDADE_FINAL_LESAO_ESOFAGICA_TRAUMATICA',
        'AUTORIDADE_FINAL_LESAO_DIAFRAGMATICA_TRAUMATICA',
        'AUTORIDADE_FINAL_LESAO_CARDIACA_CONTUSA_BCI',
        'AUTORIDADE_FINAL_TORAX_INSTAVEL',
        'AUTORIDADE_FINAL_CONTUSAO_PULMONAR',
        'AUTORIDADE_FINAL_FRATURAS_COSTAIS',
      ]) {
        expect(source, contains(token));
      }
    });

    test('abdominal bundle is placed before PCR owner without moving PCR', () {
      final appendicitis = source.indexOf('if (isAcuteAppendicitis)');
      final pcr = source.indexOf('final isPcr =');
      expect(appendicitis, greaterThanOrEqualTo(0));
      expect(pcr, greaterThan(appendicitis));
    });
  });
}
