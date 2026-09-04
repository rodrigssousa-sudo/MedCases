import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão pancreatic 10-pathology super bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all ten pancreatic specific authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_TRAUMA_PANCREATICO',
        'AUTORIDADE_FINAL_FUGA_DUCTO_PANCREATICO',
        'AUTORIDADE_FINAL_PANCREATITE_CRONICA_AGUDIZADA',
        'AUTORIDADE_FINAL_PANCREATITE_HIPERTRIGLICERIDEMIA',
        'AUTORIDADE_FINAL_PANCREATITE_BILIAR',
        'AUTORIDADE_FINAL_WALLED_OFF_NECROSIS',
        'AUTORIDADE_FINAL_PSEUDOCISTO_PANCREATICO',
        'AUTORIDADE_FINAL_NECROSE_PANCREATICA_INFECTADA',
        'AUTORIDADE_FINAL_PANCREATITE_NECROSANTE',
        'AUTORIDADE_FINAL_PANCREATITE_AGUDA_GRAVE',
      ]) {
        expect(source, contains(token));
      }
    });

    test('severe AP is persistent organ failure not isolated score', () {
      expect(source, contains('falencia organica persistente >48 h'));
      expect(source, contains('BISAP/APACHE podem ajudar na estratificacao'));
      expect(source, contains('NAO substituem a evolucao organica real'));
    });

    test('severe AP keeps moderate fluids early enteral and no prophylactic antibiotics', () {
      expect(source, contains('cristaloide moderadamente agressivo e individualizado'));
      expect(source, contains('alimentacao enteral precoce'));
      expect(source, contains('NAO usar antibioticos profilaticos pela gravidade'));
    });

    test('sterile necrosis does not trigger antibiotics or intervention by itself', () {
      expect(source, contains('presenca de necrose isolada NAO indica antibioticos nem intervencao'));
      expect(source, contains('NAO usar antibioticos profilaticos na necrose esteril'));
      expect(source, contains('Evitar desbridamento/necrosectomia precoce'));
    });

    test('infected necrosis gets antibiotics and delayed step-up when stable', () {
      expect(source, contains('gas na colecao'));
      expect(source, contains('PAAF para cultura NAO e necessaria rotineiramente'));
      expect(source, contains('antibioticos IV com boa penetracao na necrose'));
      expect(source, contains('preferir estrategia step-up'));
      expect(source, contains('adiar drenagem/desbridamento ate aproximadamente 4 semanas'));
    });

    test('infected necrosis begins with percutaneous or endoscopic drainage', () {
      expect(source, contains('Drenagem percutanea ou transmural endoscopica e primeira intervencao habitual'));
      expect(source, contains('escalar para necrosectomia endoscopica/minimamente invasiva'));
      expect(source, contains('cirurgia aberta fica para casos selecionados'));
    });

    test('pseudocyst is not drained by size alone and is distinct from WON', () {
      expect(source, contains('SEM componente necrotico significativo'));
      expect(source, contains('Pseudocisto assintomatico NAO deve ser drenado apenas pelo tamanho'));
      expect(source, contains('drenagem transmural guiada por EUS'));
    });

    test('WON is mature necrotic collection and uses step-up', () {
      expect(source, contains('colecao necrotica encapsulada geralmente madura apos aproximadamente 4 semanas'));
      expect(source, contains('WON assintomatica e esteril NAO exige drenagem apenas pelo tamanho'));
      expect(source, contains('escalar em step-up para necrosectomia endoscopica'));
    });

    test('biliary AP uses early ERCP only when cholangitis or persistent obstruction requires it', () {
      expect(source, contains('Com colangite concomitante: CPRE precoce'));
      expect(source, contains('SEM colangite nem obstrucao biliar persistente, NAO realizar CPRE urgente rotineiramente'));
      expect(source, contains('colecistectomia durante a mesma internacao'));
    });

    test('severe necrotizing biliary AP does not force index cholecystectomy', () {
      expect(source, contains('pancreatite necrosante/grave com colecoes importantes'));
      expect(source, contains('geralmente e diferido ate a inflamacao/colecoes estabilizarem ou resolverem'));
    });

    test('hypertriglyceridemic AP rejects routine plasmapheresis and insulin without diabetes', () {
      expect(source, contains('TG >1000 mg/dL'));
      expect(source, contains('NAO usar plasmaferese como primeira linha rotineira'));
      expect(source, contains('Em pacientes SEM diabetes, NAO usar infusao de insulina rotineiramente'));
      expect(source, contains('Nao usar heparina como estrategia para baixar triglicerideos'));
    });

    test('chronic pancreatitis flare searches structural complications and does not use PERT as analgesic', () {
      expect(source, contains('Nao assumir que toda dor e "flare"'));
      expect(source, contains('pseudocisto/WON, obstrucao ductal'));
      expect(source, contains('Reposicao de enzimas pancreaticas e indicada para insuficiencia pancreatica exocrina/malabsorcao'));
      expect(source, contains('NAO como analgesico universal'));
    });

    test('chronic obstructive disease routes endoscopy ESWL and surgery appropriately', () {
      expect(source, contains('terapia endoscopica/LECO'));
      expect(source, contains('cirurgia deve ser considerada'));
    });

    test('duct leak distinguishes partial leak from disconnected duct syndrome', () {
      expect(source, contains('Vazamento parcial com continuidade ductal'));
      expect(source, contains('stent atravessando a fuga'));
      expect(source, contains('Disrupcao completa/disconnected duct syndrome NAO deve ser tratada como vazamento parcial simples'));
    });

    test('duct disruption does not make octreotide universal', () {
      expect(source, contains('Octreotida/somatostatina NAO deve ser imposta como tratamento universal'));
      expect(source, contains('Nutricao enteral e preferivel'));
    });

    test('pancreatic trauma prioritizes main duct and does not rely on initial enzymes', () {
      expect(source, contains('Lesao do ducto pancreatico principal muda o manejo'));
      expect(source, contains('amilase/lipase inicial normal NAO exclui lesao'));
      expect(source, contains('TC contrastada e o exame inicial'));
    });

    test('pancreatic trauma separates minor NOM from distal duct surgery', () {
      expect(source, contains('Lesao menor sem dano do ducto principal'));
      expect(source, contains('Lesao distal com interrupcao do ducto principal geralmente exige tratamento operatorio'));
      expect(source, contains('pancreatectomia distal com preservacao esplenica'));
    });

    test('all specific pancreatic guards precede generic acute pancreatitis fallback', () {
      final trauma = source.indexOf('if (isPancreaticTrauma)');
      final severe = source.indexOf('if (isSevereAcutePancreatitis)');
      final generic = source.indexOf('if (isAcutePancreatitis)');
      expect(trauma, greaterThanOrEqualTo(0));
      expect(severe, greaterThan(trauma));
      expect(generic, greaterThan(severe));
    });

    test('generic acute pancreatitis fallback remains unchanged in presence', () {
      expect(source, contains('AUTORIDADE_FINAL_PANCREATITE_AGUDA'));
      expect(source, contains('NAO usar hidratacao agressiva fixa para todos'));
      expect(source, contains('NAO usar antibioticos profilaticos na pancreatite necrosante esteril'));
    });

    test('renal cardiac respiratory abdominal and thoracic retained bundles remain', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_LESAO_RENAL_AGUDA',
        'AUTORIDADE_FINAL_SINDROME_AORTICA_AGUDA',
        'AUTORIDADE_FINAL_HEMOPTISE_AMEACADORA_VIDA',
        'AUTORIDADE_FINAL_APENDICITE_AGUDA',
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
