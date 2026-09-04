import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Guides use topbar-only expandable search', () {
    final source = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(source, contains('Future<void> _showGuidePortalSearch() async'));
    expect(source, contains('class _GuidePortalSearchDelegate'));
    expect(source, contains('onPressed: _showGuidePortalSearch'));
    expect(source, contains('Icons.search_rounded'));
    expect(source, contains('showSearch<GuideModel?>('));
    expect(source, contains('Buscar guía clínica'));
    expect(source, contains('Buscar guia clínico'));
  });

  test('Hero expands to 3px edge while preserving current text screen X', () {
    final source = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(
      source,
      contains('viewportWidth > 720 ? 620.0 : viewportWidth - 6.0;'),
    );
    expect(
      source,
      contains('padding: const EdgeInsets.symmetric(horizontal: 3),'),
    );
    expect(source, contains('left: 29,'));
    expect(source, contains('left: 31,'));
    expect(source, contains('right: 43,'));
  });

  test('Editorial rail and native guide bridge remain active', () {
    final source = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(source, contains('portalGuides: filtered'));
    expect(source, contains('childCount: filtered.isEmpty ? 0 : 1'));
    expect(
      source,
      contains('for (var index = 0; index < guides.length; index++)'),
    );
    expect(source, isNot(contains('scrollDirection: Axis.horizontal')));
    expect(source, contains('onOpen: _openGuide,'));
    expect(
      source,
      contains('ClinicalGuidesEditorialService.loadById(g.id)'),
    );
    expect(source, contains('article != null && article.hasEditorialBody'));
    expect(source, contains('_openPdf(g);'));
  });
}
