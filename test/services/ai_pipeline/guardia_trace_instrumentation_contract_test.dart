import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const files = <String>[
    'lib/providers/app_provider.dart',
    'lib/screens/ai_screen.dart',
    'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
  ];

  group(
    'H5C1-G1-V12-M12-A-R4 — instrumentação temporária',
    () {
      test(
        'prefixo diagnóstico existe nos três proprietários',
        () {
          for (final path in files) {
            final source = File(path).readAsStringSync();

            expect(
              source,
              contains('[GUARDIA_TRACE]'),
              reason: path,
            );
          }
        },
      );

      test(
        'logs não incluem conteúdo clínico literal',
        () {
          final traceBlocks = <String>[];

          for (final path in files) {
            final source = File(path).readAsStringSync();
            final assertBlocks = RegExp(
              r'assert\(\(\) \{[\s\S]*?'
              r'return true;\s*\}\(\)\);',
              multiLine: true,
            ).allMatches(source);

            traceBlocks.addAll(
              assertBlocks.map((match) => match.group(0) ?? '').where(
                    (block) => block.contains('[GUARDIA_TRACE]'),
                  ),
            );
          }

          expect(traceBlocks, isNotEmpty);

          final traceSource = traceBlocks.join('\\n');

          const forbidden = <String>[
            r'prompt=$',
            r'response=$',
            r'content=$',
            'rawText.substring',
            'finalText.substring',
            'accumulated.substring',
            'cleanedChunk.substring',
            'snapshot.substring',
          ];

          for (final token in forbidden) {
            expect(
              traceSource,
              isNot(contains(token)),
              reason: token,
            );
          }
        },
      );

      test(
        'logs usam somente metadados mensuráveis',
        () {
          final combined =
              files.map((path) => File(path).readAsStringSync()).join('\n');

          expect(combined, contains('accumulatedLen='));
          expect(combined, contains('finalTextLen='));
          expect(combined, contains('notifierLen='));
          expect(combined, contains('effectiveTextLen='));
          expect(combined, contains('first='));
          expect(combined, contains('second='));
          expect(combined, contains('hard='));
        },
      );

      test(
        'instrumentação permanece condicionada a assert',
        () {
          for (final path in files) {
            final source = File(path).readAsStringSync();
            final traceCount = '[GUARDIA_TRACE]'.allMatches(source).length;
            final assertCount = 'assert(() {'.allMatches(source).length;

            expect(traceCount, greaterThan(0), reason: path);
            expect(
              assertCount,
              greaterThanOrEqualTo(traceCount),
              reason: path,
            );
          }
        },
      );
    },
  );
}
