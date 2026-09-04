import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath = 'lib/screens/home_screen.dart';

  late String source;

  setUpAll(() {
    source = File(homePath).readAsStringSync();
  });

  String extractAdapter() {
    const startMarker = 'class HomeLibraryHistoryRow extends StatelessWidget';
    const endMarker = 'class HomeMiGuardiaSection extends StatelessWidget';

    final start = source.indexOf(startMarker);
    final end = source.indexOf(endMarker, start);

    expect(
      start,
      greaterThanOrEqualTo(0),
      reason: 'HomeLibraryHistoryRow deve existir.',
    );

    expect(
      end,
      greaterThan(start),
      reason:
          'HomeLibraryHistoryRow deve terminar antes de HomeMiGuardiaSection.',
    );

    return source.substring(start, end);
  }

  group('HomeLibraryHistoryRow', () {
    test('permanece fachada pública sem estado próprio', () {
      expect(
        source,
        contains(
          'class HomeLibraryHistoryRow extends StatelessWidget',
        ),
      );

      expect(
        source,
        isNot(
          contains(
            'class HomeLibraryHistoryRow extends StatefulWidget',
          ),
        ),
      );
    });

    test('preserva a ponte visual oculta de compatibilidade', () {
      final adapter = extractAdapter();

      expect(adapter, contains('return Offstage('));
      expect(adapter, contains('offstage: true'));
      expect(adapter, contains('child: HomeV2ClinicalGrid('));
      expect(adapter, contains('dark: dark'));
      expect(adapter, contains('isEs: isEs'));
      expect(adapter, contains('onPatient: () {}'));
      expect(adapter, contains('onPediatrics: () {}'));
    });

    test('preserva Ferramentas e História Clínica canônicas', () {
      final adapter = extractAdapter();

      expect(adapter, contains('onTools: () {'));
      expect(adapter, contains('onClinicalHistory: () {'));

      expect(
        RegExp(
          r'toolsScreenTabNotifier\.value\s*=\s*0;',
        ).allMatches(adapter).length,
        1,
      );

      expect(
        RegExp(
          r'onTabChange\(4\);',
        ).allMatches(adapter).length,
        1,
        reason: 'Ferramentas deve usar a aba oficial 4.',
      );

      expect(
        RegExp(
          r'onTabChange\(3\);',
        ).allMatches(adapter).length,
        1,
        reason: 'História Clínica deve usar a aba oficial 3.',
      );
    });

    test('não recria o wrapper privado removido', () {
      final adapter = extractAdapter();

      expect(
        adapter,
        isNot(
          contains('_HomeBibliotecaHClinicaRow'),
        ),
      );
    });

    test('não possui sessão, internação ou navegação paralela', () {
      final adapter = extractAdapter();

      const forbiddenTokens = <String>[
        'PacienteSession',
        'initialSession',
        'onOpenInternacion',
        'CalculadoraScreen',
        'InternacionScreen(',
        'initialUrl',
        'openProtocolById',
        'Navigator.of(',
        'LibraryCard(',
        'HistoryCard(',
        'HomeNavigator',
        'HomeActions',
        'WebViewRouter',
      ];

      for (final token in forbiddenTokens) {
        expect(
          adapter,
          isNot(contains(token)),
          reason: 'Contrato fora do escopo: "$token".',
        );
      }
    });
  });
}
