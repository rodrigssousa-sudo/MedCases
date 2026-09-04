import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_compliance_guard.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_resolver.dart';

void main() {
  group('Rich evidence physical final microclosure V1-B-R1', () {
    test('physical norepinephrine wording is deterministically corrected', () {
      const query =
          'Paciente adulto em choque séptico, necessitando noradrenalina. Como preparar e por qual acesso posso iniciar?';

      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: query,
        baseContext: '',
        lang: 'pt',
      );
      expect(evidence, contains('id=norepinephrine_preparation_and_access'));

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: query,
        assistantOutput: '''
🟥 CHOQUE SEPTICO — NORADRENALINA

🚨 Conduta imediata:
• Iniciar noradrenalina 0,05 a 0,5 mcg/kg/min IV.
• Diluir em solução salina ou dextrose a 5%, em uma concentração de 4 mg em 250 mL (16 mcg/mL).

🔑 Pontos-chave:
• Acesso venoso central é preferível, mas pode-se usar um acesso venoso periférico se necessário.
• Monitorar pressão arterial continuamente.
''',
        lang: 'pt',
        evidenceContext: evidence,
      );

      expect(result.modified, isTrue);
      expect(result.evidenceId, 'norepinephrine_preparation_and_access');
      expect(
        result.text,
        contains('Não atrasar o início aguardando acesso venoso central'),
      );
      expect(result.text, contains('acesso periférico adequado'));
      expect(result.text, contains('não requer diluição adicional'));
      expect(result.text, contains('contraindicações listadas: nenhuma'));
      expect(
        result.text.toLowerCase(),
        isNot(contains('acesso venoso central é preferível')),
      );
    });

    test('Spanish central-preferred wording is deterministically corrected', () {
      const query =
          'Paciente adulto con shock séptico. ¿Cómo preparar noradrenalina y por qué acceso puedo iniciarla?';

      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: query,
        baseContext: '',
        lang: 'es',
      );
      expect(evidence, contains('id=norepinephrine_preparation_and_access'));

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: query,
        assistantOutput:
            'El acceso venoso central es preferible. Diluir en solución salina o dextrosa al 5%.',
        lang: 'es',
        evidenceContext: evidence,
      );

      expect(result.modified, isTrue);
      expect(
        result.text,
        contains('No retrasar el inicio esperando un acceso venoso central'),
      );
      expect(result.text, contains('vía periférica adecuada'));
      expect(result.text, contains('no requiere dilución adicional'));
    });

    test('fluid classification uses renderer-stable clinical section', () {
      const expanded =
          'Paciente adulto de 75 kg em manutenção IV. E qual a classificação?';

      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: expanded,
        baseContext: '',
        lang: 'pt',
      );

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: 'E qual a classificação?',
        assistantOutput:
            'Classificação do paciente: Estável. Sem sinais de desidratação ou sobrecarga.',
        lang: 'pt',
        evidenceContext: evidence,
      );

      expect(result.modified, isTrue);
      expect(result.text, startsWith('🟥 FLUIDOTERAPIA'));
      expect(result.text, contains('🚨 Conduta imediata:'));
      expect(
        result.text,
        contains('Categoria terapêutica: manutenção IV rotineira'),
      );
      expect(
        result.text,
        contains('Estado volêmico: dados insuficientes para classificar'),
      );
      expect(result.text, isNot(contains('🟥 CLASSIFICAÇÃO — FLUIDOTERAPIA')));
      expect(
        result.text,
        isNot(contains('🔑 Classificação sustentada pelos dados:')),
      );
    });

    test('unrelated no-evidence output remains no-op', () {
      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: 'cefaleia',
        assistantOutput: 'Avaliar sinais de alarme.',
        lang: 'pt',
        evidenceContext: '',
      );
      expect(result.modified, isFalse);
      expect(result.text, 'Avaliar sinais de alarme.');
    });
  });
}
