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

  final start = declaration!.start;
  final opening = source.indexOf(
    '{',
    declaration.start,
  );

  var depth = 0;

  for (var index = opening; index < source.length; index++) {
    final character = source[index];

    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;

      if (depth == 0) {
        return source.substring(
          start,
          index + 1,
        );
      }
    }
  }

  fail('Fechamento ausente: $className');
}

void main() {
  late String modules;
  late String home;
  late String dashboard;

  setUpAll(() {
    modules = File(
      'lib/home_v2/components/'
      'home_v2_modules_view.dart',
    ).readAsStringSync();

    home = File(
      'lib/screens/home_screen.dart',
    ).readAsStringSync();

    dashboard = File(
      'lib/widgets/'
      'meu_plantao_dashboard.dart',
    ).readAsStringSync();
  });

  group('MB-I.5.14-B-R6 — visual', () {
    test('preserva ícone e título bilíngue', () {
      final surface = classBlock(
        modules,
        'HomeV2GuardiaSurface',
      );

      expect(
        surface,
        contains(
          'assets/icons/home_v2/ic_plantao.svg',
        ),
      );

      expect(
        surface,
        contains(
          'HomeV2IconPalette.plantao(dark)',
        ),
      );

      expect(surface, contains("'MI GUARDIA'"));
      expect(surface, contains("'MEU PLANTÃO'"));

      expect(
        surface,
        isNot(
          contains('Organize sua rotina clínica'),
        ),
      );

      expect(
        surface,
        isNot(
          contains('Organiza tu rutina clínica'),
        ),
      );
    });

    test(
      'remove card interno somente da classe correta',
      () {
        final facade = classBlock(
          home,
          '_HomeMiGuardiaSection',
        );

        expect(
          facade,
          contains(
            'child: MeuPlantaoDashboard(',
          ),
        );

        expect(
          facade,
          isNot(contains('final leftAccent')),
        );

        expect(
          facade,
          isNot(contains('boxShadow:')),
        );

        expect(
          facade,
          isNot(contains('Container(width: 3')),
        );
      },
    );

    test('usa HomeV2Palette', () {
      expect(
        dashboard,
        contains(
          "import '../home_v2/theme/"
          "home_v2_palette.dart';",
        ),
      );

      expect(
        dashboard,
        contains(
          'HomeV2Palette.resolve(dark)',
        ),
      );

      expect(
        dashboard,
        contains(
          'palette.pressedOverlay',
        ),
      );
    });

    test('contador usa PacienteSession', () {
      expect(
        dashboard,
        contains(
          'final List<PacienteSession> sessions;',
        ),
      );

      expect(
        dashboard,
        contains(
          'final PacienteSession session;',
        ),
      );

      expect(
        dashboard,
        contains(
          'final patientCount = visibleSessions.length;',
        ),
      );
    });

    test('usa estado clínico e triagem', () {
      expect(
        dashboard,
        contains(
          'session.historial.last.evaluacion.estado',
        ),
      );

      expect(
        dashboard,
        contains('EstadoClinical.empeorando'),
      );

      expect(
        dashboard,
        contains('EstadoClinical.estable'),
      );

      expect(
        dashboard,
        contains('EstadoClinical.mejorando'),
      );

      expect(
        dashboard,
        contains('_triageColorFromDiag('),
      );
    });

    test('possui quatro chips bilíngues', () {
      expect(dashboard, contains("'CRÍTICA'"));
      expect(dashboard, contains("'ALTA'"));
      expect(dashboard, contains("'MODERADA'"));
      expect(dashboard, contains("'BAJA'"));
      expect(dashboard, contains("'BAIXA'"));
    });

    test('mantém atalhos e cores', () {
      for (final id in const [
        'calc_cardio',
        'calc_nefrologia',
        'calc_hepatologia',
      ]) {
        expect(
          dashboard,
          contains("'$id'"),
        );
      }

      expect(
        dashboard,
        contains('shortcut.icon'),
      );

      expect(
        dashboard,
        contains('color: shortcut.color'),
      );
    });

    test('mantém prévia SOAP', () {
      expect(
        dashboard,
        contains('_SoapPreviewDialog('),
      );

      expect(
        dashboard,
        contains('onLongPress: ()'),
      );

      expect(
        dashboard,
        contains('AppHaptics.medium('),
      );
    });
  });
}
