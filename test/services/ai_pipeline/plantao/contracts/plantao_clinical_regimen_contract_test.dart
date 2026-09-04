import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_clinical_regimen_contract.dart';

void main() {
  group('PlantaoClinicalRegimenResolver ACS V2', () {
    test(
      'generic IAM has AAS 300, atorvastatin 80 and clopidogrel decision support',
      () {
        final c = PlantaoClinicalRegimenResolver.resolve(query: 'IAM')!;
        expect(c.scenario, PlantaoClinicalRegimenScenario.acsUnspecified);
        expect(
          c.medications.map((m) => '${m.drugId}:${m.dose}').toList(),
          <String>['aspirin:300', 'atorvastatin:80'],
        );
        expect(c.deferNumericClopidogrel, isTrue);
        expect(c.exposeClopidogrelDecisionSupport, isTrue);
        final block = c.toPromptBlock(languageCode: 'pt');
        expect(block, contains('Atorvastatina 80 mg VO'));
        expect(block, contains('CLOPIDOGREL_DECISION_SUPPORT='));
        expect(block, contains('300 ou 600 mg por via oral'));
        expect(block, isNot(contains('CLOPIDOGREL_NUMERICO=DEFERIDO')));
      },
    );

    test('PT and ES equivalent IAM variants keep one typed core', () {
      for (final q in const <String>[
        'IAM',
        'Infarto agudo do miocárdio',
        'Infarto agudo de miocardio',
        'Síndrome coronariana aguda',
        'Síndrome coronaria aguda',
      ]) {
        final c = PlantaoClinicalRegimenResolver.resolve(query: q)!;
        expect(
          c.scenario,
          PlantaoClinicalRegimenScenario.acsUnspecified,
          reason: q,
        );
        expect(
          c.medications.map((m) => '${m.drugId}:${m.dose}').toList(),
          <String>['aspirin:300', 'atorvastatin:80'],
          reason: q,
        );
      }
    });

    test(
      'symptom-only suspected and theoretical inputs remain fail-closed',
      () {
        for (final q in const <String>[
          'Dor torácica',
          'Dolor torácico',
          'Dor torácica aguda com suspeita de infarto',
          'Dolor torácico agudo con sospecha de infarto',
          'O que é IAM?',
          'Qué es el IAM?',
        ]) {
          expect(
            PlantaoClinicalRegimenResolver.resolve(query: q),
            isNull,
            reason: q,
          );
        }
      },
    );

    test(
      'PCI has statin, ticagrelor preferred and clopidogrel 600 fallback',
      () {
        final c = PlantaoClinicalRegimenResolver.resolve(
          query: 'IAM confirmado para angioplastia primaria PCI',
        )!;
        expect(
          c.medications.map((m) => '${m.drugId}:${m.dose}').toList(),
          <String>[
            'aspirin:300',
            'atorvastatin:80',
            'ticagrelor:180',
            'clopidogrel:600',
          ],
        );
        expect(c.deferNumericClopidogrel, isFalse);
      },
    );

    test('fibrinolysis age branches remain deterministic with statin', () {
      final young = PlantaoClinicalRegimenResolver.resolve(
        query: 'STEMI confirmado com fibrinólise',
        patientAge: '75',
      )!;
      expect(
        young.medications.map((m) => '${m.drugId}:${m.dose}').toList(),
        <String>['aspirin:300', 'atorvastatin:80', 'clopidogrel:300'],
      );
      final old = PlantaoClinicalRegimenResolver.resolve(
        query: 'IAM com supra confirmado, fibrinolise',
        patientAge: '82',
      )!;
      final clop = old.medications.singleWhere(
        (m) => m.drugId == 'clopidogrel',
      );
      expect(clop.dose, 75);
      expect(clop.instructionPt, contains('sem carga'));
      final unknown = PlantaoClinicalRegimenResolver.resolve(
        query: 'STEMI confirmado com fibrinólise',
      )!;
      expect(unknown.medications.map((m) => m.drugId).toList(), <String>[
        'aspirin',
        'atorvastatin',
      ]);
      expect(unknown.ageRequiredForClopidogrel, isTrue);
    });

    test(
      'NSTE-ACS keeps statin and preferred ticagrelor while clopidogrel stays deferred',
      () {
        final c = PlantaoClinicalRegimenResolver.resolve(
          query: 'NSTEMI confirmado manejo inicial',
        )!;
        expect(
          c.medications.map((m) => '${m.drugId}:${m.dose}').toList(),
          <String>['aspirin:300', 'atorvastatin:80', 'ticagrelor:180'],
        );
        expect(c.deferNumericClopidogrel, isTrue);
        expect(c.exposeClopidogrelDecisionSupport, isFalse);
      },
    );

    test('medications remain immutable', () {
      final c = PlantaoClinicalRegimenResolver.resolve(query: 'IAM')!;
      expect(
        () => c.medications.add(c.medications.first),
        throwsUnsupportedError,
      );
    });
  });
}
