import 'guide_runtime_fixture.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  testVerticalPortal();
  test('Current editorial cover, overlay and metadata contracts remain intact',
      () {
    final source = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(source, contains('final List<GuideModel> portalGuides;'));
    expect(
      source,
      contains('final ValueChanged<GuideModel> onOpenGuide;'),
    );
    expect(source, contains('portalGuides: filtered,'));
    expect(source, contains('onOpenGuide: onOpen,'));
    expect(source, contains('if (!featured) {'));
    expect(source, contains('return const SizedBox.shrink();'));
    expect(source, contains('const railHeight = 356.0;'));
    expect(source, contains('GestureDetector('));
    expect(source, contains('onTap: () => onOpenGuide(item)'));

    // Full-bleed visual + text overlay contract.
    expect(source, contains('StackFit.expand'));
    expect(source, contains('backgroundFor(item)'));
    expect(source, contains('LinearGradient('));
    expect(source, contains('Color(0xF2000000)'));
    expect(source, contains('item.title'));
    expect(source, contains('description'));
    expect(source, contains('category.toUpperCase()'));

    // Remote image remains the primary editorial cover source.
    expect(source, contains('item.coverUrl.trim()'));
    expect(source, contains('CachedNetworkImage('));

    // The portal surface must no longer present PDF/file metadata.
    final guideCardStart = source.indexOf('class _GuideCard');
    final errorStateStart = source.indexOf(
      'class _GuideErrorState',
      guideCardStart,
    );
    expect(guideCardStart, greaterThanOrEqualTo(0));
    expect(errorStateStart, greaterThan(guideCardStart));

    final guideCard = source.substring(
      guideCardStart,
      errorStateStart,
    );

    expect(guideCard, isNot(contains('Icons.picture_as_pdf')));
    expect(guideCard, isNot(contains('fileSizeLabel')));
    expect(guideCard, isNot(contains('downloadCount')));
  });

  test('Native article bridge and PDF fallback remain untouched', () {
    final source = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(source, contains('onOpen: _openGuide,'));
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
    expect(source, contains('_openPdf(g);'));
  });

  testPortalLabels();
}
