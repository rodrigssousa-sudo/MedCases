import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_compliance_guard.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_resolver.dart';

void main() {
  group('Norepinephrine physical fail-closed microclosure V1-B-R0', () {
    const ptQuery =
        'Paciente adulto em choque séptico, necessitando noradrenalina. '
        'Como preparar e por qual acesso posso iniciar?';

    String ptEvidence() {
      return ClinicalCrosscuttingEvidenceResolver.enrich(
        query: ptQuery,
        baseContext: '',
        lang: 'pt',
      );
    }

    test('exact physical false-negative is now deterministically replaced', () {
      const physicalOutput = '''
🟥 CHOQUE SÉPTICO — NORADRENALINA

🚨 Conduta imediata:
• Acesso venoso calibroso (cateter 16-18G em veia central ou periférica).
• Preparar solução de noradrenalina diluindo 4 mg em 250 mL de SF 0,9% ou D5% (concentração de 16 mcg/mL).
• Iniciar infusão em bomba de infusão.

💊 Tratamento farmacológico:
• Noradrenalina 0,1-1 µg/kg/min IV — alvo PAM ≥65 mmHg.

🔑 Pontos-chave:
• Monitorar PA e frequência cardíaca continuamente.
• Reavaliar resposta após 30 minutos e ajustar a dose conforme necessário.

🚩 RED FLAGS:
• Não iniciar se houver ausência de acesso venoso adequado ou contrarreação grave.
''';

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: ptQuery,
        assistantOutput: physicalOutput,
        lang: 'pt',
        evidenceContext: ptEvidence(),
      );

      expect(result.evidenceId, 'norepinephrine_preparation_and_access');
      expect(result.modified, isTrue);

      final violations = result.violations.join('|');
      expect(violations, contains('veia central ou periferica'));
      expect(violations, contains('diluindo 4 mg em 250 ml'));
      expect(violations, contains('reavaliar resposta apos 30 minutos'));
      expect(
        violations,
        contains('nao iniciar se houver ausencia de acesso venoso adequado'),
      );
      expect(violations, contains('contrarreacao grave'));

      expect(
        result.text,
        contains('Não atrasar o início aguardando acesso venoso central'),
      );
      expect(result.text, contains('acesso periférico adequado'));
      expect(result.text, contains('preferencialmente proximal'));
      expect(result.text, contains('vigilância de extravasamento'));
      expect(result.text, contains('pronta para administrar'));
      expect(result.text, contains('não requer diluição adicional'));
      expect(result.text, contains('contraindicações listadas: nenhuma'));

      expect(
        result.text.toLowerCase(),
        isNot(contains('reavaliar resposta após 30 minutos')),
      );
      expect(result.text.toLowerCase(), isNot(contains('contrarreação grave')));
      expect(
        result.text.toLowerCase(),
        isNot(
          contains('não iniciar se houver ausência de acesso venoso adequado'),
        ),
      );
    });

    test('canonical norepinephrine replacement remains idempotent', () {
      final first = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: ptQuery,
        assistantOutput:
            'Acesso venoso central é preferível. Diluir em solução salina.',
        lang: 'pt',
        evidenceContext: ptEvidence(),
      );
      expect(first.modified, isTrue);

      final second = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: ptQuery,
        assistantOutput: first.text,
        lang: 'pt',
        evidenceContext: ptEvidence(),
      );
      expect(second.modified, isFalse);
      expect(second.text, first.text);
    });

    test('Spanish physical wording is also fail-closed', () {
      const esQuery =
          'Paciente adulto con shock séptico. ¿Cómo preparar noradrenalina '
          'y por qué acceso puedo iniciarla?';

      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: esQuery,
        baseContext: '',
        lang: 'es',
      );

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: esQuery,
        assistantOutput:
            'Usar catéter 16-18G en vena central o periférica. '
            'Preparar diluyendo 4 mg en 250 mL. '
            'Reevaluar respuesta a los 30 minutos. '
            'No iniciar si no hay acceso venoso adecuado.',
        lang: 'es',
        evidenceContext: evidence,
      );

      expect(result.modified, isTrue);
      expect(
        result.text,
        contains('No retrasar el inicio esperando un acceso venoso central'),
      );
      expect(result.text, contains('vía periférica adecuada'));
      expect(result.text, contains('lista para administrar'));
      expect(result.text, contains('no requiere dilución adicional'));
    });

    test('fluid profile remains untouched by norepinephrine microclosure', () {
      const query =
          'Paciente adulto de 75 kg, sem comorbidades. '
          'Quanto de fluido de manutenção devo passar por dia?';

      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: query,
        baseContext: '',
        lang: 'pt',
      );

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: query,
        assistantOutput:
            'Considerar 30-35 mL/kg/dia. Para 75 kg: 2250 a 2625 mL/dia.',
        lang: 'pt',
        evidenceContext: evidence,
      );

      expect(result.modified, isTrue);
      expect(result.text, contains('25–30 mL/kg/dia'));
      expect(result.text, contains('1875–2250 mL/dia'));
    });
  });
}
