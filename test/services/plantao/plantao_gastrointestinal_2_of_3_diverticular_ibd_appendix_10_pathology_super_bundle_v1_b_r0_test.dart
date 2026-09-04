import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GI 2/3 diverticular IBD appendix 10 pathology super bundle V1-B-R0', () {
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

    test('10 GI2 topics have PT and ES authority coverage', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_DIVERTICULOSE',
        'AUTORIDADE_FINAL_DIVERTICULITE_AGUDA',
        'AUTORIDADE_FINAL_DIVERTICULITE_COMPLICADA',
        'AUTORIDADE_FINAL_SURTO_CROHN_LUMINAL',
        'AUTORIDADE_FINAL_CROHN_COMPLICADO',
        'AUTORIDADE_FINAL_SURTO_COLITE_ULCERATIVA',
        'AUTORIDADE_FINAL_COLITE_ULCERATIVA_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_MEGACOLON_TOXICO',
        'AUTORIDADE_FINAL_OBSTRUCAO_COLORRETAL_AGUDA',
        'AUTORIDADE_FINAL_APENDICITE_AGUDA',
      ]) {
        expect(ai, contains(token), reason: token);
      }
      for (final token in <String>[
        'AUTORIDAD_FINAL_DIVERTICULOSIS',
        'AUTORIDAD_FINAL_DIVERTICULITIS_AGUDA',
        'AUTORIDAD_FINAL_DIVERTICULITIS_COMPLICADA',
        'AUTORIDAD_FINAL_BROTE_CROHN_LUMINAL',
        'AUTORIDAD_FINAL_CROHN_COMPLICADO',
        'AUTORIDAD_FINAL_BROTE_COLITIS_ULCEROSA',
        'AUTORIDAD_FINAL_COLITIS_ULCEROSA_AGUDA_GRAVE',
        'AUTORIDAD_FINAL_MEGACOLON_TOXICO',
        'AUTORIDAD_FINAL_OBSTRUCCION_COLORRECTAL_AGUDA',
        'AUTORIDAD_FINAL_APENDICITIS_AGUDA',
      ]) {
        expect(ai, contains(token), reason: token);
      }
    });

    test('complicated diverticulitis precedes general acute diverticulitis', () {
      final complicated = ai.indexOf('if (isComplicatedDiverticulitis)');
      final acute = ai.indexOf('if (isAcuteDiverticulitis)');
      final diverticulosis = ai.indexOf('if (isDiverticulosis)');
      expect(complicated, greaterThanOrEqualTo(0));
      expect(acute, greaterThan(complicated));
      expect(diverticulosis, greaterThan(acute));
    });

    test('ACG 2026 uncomplicated diverticulitis contract is retained', () {
      expect(ai, contains('ACG 2026 recomenda TC na primeira apresentacao'));
      expect(ai, contains('podem ser manejados SEM antibioticos'));
      expect(ai, contains('colonoscopia NAO e obrigatoria rotineiramente'));
      final p = protocolBlock('diverticulitis_aguda_015');
      expect(p, contains('ACG 2026'));
      expect(p, contains('Sem antibiótico em selecionados'));
      expect(p, contains('colonoscopia apenas se sintomas de alarme'));
      expect(p, contains('drugs: []'));
    });

    test('legacy diverticulitis automatic regimen/fasting/mandatory colonoscopy are removed', () {
      final p = protocolBlock('diverticulitis_aguda_015');
      expect(p, isNot(contains('ciprofloxacino 500 mg VO 12/12h + metronidazol')));
      expect(p, isNot(contains('ciprofloxacino 400 mg IV 12/12h + metronidazol')));
      expect(p, isNot(contains('Jejum + hidratação venosa + analgesia')));
      expect(p, isNot(contains('colonoscopia pós-resolução é obrigatória')));
      expect(p, isNot(contains('Colonoscopia 6–8 semanas pós-resolução: obrigatória')));
    });

    test('complicated diverticulitis preserves source control and post-recovery colon evaluation', () {
      expect(ai, contains('AUTORIDADE_FINAL_DIVERTICULITE_COMPLICADA'));
      expect(ai, contains('controle de foco cirurgico urgente'));
      expect(ai, contains('Apos diverticulite complicada, ACG 2026 recomenda avaliacao colonoscopica'));
      expect(protocols, contains("id: 'diverticulitis_complicada_2026'"));
    });

    test('Crohn 2025 separates luminal from complicated phenotype', () {
      final complicated = ai.indexOf('if (isCrohnComplicated)');
      final luminal = ai.indexOf('if (isCrohnLuminalFlare)');
      expect(complicated, greaterThanOrEqualTo(0));
      expect(luminal, greaterThan(complicated));
      expect(ai, contains('Mesalazina NAO e recomendada'));
      expect(ai, contains('nao exigir falha de tiopurina/metotrexato'));
      expect(ai, contains('evitar iniciar/escalar imunossupressao as cegas diante de sepse'));
      expect(protocols, contains("id: 'crohn_flare_luminal_2025'"));
      expect(protocols, contains("id: 'crohn_complicado_2025'"));
    });

    test('UC 2025 separates ASUC from ordinary flare', () {
      final asuc = ai.indexOf('if (isAcuteSevereUlcerativeColitis)');
      final flare = ai.indexOf('if (isUlcerativeColitisFlare)');
      expect(asuc, greaterThanOrEqualTo(0));
      expect(flare, greaterThan(asuc));
      expect(ai, contains('ACG 2025 recomenda testar C. difficile'));
      expect(ai, contains('profilaxia farmacologica para TEV'));
      expect(ai, contains('resposta ao corticoide IV for inadequada no dia 3'));
      expect(protocols, contains("id: 'colite_ulcerativa_flare_2025'"));
      expect(protocols, contains("id: 'colite_ulcerativa_aguda_grave_2025'"));
    });

    test('toxic megacolon has early surgical escape and avoids antimotility drugs', () {
      expect(ai, contains('AUTORIDADE_FINAL_MEGACOLON_TOXICO'));
      expect(ai, contains('suspender opioides, anticolinergicos e antidiarreicos'));
      expect(ai, contains('colectomia urgente'));
      expect(protocols, contains("id: 'megacolon_toxico'"));
    });

    test('acute colorectal obstruction has mechanical obstruction safety contract', () {
      expect(ai, contains('AUTORIDADE_FINAL_OBSTRUCAO_COLORRETAL_AGUDA'));
      expect(ai, contains('Nao usar laxantes/procineticos em obstrucao mecanica completa'));
      expect(ai, contains('nao impor stent universal'));
      expect(protocols, contains("id: 'obstrucao_colorretal_aguda'"));
    });

    test('appendicitis protocol no longer uses Alvarado cutoff as automatic surgery order', () {
      final p = protocolBlock('apendicite_aguda');
      expect(p, contains('scores clínicos apenas para estratificação'));
      expect(p, contains('Não usar um ponto de corte isolado de Alvarado como ordem automática de cirurgia'));
      expect(p, contains('SAGES favorece curso pós-operatório curto'));
      expect(p, contains('drugs: []'));
      expect(p, isNot(contains('ESCORE DE ALVARADO ≥7: alta probabilidade — cirurgia sem aguardar imagem')));
      expect(p, isNot(contains('Metronidazol 500 mg IV + Ceftriaxona 1–2 g IV')));
      expect(p, isNot(contains('ATB 4–6 semanas')));
    });

    test('appendicitis final authority still preserves selected NOM and source control', () {
      expect(ai, contains('apendicite NAO complicada e sem apendicolito'));
      expect(ai, contains('controle de foco cirurgico urgente'));
      expect(ai, contains('NAO requer antibioticos pos-operatorios prolongados'));
    });

    test('8 new protocol ids are unique', () {
      for (final id in <String>[
        'diverticulose_2026',
        'diverticulitis_complicada_2026',
        'crohn_flare_luminal_2025',
        'crohn_complicado_2025',
        'colite_ulcerativa_flare_2025',
        'colite_ulcerativa_aguda_grave_2025',
        'megacolon_toxico',
        'obstrucao_colorretal_aguda',
      ]) {
        expect(RegExp("id: '$id'").allMatches(protocols).length, 1, reason: id);
      }
    });

    test('GI1 authorities remain present after GI2', () {
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
  });
}
