import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão infectious 1/3 high-risk 10-pathology super bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all ten infectious 1/3 authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_MENINGITE_BACTERIANA',
        'AUTORIDADE_FINAL_ENCEFALITE_HSV_VIRAL',
        'AUTORIDADE_FINAL_EPIGLOTITE',
        'AUTORIDADE_FINAL_TUBERCULOSE_PULMONAR',
        'AUTORIDADE_FINAL_CLOSTRIDIOIDES_DIFFICILE',
        'AUTORIDADE_FINAL_ARTRITE_SEPTICA',
        'AUTORIDADE_FINAL_OSTEOMIELITE',
        'AUTORIDADE_FINAL_DENGUE',
        'AUTORIDADE_FINAL_MALARIA',
        'AUTORIDADE_FINAL_INFECCAO_AGUDA_HIV',
      ]) {
        expect(source, contains(token));
      }
    });

    test('bacterial meningitis never waits for LP or imaging to start therapy', () {
      expect(source, contains('nao atrasar a primeira dose aguardando puncao lombar ou neuroimagem'));
      expect(source, contains('se a imagem atrasar o LCR, tratar primeiro'));
      expect(source, contains('Ceftriaxona ou cefotaxima sao bases empiricas aceitas pela WHO 2025'));
    });

    test('meningitis handles droplet precautions and ICU escape', () {
      expect(source, contains('precaucoes por goticulas se meningococo ou Hib forem suspeitos'));
      expect(source, contains('Choque, convulsoes, rebaixamento de consciencia'));
      expect(source, contains('Desescalonar quando microbiologia e sensibilidade estiverem disponiveis'));
    });

    test('HSV encephalitis starts empiric IV acyclovir before PCR', () {
      expect(source, contains('Iniciar aciclovir IV empirico imediatamente'));
      expect(source, contains('sem aguardar PCR'));
      expect(source, contains('nao inventar dose sem peso e funcao renal'));
    });

    test('HSV encephalitis allows repeat PCR when early test conflicts with high suspicion', () {
      expect(source, contains('PCR HSV precoce negativo nem sempre exclui a doenca'));
      expect(source, contains('repetir LCR/PCR conforme tempo e contexto'));
      expect(source, contains('RM de encefalo e a imagem preferida'));
    });

    test('epiglottitis gives airway precedence over diagnostics and medication', () {
      expect(source, contains('preparo imediato de via aerea controlada'));
      expect(source, contains('Nao forcar exame orofaringeo'));
      expect(source, contains('nao aguardar colapso nem dessaturacao tardia'));
      expect(source, contains('Nao substituir controle de via aerea por corticoide'));
    });

    test('epiglottitis preserves Hib antimicrobial and droplet logic', () {
      expect(source, contains('cefalosporina de terceira geracao e base para Hib'));
      expect(source, contains('precaucoes por goticulas ate pelo menos 24 h de terapia efetiva'));
      expect(source, contains('avaliar profilaxia de contatos'));
    });

    test('pulmonary TB isolates early and requires rapid molecular resistance workup', () {
      expect(source, contains('isolamento respiratorio por aerossois'));
      expect(source, contains('teste molecular rapido recomendado pela WHO'));
      expect(source, contains('definir sensibilidade a rifampicina'));
    });

    test('pulmonary TB refuses monotherapy and universal shortened regimens', () {
      expect(source, contains('nunca monoterapia nem esquema improvisado'));
      expect(source, contains('Regimes abreviados nao sao universais'));
      expect(source, contains('coinfeccao HIV'));
    });

    test('C difficile distinguishes infection from colonization', () {
      expect(source, contains('nao diagnosticar nem tratar colonizacao'));
      expect(source, contains('teste positivo em fezes formadas sem sindrome compativel'));
      expect(source, contains('Suspender, se possivel, o antibiotico desencadeante'));
    });

    test('C difficile nonfulminant and fulminant routes are separated', () {
      expect(source, contains('fidaxomicina e geralmente preferida pela IDSA/SHEA'));
      expect(source, contains('CDI fulminante com hipotensao/choque, ileo ou megacolon'));
      expect(source, contains('vancomicina enteral como base'));
      expect(source, contains('acionar cirurgia precocemente'));
    });

    test('septic arthritis requires aspiration plus source control', () {
      expect(source, contains('artrocentese urgente'));
      expect(source, contains('Cristais nao excluem infeccao concomitante'));
      expect(source, contains('Drenagem/lavagem e controle de foco sao centrais'));
    });

    test('septic arthritis treats sepsis before perfect sampling', () {
      expect(source, contains('Se o paciente estiver estavel, obter amostras antes dos antibioticos'));
      expect(source, contains('Se houver sepse/choque, nao atrasar antimicrobianos'));
      expect(source, contains('Cobertura empirica deve incluir S. aureus'));
    });

    test('osteomyelitis is phenotype-specific rather than one universal regimen', () {
      expect(source, contains('Definir primeiro o fenotipo'));
      expect(source, contains('hematogenica, vertebral, contigua/diabetica'));
      expect(source, contains('Nao impor antibiotico nem duracao universal'));
    });

    test('vertebral osteomyelitis separates stable biopsy-first from unstable immediate therapy', () {
      expect(source, contains('osteomielite vertebral estavel sem sepse nem deficit neurologico'));
      expect(source, contains('diagnostico microbiologico antes de antibiotico empirico'));
      expect(source, contains('Se houver sepse, instabilidade ou comprometimento neurologico'));
      expect(source, contains('drenagem/desbridamento e cirurgia'));
    });

    test('dengue avoids NSAIDs and platelet-count-only decisions', () {
      expect(source, contains('Evitar aspirina e AINE'));
      expect(source, contains('nao apenas por plaquetas'));
      expect(source, contains('Nao transfundir plaquetas profilaticamente apenas por trombocitopenia'));
    });

    test('dengue fluids are cautious and physiology-guided', () {
      expect(source, contains('priorizar hidratacao oral'));
      expect(source, contains('cristaloide isotonico em bolus guiados'));
      expect(source, contains('evitar fluidos indiscriminados e sobrecarga'));
    });

    test('severe malaria uses parenteral therapy and ICU', () {
      expect(source, contains('Malaria grave por qualquer especie exige hospital/UTI'));
      expect(source, contains('WHO 2025 mantem artesunato injetavel como tratamento preferido'));
      expect(source, contains('seguido de curso completo de terapia combinada com artemisinina'));
    });

    test('malaria avoids artemisinin monotherapy and gates radical cure by G6PD', () {
      expect(source, contains('Nao usar monoterapia com artemisinina'));
      expect(source, contains('avaliar G6PD antes de primaquina/tafenoquina'));
      expect(source, contains('evitar sobrecarga de fluidos'));
    });

    test('acute HIV escapes generic viral syndrome and uses RNA testing', () {
      expect(source, contains('nao deve ser encerrada como gripe'));
      expect(source, contains('teste Ag/Ac de quarta geracao e HIV RNA'));
      expect(source, contains('HIV RNA detectavel em contexto compativel'));
    });

    test('acute HIV starts ART early without waiting for genotype result', () {
      expect(source, contains('NIH/HHS 2026 recomenda iniciar ART o mais cedo possivel'));
      expect(source, contains('Nao esperar resultado do genotipo para iniciar na maioria'));
      expect(source, contains('colher a amostra antes'));
    });

    test('acute HIV initial regimen remains context-dependent', () {
      expect(source, contains('exposicao previa a PrEP'));
      expect(source, contains('cabotegravir de longa acao'));
      expect(source, contains('nao inventar combinacao nem dose'));
    });

    test('infectious 1/3 precedes cutaneous and previous major bundles remain', () {
      final infectious = source.indexOf('if (isBacterialMeningitis)');
      final hiv = source.indexOf('if (isAcuteHivInfection)');
      final cutaneous = source.indexOf('if (isSjsTen)');
      expect(infectious, greaterThanOrEqualTo(0));
      expect(hiv, greaterThan(infectious));
      expect(cutaneous, greaterThan(hiv));

      for (final token in <String>[
        'AUTORIDADE_FINAL_SJS_TEN',
        'AUTORIDADE_FINAL_FASCIITE_NECROSANTE',
        'AUTORIDADE_FINAL_HEPATITE_AUTOIMUNE_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_VASCULITE_ANCA',
        'AUTORIDADE_FINAL_SINDROME_COMPARTIMENTAL_AGUDA',
        'AUTORIDADE_FINAL_CETOACIDOSE_DIABETICA',
        'AUTORIDADE_FINAL_PANCREATITE_AGUDA_GRAVE',
        'AUTORIDADE_FINAL_PIELONEFRITE_ITU_SISTEMICA',
        'AUTORIDADE_FINAL_SINDROME_AORTICA_AGUDA',
        'AUTORIDADE_FINAL_ENDOCARDITE_INFECCIOSA',
        'AUTORIDADE_FINAL_PNEUMONIA_ADQUIRIDA_COMUNIDADE_GRAVE',
        'AUTORIDADE_FINAL_TEP_AGUDO',
        'AUTORIDADE_FINAL_TAMPONAMENTO_CARDIACO_TRAUMATICO',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
