import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

int occurrences(String source, String token) {
  return token.allMatches(source).length;
}

void main() {
  const importChip = 'lib/screens/tools_patient_import.dart';
  const nephro = 'lib/screens/nephrology_tools_screen.dart';
  const cardio = 'lib/screens/cardio_tools_screen.dart';
  const electro = 'lib/screens/electrolytes_tools_screen.dart';
  const hepato = 'lib/screens/hepatology_tools_screen.dart';
  const tools = 'lib/screens/tools_screen.dart';

  test('TOOLS V1-H-R1 — quatro headers usam faixa plana e ícone sem box', () {
    final sources = <String>[
      read(nephro),
      read(cardio),
      read(electro),
      read(hepato),
    ];

    for (final source in sources) {
      expect(
        source,
        contains('TOOLS V1-H-R1: header plano unificado'),
      );
      expect(
        source,
        contains('TOOLS V1-H-R1: ícone sem box secundário'),
      );
      expect(
        source,
        contains('TOOLS V1-H-R1: subtítulo branco'),
      );
    }
  });

  test('TOOLS V1-H-R1 — importador compartilhado reduz 15%', () {
    final source = read(importChip);

    expect(
      source,
      contains('TOOLS V1-H-R1: redução visual de 15%'),
    );
    expect(source, contains('Transform.scale('));
    expect(source, contains('scale: 0.85'));
  });

  test('TOOLS V1-H-R1 — sexo é idêntico em Nefro e Cardio', () {
    final nephroSource = read(nephro);
    final cardioSource = read(cardio);

    for (final source in <String>[nephroSource, cardioSource]) {
      expect(
        source,
        contains('TOOLS V1-H-R1: seletor sexual unificado'),
      );
      expect(source, contains('Color(0xFF3B82F6)'));
      expect(source, contains('Color(0xFFEC4899)'));
      expect(source, contains('Color(0xFF2D3340)'));
      expect(source, contains('Color(0xFF374151)'));
      expect(source, contains('Masculino'));
      expect(source, contains('Feminino'));
    }
  });

  test('TOOLS V1-H-R1 — fatores de risco de Cardio são escuros', () {
    final source = read(cardio);

    expect(
      source,
      contains('TOOLS V1-H-R1: fatores de risco escuros'),
    );
    expect(source, contains('Color(0xFF2D3340)'));
    expect(source, contains('Color(0xFF374151)'));
    expect(source, contains('Color(0xFF10B981)'));
  });

  test('TOOLS V1-H-R1 — hints e labels dos campos são brancos', () {
    final sources = <String>[
      read(nephro),
      read(cardio),
      read(electro),
      read(hepato),
    ];

    final markerCount = sources.fold<int>(
      0,
      (sum, source) =>
          sum +
          occurrences(
            source,
            'TOOLS V1-H-R1: hints e labels brancos',
          ),
    );

    expect(markerCount, 5);

    for (final source in sources) {
      expect(source, contains('Colors.white'));
    }
  });

  test('TOOLS V1-H-R1 — topbar homologado permanece canônico', () {
    final source = read(tools);

    expect(source, contains("'FERRAMENTAS'"));
    expect(
      source,
      contains('Icons.arrow_back_ios_new_rounded'),
    );
    expect(
      source,
      isNot(contains('TOOLS V1-H-R1')),
    );
  });
}
