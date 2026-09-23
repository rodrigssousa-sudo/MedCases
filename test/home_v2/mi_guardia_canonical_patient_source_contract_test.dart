import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'home_release_runtime_harness.dart';

void main() {
  late String home;
  late String dashboard;

  setUpAll(() {
    home = File(
      'lib/screens/home_screen.dart',
    ).readAsStringSync();

    dashboard = File(
      'lib/widgets/meu_plantao_dashboard.dart',
    ).readAsStringSync();
  });

  group('Mi Guardia — fonte canônica', () {
    testWidgets('mantém duas rotas de novo paciente', (tester) async {
      expect(
        RegExp(
          r'onAddPatient\s*:\s*\(\)\s*\{',
        ).allMatches(home).length,
        2,
      );

      await verifyRealPatientRoute(tester, module: false);
      expect(home, contains('_AdultoShell('));
    });

    test('mantém initialSession', () {
      expect(
        RegExp(
          r'initialSession\s*:\s*session',
        ).allMatches(home).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('mantém stream e fallback', () {
      expect(
        dashboard,
        contains(
          'InternacionFirestoreService.sessionsStream(uid)',
        ),
      );

      expect(
        dashboard,
        contains(
          'InternacionFirestoreService.loadAllSessions(uid)',
        ),
      );

      expect(
        dashboard,
        contains(
          'InternacionPersistence.loadAllSessions()',
        ),
      );
    });

    test('callback chega ao corpo compacto', () {
      expect(
        dashboard,
        contains(
          'onAddPatient: widget.onAddPatient',
        ),
      );

      expect(
        dashboard,
        contains(
          'return _MiGuardiaCompactBody(',
        ),
      );
    });

    test('view não cria infraestrutura paralela', () {
      final start = dashboard.indexOf(
        '// MB-I.5.14-B-R6 — '
        'PROJEÇÃO VISUAL COMPACTA DE MI GUARDIA',
      );

      final end = dashboard.indexOf(
        'class _GuardiaShortcutCard extends StatefulWidget',
        start,
      );

      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final visual = dashboard.substring(start, end);

      for (final forbidden in const [
        'FirebaseFirestore.instance',
        'SharedPreferences.getInstance',
        'StreamSubscription',
        'ChangeNotifier',
        'collection(',
        'setState(',
        '_AdultoShell(',
      ]) {
        expect(
          visual,
          isNot(contains(forbidden)),
        );
      }
    });
  });
}
