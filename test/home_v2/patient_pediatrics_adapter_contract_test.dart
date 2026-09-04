import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath = 'lib/screens/home_screen.dart';

  late String source;

  setUpAll(() {
    final file = File(homePath);

    expect(
      file.existsSync(),
      isTrue,
      reason: 'A Home legada canônica deve existir.',
    );

    source = file.readAsStringSync();
  });

  group('HomePatientPediatricsRow', () {
    test('permanece uma fachada pública sem estado próprio', () {
      expect(
        source,
        contains(
          'class HomePatientPediatricsRow extends StatelessWidget',
        ),
      );

      expect(
        source,
        isNot(
          contains(
            'class HomePatientPediatricsRow extends StatefulWidget',
          ),
        ),
      );
    });

    test('delega a aparência para a grade visual pública oficial', () {
      expect(
        source,
        contains('return HomeV2ClinicalGrid('),
      );

      expect(source, contains('dark: dark'));
      expect(source, contains('isEs: isEs'));
    });

    test('preserva o destino real do card Paciente', () {
      expect(
        source,
        contains(
          '_AdultoShell(openProtocol: openProtocol)',
        ),
      );

      expect(
        source,
        contains(
          'final Function(String) openProtocol;',
        ),
      );
    });

    test('preserva o destino real do card Pediatria', () {
      expect(
        source,
        contains(
          'onTabChange(8);',
        ),
      );
    });

    test('preserva Navigator e transição canônicos', () {
      final wrapperStart = source.indexOf(
        'class HomePatientPediatricsRow extends StatelessWidget',
      );

      final privateRowStart = source.indexOf(
        'class _HomeAdultoPediatriaRow extends StatelessWidget',
        wrapperStart,
      );

      expect(wrapperStart, greaterThanOrEqualTo(0));
      expect(privateRowStart, greaterThan(wrapperStart));

      final wrapper = source.substring(
        wrapperStart,
        privateRowStart,
      );

      expect(wrapper, contains('Navigator.of(context).push('));
      expect(wrapper, contains('_HomeScreenState._slide('));
    });

    test('não conecta os placeholders da Home V2', () {
      final wrapperStart = source.indexOf(
        'class HomePatientPediatricsRow extends StatelessWidget',
      );

      final privateRowStart = source.indexOf(
        'class _HomeAdultoPediatriaRow extends StatelessWidget',
        wrapperStart,
      );

      final wrapper = source.substring(
        wrapperStart,
        privateRowStart,
      );

      const forbiddenTokens = <String>[
        'AdultCard(',
        'PatientCard(',
        'PediatricsCard(',
        'HomeNavigator',
        'HomeActions',
        'WebViewRouter',
        'debugPrint("[HOME V2]',
      ];

      for (final token in forbiddenTokens) {
        expect(
          wrapper,
          isNot(contains(token)),
          reason: 'A fachada não pode conectar o placeholder "$token".',
        );
      }
    });

    test('não altera InternacionScreen nem Pediatria', () {
      final wrapperStart = source.indexOf(
        'class HomePatientPediatricsRow extends StatelessWidget',
      );

      final privateRowStart = source.indexOf(
        'class _HomeAdultoPediatriaRow extends StatelessWidget',
        wrapperStart,
      );

      final wrapper = source.substring(
        wrapperStart,
        privateRowStart,
      );

      expect(
        wrapper,
        isNot(contains('class InternacionScreen')),
      );

      expect(
        wrapper,
        isNot(contains('class _PediatricsShell')),
      );

      expect(
        wrapper,
        isNot(contains('class _AdultoShell')),
      );
    });
  });
}
