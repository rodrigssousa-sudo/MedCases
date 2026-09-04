import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath = 'lib/screens/home_screen.dart';

  late String source;

  setUpAll(() {
    source = File(homePath).readAsStringSync();
  });

  String extractAdapter() {
    const startMarker = 'class HomeCalculatorDrugsCard extends StatelessWidget';
    const endMarker = 'class HomePatientPediatricsRow extends StatelessWidget';

    final start = source.indexOf(startMarker);
    final end = source.indexOf(endMarker, start);

    expect(
      start,
      greaterThanOrEqualTo(0),
      reason: 'HomeCalculatorDrugsCard deve existir.',
    );

    expect(
      end,
      greaterThan(start),
      reason:
          'HomeCalculatorDrugsCard deve terminar antes de HomePatientPediatricsRow.',
    );

    return source.substring(start, end);
  }

  group('HomeCalculatorDrugsCard', () {
    test('permanece fachada pública sem estado próprio', () {
      expect(
        source,
        contains(
          'class HomeCalculatorDrugsCard extends StatelessWidget',
        ),
      );

      expect(
        source,
        isNot(
          contains(
            'class HomeCalculatorDrugsCard extends StatefulWidget',
          ),
        ),
      );
    });

    test('delega a aparência ao card visual público atual', () {
      final adapter = extractAdapter();

      expect(
        adapter,
        contains('return HomeV2PrimaryClinicalCard('),
      );

      expect(adapter, contains('dark: dark'));
      expect(adapter, contains('isEs: isEs'));
      expect(adapter, contains('onTap: () {'));

      expect(
        adapter,
        isNot(
          contains('_HomeCalculadoraFarmacosCard'),
        ),
        reason: 'O wrapper privado antigo não deve ser recriado.',
      );
    });

    test('preserva exclusivamente a navegação canônica', () {
      final adapter = extractAdapter();

      expect(adapter, contains('AppHaptics.light(context);'));
      expect(adapter, contains('Navigator.of('));
      expect(adapter, contains('rootNavigator: true'));
      expect(adapter, contains('_HomeScreenState._slide('));
      expect(adapter, contains('const CalculadoraScreen()'));

      expect(
        RegExp(
          r'Navigator\.of\(',
        ).allMatches(adapter).length,
        1,
        reason: 'O adaptador deve possuir uma única navegação.',
      );

      expect(
        RegExp(
          r'CalculadoraScreen\(',
        ).allMatches(adapter).length,
        1,
        reason: 'O adaptador deve abrir somente a CalculadoraScreen.',
      );
    });

    test('não implementa WebView ou motor clínico paralelo', () {
      final adapter = extractAdapter();

      const forbiddenTokens = <String>[
        'WebViewController',
        'WebViewWidget',
        'WebViewRouter',
        'initialUrl',
        'http.get',
        'FirebaseFirestore',
        'SharedPreferences',
        'NotificationService',
        'Timer.periodic',
      ];

      for (final token in forbiddenTokens) {
        expect(
          adapter,
          isNot(contains(token)),
          reason: 'O adaptador não pode implementar "$token".',
        );
      }
    });
  });
}
