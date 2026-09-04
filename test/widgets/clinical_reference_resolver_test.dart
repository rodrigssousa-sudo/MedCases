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

      expect(result.sourceType, 'specialty_fallback_acute_coronary_syndrome');
      expect(result.protocolId, isNull);
      expect(result.drugKeys.length, greaterThan(1));
      expect(result.lines.join(' '), contains('Guideline for Management of Acute Coronary Syndromes (2025)'));
      expect(
        result.lines.join(' '),
        contains('ACC/AHA/ACEP/NAEMSP/SCAI'),
      );
      expect(result.lines.join(' '), contains('2025'));
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

    test('não vincula protocolo específico em sintoma ainda diferencial', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'Dor torácica',
        aiText: '🟥 DOR TORÁCICA — DIFERENCIAIS PRIORITÁRIOS\n'
            '🔑 Pontos-chave:\n'
            '• Diferenciais prioritários: IAM, TEP, pneumotórax, dissecção aórtica',
        lang: 'pt',
      );

      expect(result.sourceType, 'general_fallback');
      expect(result.protocolId, isNull);
    });

    test('nunca devolve resposta sem referências', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'explicar fisiopatologia',
        aiText: 'Resposta clínica geral sem correspondência específica.',
        lang: 'pt',
      );

      expect(result.lines, isNotEmpty);
      expect(result.lines.join(' '), contains('Harrison'));
      expect(result.lines.join(' '), contains('22nd'));
      expect(result.lines.join(' '), isNot(contains('Goodman & Gilman')));
      expect(result.lines.join(' '), isNot(contains('UpToDate')));
    });
  });
}
