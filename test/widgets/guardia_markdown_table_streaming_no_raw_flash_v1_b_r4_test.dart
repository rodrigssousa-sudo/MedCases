import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  Widget subject({
    required ValueNotifier<String> notifier,
    required bool isStreaming,
    required String rawText,
    Key? key,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GuardiaClinicalResponseView(
            key: key,
            rawText: rawText,
            output: null,
            dark: true,
            languageCode: 'es',
            onCopy: () {},
            isStreaming: isStreaming,
            streamingTextNotifier: notifier,
            scrollGeneration: 99,
          ),
        ),
      ),
    );
  }

  group('Plantao streaming Markdown table no-raw-flash V1-B-R4', () {
    testWidgets('header and separator stay hidden until first complete row', (
      tester,
    ) async {
      final notifier = ValueNotifier<String>('|');
      const key = ValueKey('guardia_streaming_table_subject');

      await tester.pumpWidget(
        subject(notifier: notifier, isStreaming: true, rawText: '', key: key),
      );
      expect(tester.takeException(), isNull);

      notifier.value = '| Categoría | Criterios | Conducta recomendada |';
      await tester.pump();

      expect(
        find.textContaining('| Categoría |', findRichText: true),
        findsNothing,
      );

      notifier.value =
          '| Categoría | Criterios | Conducta recomendada |\n'
          '| --- | --- | --- |';
      await tester.pump();

      expect(find.textContaining('| --- |', findRichText: true), findsNothing);
      expect(
        find.byKey(const ValueKey('guardia_markdown_table_0')),
        findsNothing,
      );

      notifier.value =
          '| Categoría | Criterios | Conducta recomendada |\n'
          '| --- | --- | --- |\n'
          '| A | TEP confirmado de bajo riesgo | Anticoagulación y seguimiento |';
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('guardia_markdown_table_0')),
        findsOneWidget,
      );

      notifier.dispose();
    });

    testWidgets(
      'partial next row never flashes and complete prefix stays visible',
      (tester) async {
        final notifier = ValueNotifier<String>(
          '| Categoría | Criterios | Conducta |\n'
          '| --- | --- | --- |\n'
          '| A | Bajo riesgo | Anticoagulación |',
        );

        await tester.pumpWidget(
          subject(notifier: notifier, isStreaming: true, rawText: ''),
        );

        expect(
          find.byKey(const ValueKey('guardia_markdown_table_0')),
          findsOneWidget,
        );

        notifier.value =
            '| Categoría | Criterios | Conducta |\n'
            '| --- | --- | --- |\n'
            '| A | Bajo riesgo | Anticoagulación |\n'
            '| B | Riesgo intermedio';
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('guardia_markdown_table_0')),
          findsOneWidget,
        );
        expect(
          find.textContaining('| B | Riesgo intermedio', findRichText: true),
          findsNothing,
        );

        notifier.value =
            '| Categoría | Criterios | Conducta |\n'
            '| --- | --- | --- |\n'
            '| A | Bajo riesgo | Anticoagulación |\n'
            '| B | Riesgo intermedio | Monitorización |';
        await tester.pump();

        expect(
          find.textContaining('Riesgo intermedio', findRichText: true),
          findsOneWidget,
        );

        notifier.dispose();
      },
    );

    test('sanitizer preserves narrative before pending table', () {
      const input =
          'Resumen clínico breve.\n\n'
          '| Categoría | Criterios | Conducta |';

      final sanitized = GuardiaMarkdownTableProjection.sanitizeStreamingText(
        input,
      );

      expect(
        sanitized,
        equals('Resumen clínico breve.'),
        reason:
            'Only the incomplete trailing Markdown table candidate may be hidden.',
      );
    });

    test(
      'sanitizer preserves multiline clinical prefix before pending table',
      () {
        const input =
            'Evaluación inicial:\n'
            '- Paciente hemodinámicamente estable.\n\n'
            '| Categoría | Criterios | Conducta |';

        final sanitized = GuardiaMarkdownTableProjection.sanitizeStreamingText(
          input,
        );

        expect(
          sanitized,
          equals(
            'Evaluación inicial:\n'
            '- Paciente hemodinámicamente estable.',
          ),
          reason:
              'The sanitizer may hide only the incomplete trailing table fragment.',
        );
      },
    );

    test(
      'sanitizer appends first complete table row without altering prefix',
      () {
        const input =
            'Evaluación inicial:\n'
            '- Paciente hemodinámicamente estable.\n\n'
            '| Categoría | Criterios | Conducta |\n'
            '| --- | --- | --- |\n'
            '| A | Bajo riesgo | Anticoagulación |';

        final sanitized = GuardiaMarkdownTableProjection.sanitizeStreamingText(
          input,
        );

        expect(
          sanitized,
          contains(
            'Evaluación inicial:\n'
            '- Paciente hemodinámicamente estable.',
          ),
        );
        expect(sanitized, contains('| --- | --- | --- |'));
        expect(sanitized, contains('| A | Bajo riesgo | Anticoagulación |'));
      },
    );

    testWidgets('ordinary non-table streaming remains visible', (tester) async {
      final notifier = ValueNotifier<String>(
        'Evaluar estabilidad hemodinámica',
      );

      await tester.pumpWidget(
        subject(notifier: notifier, isStreaming: true, rawText: ''),
      );

      expect(
        find.textContaining(
          'Evaluar estabilidad hemodinámica',
          findRichText: true,
        ),
        findsOneWidget,
      );

      notifier.dispose();
    });

    testWidgets('final handoff preserves real table', (tester) async {
      final notifier = ValueNotifier<String>(
        '| Categoría | Criterios | Conducta |\n'
        '| --- | --- | --- |\n'
        '| A | Bajo riesgo | Anticoagulación |',
      );
      const key = ValueKey('guardia_streaming_table_final_handoff');

      await tester.pumpWidget(
        subject(notifier: notifier, isStreaming: true, rawText: '', key: key),
      );

      expect(
        find.byKey(const ValueKey('guardia_markdown_table_0')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        subject(
          notifier: notifier,
          isStreaming: false,
          rawText: notifier.value,
          key: key,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('guardia_markdown_table_0')),
        findsOneWidget,
      );
      expect(find.textContaining('| --- |', findRichText: true), findsNothing);

      notifier.dispose();
    });
  });
}
