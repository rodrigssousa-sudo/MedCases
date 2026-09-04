import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

String prompt({
  required String lang,
  required String query,
  String? age,
  String? localContext,
  bool plantao = true,
}) {
  return AiService.buildClinicalSystemPrompt(
    lang: lang,
    matchedProtocolSummaries: const <String>[],
    matchedDrugSummaries: const <String>[],
    localAnswerContext: localContext,
    patientAge: age,
    userQuery: query,
    queryIntent: 'tratamento',
    isPlantaoMode: plantao,
  );
}

void main() {
  group('Guardia ACS deterministic regimen prompt contract V1', () {
    test('IAM PT injects canonical regimen block', () {
      final value = prompt(lang: 'pt', query: 'IAM');

      expect(value, contains('[MEDCASES_CLINICAL_REGIMEN_V1]'));
      expect(value, contains('AAS_CANONICA=300 mg VO'));
      expect(value, contains('Atorvastatina 80 mg VO'));
      expect(value, contains('CLOPIDOGREL_DECISION_SUPPORT='));
      expect(value, contains('300 ou 600 mg por via oral'));
      expect(value, isNot(contains('CLOPIDOGREL_NUMERICO=DEFERIDO')));
      expect(value, isNot(contains('Clopidogrel 300 mg VO')));
      expect(value, isNot(contains('Clopidogrel 600 mg VO')));
    });

    test('IAM ES injects localized canonical regimen block', () {
      final value = prompt(lang: 'es', query: 'IAM');

      expect(value, contains('AUTORIDAD TERAPEUTICA TIPADA'));
      expect(value, contains('AAS_CANONICA=300 mg VO'));
      expect(value, contains('Atorvastatina 80 mg VO'));
      expect(value, contains('CLOPIDOGREL_DECISION_SUPPORT='));
      expect(value, contains('300 o 600 mg por via oral'));
      expect(value, isNot(contains('CLOPIDOGREL_NUMERICO=DEFERIDO')));
      expect(value, isNot(contains('Clopidogrel 300 mg VO')));
      expect(value, isNot(contains('Clopidogrel 600 mg VO')));
    });

    test('canonical regimen is later than conflicting local RAG context', () {
      const legacy =
          'Infarto agudo do miocardio confirmado. Contexto local legado com '
          'AAS 250 mg VO e clopidogrel 300 mg VO; texto longo suficiente '
          'para o gate RAG.';
      final value = prompt(
        lang: 'pt',
        query: 'infarto agudo do miocardio confirmado',
        localContext: legacy,
      );

      final localIndex = value.indexOf('AAS 250 mg VO');
      final regimenIndex = value.indexOf('[MEDCASES_CLINICAL_REGIMEN_V1]');
      expect(localIndex, isNonNegative);
      expect(value, contains('DADOS ADICIONAIS VERIFICADOS BASE LOCAL'));
      expect(regimenIndex, greaterThan(localIndex));
      expect(value, contains('REGRA DE CONFLITO'));
    });

    test('suspected infarction/chest pain does not inject disease regimen', () {
      final value = prompt(
        lang: 'pt',
        query: 'Dor torácica aguda com suspeita de infarto',
      );

      expect(value, isNot(contains('[MEDCASES_CLINICAL_REGIMEN_V1]')));
    });

    test('Estudo mode remains untouched', () {
      final value = prompt(lang: 'pt', query: 'IAM', plantao: false);

      expect(value, isNot(contains('[MEDCASES_CLINICAL_REGIMEN_V1]')));
    });

    test('PCI and fibrinolysis are contextual rather than random', () {
      final pci = prompt(
        lang: 'pt',
        query: 'IAM confirmado para angioplastia primaria PCI',
      );
      expect(pci, contains('Atorvastatina 80 mg VO'));
      expect(pci, contains('Ticagrelor 180 mg VO'));
      expect(pci, contains('Clopidogrel 600 mg VO'));

      final lysisYoung = prompt(
        lang: 'pt',
        query: 'STEMI confirmado com fibrinólise',
        age: '60',
      );
      expect(lysisYoung, contains('Clopidogrel 300 mg VO'));
      expect(lysisYoung, isNot(contains('Clopidogrel 600 mg VO')));

      final lysisOlder = prompt(
        lang: 'pt',
        query: 'STEMI confirmado com fibrinólise',
        age: '80',
      );
      expect(lysisOlder, contains('Clopidogrel 75 mg VO'));
      expect(lysisOlder, contains('sem carga'));
    });

    test('integration stays out of frozen routing/gateway/renderer owners', () {
      final ai = File('lib/services/ai_service.dart').readAsStringSync();
      final owner = File(
        'lib/services/ai_pipeline/plantao/contracts/'
        'plantao_clinical_regimen_contract.dart',
      ).readAsStringSync();

      expect(
        ai,
        contains(
          "import 'ai_pipeline/plantao/contracts/plantao_clinical_regimen_contract.dart';",
        ),
      );
      expect(owner, isNot(contains('PlantaoCanonicalRouteResolver')));
      expect(owner, isNot(contains('AiGatewayService')));
      expect(owner, isNot(contains('GuardiaClinicalResponseView')));
      expect(owner, isNot(contains('PlantaoDeterministicDrugValidator')));
      expect(owner, isNot(contains('ClinicalNumericValidator')));
      expect(owner, isNot(contains('FirebaseFirestore')));
    });
  });
}
