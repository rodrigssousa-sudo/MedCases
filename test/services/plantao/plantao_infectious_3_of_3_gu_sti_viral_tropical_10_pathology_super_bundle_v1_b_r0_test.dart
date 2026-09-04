import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão infectious 3/3 GU STI viral tropical super bundle V1-B-R0-R1 literal case fix', () {
    late String source;

    setUpAll(() {
      source = File('lib/services/ai_service.dart').readAsStringSync();
    });

    test('all infectious 3/3 authority guards exist', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_PROSTATITE_BACTERIANA_AGUDA',
        'AUTORIDADE_FINAL_CISTITE_AGUDA',
        'AUTORIDADE_FINAL_EPIDIDIMITE_ORQUITE',
        'AUTORIDADE_FINAL_DOENCA_INFLAMATORIA_PELVICA',
        'AUTORIDADE_FINAL_GONORREIA_CLAMIDIA_URETRITE_CERVICITE',
        'AUTORIDADE_FINAL_SIFILIS',
        'AUTORIDADE_FINAL_NEUROSIFILIS_OCULAR_OTICA',
        'AUTORIDADE_FINAL_HERPES_ZOSTER',
        'AUTORIDADE_FINAL_HERPES_SIMPLEX_GENITAL',
        'AUTORIDADE_FINAL_CHIKUNGUNYA',
        'AUTORIDADE_FINAL_LEPTOSPIROSE',
      ]) {
        expect(source, contains(token));
      }
    });

    test('acute bacterial prostatitis precedes simple cystitis', () {
      final prostatitis = source.indexOf('if (isAcuteBacterialProstatitis)');
      final cystitis = source.indexOf('if (isAcuteCystitis)');
      expect(prostatitis, greaterThanOrEqualTo(0));
      expect(cystitis, greaterThan(prostatitis));
      expect(source, contains('NAO realizar massagem prostatica'));
      expect(source, contains('EAU 2026 recomenda tratar ABP conforme rota de UTI sistemica'));
      expect(source, contains('Nao usar nitrofurantoina como tratamento de prostatite'));
    });

    test('ABP cultures and abscess escape are preserved', () {
      expect(source, contains('colher hemoculturas na doenca febril/sistemica'));
      expect(source, contains('suspeita de abscesso prostatico'));
      expect(source, contains('urologia para drenagem quando indicada'));
    });

    test('cystitis uses EAU 2026 first-line stewardship', () {
      expect(source, contains('EAU 2026 atualizou especificamente diagnostico e tratamento da cistite'));
      expect(source, contains('fosfomicina, nitrofurantoina, pivmecilinam ou nitroxolina'));
      expect(source, contains('Evitar aminopenicilinas empiricas e fluoroquinolonas de rotina'));
    });

    test('cystitis escapes systemic UTI and avoids treating asymptomatic bacteriuria routinely', () {
      expect(source, contains('ativar pielonefrite/ITU sistemica'));
      expect(source, contains('confirmar ausencia de comprometimento prostatico'));
      expect(source, contains('Nao tratar bacteriuria assintomatica salvo indicacoes especificas'));
    });

    test('epididymitis prioritizes testicular torsion', () {
      expect(source, contains('excluir torcao testicular primeiro'));
      expect(source, contains('urologia/US Doppler urgente'));
      expect(source, contains('nao deve atrasar exploracao quando torcao for provavel'));
    });

    test('epididymitis therapy is exposure-specific and includes partners', () {
      expect(source, contains('NAAT para gonorreia/clamidia'));
      expect(source, contains('gonococo/clamidia versus organismos entericos'));
      expect(source, contains('tratar parceiros'));
      expect(source, contains('Falta de melhora em aproximadamente 72 h'));
    });

    test('PID uses low threshold empiric therapy and broad pathogen coverage', () {
      expect(source, contains('Manter baixo limiar para tratamento empirico'));
      expect(source, contains('atrasar terapia aumenta risco de sequelas reprodutivas'));
      expect(source, contains('cobrir N. gonorrhoeae, C. trachomatis e anaerobios/organismos vaginais'));
    });

    test('PID hospitalizes key high-risk groups and reevaluates at 72 hours', () {
      expect(source, contains('Gravidez, abscesso tubo-ovariano, doenca grave'));
      expect(source, contains('impossibilidade de excluir emergencia cirurgica'));
      expect(source, contains('Se nao houver melhora clinica em 72 h'));
    });

    test('gonorrhea chlamydia route uses anatomic-site NAAT and current CDC bases', () {
      expect(source, contains('Obter NAAT do sitio anatomico exposto'));
      expect(source, contains('ceftriaxona e a base recomendada pelo CDC'));
      expect(source, contains('Clamidia nao complicada e tratada habitualmente com doxiciclina'));
      expect(source, contains('gravidez e outras contraindicacoes mudam a escolha'));
    });

    test('persistent urethritis does not repeat blind antibiotics', () {
      expect(source, contains('Uretrite/cervicite persistente ou recorrente'));
      expect(source, contains('considerar M. genitalium, T. vaginalis'));
      expect(source, contains('antes de repetir antibioticos as cegas'));
    });

    test('STI route preserves partners and pharyngeal gonorrhea follow-up', () {
      expect(source, contains('Tratar/avaliar parceiros conforme janela CDC'));
      expect(source, contains('Gonorreia faringea possui seguimento especifico'));
      expect(source, contains('cultura/sensibilidade e saude publica'));
    });

    test('syphilis is stage-specific and pregnancy remains penicillin-only proven therapy', () {
      expect(source, contains('definir estadio antes de escolher duracao'));
      expect(source, contains('Penicilina G parenteral e o farmaco preferido em todos os estadios'));
      expect(source, contains('Na gravidez, penicilina e a unica terapia com eficacia demonstrada'));
      expect(source, contains('reacao de Jarisch-Herxheimer'));
    });

    test('neurosyphilis ocular otic route is distinct', () {
      expect(source, contains('AUTORIDADE_FINAL_NEUROSIFILIS_OCULAR_OTICA'));
      expect(source, contains('sintomas oculares exigem exame oftalmologico completo urgente'));
      expect(source, contains('penicilina G cristalina aquosa IV e a terapia preferida'));
      expect(source, contains('Penicilina benzatina IM isolada NAO atinge concentracao adequada'));
    });

    test('zoster gets early antiviral and eye ear dissemination escapes', () {
      expect(source, contains('aciclovir, valaciclovir ou famciclovir sao antivirais preferidos'));
      expect(source, contains('especialmente dentro de ~72 h'));
      expect(source, contains('oftalmologia urgente por zoster oftalmico'));
      expect(source, contains('avaliar Ramsay Hunt'));
      expect(source, contains('Doenca disseminada, visceral ou imunossupressao grave'));
    });

    test('genital HSV uses lesion NAAT and treats every first clinical episode', () {
      expect(source, contains('confirmar preferencialmente com NAAT/PCR tipada'));
      expect(source, contains('Todo primeiro episodio clinico de herpes genital deve receber antiviral sistemico'));
      expect(source, contains('Terapia topica oferece beneficio minimo'));
    });

    test('genital HSV preserves transmission pregnancy and CNS escape', () {
      expect(source, contains('preservativo reduz mas nao elimina transmissao'));
      expect(source, contains('Meningite, encefalite, hepatite, pneumonite ou doenca disseminada'));
      expect(source, contains('aquisicao perto do parto'));
      expect(source, contains('reduzir herpes neonatal'));
    });

    test('chikungunya integrates with dengue and has no specific antiviral', () {
      expect(source, contains('WHO 2025 recomenda abordagem integrada com dengue'));
      expect(source, contains('Nao existe antiviral especifico'));
      expect(source, contains('EVITAR aspirina/AINE ate excluir dengue'));
      expect(source, contains('Apos dengue descartada, anti-inflamatorios podem ser considerados'));
    });

    test('chikungunya has severe organ and persistent arthritis escape', () {
      expect(source, contains('Encefalite, miocardite, choque, falencia organica ou sangramento'));
      expect(source, contains('Artralgia/artrite persistente pode exigir seguimento reumatologico'));
    });

    test('leptospirosis uses June 2026 CDC early-treatment rule', () {
      expect(source, contains('CDC 2-jun-2026 recomenda iniciar antibiotico'));
      expect(source, contains('sem aguardar resultado laboratorial'));
      expect(source, contains('Doenca leve pode ser tratada com doxiciclina'));
      expect(source, contains('doenca grave exige terapia IV como penicilina ou ceftriaxona'));
    });

    test('leptospirosis preserves Weil ICU escape and no automatic PEP', () {
      expect(source, contains('Weil, LRA/oliguria, hemorragia pulmonar'));
      expect(source, contains('internacao/UTI'));
      expect(source, contains('CDC nao possui recomendacao padrao de PEP'));
    });

    test('final infectious precedence is 1/3 then 2/3 then 3/3 then cutaneous', () {
      final first = source.indexOf('if (isBacterialMeningitis)');
      final second = source.indexOf('if (isAcuteBacterialRhinosinusitis)');
      final third = source.indexOf('if (isAcuteBacterialProstatitis)');
      final cutaneous = source.indexOf('if (isSjsTen)');
      expect(first, greaterThanOrEqualTo(0));
      expect(second, greaterThan(first));
      expect(third, greaterThan(second));
      expect(cutaneous, greaterThan(third));
    });

    test('all 30 infectious fronts are represented by final runtime authorities', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_MENINGITE_BACTERIANA',
        'AUTORIDADE_FINAL_ENCEFALITE_HSV_VIRAL',
        'AUTORIDADE_FINAL_SINUSITE_BACTERIANA_AGUDA',
        'AUTORIDADE_FINAL_OTITE_MEDIA_AGUDA',
        'AUTORIDADE_FINAL_OTITE_EXTERNA_AGUDA',
        'AUTORIDADE_FINAL_FARINGITE_ESTREPTOCOCICA',
        'AUTORIDADE_FINAL_EPIGLOTITE',
        'AUTORIDADE_FINAL_INFLUENZA',
        'AUTORIDADE_FINAL_COVID19',
        'AUTORIDADE_FINAL_COQUELUCHE_PERTUSSIS',
        'AUTORIDADE_FINAL_TUBERCULOSE_PULMONAR',
        'AUTORIDADE_FINAL_GASTROENTERITE_DIARREIA_INFECCIOSA',
        'AUTORIDADE_FINAL_CLOSTRIDIOIDES_DIFFICILE',
        'AUTORIDADE_FINAL_CISTITE_AGUDA',
        'AUTORIDADE_FINAL_PROSTATITE_BACTERIANA_AGUDA',
        'AUTORIDADE_FINAL_EPIDIDIMITE_ORQUITE',
        'AUTORIDADE_FINAL_DOENCA_INFLAMATORIA_PELVICA',
        'AUTORIDADE_FINAL_GONORREIA_CLAMIDIA_URETRITE_CERVICITE',
        'AUTORIDADE_FINAL_SIFILIS',
        'AUTORIDADE_FINAL_HERPES_ZOSTER',
        'AUTORIDADE_FINAL_HERPES_SIMPLEX_GENITAL',
        'AUTORIDADE_FINAL_IMPETIGO_ECTIMA',
        'AUTORIDADE_FINAL_MORDEDURA_INFECTADA',
        'AUTORIDADE_FINAL_ARTRITE_SEPTICA',
        'AUTORIDADE_FINAL_OSTEOMIELITE',
        'AUTORIDADE_FINAL_DENGUE',
        'AUTORIDADE_FINAL_CHIKUNGUNYA',
        'AUTORIDADE_FINAL_LEPTOSPIROSE',
        'AUTORIDADE_FINAL_MALARIA',
        'AUTORIDADE_FINAL_INFECCAO_AGUDA_HIV',
      ]) {
        expect(source, contains(token));
      }
    });

    test('prior major bundles remain present after 30-infection closure', () {
      for (final token in <String>[
        'AUTORIDADE_FINAL_SJS_TEN',
        'AUTORIDADE_FINAL_FASCIITE_NECROSANTE',
        'AUTORIDADE_FINAL_CELULITE_ERISIPELA',
        'AUTORIDADE_FINAL_ABSCESSO_CUTANEO',
        'AUTORIDADE_FINAL_PNEUMONIA_ADQUIRIDA_COMUNIDADE_GRAVE',
        'AUTORIDADE_FINAL_PIELONEFRITE_ITU_SISTEMICA',
        'AUTORIDADE_FINAL_VASCULITE_ANCA',
        'AUTORIDADE_FINAL_CETOACIDOSE_DIABETICA',
        'AUTORIDADE_FINAL_PANCREATITE_AGUDA_GRAVE',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}
