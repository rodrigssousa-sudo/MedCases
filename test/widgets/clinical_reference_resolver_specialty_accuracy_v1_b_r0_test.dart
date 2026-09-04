import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';

void main() {
  ClinicalReferenceData resolve(
    String userText,
    String aiText, {
    String lang = 'pt',
  }) {
    return ClinicalReferenceResolver.resolve(
      userText: userText,
      aiText: aiText,
      lang: lang,
    );
  }

  String joined(ClinicalReferenceData data) => data.lines.join(' ');

  group('ClinicalReferenceResolver specialty accuracy V1-B-R0', () {
    test('neumotórax aberto usa trauma torácico e nunca referência renal', () {
      final result = resolve(
        'neumotórax abierto',
        '🟥 NEUMOTÓRAX ABIERTO\n🚨 Conducta inmediata',
        lang: 'es',
      );

      expect(joined(result), contains('ATLS 11'));
      expect(joined(result), contains('WSES-AAST'));
      expect(joined(result), isNot(contains('KDIGO')));
      expect(joined(result).toLowerCase(), isNot(contains('renal')));
    });

    test('hemotórax maciço permanece no domínio de trauma torácico', () {
      final result = resolve(
        'hemotórax maciço',
        '🟥 HEMOTÓRAX MACIÇO\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('ATLS 11'));
      expect(joined(result), contains('Thoracic trauma'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('asma usa GINA 2026', () {
      final result = resolve(
        'asma grave',
        '🟥 ASMA GRAVE\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('GINA'));
      expect(joined(result), contains('2026'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('DPOC/EPOC usa GOLD 2026', () {
      final result = resolve(
        'exacerbação de DPOC',
        '🟥 EXACERBAÇÃO DE DPOC\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('GOLD'));
      expect(joined(result), contains('2026'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('pneumonia adulta usa ATS 2025 e não renal', () {
      final result = resolve(
        'pneumonia adquirida na comunidade em adulto',
        '🟥 PNEUMONIA ADQUIRIDA NA COMUNIDADE\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('ATS'));
      expect(joined(result), contains('2025'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('pneumonia pediátrica usa IDSA/PIDS 2026', () {
      final result = resolve(
        'pneumonia em criança',
        '🟥 PNEUMONIA PEDIÁTRICA\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('IDSA/PIDS'));
      expect(joined(result), contains('2026'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('TEP usa referência de embolia pulmonar e não renal', () {
      final result = resolve(
        'TEP confirmado',
        '🟥 TROMBOEMBOLISMO PULMONAR\n🚨 Conduta imediata',
      );

      expect(
        joined(result),
        contains('AHA/ACC/ACCP/ACEP/CHEST/SCAI/SHM/SIR/SVM/SVN'),
      );
      expect(joined(result), contains('Pulmonary Embolism'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('síndrome coronariana aguda usa guideline 2025 específico', () {
      final result = resolve(
        'IAM',
        '🟥 INFARTO AGUDO DO MIOCÁRDIO\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('ACC/AHA/ACEP/NAEMSP/SCAI'));
      expect(joined(result), contains('2025'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('sepse adulta usa Surviving Sepsis Campaign 2026', () {
      final result = resolve(
        'sepse com choque séptico',
        '🟥 CHOQUE SÉPTICO\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('Surviving Sepsis Campaign'));
      expect(joined(result), contains('2026'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('sepse pediátrica usa SSC pediátrica 2026', () {
      final result = resolve(
        'sepse em criança',
        '🟥 SEPSE PEDIÁTRICA\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('Pediatric sepsis'));
      expect(joined(result), contains('2026'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('cetoacidose diabética usa consenso de crise hiperglicêmica', () {
      final result = resolve(
        'cetoacidose diabética',
        '🟥 CETOACIDOSE DIABÉTICA\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('Hyperglycemic Crises'));
      expect(joined(result), contains('ADA'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('DRC usa KDIGO e somente quando o domínio renal é explícito', () {
      final result = resolve(
        'doença renal crônica estágio 4',
        '🟥 DOENÇA RENAL CRÔNICA\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('KDIGO'));
      expect(joined(result), contains('2024'));
      expect(joined(result), isNot(contains('GINA')));
      expect(joined(result), isNot(contains('GOLD')));
    });

    test('AVC isquêmico usa AHA/ASA 2026', () {
      final result = resolve(
        'acidente vascular cerebral isquêmico',
        '🟥 AVC ISQUÊMICO AGUDO\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('AHA/ASA'));
      expect(joined(result), contains('2026'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('anafilaxia usa practice parameter específico', () {
      final result = resolve(
        'anafilaxia',
        '🟥 ANAFILAXIA\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('AAAAI/ACAAI JTFPP'));
      expect(joined(result), contains('2023'));
      expect(joined(result), isNot(contains('KDIGO')));
    });

    test('PCR adulta usa AHA CPR/ECC 2025', () {
      final result = resolve(
        'parada cardiorrespiratória em adulto',
        '🟥 PARADA CARDIORRESPIRATÓRIA\n🚨 Conduta imediata',
      );

      expect(joined(result), contains('AHA'));
      expect(joined(result), contains('CPR'));
      expect(joined(result), contains('2025'));
    });

    test('fallback inespecífico é neutro e atual, sem especialidade inventada', () {
      final result = resolve(
        'explicar fisiopatologia',
        'Resposta clínica geral sem diagnóstico ou tema definido.',
      );

      expect(result.sourceType, 'general_fallback');
      expect(joined(result), contains("Harrison's"));
      expect(joined(result), contains('22nd'));
      expect(joined(result), contains('2025'));
      expect(joined(result), isNot(contains('KDIGO')));
      expect(joined(result), isNot(contains('GINA')));
      expect(joined(result), isNot(contains('GOLD')));
      expect(joined(result), isNot(contains('UpToDate')));
    });
  });
}
