import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão infectious 2/3 ENT respiratory GI skin super bundle V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all infectious 2/3 authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_SINUSITE_BACTERIANA_AGUDA',
        'AUTORIDADE_FINAL_OTITE_MEDIA_AGUDA',
        'AUTORIDADE_FINAL_OTITE_EXTERNA_AGUDA',
        'AUTORIDADE_FINAL_OTITE_EXTERNA_NECROSANTE',
        'AUTORIDADE_FINAL_FARINGITE_ESTREPTOCOCICA',
        'AUTORIDADE_FINAL_INFLUENZA',
        'AUTORIDADE_FINAL_COVID19',
        'AUTORIDADE_FINAL_COQUELUCHE_PERTUSSIS',
        'AUTORIDADE_FINAL_GASTROENTERITE_DIARREIA_INFECCIOSA',
        'AUTORIDADE_FINAL_IMPETIGO_ECTIMA',
        'AUTORIDADE_FINAL_MORDEDURA_INFECTADA',
      ]) {
        expect(source, contains(token));
      }
    });

    test('ABRS differentiates viral illness and preserves stewardship', () {
      expect(source, contains('sintomas persistentes sem melhora'));
      expect(source, contains('piora apos melhora inicial'));
      expect(source, contains('nao indicar antibiotico por rinorreia purulenta isolada'));
      expect(source, contains('orientacao CDC 2026 favorece amoxicilina-clavulanato'));
    });

    test('ABRS has orbital and intracranial escape', () {
      expect(source, contains('Edema orbitario, alteracao visual, oftalmoplegia'));
      expect(source, contains('possivel complicacao orbitaria/intracraniana'));
    });

    test('AOM requires otoscopic inflammation and separates effusion', () {
      expect(source, contains('abaulamento da membrana timpanica'));
      expect(source, contains('efusao sem inflamacao aguda nao e AOM'));
      expect(source, contains('observacao vigilante'));
    });

    test('AOM uses current first-line logic without universal dose', () {
      expect(source, contains('amoxicilina e primeira linha habitual segundo AAP/CDC'));
      expect(source, contains('amoxicilina-clavulanato ou alternativa'));
      expect(source, contains('Nao inventar dose'));
    });

    test('AOM escapes to mastoid and intracranial complications', () {
      expect(source, contains('Mastoidalgia/edema retroauricular'));
      expect(source, contains('nao tratar como AOM ambulatorial simples'));
    });

    test('simple otitis externa is topical-first and avoids routine systemic antibiotic', () {
      expect(source, contains('terapia topica otologica'));
      expect(source, contains('considerar mecha se o edema impedir penetracao das gotas'));
      expect(source, contains('Nao usar antibiotico sistemico de rotina na AOE nao complicada'));
    });

    test('necrotizing otitis externa is explicitly split from simple AOE', () {
      expect(source, contains('final isNecrotizingOtitisExterna ='));
      expect(source, contains('AUTORIDADE_FINAL_OTITE_EXTERNA_NECROSANTE'));
      expect(source, contains('Nao manejar como otite do nadador simples'));
      expect(source, contains('atividade antipseudomonas'));
      expect(source, contains('osteomielite de base de cranio'));
    });

    test('GAS pharyngitis uses 2025 IDSA risk stratification and testing', () {
      expect(source, contains('atualizacao IDSA 2025'));
      expect(source, contains('usar escore clinico'));
      expect(source, contains('Confirmar com teste antigenico rapido ou cultura/NAAT'));
      expect(source, contains('Nao tratar faringite viral com antibiotico'));
    });

    test('GAS treatment remains penicillin or amoxicillin first-line', () {
      expect(source, contains('penicilina ou amoxicilina seguem como primeira linha'));
      expect(source, contains('Estridor, voz abafada, sialorreia, trismo'));
      expect(source, contains('descartar epiglotite ou abscesso profundo'));
    });

    test('influenza gives antiviral precedence to severe and high-risk disease', () {
      expect(source, contains('doenca grave/progressiva ou pacientes de alto risco'));
      expect(source, contains('sem aguardar confirmacao laboratorial'));
      expect(source, contains('mesmo apos 48 h do inicio'));
      expect(source, contains('CDC 2026 mantem oseltamivir'));
    });

    test('influenza does not create automatic antibiotics and escapes to CAP', () {
      expect(source, contains('Nao usar antibiotico para influenza nao complicada'));
      expect(source, contains('ativar avaliacao de CAP/sepse'));
      expect(source, contains('Nao usar corticoide sistemico apenas para influenza'));
    });

    test('COVID outpatient antiviral route is risk and window dependent', () {
      expect(source, contains('ambulatorios com risco de COVID grave'));
      expect(source, contains('dentro da janela autorizada'));
      expect(source, contains('CDC 2026 prioriza nirmatrelvir/ritonavir'));
      expect(source, contains('revisao rigorosa de interacoes e funcao renal/hepatica'));
    });

    test('COVID preserves remdesivir alternative and bacterial stewardship', () {
      expect(source, contains('remdesivir IV e alternativa eficaz'));
      expect(source, contains('molnupiravir fica para situacoes'));
      expect(source, contains('Nao indicar antibiotico por COVID isolada'));
      expect(source, contains('Nao atrasar manejo de TEP, CAP bacteriana, sepse'));
    });

    test('pertussis uses current CDC macrolide route', () {
      expect(source, contains('CDC 2025 recomenda macrolideos'));
      expect(source, contains('TMP-SMX e alternativa'));
      expect(source, contains('nao inventar dose'));
    });

    test('pertussis protects high-risk contacts and infants', () {
      expect(source, contains('precaucoes por goticulas'));
      expect(source, contains('PEP de contatos de alto risco'));
      expect(source, contains('Apneia, cianose, dificuldade respiratoria'));
    });

    test('infectious diarrhea is hydration-first and testing is selective', () {
      expect(source, contains('reidratacao oral e primeira linha'));
      expect(source, contains('cristaloide IV fica para desidratacao grave'));
      expect(source, contains('nao pedir painel amplo de rotina'));
    });

    test('infectious diarrhea preserves stewardship and STEC safety', () {
      expect(source, contains('Nao usar antibiotico empirico de rotina na diarreia aquosa aguda'));
      expect(source, contains('C. difficile possui rota propria e deve preceder esta entidade'));
      expect(source, contains('suspeita de STEC/toxina Shiga'));
      expect(source, contains('evitar antibioticos e antimotilidade'));
    });

    test('impetigo and ecthyma are separated by depth and extent', () {
      expect(source, contains('Impetigo limitado pode ser tratado com antibiotico topico'));
      expect(source, contains('lesoes numerosas, surto, ectima ou doenca mais extensa'));
      expect(source, contains('Ectima penetra derme'));
    });

    test('impetigo escapes to prior cutaneous severe routes', () {
      expect(source, contains('Dor desproporcional, progressao rapida'));
      expect(source, contains('ativar celulite/abscesso/fasciite necrosante'));
    });

    test('infected bites require irrigation exploration and broad bite-flora coverage', () {
      expect(source, contains('Irrigar copiosamente, explorar profundidade'));
      expect(source, contains('flora aerobica e anaerobica da mordedura'));
      expect(source, contains('amoxicilina-clavulanato e opcao oral habitual'));
    });

    test('bite route preserves tetanus and rabies prevention', () {
      expect(source, contains('antibiotico nao previne tetano'));
      expect(source, contains('avaliar risco de raiva com saude publica'));
      expect(source, contains('PEP inclui cuidado da ferida, vacina e HRIG'));
    });

    test('infectious precedence is 1/3 then 2/3 then cutaneous', () {
      final first = source.indexOf('if (isBacterialMeningitis)');
      final second = source.indexOf('if (isAcuteBacterialRhinosinusitis)');
      final cDiff = source.indexOf('if (isClostridioidesDifficile)');
      final genericDiarrhea = source.indexOf('if (isInfectiousGastroenteritis)');
      final cutaneous = source.indexOf('if (isSjsTen)');

      expect(first, greaterThanOrEqualTo(0));
      expect(second, greaterThan(first));
      expect(cDiff, lessThan(genericDiarrhea));
      expect(cutaneous, greaterThan(second));
      expect(genericDiarrhea, lessThan(cutaneous));
    });

    test('infectious 1/3 and prior major authorities remain present', () {
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
        'AUTORIDADE_FINAL_SJS_TEN',
        'AUTORIDADE_FINAL_FASCIITE_NECROSANTE',
        'AUTORIDADE_FINAL_CELULITE_ERISIPELA',
        'AUTORIDADE_FINAL_ABSCESSO_CUTANEO',
        'AUTORIDADE_FINAL_PNEUMONIA_ADQUIRIDA_COMUNIDADE_GRAVE',
        'AUTORIDADE_FINAL_PIELONEFRITE_ITU_SISTEMICA',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
