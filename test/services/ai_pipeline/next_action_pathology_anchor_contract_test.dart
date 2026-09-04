import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';

void main() {
  group(
    'H5C1-G1-V12-M11-R3 — âncora clínica da continuação',
    () {
      test(
        'PT rejeita CAUSAS PROVÁVEIS e ancora em diabetes',
        () {
          final action = NextActionEngine.build(
            lastUserMessage: 'Tratamento diabetes',
            lastAiResponse: """
🟥 CAUSAS PROVÁVEIS
Tratamento farmacológico:
• Metformina 500 mg VO 12/12h (se DM2)
""",
            isPlantaoMode: true,
            currentLanguage: 'pt',
            chatHistory: const <String>[],
          );

          expect(action.label, 'Exames e evolução');
          expect(
            action.promptToSend,
            'Quais exames complementares solicitar e como monitorar '
            'a evolução em diabetes?',
          );
          expect(
            action.promptToSend.toLowerCase(),
            isNot(contains('causas prováveis')),
          );
        },
      );

      test(
        'ES rejeita CAUSAS PROBABLES e ancora em diabetes',
        () {
          final action = NextActionEngine.build(
            lastUserMessage: 'Tratamiento diabetes',
            lastAiResponse: """
🟥 CAUSAS PROBABLES
Tratamiento farmacológico:
• Metformina 500 mg VO cada 12 h (si DM2)
""",
            isPlantaoMode: true,
            currentLanguage: 'es',
            chatHistory: const <String>[],
          );

          expect(action.label, 'Estudios y evolución');
          expect(
            action.promptToSend,
            '¿Qué exámenes complementarios solicitar y cómo monitorear '
            'la evolución en diabetes?',
          );
          expect(
            action.promptToSend.toLowerCase(),
            isNot(contains('causas probables')),
          );
        },
      );

      test(
        'remove preposição sem inventar o diagnóstico',
        () {
          final action = NextActionEngine.build(
            lastUserMessage: 'Tratamento da hiperglicemia 340',
            lastAiResponse: """
🟥 CAUSAS POSSÍVEIS
Tratamento farmacológico:
• Insulina conforme avaliação clínica
""",
            isPlantaoMode: true,
            currentLanguage: 'pt',
            chatHistory: const <String>[],
          );

          expect(action.label, 'Exames e evolução');
          expect(
            action.promptToSend,
            contains('hiperglicemia 340'),
          );
          expect(
            action.promptToSend,
            isNot(contains('da hiperglicemia')),
          );
        },
      );

      test(
        'candidato específico de IAM permanece prioritário',
        () {
          final action = NextActionEngine.build(
            lastUserMessage: 'Iam',
            lastAiResponse: """
🟥 IAM — INFARTO AGUDO MIOCÁRDIO
Conduta imediata:
• Realizar ECG em menos de 10 minutos
Tratamento farmacológico:
• AAS 300 mg VO
""",
            isPlantaoMode: true,
            currentLanguage: 'pt',
            chatHistory: const <String>[],
          );

          expect(action.label, 'ECG + Troponina urgente');
        },
      );

      test(
        'PT remove TRATAMENTO do título clínico específico',
        () {
          final action = NextActionEngine.build(
            lastUserMessage: 'Tratamiento diabetes',
            lastAiResponse: """
🟥 DIABETES MELLITUS — TRATAMENTO
Tratamento farmacológico:
• Metformina 500 mg VO 12/12h (se Tipo 2)
""",
            isPlantaoMode: true,
            currentLanguage: 'pt',
            chatHistory: const <String>[],
          );

          expect(action.label, 'Exames e evolução');
          expect(
            action.promptToSend,
            'Quais exames complementares solicitar e como monitorar '
            'a evolução em DIABETES MELLITUS?',
          );
          expect(
            action.promptToSend,
            isNot(contains('— TRATAMENTO')),
          );
        },
      );

      test(
        'ES remove TRATAMIENTO do título clínico específico',
        () {
          final action = NextActionEngine.build(
            lastUserMessage: 'Tratamiento diabetes',
            lastAiResponse: """
🟥 DIABETES MELLITUS — TRATAMIENTO
Tratamiento farmacológico:
• Metformina 500 mg VO cada 12 h (si Tipo 2)
""",
            isPlantaoMode: true,
            currentLanguage: 'es',
            chatHistory: const <String>[],
          );

          expect(action.label, 'Estudios y evolución');
          expect(
            action.promptToSend,
            '¿Qué exámenes complementarios solicitar y cómo monitorear '
            'la evolución en DIABETES MELLITUS?',
          );
          expect(
            action.promptToSend,
            isNot(contains('— TRATAMIENTO')),
          );
        },
      );

      test(
        'pergunta sem prefixo clínico preserva o texto literal',
        () {
          final action = NextActionEngine.build(
            lastUserMessage: 'Hiperglicemia 340',
            lastAiResponse: """
🟥 CAUSAS PROVÁVEIS
Tratamento farmacológico:
• Insulina conforme avaliação clínica
""",
            isPlantaoMode: true,
            currentLanguage: 'pt',
            chatHistory: const <String>[],
          );

          expect(action.label, 'Condutas e dosagens');
          expect(
            action.promptToSend,
            contains('Hiperglicemia 340'),
          );
          expect(
            action.promptToSend.toLowerCase(),
            isNot(contains('causas prováveis')),
          );
        },
      );
    },
  );
}
