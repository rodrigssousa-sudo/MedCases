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
        ? source.substring(
            index,
            index + 2,
          )
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
  late String modules;
  late String dashboard;

  setUpAll(() {
    modules = File(
      'lib/home_v2/components/'
      'home_v2_modules_view.dart',
    ).readAsStringSync();

    dashboard = File(
      'lib/widgets/'
      'meu_plantao_dashboard.dart',
    ).readAsStringSync();
  });

  group(
    'MB-I.5.14-C-B — refinamento visual',
    () {
      test(
        'remove divisor abaixo do título',
        () {
          final surface = classBlock(
            modules,
            'HomeV2GuardiaSurface',
          );

          expect(
            surface,
            isNot(
              contains(
                'color: palette.border',
              ),
            ),
          );

          expect(
            surface,
            isNot(
              contains('height: 1'),
            ),
          );

          expect(
            surface,
            contains(
              "'MI GUARDIA'",
            ),
          );

          expect(
            surface,
            contains(
              "'MEU PLANTÃO'",
            ),
          );
        },
      );

      test(
        'exibe o SVG oficial sem card',
        () {
          final surface = classBlock(
            modules,
            'HomeV2GuardiaSurface',
          );

          expect(
            surface,
            contains(
              'SvgPicture.asset(',
            ),
          );

          expect(
            surface,
            contains(
              'assets/icons/home_v2/'
              'ic_plantao.svg',
            ),
          );

          expect(
            surface,
            contains(
              'HomeV2IconPalette.'
              'plantao(dark)',
            ),
          );

          expect(
            surface,
            contains('width: 26.4'),
          );

          expect(
            surface,
            contains('height: 26.4'),
          );

          expect(
            surface,
            isNot(
              contains('_ModuleIcon('),
            ),
          );

          expect(
            surface,
            isNot(
              contains(
                'palette.surfaceStrong',
              ),
            ),
          );
        },
      );

      test(
        'mantém _ModuleIcon compartilhado intacto',
        () {
          final moduleIcon = classBlock(
            modules,
            '_ModuleIcon',
          );

          expect(
            moduleIcon,
            contains(
              'color: palette.surfaceStrong',
            ),
          );

          expect(
            moduleIcon,
            contains(
              'border: Border.all(',
            ),
          );
        },
      );

      test(
        'CTA possui somente um sinal de adição',
        () {
          final button = classBlock(
            dashboard,
            '_MiGuardiaAddPatientButton',
          );

          expect(
            button,
            contains("'+ PACIENTE'"),
          );

          expect(
            RegExp(
              r"'\+ PACIENTE'",
            ).allMatches(button).length,
            1,
          );

          expect(
            button,
            isNot(
              contains(
                'Icons.add_rounded',
              ),
            ),
          );

          expect(
            button,
            isNot(
              contains('Icon('),
            ),
          );
        },
      );

      test(
        'CTA é compacto e centralizado',
        () {
          final button = classBlock(
            dashboard,
            '_MiGuardiaAddPatientButton',
          );

          expect(
            button,
            contains('return Align('),
          );

          expect(
            button,
            contains(
              'alignment: Alignment.center',
            ),
          );

          expect(
            button,
            contains(
              'const StadiumBorder()',
            ),
          );

          expect(
            button,
            contains(
              'horizontal: 16',
            ),
          );

          expect(
            button,
            contains(
              'vertical: 7',
            ),
          );

          expect(
            button,
            contains('fontSize: 10'),
          );

          expect(
            button,
            isNot(
              contains('height: 38'),
            ),
          );

          expect(
            button,
            isNot(
              contains(
                'width: double.infinity',
              ),
            ),
          );
        },
      );

      test(
        'CTA preserva callback e haptic',
        () {
          final button = classBlock(
            dashboard,
            '_MiGuardiaAddPatientButton',
          );

          expect(
            button,
            contains(
              'AppHaptics.light(context)',
            ),
          );

          expect(
            button,
            contains('onTap();'),
          );

          final body = classBlock(
            dashboard,
            '_MiGuardiaCompactBody',
          );

          expect(
            body,
            contains(
              '_MiGuardiaAddPatientButton(',
            ),
          );

          expect(
            body,
            contains(
              'onTap: onAddPatient',
            ),
          );
        },
      );
    },
  );
}
