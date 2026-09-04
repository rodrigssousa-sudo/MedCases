import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:medcases/screens/ai/widgets/message_render_policy.dart';
import 'package:medcases/services/study_continuation_resolver.dart';

void main() {
  group('STUDY-PREMIUM-V1-B-R6', () {
    late String router;
    late String screen;
    late String resolver;
    late String button;

    setUpAll(() {
      router = File('lib/services/ai_smart_router.dart').readAsStringSync();
      screen = File('lib/screens/ai_screen.dart').readAsStringSync();
      resolver = File('lib/services/study_continuation_resolver.dart')
          .readAsStringSync();
      button = File('lib/screens/ai/widgets/study_continuation_button.dart')
          .readAsStringSync();
    });

    test('contrato editorial Study premium está presente', () {
      expect(router,
          contains('Comece DIRETAMENTE com ## [título específico do tema]'));
      expect(router,
          contains('NÃO repita, cite nem parafraseie a pergunta do usuário'));
      expect(
          router,
          contains(
              'ZERO emojis, pictogramas ou ícones decorativos no texto visível'));
      expect(
          router,
          contains(
              'Negrito inline SOMENTE para informação clinicamente importante'));
      expect(router, contains('A continuidade pertence SOMENTE ao botão'));
    });

    test('parser oculta tags sem alterar conteúdo clínico legado', () {
      final result = MessageRenderPolicy.parseStudyAction(
        text: """## Pancreatite aguda
📌 **Lipase** maior que 3 vezes o limite.

[NEXT_ACTION_LABEL: Critérios de gravidade]
[NEXT_ACTION_PROMPT: Quais critérios definem gravidade na pancreatite aguda?]""",
        isStudyMode: true,
      );
      expect(result.label, 'Critérios de gravidade');
      expect(result.prompt,
          'Quais critérios definem gravidade na pancreatite aguda?');
      expect(result.displayText, contains('📌'));
      expect(result.displayText, isNot(contains('NEXT_ACTION_')));
      expect(result.displayText, contains('## Pancreatite aguda'));
      expect(result.displayText, contains('**Lipase**'));
    });

    test('resolver separa label visível de prompt produtivo', () {
      final result = StudyContinuationResolver.resolve(
        rawText: """## Pancreatite aguda
Conteúdo didático.

[NEXT_ACTION_LABEL: Critérios de gravidade]
[NEXT_ACTION_PROMPT: Quais critérios definem gravidade na pancreatite aguda?]""",
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explique pancreatite aguda',
        languageCode: 'pt',
      );
      expect(result.source, StudyContinuationSource.remoteTag);
      expect(result.displayText, isNot(contains('📌')));
      expect(result.label, 'Critérios de gravidade');
      expect(result.question,
          'Quais critérios definem gravidade na pancreatite aguda?');
      expect(result.label, isNot(result.question));
      expect(result.hasContinuation, isTrue);
    });

    test('continuação contextual do mesmo tema não é falso duplicado', () {
      final result = StudyContinuationResolver.resolve(
        rawText: """## Pancreatite aguda
Conteúdo didático.

[NEXT_ACTION_LABEL: Critérios de gravidade]
[NEXT_ACTION_PROMPT: Quais critérios definem gravidade na pancreatite aguda?]""",
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explique pancreatite aguda',
        languageCode: 'pt',
      );
      expect(result.source, StudyContinuationSource.remoteTag);
      expect(result.label, 'Critérios de gravidade');
      expect(
        result.question,
        'Quais critérios definem gravidade na pancreatite aguda?',
      );
    });

    test('wrapper espanhol equivalente cai no fallback genérico', () {
      final result = StudyContinuationResolver.resolve(
        rawText: """## Fisiología
Contenido.

[NEXT_ACTION_LABEL: Fisiología detallada]
[NEXT_ACTION_PROMPT: Explica la fisiología detallada]""",
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: '¿Explica la fisiología detallada?',
        languageCode: 'es',
      );
      expect(result.source, StudyContinuationSource.genericFallback);
      expect(
        result.question.toLowerCase(),
        isNot(contains('explica la fisiología detallada')),
      );
      expect(result.question, startsWith('¿'));
    });

    test('remote duplicado do usuário pula engine local e usa fallback', () {
      final result = StudyContinuationResolver.resolve(
        rawText: """## Fisiología
Contenido.

[NEXT_ACTION_LABEL: Fisiología detallada]
[NEXT_ACTION_PROMPT: Explica la fisiología detallada]""",
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: '¿Explica la fisiología detallada?',
        languageCode: 'es',
      );
      expect(result.source, StudyContinuationSource.genericFallback);
      expect(result.hasContinuation, isTrue);
      expect(
        result.question.toLowerCase(),
        isNot(contains('explica la fisiología detallada')),
      );
    });

    test('resolver declara bypass antes do NextActionEngine', () {
      final duplicatePos =
          resolver.indexOf('if (remoteDuplicatesUserQuestion)');
      final enginePos =
          resolver.indexOf('final localAction = NextActionEngine.build(');
      expect(duplicatePos, greaterThanOrEqualTo(0));
      expect(enginePos, greaterThan(duplicatePos));
    });

    test('label remoto fica sem emoji e com até cinco palavras', () {
      final result = StudyContinuationResolver.resolve(
        rawText: """## Sepse
Conteúdo.

[NEXT_ACTION_LABEL: 📌 Critérios prognósticos mais importantes agora na prática]
[NEXT_ACTION_PROMPT: Quais critérios prognósticos são mais importantes na sepse?]""",
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Sepse',
        languageCode: 'pt',
      );
      expect(result.label, isNot(contains('📌')));
      expect(result.label.split(RegExp(r'\s+')).length, lessThanOrEqualTo(5));
    });

    test('AiScreen oculta user turn visualmente e envia prompt oculto', () {
      expect(screen, contains("ValueKey('msg_\${msg.id}_study_user_hidden')"));
      expect(screen,
          contains('final String studyButtonLabel = studyContinuation.label;'));
      expect(screen, contains('label: studyButtonLabel.trim()'));
      expect(screen, contains('final prompt = nextActionPrompt.trim();'));
      expect(screen, contains('fromButton: true'));
      expect(screen, contains('userDisplayText: studyButtonLabel.trim()'));
      expect(screen, isNot(contains('question: nextActionPrompt.trim()')));
    });

    test('botão não possui campo do prompt produtivo', () {
      expect(button, contains('final String label;'));
      expect(button, isNot(contains('final String question;')));
    });

    test('resolver mantém labels remoto e local', () {
      expect(resolver, contains('metadata.label'));
      expect(resolver, contains('localAction.label'));
      expect(resolver, contains('label.isNotEmpty && question.isNotEmpty'));
    });
  });
}
