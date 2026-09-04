import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GI 1/3 upper/bleeding/colonic 10 pathology super bundle V1-B-R0', () {
    late String ai;
    late String protocols;

    setUpAll(() {
      ai = File('lib/services/ai_service.dart').readAsStringSync();
      protocols = File('lib/data/protocols_database.dart').readAsStringSync();
    });

    test('10 PT final authorities exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_DOENCA_ULCEROSA_PEPTICA_H_PYLORI',
        'AUTORIDADE_FINAL_HDA_NAO_VARICOSA',
        'AUTORIDADE_FINAL_ULCERA_PEPTICA_PERFURADA',
        'AUTORIDADE_FINAL_IMPACTACAO_ALIMENTAR_ESOFAGICA',
        'AUTORIDADE_FINAL_PERFURACAO_ESOFAGICA_BOERHAAVE',
        'AUTORIDADE_FINAL_OBSTRUCAO_SAIDA_GASTRICA',
        'AUTORIDADE_FINAL_HDB_AGUDA',
        'AUTORIDADE_FINAL_SANGRAMENTO_DIVERTICULAR',
        'AUTORIDADE_FINAL_COLITE_ISQUEMICA',
        'AUTORIDADE_FINAL_COLITE_ESTERCORAL_IMPACTACAO_FECAL',
      ]) {
        expect(ai, contains(token), reason: token);
      }
    });

    test('10 ES final authorities exist', () {
      for (final token in <String>[
        'AUTORIDAD_FINAL_ENFERMEDAD_ULCEROSA_PEPTICA_H_PYLORI',
        'AUTORIDAD_FINAL_HDA_NO_VARICOSA',
        'AUTORIDAD_FINAL_ULCERA_PEPTICA_PERFORADA',
        'AUTORIDAD_FINAL_IMPACTACION_ALIMENTARIA_ESOFAGICA',
        'AUTORIDAD_FINAL_PERFORACION_ESOFAGICA_BOERHAAVE',
        'AUTORIDAD_FINAL_OBSTRUCCION_SALIDA_GASTRICA',
        'AUTORIDAD_FINAL_HDB_AGUDA',
        'AUTORIDAD_FINAL_SANGRADO_DIVERTICULAR',
        'AUTORIDAD_FINAL_COLITIS_ISQUEMICA',
        'AUTORIDAD_FINAL_COLITIS_ESTERCORAL_IMPACTACION_FECAL',
      ]) {
        expect(ai, contains(token), reason: token);
      }
    });

    test('H pylori 2024 safety contract', () {
      expect(ai, contains('terapia quadrupla otimizada com bismuto por 14 dias'));
      expect(ai, contains('evitar terapia tripla com claritromicina'));
      expect(ai, contains('pelo menos 4 semanas apos antibioticos'));
      expect(protocols, contains('doenca_ulcerosa_peptica_h_pylori_2024'));
      expect(protocols, contains('terapia quádrupla otimizada com bismuto por 14 dias'));
    });

    String protocolBlock(String id) {
      final marker = "id: '$id'";
      final markerIndex = protocols.indexOf(marker);
      expect(markerIndex, greaterThanOrEqualTo(0), reason: 'missing protocol $id');
      final start = protocols.lastIndexOf('ProtocolModel(', markerIndex);
      expect(start, greaterThanOrEqualTo(0), reason: 'missing ProtocolModel start $id');
      final next = protocols.indexOf('\n  ProtocolModel(', markerIndex);
      return protocols.substring(start, next < 0 ? protocols.length : next);
    }

    test('nonvariceal UGIB current timing and escalation contract', () {
      expect(ai, contains('GBS 0-1'));
      expect(ai, contains('Realizar EDA em ate 24 h'));
      expect(ai, contains('nao impor EDA <6-12 h rotineiramente'));
      expect(ai, contains('repetir endoscopia antes de embolizacao transcateter'));

      final hda = protocolBlock('hda_nao_varicosa');
      expect(hda, contains('EDA em até 24 h após estabilização'));
      expect(hda, contains('não impor <6–12 h rotineiramente'));
      expect(hda, contains("drugs: ['omeprazol', 'pantoprazol']"));
      expect(hda, isNot(contains('ceftriaxona')));
      expect(hda, isNot(contains('noradrenalina')));
    });

    test('perforated peptic ulcer owns source control before generic viscus', () {
      final specific = ai.indexOf('if (isPerforatedPepticUlcerGi)');
      final generic = ai.indexOf('if (isPerforatedViscus)');
      expect(specific, greaterThanOrEqualTo(0));
      expect(generic, greaterThan(specific));
      expect(protocols, contains("id: 'ulcera_peptica_perfurada_2020'"));
    });

    test('food bolus complete obstruction keeps emergent endoscopy route', () {
      expect(ai, contains('incapacidade de engolir saliva'));
      expect(ai, contains('no maximo em 6 h'));
      expect(ai, contains('endoscopia urgente em ate 24 h'));
      expect(protocols, contains("id: 'impactacao_alimentar_esofagica'"));
    });

    test('Boerhaave owns CT, antibiotics and urgent source control', () {
      expect(ai, contains('AUTORIDADE_FINAL_PERFURACAO_ESOFAGICA_BOERHAAVE'));
      expect(ai, contains('TC contrastada define perfuracao e contaminacao'));
      expect(ai, contains('controle de foco urgente'));
      expect(protocols, contains("id: 'perfuracao_esofagica_boerhaave'"));
    });

    test('gastric outlet obstruction distinguishes mechanical obstruction', () {
      expect(ai, contains('Nao usar procineticos como solucao de obstrucao mecanica fixa'));
      expect(ai, contains('causa benigna versus maligna'));
      expect(protocols, contains("id: 'obstrucao_saida_gastrica'"));
    });

    test('lower GI bleed uses CTA for active significant bleeding and no routine urgent colonoscopy', () {
      expect(ai, contains('hematoquezia hemodinamicamente significativa com sangramento ativo'));
      expect(ai, contains('colonoscopia e nao emergente'));
      expect(ai, contains('Nao usar acido tranexamico rotineiramente'));
      expect(protocols, contains('Não impor colonoscopia <24 h como benefício universal'));
    });

    test('diverticular bleeding has own phenotype and no routine TXA', () {
      expect(ai, contains('AUTORIDADE_FINAL_SANGRAMENTO_DIVERTICULAR'));
      expect(ai, contains('tipicamente hematoquezia indolor'));
      expect(protocols, contains("id: 'sangramento_diverticular_agudo'"));
      expect(protocols, contains('Não usar TXA de rotina'));
    });

    test('ischemic colitis separates mild support from surgical red flags', () {
      expect(ai, contains('AUTORIDADE_FINAL_COLITE_ISQUEMICA'));
      expect(ai, contains('Antibioticos ficam para doenca moderada/grave'));
      expect(ai, contains('gangrena ou deterioracao: cirurgia urgente'));
      expect(protocols, contains("id: 'colite_isquemica'"));
    });

    test('stercoral colitis avoids blind aggressive bowel regimen when complicated', () {
      expect(ai, contains('AUTORIDADE_FINAL_COLITE_ESTERCORAL_IMPACTACAO_FECAL'));
      expect(ai, contains('Nao realizar enemas/laxantes agressivos as cegas'));
      expect(ai, contains('cirurgia urgente para controle de foco'));
      expect(protocols, contains("id: 'colite_estercoral_impactacao_fecal'"));
    });

    test('8 new protocol ids are unique', () {
      for (final id in <String>[
        'doenca_ulcerosa_peptica_h_pylori_2024',
        'ulcera_peptica_perfurada_2020',
        'impactacao_alimentar_esofagica',
        'perfuracao_esofagica_boerhaave',
        'obstrucao_saida_gastrica',
        'sangramento_diverticular_agudo',
        'colite_isquemica',
        'colite_estercoral_impactacao_fecal',
      ]) {
        expect(RegExp("id: '$id'").allMatches(protocols).length, 1, reason: id);
      }
    });

    test('legacy HDA/HDB drug contamination is removed inside reconciled blocks', () {
      final hda = protocolBlock('hda_nao_varicosa');
      final hdbSimple = protocolBlock('hemorragia_digestiva_baixa');
      final hdbRich = protocolBlock('hdb_sangrado_rectal_014');

      expect(hda, contains("drugs: ['omeprazol', 'pantoprazol']"));
      expect(hda, isNot(contains('ceftriaxona')));
      expect(hda, isNot(contains('noradrenalina')));

      expect(hdbSimple, contains('Não usar TXA de rotina'));
      expect(hdbSimple, contains('colonoscopia não emergente'));
      expect(hdbSimple, contains('drugs: []'));

      expect(hdbRich, contains('Não usar TXA de rotina'));
      expect(hdbRich, contains('colonoscopia não emergente'));
      expect(hdbRich, contains('drugs: []'));
      expect(hdbRich, isNot(contains('acido_tranexamico')));
      expect(hdbRich, isNot(contains('vitamina_k')));
    });

    test('diverticular authority from prior physical fix remains intact', () {
      expect(ai, contains('AUTORIDADE_FINAL_DIVERTICULITE_AGUDA'));
      expect(ai, contains('AUTORIDADE_FINAL_DIVERTICULOSE'));
      expect(ai, contains('Antibioticos sao seletivos, NAO automaticos'));
    });

    test('generic GI bleed remains after the specific GI 1/3 authorities', () {
      final specific = ai.indexOf('if (isAcuteLowerGiBleeding)');
      final generic = ai.indexOf('if (isAcuteGiBleeding)');
      expect(specific, greaterThanOrEqualTo(0));
      expect(generic, greaterThan(specific));
    });
  });
}
