import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: className);
  final next = source.indexOf('\nclass ', start + 7);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  final tools = File('lib/screens/tools_screen.dart').readAsStringSync();

  group('Pediatria final first-card title references V1-B-R0-R2', () {
    test('places first clinical card 0.1px below subnav', () {
      final state = classBlock(tools, '_PediatricsTabContentState');

      expect(state, contains('const SizedBox(height: 0)'));
      expect(
        state,
        contains(
          'padding: const EdgeInsets.fromLTRB(0.1, 0.1, 0.1, 100)',
        ),
      );
    });

    test('reduces only main section/card titles to 14px', () {
      final scale = classBlock(tools, '_PediatricsVisualScaleR3');

      expect(scale, contains('static const double sectionTitle = 14.0'));
      expect(scale, contains('static const double sectionLabel = 13.0'));
      expect(scale, contains('static const double subsectionTitle = 12.5'));
      expect(scale, contains('static const double body = 14.5'));
    });

    test('references are collapsed by default and expand on tap', () {
      final widget = classBlock(tools, '_PedSourceNote');
      final state = classBlock(tools, '_PedSourceNoteState');

      expect(widget, contains('extends StatefulWidget'));
      expect(
        widget,
        contains(
            'State<_PedSourceNote> createState() => _PedSourceNoteState()'),
      );

      expect(state, contains('bool _expanded = false'));
      expect(
        state,
        contains('onTap: () => setState(() => _expanded = !_expanded)'),
      );
      expect(state, contains('if (_expanded)'));
      expect(state, contains('widget.text'));
    });

    test('references preserve PT ES and explicit disclosure affordance', () {
      final state = classBlock(tools, '_PedSourceNoteState');

      expect(
        state,
        contains("widget.isEs ? 'Referencias' : 'Referências'"),
      );
      expect(state, contains('Icons.menu_book_outlined'));
      expect(state, contains('Icons.keyboard_arrow_down_rounded'));
      expect(state, contains('Icons.keyboard_arrow_up_rounded'));
      expect(state, contains('_PediatricsVisualScaleR3.micro'));
    });

    test('keeps premium card geometry and one pixel between cards', () {
      final card = classBlock(tools, '_PedFlatSection');

      expect(
        card,
        contains('padding: const EdgeInsets.fromLTRB(13, 10, 13, 10)'),
      );
      expect(
        classBlock(tools, '_PedSectionGap'),
        contains('SizedBox(height: 1)'),
      );
    });

    test('preserves clinical engines and four localized routes', () {
      for (final token in <String>[
        'PediatricGrowthEngineV2026',
        'PediatricRenalEngineV2026',
        'BrightonPewsEngineV2026',
        'PediatricReferenceRegistryV2026',
        "const ['BIOMETRÍA', 'CRECIMIENTO', 'FUNCIÓN RENAL', 'PEWS']",
        "const ['BIOMETRIA', 'CRESCIMENTO', 'FUNÇÃO RENAL', 'PEWS']",
      ]) {
        expect(tools, contains(token), reason: token);
      }
    });
  });
}
