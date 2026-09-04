import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const modulesPath = 'lib/home_v2/components/home_v2_modules_view.dart';

  late String source;

  setUpAll(() {
    source = File(modulesPath).readAsStringSync();
  });

  String extractBlock(String startMarker, String endMarker) {
    final start = source.indexOf(startMarker);
    final end = source.indexOf(endMarker, start);

    expect(
      start,
      greaterThanOrEqualTo(0),
      reason: 'Bloco inicial ausente: $startMarker',
    );

    expect(
      end,
      greaterThan(start),
      reason: 'Bloco final ausente: $endMarker',
    );

    return source.substring(start, end);
  }

  group('Home V2 — views clínicas primárias oficiais', () {
    test('expõe card primário e grade clínica como views separadas', () {
      expect(
        source,
        contains(
          'class HomeV2PrimaryClinicalCard extends StatelessWidget',
        ),
      );

      expect(
        source,
        contains(
          'class HomeV2ClinicalGrid extends StatelessWidget',
        ),
      );

      expect(
        source,
        isNot(
          contains(
            'class HomeV2PrimaryClinicalCluster extends StatelessWidget',
          ),
        ),
        reason: 'O wrapper público antigo não deve ser recriado.',
      );
    });

    test('card primário preserva aparência e callback externos', () {
      final card = extractBlock(
        'class HomeV2PrimaryClinicalCard extends StatelessWidget',
        'class HomeV2ClinicalGrid extends StatelessWidget',
      );

      expect(card, contains('final VoidCallback onTap;'));
      expect(card, contains('HomeV2Palette.resolve(dark)'));
      expect(card, contains('return HomeV2PressSurface('));
      expect(card, contains('onTap: onTap'));
      expect(card, contains('FÁRMACOS & CALCULADORAS'));
      expect(
        card,
        contains('assets/icons/home_v2/ic_farmacos.svg'),
      );
    });

    test('grade clínica preserva quatro callbacks visuais', () {
      final grid = extractBlock(
        'class HomeV2ClinicalGrid extends StatelessWidget',
        'class HomeV2UtilityRow extends StatelessWidget',
      );

      const callbacks = <String>[
        'final VoidCallback onPatient;',
        'final VoidCallback onPediatrics;',
        'final VoidCallback onTools;',
        'final VoidCallback onClinicalHistory;',
      ];

      for (final callback in callbacks) {
        expect(grid, contains(callback));
      }

      const assets = <String>[
        'assets/icons/home_v2/ic_paciente.svg',
        'assets/icons/home_v2/ic_pediatria.svg',
        'assets/icons/home_v2/ic_ferramentas.svg',
        'assets/icons/home_v2/ic_historia.svg',
      ];

      for (final asset in assets) {
        expect(grid, contains(asset));
      }
    });

    test('camada visual não possui motores funcionais paralelos', () {
      const forbiddenTokens = <String>[
        'Navigator.of(',
        'SharedPreferences',
        'NotificationService',
        'FirebaseFirestore',
        'WebViewController',
        'Timer.periodic',
      ];

      for (final token in forbiddenTokens) {
        expect(
          source,
          isNot(contains(token)),
          reason: 'A camada visual não pode possuir o motor "$token".',
        );
      }
    });
  });
}
