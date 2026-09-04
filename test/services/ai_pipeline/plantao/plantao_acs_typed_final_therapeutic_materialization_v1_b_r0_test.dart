import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_clinical_regimen_output_guard.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

void main() {
  group('ACS final therapeutic materialization PT/ES', () {
    const pt = '''
🟥 INFARTO AGUDO DO MIOCÁRDIO
🚨 Conduta imediata:
• Monitorização contínua e ECG seriado
💊 Tratamento farmacológico:
• AAS 300 mg VO
• Atorvastatina 80 mg VO
• Clopidogrel 600 mg VO
🔑 Pontos-chave:
• Definir estratégia de reperfusão
🚩 RED FLAGS:
• Choque cardiogênico
''';
    const es = '''
🟥 INFARTO AGUDO DE MIOCARDIO
🚨 Conducta inmediata:
• Monitorización continua y ECG seriado
💊 Tratamiento farmacológico:
• AAS 300 mg VO
• Nitroglicerina 0.4 mg SL
• Morfina si dolor refractario
• Clopidogrel 300 mg VO
🔑 Puntos clave:
• Definir estrategia de reperfusión
🚩 RED FLAGS:
• Shock cardiogénico
''';

    test(
      'different PT/ES model pharmacology converges to one semantic core',
      () {
        final a = PlantaoClinicalRegimenOutputGuard.enforce(
          userInput: 'IAM',
          assistantOutput: pt,
          languageCode: 'pt',
        );
        final b = PlantaoClinicalRegimenOutputGuard.enforce(
          userInput: 'IAM',
          assistantOutput: es,
          languageCode: 'es',
        );
        for (final text in <String>[a.text, b.text]) {
          expect(text, contains('AAS 300 mg VO'));
          expect(text, contains('Atorvastatina 80 mg VO'));
          expect(text, contains('Clopidogrel —'));
          expect(text, contains('300'));
          expect(text, contains('600'));
          expect(text, isNot(contains('Nitroglicerina 0.4 mg SL')));
          expect(text, isNot(contains('Morfina si dolor refractario')));
          expect(RegExp(r'\bAAS 300 mg VO\b').allMatches(text).length, 1);
          expect(
            RegExp(r'\bAtorvastatina 80 mg VO\b').allMatches(text).length,
            1,
          );
          expect(RegExp(r'Clopidogrel —').allMatches(text).length, 1);
        }
        expect(a.text, contains('300 ou 600 mg por via oral'));
        expect(b.text, contains('300 o 600 mg por vía oral'));
        expect(a.text, contains('Monitorização contínua e ECG seriado'));
        expect(b.text, contains('Monitorización continua y ECG seriado'));
      },
    );

    test(
      'decision-support remains raw while AAS and atorvastatin are typed',
      () {
        final r = PlantaoClinicalRegimenOutputGuard.enforce(
          userInput: 'IAM',
          assistantOutput: pt,
          languageCode: 'pt',
        );
        final dto = PlantaoLocalClinicalOutputAdapter.fromValidatedText(r.text);
        expect(dto, isNotNull);
        final names = dto!.prescricao
            .map((x) => x.farmaco.toLowerCase())
            .toList();
        expect(names.any((x) => x.contains('aas')), isTrue);
        expect(names.any((x) => x.contains('atorvastatina')), isTrue);
        expect(names.any((x) => x.contains('clopidogrel')), isFalse);
        expect(r.text, contains('Clopidogrel — se for o P2Y12 escolhido'));
      },
    );
  });
}
