import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão cutaneous dermatologic 10-pathology super bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all ten cutaneous authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_SJS_TEN',
        'AUTORIDADE_FINAL_DRESS',
        'AUTORIDADE_FINAL_AGEP',
        'AUTORIDADE_FINAL_PSORIASE_PUSTULOSA_GENERALIZADA',
        'AUTORIDADE_FINAL_ERITRODERMIA',
        'AUTORIDADE_FINAL_PENFIGO_VULGAR_GRAVE',
        'AUTORIDADE_FINAL_URTICARIA_ANGIOEDEMA',
        'AUTORIDADE_FINAL_FASCIITE_NECROSANTE',
        'AUTORIDADE_FINAL_ABSCESSO_CUTANEO',
        'AUTORIDADE_FINAL_CELULITE_ERISIPELA',
      ]) {
        expect(source, contains(token));
      }
    });

    test('SJS TEN immediately withdraws culprit and uses body surface classification', () {
      expect(source, contains('Suspender imediatamente o farmaco causal provavel'));
      expect(source, contains('SJS geralmente envolve <10% da superficie, overlap 10-30% e TEN >30%'));
      expect(source, contains('usar SCORTEN como apoio prognostico, NAO como substituto da avaliacao clinica'));
    });

    test('SJS TEN uses supportive burn ICU principles without thermal formula copy', () {
      expect(source, contains('UTI ou queimados conforme gravidade'));
      expect(source, contains('cuidado atraumatico da pele'));
      expect(source, contains('nao devem copiar automaticamente formulas de queimadura termica'));
      expect(source, contains('Antibiotico profilatico rotineiro NAO e indicado'));
    });

    test('SJS TEN calls ophthalmology early and avoids aggressive debridement', () {
      expect(source, contains('Solicitar oftalmologia precocemente'));
      expect(source, contains('nas primeiras 24 h'));
      expect(source, contains('Evitar desbridamento mecanico agressivo rotineiro de epiderme viavel'));
    });

    test('DRESS uses RegiSCAR organ surveillance and identifies fulminant myocarditis', () {
      expect(source, contains('usar RegiSCAR como apoio diagnostico'));
      expect(source, contains('funcao hepatica, creatinina/urina'));
      expect(source, contains('Miocardite por DRESS pode ser fulminante'));
    });

    test('DRESS severity separates topical support from systemic steroid and slow taper', () {
      expect(source, contains('DRESS leve sem dano organico significativo'));
      expect(source, contains('Comprometimento visceral moderado/grave geralmente exige glicocorticoide sistemico'));
      expect(source, contains('desmame lento individualizado'));
    });

    test('AGEP withdraws culprit and distinguishes sterile pustules', () {
      expect(source, contains('EuroSCAR e biopsia podem ajudar a diferenciar AGEP de psoriase pustulosa'));
      expect(source, contains('Pustulas da AGEP sao estereis'));
      expect(source, contains('NAO iniciar antibiotico apenas por pustulose/febre'));
      expect(source, contains('Corticoide sistemico NAO e obrigatorio para todos'));
    });

    test('GPP is potentially life threatening sterile pustular disease', () {
      expect(source, contains('dermatose inflamatoria potencialmente fatal com pustulas estereis'));
      expect(source, contains('Evitar retirada abrupta de glicocorticoide sistemico'));
      expect(source, contains('Spesolimabe, antagonista de IL-36R'));
    });

    test('erythroderma is syndrome requiring physiologic stabilization and etiology search', () {
      expect(source, contains('E uma sindrome, nao um diagnostico etiologico'));
      expect(source, contains('temperatura, volume, eletrolitos, albumina'));
      expect(source, contains('linfoma cutaneo'));
      expect(source, contains('Evitar iniciar glicocorticoide sistemico empirico de rotina'));
    });

    test('severe pemphigus uses lesion histology perilesional DIF and desmoglein', () {
      expect(source, contains('biopsia de lesao para histologia e biopsia perilesional para imunofluorescencia direta'));
      expect(source, contains('anti-desmogleina 1/3'));
    });

    test('severe pemphigus uses rituximab plus systemic glucocorticoid strategy', () {
      expect(source, contains('Rituximabe combinado com glicocorticoide sistemico e estrategia de primeira linha'));
      expect(source, contains('Nao realizar desbridamento agressivo de pele fragil'));
    });

    test('urticaria angioedema first decides anaphylaxis or airway threat', () {
      expect(source, contains('Primeira decisao: existe anafilaxia ou ameaca de via aerea?'));
      expect(source, contains('epinefrina IM e primeira linha'));
      expect(source, contains('corticoide NAO substitui epinefrina'));
    });

    test('isolated urticaria does not routinely receive epinephrine', () {
      expect(source, contains('Urticaria isolada sem anafilaxia'));
      expect(source, contains('anti-histaminico H1 de segunda geracao e primeira linha'));
      expect(source, contains('epinefrina NAO e rotina para urticas isoladas'));
    });

    test('bradykinin angioedema is separated from histaminergic route', () {
      expect(source, contains('Angioedema SEM urticaria/prurido'));
      expect(source, contains('sugere via de bradicinina'));
      expect(source, contains('epinefrina, anti-histaminicos e corticoides geralmente sao ineficazes'));
      expect(source, contains('concentrado de C1-INH ou icatibanto'));
    });

    test('progressive airway angioedema gets early controlled airway plan', () {
      expect(source, contains('envolver anestesia/ORL precocemente'));
      expect(source, contains('garantir via aerea antes de obstrucao completa'));
      expect(source, contains('Nao esperar dessaturacao tardia'));
    });

    test('necrotizing fasciitis does not wait for imaging LRINEC or gas', () {
      expect(source, contains('Dor desproporcional, progressao rapida'));
      expect(source, contains('exploracao/desbridamento cirurgico urgente'));
      expect(source, contains('NAO atrasar cirurgia por TC/RM, LRINEC, cultura ou ausencia de gas'));
    });

    test('necrotizing fasciitis combines broad antibiotics with source control', () {
      expect(source, contains('cobertura para MRSA, gram-negativos e anaerobios'));
      expect(source, contains('estreptococo do grupo A'));
      expect(source, contains('beta-lactamica dirigida + clindamicina'));
      expect(source, contains('Nao usar antibiotico como substituto do controle de foco cirurgico'));
    });

    test('cutaneous abscess incision drainage is primary intervention', () {
      expect(source, contains('incisao e drenagem; antibiotico isolado NAO substitui drenagem adequada'));
      expect(source, contains('Acrescentar antibiotico ativo contra S. aureus/MRSA'));
      expect(source, contains('Ultrassom a beira-leito ajuda'));
    });

    test('abscess danger signs yield to necrotizing fasciitis route', () {
      expect(source, contains('Se houver dor desproporcional, progressao rapida, bolhas ou toxicidade'));
      expect(source, contains('ativar fasciite necrosante'));
    });

    test('cellulitis distinguishes nonpurulent disease from abscess', () {
      expect(source, contains('celulite/erisipela nao purulenta'));
      expect(source, contains('se houver flutuacao/pus, usar rota de abscesso'));
      expect(source, contains('tratada principalmente contra estreptococos'));
    });

    test('cellulitis cultures are selective and necrotizing signs escalate', () {
      expect(source, contains('Hemoculturas NAO sao rotineiras na celulite tipica leve'));
      expect(source, contains('Dor desproporcional, anestesia, bolhas, crepitacao, toxicidade'));
      expect(source, contains('cirurgia sem demora'));
    });

    test('specific severe cutaneous reactions precede infectious skin routes', () {
      final sjs = source.indexOf('if (isSjsTen)');
      final agep = source.indexOf('if (isAgep)');
      final nec = source.indexOf('if (isNecrotizingFasciitis)');
      final cellulitis = source.indexOf('if (isCellulitisErysipelas)');
      expect(sjs, greaterThanOrEqualTo(0));
      expect(agep, greaterThan(sjs));
      expect(nec, greaterThan(agep));
      expect(cellulitis, greaterThan(nec));
    });

    test('cutaneous bundle precedes autoimmune and preserves previous bundles', () {
      final cutaneous = source.indexOf('if (isSjsTen)');
      final autoimmune = source.indexOf('if (isAcuteSevereAutoimmuneHepatitis)');
      expect(cutaneous, greaterThanOrEqualTo(0));
      expect(autoimmune, greaterThan(cutaneous));

      for (final token in <String>[
        'AUTORIDADE_FINAL_HEPATITE_AUTOIMUNE_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_VASCULITE_ANCA',
        'AUTORIDADE_FINAL_SINDROME_COMPARTIMENTAL_AGUDA',
        'AUTORIDADE_FINAL_CETOACIDOSE_DIABETICA',
        'AUTORIDADE_FINAL_PANCREATITE_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_LESAO_RENAL_AGUDA',
        'AUTORIDADE_FINAL_SINDROME_AORTICA_AGUDA',
        'AUTORIDADE_FINAL_TEP_AGUDO',
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
