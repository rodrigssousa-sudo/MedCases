import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'AiScreen JSON extractor boundary',
    () {
      late String aiScreenSource;
      late String parserSource;

      setUpAll(() {
        aiScreenSource = File(
          'lib/screens/ai_screen.dart',
        ).readAsStringSync();

        parserSource = File(
          'lib/services/ai_pipeline/'
          'ai_response_structure_parser.dart',
        ).readAsStringSync();
      });

      test(
        'permanece privado e limitado à AiScreen',
        () {
          const symbol = '_stripCodeFencesAndExtractJson';

          expect(
            symbol.allMatches(aiScreenSource).length,
            3,
          );

          expect(
            aiScreenSource,
            contains(
              'String '
              '_stripCodeFencesAndExtractJson'
              '(String text)',
            ),
          );
        },
      );

      test(
        'mantém as três estratégias já observadas',
        () {
          expect(
            aiScreenSource,
            contains('Estratégia A'),
          );

          expect(
            aiScreenSource,
            contains('Estratégia B'),
          );

          expect(
            aiScreenSource,
            contains('Estratégia C'),
          );

          expect(
            aiScreenSource,
            contains('jsonDecode'),
          );

          expect(
            aiScreenSource,
            contains('fieldToAnchor'),
          );

          expect(
            aiScreenSource,
            contains('anchorOrder'),
          );
        },
      );

      test(
        'não é confundido com o parser estrutural canônico',
        () {
          expect(
            parserSource,
            isNot(
              contains(
                '_stripCodeFencesAndExtractJson',
              ),
            ),
          );

          expect(
            parserSource,
            isNot(contains('jsonDecode')),
          );

          expect(
            parserSource,
            isNot(contains('fieldToAnchor')),
          );

          expect(
            parserSource,
            contains(
              'PlantaoParser.parse(text)',
            ),
          );
        },
      );

      test(
        'não possui dependências ou execução visual',
        () {
          final importLines = parserSource
              .split('\n')
              .where(
                (line) => line.trimLeft().startsWith(
                      'import ',
                    ),
              )
              .toList(growable: false);

          expect(
            importLines.any(
              (line) => line.contains('package:flutter/'),
            ),
            isFalse,
          );

          expect(
            parserSource,
            isNot(contains('extends Widget')),
          );

          expect(
            parserSource,
            isNot(contains('StatelessWidget')),
          );

          expect(
            parserSource,
            isNot(contains('StatefulWidget')),
          );

          expect(
            parserSource,
            isNot(contains('AiBubble')),
          );

          expect(
            parserSource,
            isNot(contains('AiBlockBubble')),
          );

          expect(
            parserSource,
            isNot(contains('Markdown(')),
          );
        },
      );
    },
  );
}
