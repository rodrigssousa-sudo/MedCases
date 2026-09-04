import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_compliance_guard.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_resolver.dart';

void main() {
  group('Norepinephrine required assertions semantic final closure', () {
    const bothQuery =
        'Paciente adulto em choque séptico, necessitando noradrenalina. '
        'Como preparar e por qual acesso posso iniciar?';

    String evidencePt(String query) =>
        ClinicalCrosscuttingEvidenceResolver.enrich(
          query: query,
          baseContext: '',
          lang: 'pt',
        );

    test(
      'latest iPhone physical output is fail-closed by missing assertions',
      () {
        const physicalOutput = '''
🟥 CHOQUE SÉPTICO — CONDUTA IMEDIATA

🚨 Conduta imediata:
• Acesso venoso calibroso periférico ou central é preferível.
• Preparar Noradrenalina 0,1-3 mcg/kg/min IV em diluição com SF 0,9%.
• Iniciar infusão em bomba de infusão, monitorando PA continuamente.

🔑 Pontos-chave:
• Iniciar a noradrenalina se PAM <65 mmHg após reanimação volêmica.
• Avaliar resposta em 5 a 10 minutos.

🚩 RED FLAGS:
• Se ocorrer isquemia periférica ou arritmias, considere ajuste ou interrupção.
''';

        final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
          query: bothQuery,
          assistantOutput: physicalOutput,
          lang: 'pt',
          evidenceContext: evidencePt(bothQuery),
        );

        expect(result.evidenceId, 'norepinephrine_preparation_and_access');
        expect(result.modified, isTrue);
        final violations = result.violations.join('|');
        expect(
          violations,
          contains('required_assertion_missing:norepi_access_core:0'),
        );
        expect(
          violations,
          contains('required_assertion_missing:norepi_preparation_core:0'),
        );
        expect(
          result.text,
          contains('Não atrasar o início aguardando acesso venoso central'),
        );
        expect(result.text, contains('acesso periférico adequado'));
        expect(result.text, contains('preferencialmente proximal'));
        expect(result.text, contains('vigilância de extravasamento'));
        expect(result.text, contains('migrar para acesso central'));
        expect(result.text, contains('apresentação premisturada'));
        expect(result.text, contains('pronta para administrar'));
        expect(result.text, contains('não requer diluição adicional'));
        expect(
          result.text,
          contains('Formulações manipuladas ou institucionais'),
        );
      },
    );

    test('canonical replacement is idempotent under both positive rules', () {
      final first = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: bothQuery,
        assistantOutput:
            'Acesso periférico ou central é preferível. Diluir em SF 0,9%.',
        lang: 'pt',
        evidenceContext: evidencePt(bothQuery),
      );
      expect(first.modified, isTrue);
      final second = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: bothQuery,
        assistantOutput: first.text,
        lang: 'pt',
        evidenceContext: evidencePt(bothQuery),
      );
      expect(second.modified, isFalse);
      expect(second.violations, isEmpty);
      expect(second.text, first.text);
    });

    test('access-only query does not require preparation assertions', () {
      const query = 'Posso iniciar noradrenalina por qual acesso?';
      const output = '''
Não atrasar o início aguardando acesso venoso central.
Pode ser iniciada por acesso periférico adequado, preferencialmente proximal,
com vigilância de extravasamento; migrar para acesso central conforme necessidade.
''';
      final result =
          ClinicalCrosscuttingEvidenceComplianceGuard.enforceByEvidenceId(
            query: query,
            assistantOutput: output,
            lang: 'pt',
            evidenceId: 'norepinephrine_preparation_and_access',
          );
      expect(result.modified, isFalse);
      expect(result.violations, isEmpty);
    });

    test('preparation-only query does not require access assertions', () {
      const query = 'Como preparar e qual a diluição da noradrenalina?';
      const output = '''
Confirmar sempre a apresentação e a concentração reais.
Na apresentação premisturada contemplada, ela é pronta para administrar e não requer diluição adicional.
Formulações manipuladas ou institucionais podem usar concentrações diferentes.
''';
      final result =
          ClinicalCrosscuttingEvidenceComplianceGuard.enforceByEvidenceId(
            query: query,
            assistantOutput: output,
            lang: 'pt',
            evidenceId: 'norepinephrine_preparation_and_access',
          );
      expect(result.modified, isFalse);
      expect(result.violations, isEmpty);
    });

    test(
      'dose-only query does not activate access or preparation requirements',
      () {
        const query = 'Qual a dose da noradrenalina no choque séptico?';
        const output =
            'Titular noradrenalina conforme PAM e resposta hemodinâmica.';
        final result =
            ClinicalCrosscuttingEvidenceComplianceGuard.enforceByEvidenceId(
              query: query,
              assistantOutput: output,
              lang: 'pt',
              evidenceId: 'norepinephrine_preparation_and_access',
            );
        expect(result.modified, isFalse);
        expect(result.violations, isEmpty);
        expect(result.text, output);
      },
    );

    test('Spanish combined incomplete output fails closed', () {
      const query =
          'Paciente adulto con shock séptico. ¿Cómo preparar noradrenalina '
          'y por qué acceso puedo iniciarla?';
      final result =
          ClinicalCrosscuttingEvidenceComplianceGuard.enforceByEvidenceId(
            query: query,
            assistantOutput:
                'Puede usarse acceso central o periférico. Diluir en solución salina.',
            lang: 'es',
            evidenceId: 'norepinephrine_preparation_and_access',
          );
      expect(result.modified, isTrue);
      expect(
        result.text,
        contains('No retrasar el inicio esperando un acceso venoso central'),
      );
      expect(result.text, contains('vía periférica adecuada'));
      expect(result.text, contains('preferentemente proximal'));
      expect(result.text, contains('vigilancia de extravasación'));
      expect(result.text, contains('lista para administrar'));
      expect(result.text, contains('no requiere dilución adicional'));
    });

    test('fluid maintenance semantic fail-closed remains intact', () {
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
