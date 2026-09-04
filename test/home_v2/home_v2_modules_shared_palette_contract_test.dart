import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home V2 — módulos consomem a paleta compartilhada', () {
    test(
      'abandona a paleta intermediária e resolve Dark/Light pelo parâmetro dark',
      () {
        final root = Directory.current;

        final modulesFile = File(
          '${root.path}/lib/home_v2/components/home_v2_modules_view.dart',
        );
        final paletteFile = File(
          '${root.path}/lib/home_v2/theme/home_v2_palette.dart',
        );

        expect(
          modulesFile.existsSync(),
          isTrue,
          reason: 'Os módulos visuais oficiais devem existir.',
        );
        expect(
          paletteFile.existsSync(),
          isTrue,
          reason: 'A paleta compartilhada oficial deve existir.',
        );

        final modulesSource = modulesFile.readAsStringSync();
        final paletteSource = paletteFile.readAsStringSync();

        expect(
          paletteSource,
          contains('class HomeV2Palette'),
          reason: 'A paleta compartilhada pública deve permanecer disponível.',
        );
        expect(
          paletteSource,
          contains('resolve(bool dark)'),
          reason:
              'A paleta deve continuar resolvendo Dark/Light por bool dark.',
        );

        expect(
          modulesSource,
          contains("../theme/home_v2_palette.dart"),
          reason: 'Os módulos devem importar a paleta compartilhada oficial.',
        );
        expect(
          modulesSource,
          contains('HomeV2Palette.resolve(dark)'),
          reason: 'Os módulos devem resolver a paleta usando o parâmetro dark.',
        );

        expect(
          modulesSource,
          isNot(contains('abstract final class _HomeV2Palette')),
          reason: 'A paleta privada intermediária deve ser removida.',
        );
        expect(
          modulesSource,
          isNot(contains('_HomeV2Palette.')),
          reason: 'Nenhum widget deve continuar usando a paleta privada.',
        );

        const forbiddenIntermediateTokens = <String>[
          '0xFF0C1724',
          '0xFF102238',
          '0xFF152B44',
          '0xFF20364C',
          '0xFFF7F9FC',
          '0xFF9EADBD',
        ];

        for (final token in forbiddenIntermediateTokens) {
          expect(
            modulesSource,
            isNot(contains(token)),
            reason: 'Token intermediário proibido ainda presente: $token',
          );
        }

        expect(
          modulesSource,
          isNot(contains('preview/home_v2_preview_screen.dart')),
          reason: 'Produção não pode depender da tela temporária de preview.',
        );
      },
    );
  });
}
