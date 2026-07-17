import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/screens/ai/widgets/message_render_policy.dart';

void main() {
  group('MessageRenderPolicy.isSafeCard', () {
    test('reconhece marcador canônico em português', () {
      final text =
          '${AppProvider.kSafeCardMarkerPt}\nNão foi possível finalizar.';

      expect(MessageRenderPolicy.isSafeCard(text), isTrue);
    });

    test('reconhece marcador canônico em espanhol', () {
      final text =
          '${AppProvider.kSafeCardMarkerEs}\nNo fue posible finalizar.';

      expect(MessageRenderPolicy.isSafeCard(text), isTrue);
    });

    test('mantém compatibilidade com safe-card legado', () {
      expect(
        MessageRenderPolicy.isSafeCard(
          'Estamos ajustando la respuesta para mantener la seguridad.',
        ),
        isTrue,
      );
    });

    test('não classifica resposta clínica normal como safe-card', () {
      expect(
        MessageRenderPolicy.isSafeCard(
          '🟥 Síndrome coronario agudo con elevación del ST.',
        ),
        isFalse,
      );
    });
  });

  group('MessageRenderPolicy.parseStudyAction', () {
    test('extrai label e prompt e remove as tags do texto visível', () {
      const raw = '''
## Fisiopatología

Contenido clínico principal.

[NEXT_ACTION_LABEL: Profundizar mecanismos celulares]
[NEXT_ACTION_PROMPT: Explica los mecanismos celulares avanzados.]
''';

      final result = MessageRenderPolicy.parseStudyAction(
        text: raw,
        isStudyMode: true,
      );

      expect(result.label, 'Profundizar mecanismos celulares');
      expect(
        result.prompt,
        'Explica los mecanismos celulares avanzados.',
      );
      expect(result.hasAction, isTrue);
      expect(result.displayText, contains('Contenido clínico principal.'));
      expect(result.displayText, isNot(contains('NEXT_ACTION_LABEL')));
      expect(result.displayText, isNot(contains('NEXT_ACTION_PROMPT')));
    });

    test('preserva texto sem tags no Modo Estudo', () {
      const raw = 'Resposta teórica sem próxima ação.';

      final result = MessageRenderPolicy.parseStudyAction(
        text: raw,
        isStudyMode: true,
      );

      expect(result.label, isEmpty);
      expect(result.prompt, isEmpty);
      expect(result.displayText, raw);
      expect(result.hasAction, isFalse);
    });

    test('não processa tags no Modo Plantão', () {
      const raw = '''
🟥 CONDUTA IMEDIATA
Monitorização contínua.
[NEXT_ACTION_LABEL: Não deve aparecer]
[NEXT_ACTION_PROMPT: Não deve ser enviado]
''';

      final result = MessageRenderPolicy.parseStudyAction(
        text: raw,
        isStudyMode: false,
      );

      expect(result.label, isEmpty);
      expect(result.prompt, isEmpty);
      expect(result.displayText, raw);
      expect(result.hasAction, isFalse);
    });

    test('tolera tag parcialmente encerrada no fim da resposta', () {
      const raw = '''
Conteúdo clínico.
[NEXT_ACTION_LABEL: Avançar investigação
''';

      final result = MessageRenderPolicy.parseStudyAction(
        text: raw,
        isStudyMode: true,
      );

      expect(result.label, 'Avançar investigação');
      expect(result.prompt, isEmpty);
      expect(result.displayText, 'Conteúdo clínico.');
    });
  });
}
