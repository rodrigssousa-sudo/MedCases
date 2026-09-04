import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_clinical_regimen_output_guard.dart';

void main() {
  group('PlantaoClinicalRegimenOutputGuard V2', () {
    String generic(String clop) =>
        '''
INFARTO AGUDO DO MIOCÁRDIO
🚨 Conduta imediata:
• Monitorização contínua
💊 Tratamento farmacológico:
• AAS 300 mg VO
• Clopidogrel $clop mg VO
🔑 Pontos-chave:
• Definir reperfusão
''';

    test('generic 300 and 600 converge to the same final pharmacology', () {
      final a = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'IAM',
        assistantOutput: generic('300'),
        languageCode: 'pt',
      );
      final b = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'IAM',
        assistantOutput: generic('600'),
        languageCode: 'pt',
      );
      expect(a.text, b.text);
      expect(a.text, contains('AAS 300 mg VO'));
      expect(a.text, contains('Atorvastatina 80 mg VO'));
      expect(a.text, contains('300 ou 600 mg por via oral'));
      expect(a.text, isNot(contains('Clopidogrel 300 mg VO')));
      expect(a.text, isNot(contains('Clopidogrel 600 mg VO')));
    });

    test(
      'generic Spanish removes random nitrate and morphine from pharmacology',
      () {
        const raw = '''
INFARTO AGUDO DE MIOCARDIO
🚨 Conducta inmediata:
• Monitorización
💊 Tratamiento farmacológico:
• AAS 300 mg VO
• Nitroglicerina 0.4 mg SL
• Morfina si dolor refractario
• Clopidogrel 600 mg VO
🔑 Puntos clave:
• Definir reperfusión
''';
        final r = PlantaoClinicalRegimenOutputGuard.enforce(
          userInput: 'IAM',
          assistantOutput: raw,
          languageCode: 'es',
        );
        expect(r.text, contains('AAS 300 mg VO'));
        expect(r.text, contains('Atorvastatina 80 mg VO'));
        expect(r.text, contains('300 o 600 mg por vía oral'));
        expect(r.text, isNot(contains('Nitroglicerina 0.4 mg SL')));
        expect(r.text, isNot(contains('Morfina si dolor refractario')));
      },
    );

    test(
      'physical ES without pharmacology heading inserts canonical block before emoji key points',
      () {
        const raw = '''
🟥 INFARTO AGUDO DE MIOCARDIO — CONDUCTA INMEDIATA
🚨 Conducta inmediata:
* AAS 300 mg VO — carga masticable.
* Atorvastatina 80 mg VO — estatina de alta intensidad.
* Evaluar necesidad de anticoagulación y fármacos P2Y12.
🔑 Puntos clave:
* Confirmar diagnóstico con ECG y marcadores.
🚩 RED FLAGS:
* Deterioro hemodinámico.
''';
        final result = PlantaoClinicalRegimenOutputGuard.enforce(
          userInput: 'IAM',
          assistantOutput: raw,
          languageCode: 'es',
        );
        expect(result.modified, isTrue);
        expect(result.text, contains('Tratamiento farmacológico:'));
        expect(RegExp(r'\bAAS 300 mg VO\b').allMatches(result.text).length, 1);
        expect(
          RegExp(r'\bAtorvastatina 80 mg VO\b').allMatches(result.text).length,
          1,
        );
        expect(RegExp(r'Clopidogrel —').allMatches(result.text).length, 1);
        expect(result.text, contains('300 o 600 mg por vía oral'));
        expect(result.text, contains('🔑 Puntos clave:'));
      },
    );

    test(
      'physical PT duplicate immediate core plus emoji pharmacology converges to one core',
      () {
        const raw = '''
🟥 INFARTO AGUDO DO MIOCARDIO — CONDUTA IMEDIATA
🚨 Conduta imediata:
*AAS 300 mg VO mastigável — carga canônica*
*Atorvastatina 80 mg VO — estatina de alta intensidade*
*Se indicado, administrar Clopidogrel — se for o P2Y12 escolhido: sem fibrinólise, carga de 300 ou 600 mg por via oral conforme a estratégia; com fibrinólise, 300 mg se idade ≤75 anos e 75 mg inicial sem carga se >75 anos — carga*
💊 Tratamento farmacológico:
* **AAS + 300 mg + VO** — redução da mortalidade
* **Atorvastatina + 80 mg + VO** — proteção cardiovascular
* **Clopidogrel 600 mg VO** — antiagregante plaquetário
🔑 Pontos-chave:
* Considerar estratégia de reperfusão se indicada
🚩 RED FLAGS:
* Sinais de choque
''';
        final result = PlantaoClinicalRegimenOutputGuard.enforce(
          userInput: 'IAM',
          assistantOutput: raw,
          languageCode: 'pt',
        );
        expect(result.modified, isTrue);
        expect(RegExp(r'\bAAS 300 mg VO\b').allMatches(result.text).length, 1);
        expect(
          RegExp(r'\bAtorvastatina 80 mg VO\b').allMatches(result.text).length,
          1,
        );
        expect(RegExp(r'Clopidogrel —').allMatches(result.text).length, 1);
        expect(result.text, isNot(contains('AAS + 300 mg + VO')));
        expect(result.text, isNot(contains('Atorvastatina + 80 mg + VO')));
        expect(result.text, isNot(contains('>75 anos — carga')));
        expect(result.text, contains('🔑 Pontos-chave:'));
      },
    );

    test('PCI wrong 300 becomes 600 and correct 600 stays unchanged', () {
      final wrong = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'IAM confirmado para angioplastia primaria PCI',
        assistantOutput: '• Clopidogrel 300 mg VO de carga',
        languageCode: 'pt',
      );
      expect(wrong.text, contains('Clopidogrel 600 mg VO'));
      final good = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'IAM confirmado para angioplastia primaria PCI',
        assistantOutput: '• Clopidogrel 600 mg VO como alternativa',
        languageCode: 'pt',
      );
      expect(good.modified, isFalse);
    });

    test('fibrinolysis <=75 rejects 600 and loading 75 in favor of 300', () {
      for (final raw in const <String>[
        '• Clopidogrel 600 mg VO de carga',
        '• Clopidogrel 75 mg VO inicial de carga',
      ]) {
        final r = PlantaoClinicalRegimenOutputGuard.enforce(
          userInput: 'STEMI confirmado com fibrinólise',
          assistantOutput: raw,
          languageCode: 'pt',
          patientAge: '70',
        );
        expect(r.text, contains('Clopidogrel 300 mg VO'), reason: raw);
      }
    });

    test(
      'fibrinolysis >75 rejects 300/600 and enforces 75 initial without load',
      () {
        for (final dose in const <String>['300', '600']) {
          final r = PlantaoClinicalRegimenOutputGuard.enforce(
            userInput: 'IAM com supra confirmado, fibrinolise',
            assistantOutput: '• Clopidogrel $dose mg VO de carga',
            languageCode: 'pt',
            patientAge: '82',
          );
          expect(r.text, contains('Clopidogrel 75 mg VO'), reason: dose);
          expect(r.text, contains('sem carga'), reason: dose);
        }
        final wording = PlantaoClinicalRegimenOutputGuard.enforce(
          userInput: 'IAM com supra confirmado, fibrinolise',
          assistantOutput: '• Clopidogrel 75 mg VO inicial',
          languageCode: 'pt',
          patientAge: '82',
        );
        expect(wording.text, contains('sem carga'));
      },
    );

    test('fibrinolysis unknown age remains deferred', () {
      final r = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'STEMI confirmado com fibrinólise',
        assistantOutput: '• Clopidogrel 600 mg VO de carga',
        languageCode: 'pt',
      );
      expect(r.text, contains('carga numérica a definir'));
      expect(r.text, isNot(contains('Clopidogrel 600 mg VO')));
    });

    test(
      'symptom-only theoretical and maintenance-only content remains unchanged',
      () {
        const raw = '• Clopidogrel 600 mg VO';
        for (final q in const <String>[
          'Dor torácica com ECG pendente',
          'O que é IAM?',
        ]) {
          final r = PlantaoClinicalRegimenOutputGuard.enforce(
            userInput: q,
            assistantOutput: raw,
            languageCode: 'pt',
          );
          expect(r.text, raw, reason: q);
          expect(r.modified, isFalse, reason: q);
        }
        const maintenance = '• Manutenção: clopidogrel 75 mg/dia';
        final m = PlantaoClinicalRegimenOutputGuard.enforce(
          userInput: 'IAM confirmado em paciente já tratado',
          assistantOutput: maintenance,
          languageCode: 'pt',
        );
        expect(m.text, maintenance);
        expect(m.modified, isFalse);

        const wrongLoading75 = '• Clopidogrel 75 mg VO de carga';
        final loading = PlantaoClinicalRegimenOutputGuard.enforce(
          userInput: 'IAM confirmado em paciente ainda sem estratégia definida',
          assistantOutput: wrongLoading75,
          languageCode: 'pt',
        );
        expect(loading.modified, isTrue);
        expect(loading.text, contains('300 ou 600 mg por via oral'));
        expect(loading.text, isNot(contains('Clopidogrel 75 mg VO de carga')));
      },
    );

    test('generic materialization is idempotent', () {
      final first = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'IAM',
        assistantOutput: generic('600'),
        languageCode: 'pt',
      );
      final second = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'IAM',
        assistantOutput: first.text,
        languageCode: 'pt',
      );
      expect(second.modified, isFalse);
      expect(second.text, first.text);
    });
  });
}
