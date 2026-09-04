import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/library_screen.dart').readAsStringSync();
  });

  test('Guide count header is replaced by a zero-size widget', () {
    final start = source.indexOf('class _GuidesTab');
    final end = source.indexOf('\nclass ', start + 1);

    expect(start, isNonNegative);
    expect(end, greaterThan(start));

    final guidesTab = source.substring(start, end);

    expect(guidesTab, contains('MEDCASES_GUIDES_COUNT_HEADER_REMOVED_V1_B_R3'));
    expect(guidesTab, contains('const SizedBox.shrink()'));
  });

  test('Guide portal critical contracts remain intact', () {
    expect(source, contains('MEDCASES_GUIA_CLINICO_TRUE_LIQUID_GLASS_V1_B_R1'));
    expect(source, contains('GUIDE_SEARCH_EXACT_TITLE_ROW_GUIDE_ONLY'));
    expect(source, contains('onPressed: _showGuidePortalSearch'));
    expect(source, contains('Future<void> _loadMoreGuides()'));
    expect(source, contains('NotificationListener<ScrollNotification>'));
    expect(source, contains('ClinicalGuidesEditorialService.loadById(g.id)'));
    expect(source, contains('_openPdf(g);'));
  });

  test('Simulation remains blur 14', () {
    final start = source.indexOf('class _LibraryTopbarBg');
    final guide = source.indexOf(
      'MEDCASES_GUIA_CLINICO_TRUE_LIQUID_GLASS_V1_B_R1',
      start,
    );

    expect(start, isNonNegative);
    expect(guide, greaterThan(start));

    final simulationOwner = source.substring(start, guide);

    expect(simulationOwner, contains('if (flatSimulation)'));
    expect(
      simulationOwner,
      contains('ImageFilter.blur(sigmaX: 14, sigmaY: 14)'),
    );
  });
}
