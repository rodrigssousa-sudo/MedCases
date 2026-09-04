import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(
  String source,
  String className,
) {
  final declaration = RegExp(
    'class\\s+$className\\b[^\\{]*\\{',
  ).firstMatch(source);

  expect(
    declaration,
    isNotNull,
    reason: 'Classe ausente: $className',
  );

  final opening = source.indexOf(
    '{',
    declaration!.start,
  );

  var depth = 0;
  String? quote;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;

  for (var index = opening; index < source.length; index++) {
    final character = source[index];

    final pair = index + 1 < source.length
        ? source.substring(index, index + 2)
        : character;

    if (lineComment) {
      if (character == '\n') {
        lineComment = false;
      }
      continue;
    }

    if (blockComment) {
      if (pair == '*/') {
        blockComment = false;
        index++;
      }
      continue;
    }

    if (quote != null) {
      if (escaped) {
        escaped = false;
        continue;
      }

      if (character == '\\') {
        escaped = true;
        continue;
      }

      if (character == quote) {
        quote = null;
      }

      continue;
    }

    if (pair == '//') {
      lineComment = true;
      index++;
      continue;
    }

    if (pair == '/*') {
      blockComment = true;
      index++;
      continue;
    }

    if (character == "'" || character == '"') {
      quote = character;
      continue;
    }

    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;

      if (depth == 0) {
        return source.substring(
          declaration.start,
          index + 1,
        );
      }
    }
  }

  fail(
    'Fechamento ausente: $className',
  );
}

void main() {
  late String mainSource;

  setUpAll(() {
    mainSource = File(
      'lib/main.dart',
    ).readAsStringSync();
  });

  group(
    'MB-I.5.15-A-R1 — shell visual final',
    () {
      test(
        'dock reutiliza as bordas da topbar',
        () {
          final footer = classBlock(
            mainSource,
            '_FloatingFooterState',
          );

          expect(
            footer,
            contains(
              'const Color(0xFF374151)',
            ),
          );

          expect(
            footer,
            contains(
              'const Color(0xFFE2E7EC)',
            ),
          );

          expect(
            footer,
            isNot(
              contains(
                '_medcasesGreen'
                '.withOpacity(0.18)',
              ),
            ),
          );

          expect(
            footer,
            isNot(
              contains(
                'const Color(0xFF0F766E)'
                '.withOpacity(0.18)',
              ),
            ),
          );

          expect(
            footer,
            contains('width: 0.9'),
          );
        },
      );

      test(
        'topbar usa setenta por cento',
        () {
          final topbar = classBlock(
            mainSource,
            '_MobileAppBar',
          );

          expect(
            topbar,
            contains(
              'const Color(0xFF252930)'
              '.withOpacity(0.70)',
            ),
          );

          expect(
            topbar,
            contains(
              'Colors.white'
              '.withOpacity(0.70)',
            ),
          );

          expect(
            topbar,
            isNot(
              contains(
                'withOpacity(0.88)',
              ),
            ),
          );

          expect(
            topbar,
            contains(
              'ImageFilter.blur'
              '(sigmaX: 14, sigmaY: 14)',
            ),
          );

          expect(
            topbar,
            contains('height: 48'),
          );

          expect(
            topbar,
            contains(
              'const Color(0xFF374151)',
            ),
          );

          expect(
            topbar,
            contains(
              'const Color(0xFFE2E7EC)',
            ),
          );
        },
      );

      test(
        'disclaimer usa transparência idêntica',
        () {
          final legalShelf = classBlock(
            mainSource,
            '_LegalGlassShelf',
          );

          expect(
            legalShelf,
            contains(
              'const Color(0xFF252930)'
              '.withOpacity(0.70)',
            ),
          );

          expect(
            legalShelf,
            contains(
              'Colors.white'
              '.withOpacity(0.70)',
            ),
          );

          expect(
            legalShelf,
            isNot(
              contains(
                'withOpacity(0.88)',
              ),
            ),
          );

          expect(
            legalShelf,
            contains(
              'ImageFilter.blur'
              '(sigmaX: 14, sigmaY: 14)',
            ),
          );
        },
      );

      test(
        'texto legal mantém 88 por cento',
        () {
          final legalBar = classBlock(
            mainSource,
            '_LegalBar',
          );

          expect(
            legalBar,
            contains(
              'Colors.white'
              '.withOpacity(0.88)',
            ),
          );

          expect(
            legalBar,
            contains(
              'final disclaimer =',
            ),
          );
        },
      );

      test(
        'estrutura do dock permanece intacta',
        () {
          final footer = classBlock(
            mainSource,
            '_FloatingFooterState',
          );

          expect(
            footer,
            contains(
              '_barHeightFull = 50.0',
            ),
          );

          expect(
            footer,
            contains(
              '_barHeightShrunk = 38.0',
            ),
          );

          expect(
            footer,
            contains(
              'EdgeInsets.symmetric('
              'horizontal: 30, '
              'vertical: 8)',
            ),
          );

          expect(
            footer,
            contains(
              'ImageFilter.blur'
              '(sigmaX: 12, sigmaY: 12)',
            ),
          );

          expect(
            footer,
            contains('_LegalGlassShelf('),
          );
        },
      );
    },
  );
}
