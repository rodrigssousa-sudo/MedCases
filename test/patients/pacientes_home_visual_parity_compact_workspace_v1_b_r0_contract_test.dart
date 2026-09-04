import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: className);

  final open = source.indexOf('{', start);
  expect(open, greaterThanOrEqualTo(0));

  var depth = 0;
  var inString = false;
  var quote = '';
  var escaped = false;

  for (var i = open; i < source.length; i++) {
    final char = source[i];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char.codeUnitAt(0) == 92) {
        escaped = true;
      } else if (char == quote) {
        inString = false;
      }
      continue;
    }

    if (char == "'" || char == '"') {
      inString = true;
      quote = char;
      continue;
    }

    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(start, i + 1);
      }
    }
  }

  fail('Unclosed class $className');
}

void main() {
  final screen =
      read('lib/screens/internacion/internacion_screen.dart');
  final summary =
      read('lib/screens/internacion/components/resumen_header.dart');
  final copilot =
      read('lib/screens/internacion/components/copilot_button.dart');

  group('Pacientes Home visual parity compact workspace', () {
    test('topbar contract remains present', () {
      expect(screen, contains('appBar: PreferredSize('));
      expect(screen, contains('preferredSize: const Size.fromHeight(48)'));
      expect(screen, contains("'PACIENTES'"));
      expect(screen, contains("isEs ? '+ Nueva' : '+ Nova'"));
    });

    test('workspace uses final 16px breathing gutter', () {
      expect(
        screen,
        contains('MEDCASES_PACIENTES_FINAL_BREATHING_GUTTER_V1_B_R0'),
      );
      expect(screen, contains('EdgeInsets.fromLTRB(16, 10, 16, 24)'));
      expect(screen, isNot(contains('left: -15.5')));
      expect(screen, isNot(contains('right: -15.5')));
    });

    test('main modules no longer receive duplicate outer surfaces', () {
      for (final token in [
        'MEDCASES_PACIENTES_PATIENT_DATA_CALLSITE_CARD_V1',
        'MEDCASES_PACIENTES_FARMACOS_CALLSITE_CARD_V1',
        'MEDCASES_PACIENTES_SOAP_CALLSITE_CARD_V1',
      ]) {
        final pos = screen.indexOf(token);
        expect(pos, greaterThanOrEqualTo(0));

        final start = pos > 900 ? pos - 900 : 0;
        final end = pos + 900 < screen.length
            ? pos + 900
            : screen.length;
        final neighborhood = screen.substring(start, end);

        expect(
          neighborhood,
          isNot(contains('left: -15.5')),
          reason: token,
        );
        expect(
          neighborhood,
          isNot(contains('right: -15.5')),
          reason: token,
        );
      }
    });

    test('summary is compact canonical surface', () {
      expect(
        summary,
        contains('MEDCASES_PACIENTES_HOME_COMPACT_SUMMARY_V1_B_R0'),
      );
      expect(summary, contains('BorderRadius.circular(8)'));
      expect(summary, contains('Color(0xFFFFFFFF)'));
      expect(summary, contains('Color(0xFF252930)'));
      expect(summary, isNot(contains('BoxShadow(')));
      expect(summary, isNot(contains('LinearGradient(')));
    });

    test('copilot is compact while processing methods remain wired', () {
      expect(
        copilot,
        contains('MEDCASES_PACIENTES_HOME_COMPACT_COPILOT_V1_B_R0'),
      );
      expect(copilot, contains('_openInputSheet'));
      expect(copilot, contains('_handleSubmit'));
      expect(copilot, contains('RevisionSheet.show('));
      expect(copilot, contains('widget.onApproved(draft)'));
      expect(copilot, contains('BorderRadius.circular(10)'));
      expect(copilot, isNot(contains('_shimmerBar(')));
    });

    test('section labels are compact without ornamental dividers', () {
      final divider = classBlock(screen, '_SectionDivider');
      expect(
        divider,
        contains(
          'MEDCASES_PACIENTES_HOME_COMPACT_SECTION_LABEL_V1_B_R0',
        ),
      );
      final normalizedDivider =
          divider.replaceAll('_SectionDivider', '');
      expect(normalizedDivider, isNot(contains('Divider(')));
    });

    test('saved patient list is compact and no fixed 176px grid remains', () {
      final grid = classBlock(screen, '_SessionsGrid');
      final card = classBlock(screen, '_SessionCard168');

      expect(
        grid,
        contains('MEDCASES_PACIENTES_HOME_COMPACT_SAVED_LIST_V1_B_R0'),
      );
      expect(grid, contains('ListView.separated('));
      expect(grid, isNot(contains('GridView.builder(')));
      expect(grid, isNot(contains('mainAxisExtent:')));

      expect(
        card,
        contains('MEDCASES_PACIENTES_HOME_COMPACT_SESSION_CARD_V1_B_R0'),
      );
      expect(card, contains('onTap: onEvolve'));
      expect(card, contains('PopupMenuButton<String>'));
      expect(card, contains("if (value == 'edit') onEdit()"));
      expect(card, contains("if (value == 'delete') onDelete()"));
    });

    test('clinical engines and callbacks remain connected', () {
      for (final token in [
        'InternacionFirestoreService.sessionsStream(uid)',
        'PatientAccordion(',
        'FarmacosAccordion(',
        'SoapSectionWidget(',
        '_onSaveEvolucion(ev)',
        '_editSession(',
        '_evolveSession(',
        '_deleteSession(',
      ]) {
        expect(screen, contains(token), reason: token);
      }
    });
  });
}
