import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Library opens editorial guides natively and preserves PDF fallback',
      () {
    final source = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import '../services/clinical_guides_editorial_service.dart';",
      ),
    );
    expect(
      source,
      contains("import 'clinical_guide_article_screen.dart';"),
    );
    expect(
      source,
      contains('Future<void> _openGuide(GuideModel g) async'),
    );
    expect(
      source,
      contains('ClinicalGuidesEditorialService.loadById(g.id)'),
    );
    expect(
      source,
      contains('article != null && article.hasEditorialBody'),
    );
    expect(source, contains('ClinicalGuideArticleScreen('));
    expect(source, contains('_openPdf(g);'));
    expect(source, contains('onOpen: _openGuide,'));
    expect(source, isNot(contains('onOpen: _openPdf,')));
  });
}
