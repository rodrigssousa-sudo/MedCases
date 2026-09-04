import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../lib/screens/ai/widgets/clinical_markdown_presentation.dart';

void main() {
  group('R18.6AC-R1B-H4B-R3 — tipografia clínica', () {
    test('formata títulos PT e ES isolados', () {
      expect(
        ClinicalMarkdownPresentation.format('Definição:'),
        '**Definição**',
      );

      expect(
        ClinicalMarkdownPresentation.format('Fisiopatología'),
        '**Fisiopatología**',
      );

      expect(
        ClinicalMarkdownPresentation.format(
          'Diagnóstico diferencial:',
        ),
        '**Diagnóstico diferencial**',
      );
    });

    test('formata somente o rótulo inline', () {
      expect(
        ClinicalMarkdownPresentation.format(
          'Tratamento: hidratação e controle da causa.',
        ),
        '**Tratamento:** hidratação e controle da causa.',
      );

      expect(
        ClinicalMarkdownPresentation.format(
          'Tratamiento: hidratación y control etiológico.',
        ),
        '**Tratamiento:** hidratación y control etiológico.',
      );
    });

    test('preserva numeração', () {
      expect(
        ClinicalMarkdownPresentation.format('1. Definição:'),
        '1. **Definição**',
      );

      expect(
        ClinicalMarkdownPresentation.format(
          'II) Fisiopatología: mecanismo principal.',
        ),
        'II) **Fisiopatología:** mecanismo principal.',
      );
    });

    test('não duplica negrito existente', () {
      expect(
        ClinicalMarkdownPresentation.format(
          '**Diagnóstico:** critérios clínicos.',
        ),
        '**Diagnóstico:** critérios clínicos.',
      );
    });

    test('recua somente a primeira linha da unidade textual', () {
      final result = ClinicalMarkdownPresentation.format(
        'Primeira linha do parágrafo.\n'
        'Continuação da mesma unidade textual.',
      );

      expect(
        result,
        '${ClinicalMarkdownPresentation.firstLineIndent}'
        'Primeira linha do parágrafo.\n'
        'Continuação da mesma unidade textual.',
      );
    });

    test('recua cada novo parágrafo', () {
      final result = ClinicalMarkdownPresentation.format(
        'Primeiro parágrafo.\n\n'
        'Segundo parágrafo.',
      );

      expect(
        result,
        '${ClinicalMarkdownPresentation.firstLineIndent}'
        'Primeiro parágrafo.\n\n'
        '${ClinicalMarkdownPresentation.firstLineIndent}'
        'Segundo parágrafo.',
      );
    });

    test('frase comum não vira título', () {
      final result = ClinicalMarkdownPresentation.format(
        'O diagnóstico diferencial inclui causas infecciosas.',
      );

      expect(result, isNot(contains('**')));

      expect(
        result,
        startsWith(
          ClinicalMarkdownPresentation.firstLineIndent,
        ),
      );
    });

    test('listas, cards e referências não recebem recuo', () {
      final result = ClinicalMarkdownPresentation.format(
        '- Item clínico\n\n'
        '1. Primeiro item\n\n'
        '📌 Monitorar creatinina.\n\n'
        '📚 Referências',
      );

      expect(
        result,
        '- Item clínico\n\n'
        '1. Primeiro item\n\n'
        '📌 Monitorar creatinina.\n\n'
        '📚 Referências',
      );
    });

    test('tabela, blockquote e código não recebem recuo', () {
      final result = ClinicalMarkdownPresentation.format(
        '| Exame | Resultado |\n\n'
        '> Atenção clínica\n\n'
        '```dart\n'
        'final dose = 5;\n'
        '```',
      );

      expect(
        result,
        '| Exame | Resultado |\n\n'
        '> Atenção clínica\n\n'
        '```dart\n'
        'final dose = 5;\n'
        '```',
      );
    });

    test('recuo EM SPACE é estritamente idempotente', () {
      const input = '''
Definição: condição clínica.

Texto explicativo.
''';

      final once = ClinicalMarkdownPresentation.format(input);
      final twice = ClinicalMarkdownPresentation.format(once);
      final threeTimes = ClinicalMarkdownPresentation.format(twice);

      expect(twice, once);
      expect(threeTimes, once);

      expect(
        RegExp(
          ClinicalMarkdownPresentation.firstLineIndent,
        ).allMatches(once).length,
        1,
      );
    });

    test('linha já recuada não recebe segundo recuo', () {
      final input = '${ClinicalMarkdownPresentation.firstLineIndent}'
          'Parágrafo já recuado.';

      expect(
        ClinicalMarkdownPresentation.format(input),
        input,
      );
    });

    test('entidade emsp existente não recebe novo recuo', () {
      const input = '&emsp;Parágrafo já recuado.';

      expect(
        ClinicalMarkdownPresentation.format(input),
        input,
      );
    });

    test('AiBlockBubble aplica somente na apresentação', () {
      final source = File(
        'lib/screens/ai/widgets/ai_block_bubble.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          'ClinicalMarkdownPresentation.format(normalizedText)',
        ),
      );

      expect(
        source,
        contains('final normalizedText = block'),
      );

      expect(
        source,
        isNot(contains('FirebaseFirestore')),
      );

      expect(
        source,
        isNot(contains('persistAiExchangeOnce')),
      );
    });
  });
}
