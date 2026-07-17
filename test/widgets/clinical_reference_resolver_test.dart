import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';

void main() {
  group('ClinicalReferenceResolver', () {
    test('usa evidência específica quando existe um único fármaco', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'Dose de amiodarona',
        aiText: 'Administrar amiodarona IV em infusão conforme protocolo.',
        lang: 'pt',
      );

      expect(result.sourceType, 'single_drug');
      expect(result.drugKeys, ['amiodarona']);
      expect(result.lines.join(' '), contains('AHA ACLS'));
    });

    test('usa protocolo clínico em resposta polifarmacológica de IAM', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'IAM',
        aiText: 'Clopidogrel 600 mg VO, nitroglicerina 0,4 mg SL, '
            'morfina 2 mg IV, heparina 60 U/kg IV e metoprolol 25 mg VO.',
        lang: 'es',
      );

      expect(result.sourceType, 'polypharmacy_protocol');
      expect(result.protocolId, 'iam_congestao');
      expect(result.drugKeys.length, greaterThan(1));
      expect(result.lines.join(' '), contains('ESC Guidelines for STEMI'));
      expect(result.lines.join(' '), contains('Goodman & Gilman'));
      expect(result.lines.join(' '), contains('Harrison'));
    });

    test('usa protocolo temático mesmo sem fármaco detectado', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'asma grave',
        aiText: 'Evaluar gravedad, saturación y signos de fatiga respiratoria.',
        lang: 'es',
      );

      expect(result.sourceType, 'clinical_protocol');
      expect(result.protocolId, 'asma_grave');
      expect(result.lines.join(' '), contains('GINA'));
    });

    test('nunca devolve resposta sem referências', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'explicar fisiopatologia',
        aiText: 'Resposta clínica geral sem correspondência específica.',
        lang: 'pt',
      );

      expect(result.lines, isNotEmpty);
      expect(result.lines.join(' '), contains('Harrison'));
      expect(result.lines.join(' '), contains('Goodman & Gilman'));
      expect(result.lines.join(' '), contains('UpToDate'));
    });
  });
}
