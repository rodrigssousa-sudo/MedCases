import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';

void main() {
  group('Plantão adaptive diagnostic flow', () {
    test('sintoma diferencial começa por Perguntas-chave', () {
      final action = NextActionEngine.build(
        lastUserMessage: 'Dor na fossa ilíaca',
        lastAiResponse: '''
🟥 DOR NA FOSSA ILÍACA — DIFERENCIAIS PRIORITÁRIOS
🚨 Avaliação inicial:
• Avaliar estabilidade e exame abdominal dirigido
🔑 Pontos-chave:
• Hipótese principal: indeterminada — faltam dados discriminadores
• Diferenciais prioritários: apendicite, diverticulite, cólica ureteral
🚩 RED FLAGS:
• Instabilidade hemodinâmica ou sinais de irritação peritoneal
''',
        isPlantaoMode: true,
        currentLanguage: 'pt',
      );

      expect(action.label, 'Perguntas-chave');
      expect(action.promptToSend, contains('Não invente respostas do paciente'));
    });

    test('após perguntas respondidas, fluxo oferece exames e imagens', () {
      const differential = '''
🟥 DOR NA FOSSA ILÍACA — DIFERENCIAIS PRIORITÁRIOS
🔑 Pontos-chave:
• Diferenciais prioritários: apendicite, diverticulite, cólica ureteral
''';
      const questions = '''
🟥 DOR NA FOSSA ILÍACA
Perguntas-chave:
• Início e evolução da dor
• Migração da dor
• Febre, vômitos, sintomas urinários
''';

      final action = NextActionEngine.build(
        lastUserMessage: 'Dor há 12 horas, migrou para FID e tenho febre.',
        lastAiResponse: differential,
        isPlantaoMode: true,
        currentLanguage: 'pt',
        chatHistory: const <String>[
          'Dor na fossa ilíaca',
          differential,
          'Quais perguntas-chave?',
          questions,
        ],
      );

      expect(action.label, 'Exames e imagens');
      expect(action.promptToSend, contains('Não presuma resultados'));
    });

    test('após perguntas e exames, fluxo oferece conduta condicionada', () {
      const differential = '''
🟥 DOR NA FOSSA ILÍACA — DIFERENCIAIS PRIORITÁRIOS
🔑 Pontos-chave:
• Diferenciais prioritários: apendicite, diverticulite, cólica ureteral
''';

      final action = NextActionEngine.build(
        lastUserMessage: 'Leucócitos 15.000 e USG inconclusiva.',
        lastAiResponse: differential,
        isPlantaoMode: true,
        currentLanguage: 'pt',
        chatHistory: const <String>[
          'Dor na fossa ilíaca',
          differential,
          'Liste somente as perguntas clínicas-chave para discriminar os diferenciais.',
          'Perguntas-chave: início, migração, febre, sintomas urinários.',
          'Dor migrou para FID e há febre.',
          differential,
          'Indique somente os exames complementares e imagens que melhor discriminam os diferenciais.',
          'Exames complementares: hemograma, urina, ultrassonografia ou TC conforme contexto.',
        ],
      );

      expect(action.label, 'Conduta e tratamento');
      expect(
        action.promptToSend,
        contains(
          'somente se o diagnóstico ou a indicação estiverem suficientemente sustentados',
        ),
      );
    });

    test('resposta que acabou de listar perguntas espera dados do usuário', () {
      final action = NextActionEngine.build(
        lastUserMessage: 'Quais perguntas-chave?',
        lastAiResponse: '''
🟥 DOR TORÁCICA
Perguntas-chave:
• Início e duração
• Relação com esforço
''',
        isPlantaoMode: true,
        currentLanguage: 'pt',
        chatHistory: const <String>[
          'Dor torácica',
          '🟥 DOR TORÁCICA — DIFERENCIAIS PRIORITÁRIOS',
        ],
      );

      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test('prompt ativo remove placeholders e proíbe inventar dados', () {
      final source = File('lib/services/ai_service.dart').readAsStringSync();

      expect(source, contains('DADO NÃO INFORMADO = DESCONHECIDO'));
      expect(source, contains('DATO NO INFORMADO = DESCONOCIDO'));
      expect(source, contains('🚩 RED FLAGS:'));
      expect(source, isNot(contains('🟥 [SINTOMA OU QUADRO]')));
      expect(source, isNot(contains('* [hipotese plausivel')));
      expect(source, isNot(contains('**Farmaco + dose + via** [indicacao')));
      expect(source, isNot(contains('📌 [ação clínica pura')));
      expect(source, isNot(contains('📌 [acao clinica pura')));
    });

    test('renderer aceita RED FLAGS e Avaliação inicial mantendo hardStops interno', () {
      final source = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      expect(source, contains('usesRedFlagsLabel'));
      expect(source, contains("'Red flags/escalamiento'"));
      expect(source, contains("'Red flags/escalonamento'"));
      expect(source, isNot(contains("title: 'RED FLAGS'")));
      expect(source, isNot(contains("title: 'HARD STOP'")));
      expect(source, contains("heading == 'red flags'"));
      expect(source, contains("value == 'hard stop'"));
      expect(source, contains("value == 'avaliacao inicial'"));
      expect(source, contains("value == 'evaluacion inicial'"));
      expect(source, contains('hardStops: hardStops'));
      expect(source, contains("'guardia_hard_stop_section'"));
    });

    test('topic extraído remove o sufixo DIFERENCIAIS PRIORITÁRIOS', () {
      final source = File(
        'lib/services/ai_next_action_engine.dart',
      ).readAsStringSync();

      expect(source, contains(r'diferenciais?\s+priorit[aá]rios'));
      expect(source, contains(r'diferenciales?\s+prioritarios'));
    });
  });
}
