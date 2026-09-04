import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  final screen =
      read('lib/screens/internacion/internacion_screen.dart');
  final summary =
      read('lib/screens/internacion/components/resumen_header.dart');
  final copilot =
      read('lib/screens/internacion/components/copilot_button.dart');

  group('Pacientes final breathing + AI emphasis', () {
    test('workspace has 16px lateral breathing gutter', () {
      expect(
        screen,
        contains('MEDCASES_PACIENTES_FINAL_BREATHING_GUTTER_V1_B_R0'),
      );
      expect(
        screen,
        contains('EdgeInsets.fromLTRB(16, 10, 16, 24)'),
      );
      expect(
        screen,
        isNot(contains('EdgeInsets.fromLTRB(4, 6, 4, 24)')),
      );
    });

    test('patient summary is thicker but still compact', () {
      expect(
        summary,
        contains('MEDCASES_PACIENTES_FINAL_BREATHING_SUMMARY_V1_B_R0'),
      );
      expect(summary, contains('EdgeInsets.fromLTRB(12, 12, 12, 12)'));
      expect(summary, contains('fontSize: 15'));
      expect(summary, contains('fontSize: 11.5'));
      expect(summary, isNot(contains('BoxShadow(')));
      expect(summary, isNot(contains('med_typography.dart')));
    });

    test('MedCases Inteligente receives distinctive IA surface', () {
      expect(
        copilot,
        contains('MEDCASES_PACIENTES_FINAL_AI_EMPHASIS_V1_B_R0'),
      );
      expect(copilot, contains('Color(0xFF202A29)'));
      expect(copilot, contains('Color(0xFFF4FAF7)'));
      expect(copilot, contains('Border.all('));
      expect(
        copilot,
        contains('MEDCASES_PACIENTES_AI_SIGNATURE_CARD_V1_B_R0'),
      );
      expect(
        copilot,
        contains("assets/icons/home_v2/ic_ia.svg"),
      );
      expect(copilot, contains("'IA CLÍNICA'"));
      expect(copilot, contains("'Abrir'"));

      final aiMarker =
          copilot.indexOf('MEDCASES_PACIENTES_FINAL_AI_EMPHASIS_V1_B_R0');
      expect(aiMarker, greaterThanOrEqualTo(0));

      final idleMarker = copilot.indexOf(
        '// ── Estado idle',
        aiMarker,
      );
      expect(idleMarker, greaterThan(aiMarker));

      final aiCardBuild = copilot.substring(aiMarker, idleMarker);
      expect(aiCardBuild, isNot(contains('LinearGradient(')));
      expect(aiCardBuild, isNot(contains('BoxShadow(')));
    });

    test('saved patient card gets breathing without changing actions', () {
      expect(
        screen,
        contains('MEDCASES_PACIENTES_FINAL_BREATHING_SESSION_CARD_V1_B_R0'),
      );
      expect(
        screen,
        contains('EdgeInsets.fromLTRB(11, 11, 8, 11)'),
      );
      expect(screen, contains('onTap: onEvolve'));
      expect(screen, contains("if (value == 'edit') onEdit()"));
      expect(screen, contains("if (value == 'delete') onDelete()"));
    });

    test('clinical engines remain connected', () {
      for (final token in [
        'PatientAccordion(',
        'FarmacosAccordion(',
        'SoapSectionWidget(',
        'InternacionFirestoreService.sessionsStream(uid)',
        '_onSaveEvolucion(ev)',
        '_editSession(',
        '_evolveSession(',
        '_deleteSession(',
      ]) {
        expect(screen, contains(token), reason: token);
      }
    });

    test('topbar remains 48px', () {
      expect(screen, contains('preferredSize: const Size.fromHeight(48)'));
      expect(screen, contains("'PACIENTES'"));
      expect(screen, contains("isEs ? '+ Nueva' : '+ Nova'"));
    });
  });
}
