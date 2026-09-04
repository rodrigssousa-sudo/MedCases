import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String meu;
  late String library;
  late String common;

  setUpAll(() {
    meu = File('lib/widgets/meu_plantao_dashboard.dart').readAsStringSync();
    library = File('lib/screens/library_screen.dart').readAsStringSync();
    common = File('lib/widgets/common_widgets.dart').readAsStringSync();
  });

  test('Meu Plantao SOAP copy-sheet generic UI uses canonical accent', () {
    expect(
      meu,
      contains(
        'border: Border.all(color: const Color(0xFF0D6B57).withOpacity(0.25)),',
      ),
    );
    expect(
      meu,
      contains('colors: [Color(0xFF0D6B57), Color(0xFF0D6B57)],'),
    );
    expect(meu, contains('iconColor: const Color(0xFF0D6B57),'));
    expect(meu, contains('badgeColor: const Color(0xFF0D6B57),'));
  });

  test('Meu Plantao semantic and taxonomy greens stay distinct', () {
    expect(meu, contains("labelPt: 'Referência',"));
    expect(
      meu,
      contains('return const Color(0xFF10B981); // green = stable'),
    );
    expect(
      meu,
      contains('colors: [Color(0xFF0A7C4E), Color(0xFF10B981)],'),
    );
    expect(
      meu,
      contains("label: widget.isEs ? 'Fármacos' : 'Fármacos',"),
    );
  });

  test('Library remaining greens stay taxonomy/category colors', () {
    expect(
      library,
      contains(
        "case 'Infectologia':\n        return const Color(0xFF10B981);",
      ),
    );
    expect(
      library,
      contains(
        'iconColor: Color(0xFF34D399), // verde esmeralda clínico',
      ),
    );
    expect(library, contains('color: Color(0x2410B981),'));
  });

  test('Common Widgets green evidence/status palette is preserved', () {
    expect(
      common,
      contains(
        "Color get green => dark ? const Color(0xFF10B981) : const Color(0xFF075f45);",
      ),
    );
    expect(
      common,
      contains("_EvBadge('✓ Revisado', const Color(0xFF059669))"),
    );
    expect(common, contains("case 'Directriz':"));
    expect(common, contains("label: 'Estado',"));
    expect(common, contains('value: ev.reviewStatus,'));
  });
}
