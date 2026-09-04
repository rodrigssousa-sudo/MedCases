import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_compliance_guard.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_resolver.dart';

bool _hasEmoji(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x1F000 && rune <= 0x1FAFF) ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        (rune >= 0x2300 && rune <= 0x23FF) ||
        (rune >= 0x2B00 && rune <= 0x2BFF)) {
      return true;
    }
  }
  return false;
}

void main() {
  group('Norepinephrine canonical presentation no emoji', () {
    const ptQuery =
        'Paciente adulto em choque séptico, necessitando noradrenalina. '
        'Como preparar e por qual acesso posso iniciar?';

    String ptEvidence() => ClinicalCrosscuttingEvidenceResolver.enrich(
      query: ptQuery,
      baseContext: '',
      lang: 'pt',
    );

    test(
      'incomplete provider output converges to clean text-only hierarchy',
      () {
        final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
          query: ptQuery,
          assistantOutput:
              'Acesso periférico ou central é preferível. Diluir em SF 0,9%.',
          lang: 'pt',
          evidenceContext: ptEvidence(),
        );

        expect(result.modified, isTrue);
        expect(result.text, contains('NORADRENALINA — CHOQUE SÉPTICO'));
        expect(result.text, contains('Conduta imediata:'));
        expect(result.text, contains('Tratamento farmacológico:'));
        expect(result.text, contains('Pontos-chave:'));
        expect(result.text, contains('Red flags:'));
        expect(_hasEmoji(result.text), isFalse);
        expect(result.text, isNot(contains('\uFFFD')));
        expect(result.text, isNot(contains('Preparo:')));
        expect(result.text, isNot(contains('Segurança:')));

        expect(
          result.text,
          contains('Não atrasar o início aguardando acesso venoso central'),
        );
        expect(result.text, contains('acesso periférico adequado'));
        expect(result.text, contains('preferencialmente proximal'));
        expect(result.text, contains('migrar para acesso central'));
        expect(result.text, contains('vigilância de extravasamento'));
        expect(result.text, contains('apresentação premisturada'));
        expect(result.text, contains('pronta para administrar'));
        expect(result.text, contains('não requer diluição adicional'));
      },
    );

    test('text-only canonical output remains idempotent', () {
      final first = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: ptQuery,
        assistantOutput:
            'Acesso periférico ou central é preferível. Diluir em SF 0,9%.',
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
      expect(second.violations, isEmpty);
      expect(second.text, first.text);
      expect(_hasEmoji(second.text), isFalse);
    });
  });
}
