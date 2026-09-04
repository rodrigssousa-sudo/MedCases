import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_clinical_regimen_output_guard.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_generic_acs_whole_response_semantic_core.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

void main() {
  group('PlantaoGenericAcsWholeResponseSemanticCore V1', () {
    test('different PT model outputs converge byte-for-byte', () {
      final a = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
        userInput: 'IAM',
        assistantOutput: 'resposta livre A',
        languageCode: 'pt',
      );
      final b = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
        userInput: 'IAM',
        assistantOutput: 'resposta livre B completamente diferente',
        languageCode: 'pt',
      );

      expect(a, b);
      expect(a, contains('Conduta imediata:'));
      expect(a, contains('Tratamento farmacológico:'));
      expect(a, contains('Pontos-chave:'));
      expect(a, contains('🚩 RED FLAGS:'));
      expect(a, contains('📌 Realizar ECG e troponina de alta sensibilidade'));
      expect(a, contains('troponina de alta sensibilidade'));
      expect(a, isNot(contains('AAS 300 mg')));
      expect(a, isNot(contains('Atorvastatina 80 mg')));
      expect(a, isNot(contains('Clopidogrel')));
    });

    test('different ES model outputs converge byte-for-byte', () {
      final a = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
        userInput: 'IAM',
        assistantOutput: 'respuesta libre A',
        languageCode: 'es',
      );
      final b = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
        userInput: 'IAM',
        assistantOutput: 'respuesta libre B totalmente diferente',
        languageCode: 'es',
      );

      expect(a, b);
      expect(a, contains('Conducta inmediata:'));
      expect(a, contains('Tratamiento farmacológico:'));
      expect(a, contains('Puntos clave:'));
      expect(a, contains('🚩 RED FLAGS:'));
      expect(a, contains('📌 Realizar ECG y troponina de alta sensibilidad'));
      expect(a, contains('troponina de alta sensibilidad'));
      expect(a, isNot(contains('AAS 300 mg')));
      expect(a, isNot(contains('Atorvastatina 80 mg')));
      expect(a, isNot(contains('Clopidogrel')));
    });

    test('PT and ES use the same section count and semantic slots', () {
      final pt = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
        userInput: 'IAM',
        assistantOutput: 'x',
        languageCode: 'pt',
      );
      final es = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
        userInput: 'IAM',
        assistantOutput: 'y',
        languageCode: 'es',
      );

      expect(pt.split('\n'), hasLength(es.split('\n').length));
      expect(RegExp(r'^• ', multiLine: true).allMatches(pt), hasLength(7));
      expect(RegExp(r'^• ', multiLine: true).allMatches(es), hasLength(7));
    });

    test('all frozen bare generic aliases materialize', () {
      for (final query in <String>[
        'IAM',
        'SCA',
        'infarto',
        'infarto agudo do miocárdio',
        'infarto agudo de miocardio',
        'infarto de miocardio',
        'síndrome coronariana aguda',
        'síndrome coronaria aguda',
        'acute coronary syndrome',
        'myocardial infarction',
      ]) {
        final out = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
          userInput: query,
          assistantOutput: 'free',
          languageCode: 'pt',
        );
        expect(out, startsWith('🟥 INFARTO AGUDO DO MIOCÁRDIO'), reason: query);
      }
    });

    test('modifier-rich and suspected cases remain untouched', () {
      for (final query in <String>[
        'IAM com choque',
        'IAM com alergia a AAS',
        'IAM confirmado para PCI',
        'STEMI confirmado com fibrinólise',
        'suspeita de IAM',
      ]) {
        final out = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
          userInput: query,
          assistantOutput: 'ORIGINAL',
          languageCode: 'pt',
        );
        expect(out, 'ORIGINAL', reason: query);
      }
    });

    test('composition with frozen regimen guard yields one deterministic core', () {
      final semantic = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
        userInput: 'IAM',
        assistantOutput: 'qualquer saída do modelo',
        languageCode: 'pt',
      );
      final finalText = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'IAM',
        assistantOutput: semantic,
        languageCode: 'pt',
      ).text;

      expect(RegExp(r'\bAAS 300 mg VO\b').allMatches(finalText), hasLength(1));
      expect(
        RegExp(r'\bAtorvastatina 80 mg VO\b').allMatches(finalText),
        hasLength(1),
      );
      expect(
        RegExp(r'Clopidogrel — se for o P2Y12 escolhido').allMatches(finalText),
        hasLength(1),
      );
      expect(finalText, contains('Conduta imediata:'));
      expect(finalText, contains('Pontos-chave:'));
      expect(finalText, contains('🚩 RED FLAGS:'));
      expect(
        finalText,
        contains('📌 Realizar ECG e troponina de alta sensibilidade'),
      );

      final dto = PlantaoLocalClinicalOutputAdapter.fromValidatedText(
        finalText,
      );
      expect(dto, isNotNull);
      expect(dto?.condutaImediataItens, hasLength(2));
      expect(dto?.prescricao, hasLength(2));
      expect(dto?.pontosChave, hasLength(2));
      expect(
        dto?.pontosChave,
        contains(
          'Considerar contraindicações e risco hemorrágico antes da terapia antitrombótica',
        ),
      );
      expect(
        dto?.pontosChave,
        contains(
          'Reavaliar sinais vitais, isquemia recorrente e complicações mecânicas ou elétricas',
        ),
      );
      expect(dto?.hardStops, hasLength(3));
    });

    test('materialization is idempotent', () {
      final first = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
        userInput: 'IAM',
        assistantOutput: 'x',
        languageCode: 'es',
      );
      final second = PlantaoGenericAcsWholeResponseSemanticCore.materialize(
        userInput: 'IAM',
        assistantOutput: first,
        languageCode: 'es',
      );
      expect(second, first);
    });
  });
}
