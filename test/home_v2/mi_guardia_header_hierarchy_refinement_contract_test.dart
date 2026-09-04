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
    'MB-I.5.14-C-D — hierarquia do header',
    () {
      test(
        'ícone cresce exatamente dez por cento',
        () {
          final surface = classBlock(
            modules,
            'HomeV2GuardiaSurface',
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
            isNot(contains('width: 24')),
          );

          expect(
            surface,
            isNot(contains('height: 24')),
          );
        },
      );

      test(
        'preserva SVG, cor e título bilíngue',
        () {
          final surface = classBlock(
            modules,
            'HomeV2GuardiaSurface',
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
            contains("'MI GUARDIA'"),
          );

          expect(
            surface,
            contains("'MEU PLANTÃO'"),
          );

          expect(
            surface,
            contains(
              'const SizedBox(width: 76)',
            ),
          );
        },
      );

      test(
        'remove os rótulos redundantes',
        () {
          final body = classBlock(
            dashboard,
            '_MiGuardiaCompactBody',
          );

          expect(
            body,
            isNot(
              contains(
                "'PACIENTES DE GUARDIA'",
              ),
            ),
          );

          expect(
            body,
            isNot(
              contains(
                "'PACIENTES DO PLANTÃO'",
              ),
            ),
          );
        },
      );

      test(
        'contador e chevron ficam ancorados à direita',
        () {
          final body = classBlock(
            dashboard,
            '_MiGuardiaCompactBody',
          );

          expect(
            body,
            contains(
              'MB-I.5.14-C-D',
            ),
          );

          expect(
            body,
            contains(
              'width: double.infinity',
            ),
          );

          expect(
            body,
            contains('Stack('),
          );

          expect(
            body,
            contains(
              'clipBehavior: Clip.none',
            ),
          );

          expect(
            body,
            contains('Positioned('),
          );

          expect(
            body,
            contains('top: -43'),
          );

          expect(
            body,
            contains('right: 2'),
          );

          expect(
            body,
            contains(r"'$patientCount'"),
          );

          expect(
            body,
            contains(
              'Icons.'
              'keyboard_arrow_down_rounded',
            ),
          );

          expect(
            body,
            contains('onTap: onToggle'),
          );

          expect(
            body,
            contains(
              'turns: chevronAngle',
            ),
          );

          expect(
            body,
            isNot(
              contains('OverflowBox('),
            ),
          );

          expect(
            body,
            isNot(
              contains(
                'Transform.translate(',
              ),
            ),
          );
        },
      );

      test(
        'controles aparecem antes do CTA',
        () {
          final body = classBlock(
            dashboard,
            '_MiGuardiaCompactBody',
          );

          final controlsIndex = body.indexOf(
            'MB-I.5.14-C-D',
          );

          final buttonIndex = body.indexOf(
            '_MiGuardiaAddPatientButton(',
          );

          expect(
            controlsIndex,
            greaterThanOrEqualTo(0),
          );

          expect(
            buttonIndex,
            greaterThan(controlsIndex),
          );
        },
      );

      test(
        'CTA continua compacto e centralizado',
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
            contains("'+ PACIENTE'"),
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
        },
      );

      test(
        'estado vazio permanece bilíngue',
        () {
          final patientList = classBlock(
            dashboard,
            '_MiGuardiaPatientList',
          );

          expect(
            patientList,
            contains(
              'Todavía no hay pacientes '
              'en la guardia.',
            ),
          );

          expect(
            patientList,
            contains(
              'Ainda não há pacientes '
              'no plantão.',
            ),
          );
        },
      );

      test(
        'não cria infraestrutura paralela',
        () {
          final body = classBlock(
            dashboard,
            '_MiGuardiaCompactBody',
          );

          for (final forbidden in const [
            'FirebaseFirestore.instance',
            'StreamSubscription',
            'SharedPreferences',
            'setState(',
            'ChangeNotifier',
            'collection(',
          ]) {
            expect(
              body,
              isNot(contains(forbidden)),
            );
          }
        },
      );
    },
  );
}
