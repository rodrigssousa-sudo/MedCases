import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GI 3/3 obstruction volvulus hernia peritonitis 10 pathology super bundle V1-B-R0', () {
    late String ai;
    late String protocols;

    setUpAll(() {
      ai = File('lib/services/ai_service.dart').readAsStringSync();
      protocols = File('lib/data/protocols_database.dart').readAsStringSync();
    });

    String protocolBlock(String id) {
      final marker = "id: '$id'";
      final markerIndex = protocols.indexOf(marker);
      expect(markerIndex, greaterThanOrEqualTo(0), reason: 'missing $id');
      final start = protocols.lastIndexOf('ProtocolModel(', markerIndex);
      final next = protocols.indexOf('\n  ProtocolModel(', markerIndex);
      return protocols.substring(start, next < 0 ? protocols.length : next);
    }

    test('10 GI3 topics have PT authority coverage', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_OBSTRUCAO_ADESIVA_DELGADO_ASBO',
        'AUTORIDADE_FINAL_OBSTRUCAO_MECANICA_ALCA_FECHADA_ESTRANGULAMENTO',
        'AUTORIDADE_FINAL_ILEO_PARALITICO',
        'AUTORIDADE_FINAL_PSEUDO_OBSTRUCAO_COLONICA_AGUDA_OGILVIE',
        'AUTORIDADE_FINAL_VOLVULO_SIGMOIDE',
        'AUTORIDADE_FINAL_VOLVULO_CECAL',
        'AUTORIDADE_FINAL_HERNIA_INGUINAL_FEMORAL_COMPLICADA',
        'AUTORIDADE_FINAL_HERNIA_VENTRAL_UMBILICAL_INCISIONAL_COMPLICADA',
        'AUTORIDADE_FINAL_VISCERA_OCA_PERFURADA',
        'AUTORIDADE_FINAL_ISQUEMIA_MESENTERICA_AGUDA',
      ]) {
        expect(ai, contains(token), reason: token);
      }
    });

    test('10 GI3 topics have ES authority coverage', () {
      for (final token in <String>[
        'AUTORIDAD_FINAL_OBSTRUCCION_ADHERENCIAL_INTESTINO_DELGADO_ASBO',
        'AUTORIDAD_FINAL_OBSTRUCCION_MECANICA_ASA_CERRADA_ESTRANGULACION',
        'AUTORIDAD_FINAL_ILEO_PARALITICO',
        'AUTORIDAD_FINAL_PSEUDO_OBSTRUCCION_COLONICA_AGUDA_OGILVIE',
        'AUTORIDAD_FINAL_VOLVULO_SIGMOIDE',
        'AUTORIDAD_FINAL_VOLVULO_CECAL',
        'AUTORIDAD_FINAL_HERNIA_INGUINAL_FEMORAL_COMPLICADA',
        'AUTORIDAD_FINAL_HERNIA_VENTRAL_UMBILICAL_INCISIONAL_COMPLICADA',
        'AUTORIDAD_FINAL_VISCERA_HUECA_PERFORADA',
        'AUTORIDAD_FINAL_ISQUEMIA_MESENTERICA_AGUDA',
      ]) {
        expect(ai, contains(token), reason: token);
      }
    });

    test('specific obstruction phenotypes precede generic bowel obstruction', () {
      final sigmoid = ai.indexOf('if (isSigmoidVolvulus)');
      final cecal = ai.indexOf('if (isCecalVolvulus)');
      final ogilvie = ai.indexOf('if (isAcuteColonicPseudoObstruction)');
      final ileus = ai.indexOf('if (isParalyticIleus)');
      final groin = ai.indexOf('if (isComplicatedGroinHernia)');
      final ventral = ai.indexOf('if (isComplicatedVentralHernia)');
      final closedLoop = ai.indexOf('if (isClosedLoopStrangulatingSbo)');
      final asbo = ai.indexOf('if (isAdhesiveSbo)');
      final generic = ai.indexOf('if (isBowelObstruction)');
      for (final x in [sigmoid, cecal, ogilvie, ileus, groin, ventral, closedLoop, asbo]) {
        expect(x, greaterThanOrEqualTo(0));
        expect(generic, greaterThan(x));
      }
      expect(asbo, greaterThan(closedLoop));
    });

    test('ASBO preserves WSES nonoperative trial but not therapeutic certainty for contrast', () {
      expect(ai, contains('Tentativa conservadora de ate aproximadamente 72 h'));
      expect(ai, contains('nao apresenta-lo como terapia garantida que evita operacao'));
      expect(ai, contains('Nao extrapolar o algoritmo ASBO para hernia, volvulo, tumor ou obstrucao colonica'));
      final p = protocolBlock('obstrucao_adesiva_delgado_asbo');
      expect(p, contains('aproximadamente 72 h'));
      expect(p, contains('não tratá-lo como terapêutica garantida'));
    });

    test('closed loop strangulation is surgical escape not conservative extension', () {
      expect(ai, contains('emergencia cirurgica tempo-dependente'));
      expect(ai, contains('Nao prolongar tentativa conservadora'));
      expect(ai, contains('Nao dar antibiotico de rotina a toda obstrucao mecanica simples'));
      expect(protocols, contains("id: 'obstrucao_mecanica_alca_fechada_estrangulamento'"));
    });

    test('paralytic ileus is separated from mechanical obstruction and Ogilvie', () {
      expect(ai, contains('Antes de assumir dismotilidade, excluir obstrucao mecanica'));
      expect(ai, contains('Sonda nasogastrica apenas se vomitos importantes'));
      expect(ai, contains('Ogilvie e entidade distinta com rota especifica'));
      expect(protocols, contains("id: 'ileo_paralitico'"));
    });

    test('Ogilvie uses support then monitored neostigmine then colonoscopic decompression', () {
      expect(ai, contains('neostigmina e opcao sob monitorizacao cardiaca'));
      expect(ai, contains('nao impor dose fixa'));
      expect(ai, contains('descompressao colonoscopica por equipe experiente'));
      expect(ai, contains('Isquemia, perfuracao, peritonite ou deterioracao exigem cirurgia urgente'));
      expect(protocols, contains("id: 'pseudo_obstrucao_colonica_aguda_ogilvie'"));
    });

    test('sigmoid and cecal volvulus have different definitive routes', () {
      expect(ai, contains('AUTORIDADE_FINAL_VOLVULO_SIGMOIDE'));
      expect(ai, contains('planejar sigmoidectomia durante a mesma internacao'));
      expect(ai, contains('Nao usar enema baritado como requisito'));
      expect(ai, contains('AUTORIDADE_FINAL_VOLVULO_CECAL'));
      expect(ai, contains('Reducao endoscopica tem baixa taxa de sucesso'));
      expect(protocols, contains("id: 'volvulo_sigmoide'"));
      expect(protocols, contains("id: 'volvulo_cecal'"));
    });

    test('complicated groin and ventral hernias preserve urgent strangulation escape', () {
      expect(ai, contains('AUTORIDADE_FINAL_HERNIA_INGUINAL_FEMORAL_COMPLICADA'));
      expect(ai, contains('hernia femoral tem risco particularmente alto de estrangulamento'));
      expect(ai, contains('Taxis/reducao manual so pode ser considerada'));
      expect(ai, contains('AUTORIDADE_FINAL_HERNIA_VENTRAL_UMBILICAL_INCISIONAL_COMPLICADA'));
      expect(ai, contains('Dor persistente apos aparente reducao exige excluir reducao em massa/isquemia'));
      expect(protocols, contains("id: 'hernia_inguinal_femoral_complicada'"));
      expect(protocols, contains("id: 'hernia_ventral_umbilical_incisional_complicada'"));
    });

    test('existing perforated viscus authority remains and new secondary peritonitis protocol adds stewardship', () {
      expect(ai, contains('AUTORIDADE_FINAL_VISCERA_OCA_PERFURADA'));
      expect(ai, contains('TC de abdomen/pelve com contraste e o exame principal'));
      expect(ai, contains('antibioticos IV de amplo espectro'));
      expect(ai, contains('controle de foco cirurgico urgente'));
      final p = protocolBlock('perfuracao_viscera_oca_peritonite_secundaria');
      expect(p, contains('controle de foco desde o início'));
      expect(p, contains('evitar antibioticoterapia desnecessariamente prolongada'));
    });

    test('existing mesenteric ischemia authority remains aligned with WSES 2022 and gets protocol', () {
      expect(ai, contains('lactato normal NAO exclui isquemia precoce'));
      expect(ai, contains('angio-TC arterial/venosa SEM DEMORA'));
      expect(ai, contains('priorizar revascularizacao endovascular ou aberta'));
      expect(ai, contains('Trombose venosa mesenterica sem peritonite: anticoagulacao sistemica'));
      expect(ai, contains('second-look em 24-48 h'));
      expect(protocols, contains("id: 'isquemia_mesenterica_aguda_2022'"));
    });

    test('legacy obstruction umbrella fixed doses and obsolete cross-topic claims are removed', () {
      final p = protocolBlock('obstrucao_intestinal');
      expect(p, contains('Umbrella'));
      expect(p, contains('drugs: []'));
      for (final stale in <String>[
        'NEOSTIGMINA 2 mg IV',
        'enema baritado',
        'TC É OBRIGATÓRIO',
        'Dipirona 1 g IV 6/6h + Morfina 2–4 mg IV',
        'Metronidazol 500 mg IV 8/8h + Ceftriaxona',
        'reduz taxa de cirurgia em 20–30%',
        'NÃO omitir sonda nasogástrica em obstrução mecânica completa',
      ]) {
        expect(p, isNot(contains(stale)), reason: stale);
      }
    });

    test('10 new GI3 protocol ids are unique', () {
      for (final id in <String>[
        'obstrucao_adesiva_delgado_asbo',
        'obstrucao_mecanica_alca_fechada_estrangulamento',
        'ileo_paralitico',
        'pseudo_obstrucao_colonica_aguda_ogilvie',
        'volvulo_sigmoide',
        'volvulo_cecal',
        'hernia_inguinal_femoral_complicada',
        'hernia_ventral_umbilical_incisional_complicada',
        'perfuracao_viscera_oca_peritonite_secundaria',
        'isquemia_mesenterica_aguda_2022',
      ]) {
        expect(RegExp("id: '$id'").allMatches(protocols).length, 1, reason: id);
      }
    });

    test('GI1 and GI2 authorities remain present', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_HDA_NAO_VARICOSA',
        'AUTORIDADE_FINAL_HDB_AGUDA',
        'AUTORIDADE_FINAL_DIVERTICULITE_AGUDA',
        'AUTORIDADE_FINAL_CROHN_COMPLICADO',
        'AUTORIDADE_FINAL_COLITE_ULCERATIVA_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_APENDICITE_AGUDA',
      ]) {
        expect(ai, contains(token), reason: token);
      }
    });
  });
}
