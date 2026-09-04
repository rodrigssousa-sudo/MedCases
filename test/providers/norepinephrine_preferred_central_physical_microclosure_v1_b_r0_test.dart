import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_compliance_guard.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_resolver.dart';

void main() {
  group('Norepinephrine preferred-central physical microclosure', () {
    const ptQuery =
        'Paciente adulto em choque séptico, necessitando noradrenalina. '
        'Como preparar e por qual acesso posso iniciar?';

    String evidencePt() => ClinicalCrosscuttingEvidenceResolver.enrich(
      query: ptQuery,
      baseContext: '',
      lang: 'pt',
    );

    test('second exact iPhone physical false-negative is replaced', () {
      const physicalOutput = '''
🟥 CHOQUE SÉPTICO — CONDUTA IMEDIATA

🚨 Conduta imediata:
• 1. Preparar noradrenalina 1 mg em 250 mL de SF 0,9% (taxa inicial de 0,1–0,5 µg/kg/min IV).
• 2. Acesso venoso calibroso (preferencialmente veia central) para administração.
• 3. Monitorar constantemente a pressão arterial e a resposta hemodinâmica.

🔑 Pontos-chave:
• Ajustar a dose conforme resposta clínica e metas de PAM (≥65 mmHg).
• Avaliar frequentemente sinais de hipoperfusão.

🚩 RED FLAGS:
• Cuidado com extravasamento e alteração no fluxo.

📌 Iniciar monitorização hemodinâmica contínua.
''';

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: ptQuery,
        assistantOutput: physicalOutput,
        lang: 'pt',
        evidenceContext: evidencePt(),
      );

      expect(result.evidenceId, 'norepinephrine_preparation_and_access');
      expect(result.modified, isTrue);
      expect(
        result.violations.join('|'),
        contains('preferencialmente veia central'),
      );

      expect(
        result.text,
        contains('Não atrasar o início aguardando acesso venoso central'),
      );
      expect(result.text, contains('acesso periférico adequado'));
      expect(result.text, contains('preferencialmente proximal'));
      expect(result.text, contains('vigilância de extravasamento'));
      expect(result.text, contains('pronta para administrar'));
      expect(result.text, contains('não requer diluição adicional'));

      expect(
        result.text.toLowerCase(),
        isNot(contains('preferencialmente veia central')),
      );
    });

    test('preferred-central PT wording variants fail closed', () {
      const variants = <String>[
        'Preferencialmente via central para a noradrenalina.',
        'Preferencialmente acesso central para infusão.',
        'De preferência veia central.',
        'Acesso central preferencial.',
      ];

      for (final output in variants) {
        final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
          query: ptQuery,
          assistantOutput: output,
          lang: 'pt',
          evidenceContext: evidencePt(),
        );
        expect(result.modified, isTrue, reason: output);
      }
    });

    test('preferred-central Spanish wording variants fail closed', () {
      const esQuery =
          'Paciente adulto con shock séptico. ¿Cómo preparar noradrenalina '
          'y por qué acceso puedo iniciarla?';

      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: esQuery,
        baseContext: '',
        lang: 'es',
      );

      const variants = <String>[
        'Preferentemente vena central.',
        'Preferentemente acceso central.',
        'De preferencia vena central.',
      ];

      for (final output in variants) {
        final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
          query: esQuery,
          assistantOutput: output,
          lang: 'es',
          evidenceContext: evidence,
        );
        expect(result.modified, isTrue, reason: output);
      }
    });

    test('canonical replacement remains idempotent', () {
      final first = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: ptQuery,
        assistantOutput: 'Preferencialmente veia central.',
        lang: 'pt',
        evidenceContext: evidencePt(),
      );
      expect(first.modified, isTrue);

      final second = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: ptQuery,
        assistantOutput: first.text,
        lang: 'pt',
        evidenceContext: evidencePt(),
      );
      expect(second.modified, isFalse);
      expect(second.text, first.text);
    });
  });
}
