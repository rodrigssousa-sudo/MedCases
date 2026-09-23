import 'home_composition_runtime_harness.dart';
import 'package:flutter/material.dart';
import 'package:medcases/home_v2/components/common/home_v2_press_surface.dart';
import 'home_utility_guardia_runtime_harness.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final match = RegExp(
    'class\\s+$className\\b[^\\{]*\\{',
  ).firstMatch(source);

  expect(
    match,
    isNotNull,
    reason: 'Classe ausente: $className',
  );

  final start = match!.start;
  final braceStart = source.indexOf('{', start);

  var depth = 0;

  for (var index = braceStart; index < source.length; index++) {
    final char = source[index];

    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;

      if (depth == 0) {
        return source.substring(start, index + 1);
      }
    }
  }

  fail('Fechamento ausente: $className');
}

void main() {
  late String iconPalette;
  late String modules;
  late String surface;
  late String faithful;

  setUpAll(() {
    iconPalette = File(
      'lib/home_v2/theme/home_v2_icon_palette.dart',
    ).readAsStringSync();

    modules = File(
      'lib/home_v2/components/home_v2_modules_view.dart',
    ).readAsStringSync();

    surface = File(
      'lib/home_v2/components/common/'
      'home_v2_press_surface.dart',
    ).readAsStringSync();

    faithful = File(
      'test/home_v2/'
      'home_v2_faithful_visual_composition_contract_test.dart',
    ).readAsStringSync();
  });

  group('Home V2 — paleta semântica dos ícones', () {
    test('protege as 24 cores aprovadas', () {
      const required = <String>[
        '0xFF087F7B',
        '0xFF2DD4BF',
        '0xFF3478C7',
        '0xFF60A5FA',
        '0xFFC58A1A',
        '0xFFFBBF24',
        '0xFF465568',
        '0xFFB2C0D0',
        '0xFF0F766E',
        '0xFF2DD4BF',
        '0xFF16845B',
        '0xFF34D399',
        '0xFF7659B8',
        '0xFFA78BFA',
        '0xFFC64A4A',
        '0xFFFB7185',
        '0xFF087A55',
        '0xFF34D399',
        '0xFFC64A52',
        '0xFFFB7185',
        '0xFF267EAE',
        '0xFF38BDF8',
        '0xFFC97828',
        '0xFFFB923C',
      ];

      for (final token in required) {
        expect(
          iconPalette,
          contains(token),
          reason: 'Cor semântica ausente: $token',
        );
      }
    });

    test('possui resolvedores independentes para os 12 módulos', () {
      const methods = <String>[
        'farmacos(bool dark)',
        'paciente(bool dark)',
        'pediatria(bool dark)',
        'ferramentas(bool dark)',
        'historia(bool dark)',
        'avaliacao(bool dark)',
        'notas(bool dark)',
        'timer(bool dark)',
        'plantao(bool dark)',
        'cardio(bool dark)',
        'nefro(bool dark)',
        'hepato(bool dark)',
      ];

      for (final method in methods) {
        expect(iconPalette, contains(method));
      }
    });
  });

  group('Home V2 — aplicação exclusiva aos desenhos', () {
    test('conecta os SVGs efetivamente exibidos na Home atual', () {
      const assets = <String>[
        'ic_guia_clinica.svg',
        'ic_simulacao.svg',
        'ic_farmacos.svg',
        'ic_vacina.svg',
        'ic_paciente.svg',
        'ic_pediatria.svg',
        'ic_ferramentas.svg',
        'ic_historia.svg',
        'ic_laboratorio.svg',
        'ic_avaliacao.svg',
        'resumo.svg',
        'ic_timer.svg',
        'ic_mi_guardia.svg',
      ];
      for (final asset in assets) {
        expect(modules, contains('assets/icons/home_v2/$asset'),
            reason: 'SVG produtivo ausente: $asset');
      }
      expect(modules, isNot(contains('assets/icons/home_v2/ic_notas.svg')));
    });
    testWidgets('preserva SVG nativo e callbacks nos owners produtivos',
        (tester) async {
      await verifyUtilityRuntime(tester);
      final card = classBlock(modules, '_HomeV2MobilePairButton');
      expect(card, contains('SvgPicture.asset('));
      expect(card, isNot(contains('colorFilter:')));
    });
    testWidgets('utilidades usam os SVGs canônicos e os quatro callbacks',
        (tester) async {
      await verifyUtilityRuntime(tester, isEs: true);
      for (final token in [
        'Icons.fact_check_outlined',
        'Icons.edit_note_outlined',
        'Icons.timer_outlined'
      ]) {
        expect(modules, isNot(contains(token)));
      }
    });

    testWidgets('Meu Plantão usa proprietário exclusivamente SVG',
        (tester) async {
      await verifyGuardiaRuntime(tester);
      expect(modules, isNot(contains('Icons.medical_services_outlined')));
    });

    testWidgets('preserva geometria nativa dos SVGs e ações no modo escuro',
        (tester) async {
      await verifyUtilityRuntime(tester, dark: true);
    });
  });

  group('Home V2 — fundo chumbo', () {
    test('dark usa #1A1D23 e remove #071A23', () {
      expect(
        surface,
        contains(
          'darkPageBackground = Color(0xFF1A1D23)',
        ),
      );

      expect(
        surface,
        isNot(contains('0xFF071A23')),
      );

      expect(
        faithful,
        contains('Color(0xFF1A1D23)'),
      );

      expect(
        faithful,
        isNot(contains('Color(0xFF071A23)')),
      );
    });

    testWidgets('light usa o token produtivo e o aplica ao canvas renderizado',
        (tester) async {
      await verifyHomeComposition(tester, verifyMounted: () {
        expect(
            HomeV2SurfaceTokens.pageBackground(false), const Color(0xFFE0E6E9));
        expect(
            HomeV2SurfaceTokens.pageBackground(true), const Color(0xFF1A1D23));
        expect(
            tester.widgetList<ColoredBox>(find.byType(ColoredBox)).where(
                (w) => w.color == HomeV2SurfaceTokens.pageBackground(false)),
            isNotEmpty);
      });
    });
  });
}
